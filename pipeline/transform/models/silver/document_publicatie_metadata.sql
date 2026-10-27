{{
    config(
        contract={'enforced': true}
    )
}}

WITH links AS (
    SELECT
        _dlt_parent_id,
        MAX(CASE WHEN rel = 'enclosure' THEN href END) AS document_url
    FROM {{ source('bronze', 'document_publicatie_metadata__atom_links') }}
    GROUP BY 1
),

latest AS (
    SELECT
        m.id,
        m.content_type,
        m.content_length,
        m.identifier,
        m.document_type,
        m.file_name,
        m.source,
        CAST(m.publicatie_datum AS DATE) AS publicatie_datum,
        m.url,
        l.document_url,
        m.document_versie__ref AS document_versie_id,
        m.verwijderd,
        m.bijgewerkt AS gewijzigd_op,
        m.feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'document_publicatie_metadata') }} AS m
    LEFT JOIN links AS l ON m._dlt_id = l._dlt_parent_id
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY m.id
        ORDER BY m.bijgewerkt DESC, m.feed_updated DESC, m._dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, document_versie_id),
        CASE WHEN version.id IS NOT NULL THEN latest.document_versie_id END AS document_versie_id
    FROM latest
    LEFT JOIN {{ ref('document_versie') }} AS version
        ON latest.document_versie_id = version.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming