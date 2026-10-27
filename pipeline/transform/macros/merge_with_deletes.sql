{% macro get_incremental_merge_with_deletes_sql(arg_dict) %}
    {% set target_relation = arg_dict['target_relation'] %}
    {% set temp_relation = arg_dict['temp_relation'] %}
    {% set unique_key = arg_dict['unique_key'] %}
    {% set dest_columns = arg_dict['dest_columns'] %}
    {% set incremental_predicates = arg_dict.get('incremental_predicates') %}
    {% set deletion_relation = config.get('deletion_relation') %}

    {% if not deletion_relation %}
        {{ exceptions.raise_compiler_error(
            "incremental_strategy='merge_with_deletes' requires deletion_relation"
        ) }}
    {% endif %}

    {% set unique_keys = [unique_key] if unique_key is string else unique_key %}
    {% set deletion_key = unique_keys[0] %}

    {% set column_names = dest_columns | map(attribute='name') | list %}
    {% set quoted_columns = get_quoted_csv(column_names) %}
    {% set active_values = [] %}
    {% set source_values = [] %}
    {% set update_statements = [] %}

    {% for column_name in column_names %}
        {% do active_values.append('DBT_ACTIVE_SOURCE.' ~ adapter.quote(column_name)) %}
        {% do source_values.append('DBT_SOURCE.' ~ adapter.quote(column_name)) %}
        {% if column_name not in unique_keys %}
            {% set update_statement %}
                UPDATE {{ target_relation }} AS DBT_TARGET
                SET {{ adapter.quote(column_name) }} = DBT_SOURCE.{{ adapter.quote(column_name) }}
                FROM {{ temp_relation }} AS DBT_SOURCE
                WHERE {% for key in unique_keys %}DBT_TARGET.{{ adapter.quote(key) }} = DBT_SOURCE.{{ adapter.quote(key) }}{% if not loop.last %} AND {% endif %}{% endfor %}
                  AND DBT_TARGET.{{ adapter.quote(column_name) }} IS DISTINCT FROM DBT_SOURCE.{{ adapter.quote(column_name) }}
            {% endset %}
            {% do update_statements.append(update_statement) %}
        {% endif %}
    {% endfor %}

    {% if deletion_relation == 'none' %}
        {% set latest_deleted_sql %}
            SELECT NULL AS id
            WHERE FALSE
        {% endset %}
        {% set stale_sql %}
            DELETE FROM {{ target_relation }} AS DBT_TARGET
            WHERE NOT EXISTS (
                SELECT 1
                FROM {{ temp_relation }} AS DBT_SOURCE
                WHERE {% for key in unique_keys %}DBT_TARGET.{{ adapter.quote(key) }} = DBT_SOURCE.{{ adapter.quote(key) }}{% if not loop.last %} AND {% endif %}{% endfor %}
            )
        {% endset %}
    {% else %}
        {% set latest_deleted_sql %}
            SELECT {{ deletion_key }}
            FROM (
                SELECT
                    {{ deletion_key }},
                    verwijderd,
                    ROW_NUMBER() OVER (
                        PARTITION BY {{ deletion_key }}
                        ORDER BY bijgewerkt DESC NULLS LAST, feed_updated DESC NULLS LAST, _dlt_id DESC
                    ) AS version_number
                FROM {{ deletion_relation }}
            ) AS latest
            WHERE version_number = 1
                AND verwijderd = true
        {% endset %}
        {% set stale_sql %}
            SELECT NULL
            WHERE FALSE
        {% endset %}
    {% endif %}

    {#
        DuckDB's FK constraint checks are over-eager against a live correlated subquery
        re-evaluated across several statements/chunks (a documented ART index
        limitation), so the deleted-keys set is materialized once into a real temp
        table and every cascade/delete statement below references that table instead.
    #}
    {% set deleted_keys_table = '_deleted_keys_' ~ target_relation.identifier %}
    {% set materialize_deleted_keys = [] %}
    {% if deletion_relation != 'none' %}
        {% set materialize_deleted_keys_sql %}
            CREATE OR REPLACE TEMP TABLE {{ deleted_keys_table }} AS (
                {{ latest_deleted_sql }}
            )
        {% endset %}
        {% do materialize_deleted_keys.append(materialize_deleted_keys_sql) %}
    {% endif %}

    {#
        Cascade deletes are resolved by walking the physical foreign-key graph of the
        schema at compile time (BFS from this model's table) instead of hardcoding
        table names. A back-edge (a descendant pointing back at this table, e.g.
        document.huidige_document_versie_id -> document_versie.id) is nulled out
        before its target is deleted, rather than treated as a further cascade.
    #}
    {% set prep_statements = [] %}
    {% set cascade_deletes = [] %}
    {% if execute and deletion_relation != 'none' %}
        {% set edges_query %}
            SELECT
                kcu.table_name AS child_table,
                kcu.column_name AS child_column,
                ccu.table_name AS parent_table,
                ccu.column_name AS parent_column
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
                ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
            JOIN information_schema.referential_constraints AS rc
                ON tc.constraint_name = rc.constraint_name AND tc.table_schema = rc.constraint_schema
            JOIN information_schema.constraint_column_usage AS ccu
                ON rc.unique_constraint_name = ccu.constraint_name AND rc.unique_constraint_schema = ccu.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema = '{{ target_relation.schema }}'
        {% endset %}
        {% set edges_result = run_query(edges_query) %}
        {% set edges = [] %}
        {% for row in edges_result.rows %}
            {% do edges.append({'child_table': row[0], 'child_column': row[1], 'parent_table': row[2], 'parent_column': row[3]}) %}
        {% endfor %}

        {% set root_table = target_relation.identifier %}
        {% set membership = {root_table: '"' ~ deletion_key ~ '" IN (SELECT "' ~ deletion_key ~ '" FROM ' ~ deleted_keys_table ~ ')'} %}
        {% set depth_of = {root_table: 0} %}
        {% set deletes_by_depth = {} %}

        {% for _ in range(10) %}
            {% for edge in edges %}
                {% if edge.parent_table in membership %}
                    {% set parent_filter = membership[edge.parent_table] %}
                    {% if edge.child_table == root_table and edge.parent_table != root_table %}
                        {% set null_statement %}
                            UPDATE {{ target_relation }}
                            SET {{ adapter.quote(edge.child_column) }} = NULL
                            WHERE "{{ edge.child_column }}" IN (
                                SELECT "{{ edge.parent_column }}"
                                FROM "{{ target_relation.schema }}"."{{ edge.parent_table }}"
                                WHERE {{ parent_filter }}
                            )
                        {% endset %}
                        {% if null_statement not in prep_statements %}
                            {% do prep_statements.append(null_statement) %}
                        {% endif %}
                    {% else %}
                        {% set child_filter = '"' ~ edge.child_column ~ '" IN (SELECT "' ~ edge.parent_column ~ '" FROM "' ~ target_relation.schema ~ '"."' ~ edge.parent_table ~ '" WHERE ' ~ parent_filter ~ ')' %}
                        {% set delete_statement %}
                            DELETE FROM "{{ target_relation.schema }}"."{{ edge.child_table }}"
                            WHERE {{ child_filter }}
                        {% endset %}
                        {% set child_depth = depth_of[edge.parent_table] + 1 %}
                        {% do deletes_by_depth.setdefault(child_depth, []) %}
                        {% if delete_statement not in deletes_by_depth[child_depth] %}
                            {% do deletes_by_depth[child_depth].append(delete_statement) %}
                        {% endif %}
                        {% if edge.child_table not in membership %}
                            {% do membership.update({edge.child_table: child_filter}) %}
                            {% do depth_of.update({edge.child_table: child_depth}) %}
                        {% endif %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endfor %}

        {#
            DuckDB's foreign-key check for a DELETE does not see other DELETEs from
            earlier in the same open transaction, so each depth of the cascade (deepest
            descendants first) must be committed before the next, shallower depth runs.
        #}
        {% set cascade_deletes = [] %}
        {% for depth in deletes_by_depth.keys() | sort(reverse=True) %}
            {% do cascade_deletes.append(deletes_by_depth[depth] | join(';\n')) %}
        {% endfor %}
        {% set cascade_deletes = cascade_deletes | join(';\nCOMMIT;\nBEGIN;\n') %}
        {% set cascade_deletes = [cascade_deletes] if cascade_deletes else [] %}
    {% endif %}

    {% if deletion_relation == 'none' %}
        {% set delete_sql %}
            DELETE FROM {{ target_relation }} AS DBT_TARGET
            WHERE FALSE
        {% endset %}
    {% else %}
        {% set delete_sql %}
            DELETE FROM {{ target_relation }} AS DBT_TARGET
            WHERE {% for key in unique_keys %}{{ adapter.quote(key) }} IN (
                SELECT {{ deletion_key }}
                FROM {{ deleted_keys_table }}
            ){% if not loop.last %} OR {% endif %}{% endfor %}
        {% endset %}
    {% endif %}

    {% set insert_sql %}
        INSERT INTO {{ target_relation }} ({{ quoted_columns }})
        SELECT {{ source_values | join(', ') }}
        FROM {{ temp_relation }} AS DBT_SOURCE
        WHERE NOT EXISTS (
            SELECT 1
            FROM {{ target_relation }} AS DBT_TARGET
            WHERE {% for key in unique_keys %}DBT_TARGET.{{ adapter.quote(key) }} = DBT_SOURCE.{{ adapter.quote(key) }}{% if not loop.last %} AND {% endif %}{% endfor %}
        )
    {% endset %}

    {% set statement_groups = [] %}
    {% if materialize_deleted_keys %}
        {% do statement_groups.append(materialize_deleted_keys | join(';\n')) %}
    {% endif %}
    {% if prep_statements %}
        {% do statement_groups.append(prep_statements | join(';\n')) %}
    {% endif %}
    {% if cascade_deletes %}
        {% do statement_groups.append(cascade_deletes | join(';\n')) %}
    {% endif %}
    {#
        DuckDB's foreign-key check for the parent DELETE below does not see the cascade
        deletes above unless they are committed first, so force a commit boundary
        between cleanup and the actual merge.
    #}
    {% if prep_statements or cascade_deletes %}
        {% do statement_groups.append('COMMIT;\nBEGIN') %}
    {% endif %}
    {% do statement_groups.append(delete_sql) %}
    {% do statement_groups.append(update_statements | join(';\n')) %}
    {% do statement_groups.append(insert_sql) %}

    {{ return(statement_groups | join(';\n')) }}
{% endmacro %}