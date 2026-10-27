{{ config(contract={'enforced': true}) }}

WITH current_toezeggingen AS (
    SELECT id, _dlt_id
    FROM {{ source('bronze', 'toezegging') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
       AND NOT verwijderd
),
links AS (
    SELECT
        parent.id AS toezegging_id,
        link.ref AS herhaling_van_id,
        MAX(link.bijgewerkt) AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'toezegging__is_herhaling_van') }} AS link
    JOIN current_toezeggingen AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
    GROUP BY parent.id, link.ref
)

SELECT links.*
FROM links
JOIN {{ ref('toezegging') }} AS toezegging ON links.toezegging_id = toezegging.id
JOIN {{ ref('toezegging') }} AS herhaling ON links.herhaling_van_id = herhaling.id