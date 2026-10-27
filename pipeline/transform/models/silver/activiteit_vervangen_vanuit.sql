{{
    config(
        contract={'enforced': true}
    )
}}

WITH current_activiteiten AS (
    SELECT id, _dlt_id, feed_updated AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'activiteit') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1 AND NOT verwijderd
),
links AS (
    SELECT DISTINCT
        parent.id AS activiteit_id,
        link.ref AS vervangen_vanuit_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'activiteit__vervangen_vanuit') }} AS link
    INNER JOIN current_activiteiten AS parent
        ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
),

incoming AS (
    SELECT links.*
    FROM links
    INNER JOIN {{ ref('activiteit') }} AS activity
        ON links.activiteit_id = activity.id
    INNER JOIN {{ ref('activiteit') }} AS replaced
        ON links.vervangen_vanuit_id = replaced.id
)

SELECT * FROM incoming