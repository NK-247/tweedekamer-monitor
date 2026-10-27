{{ config(contract={'enforced': true}) }}

WITH current_toezeggingen AS (
    SELECT id, _dlt_id, feed_updated AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'toezegging') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
       AND NOT verwijderd
),
links AS (
    SELECT DISTINCT
        parent.id AS toezegging_id,
        link.ref AS document_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'toezegging__kamerbrief_nakoming') }} AS link
    JOIN current_toezeggingen AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
)

SELECT links.*
FROM links
JOIN {{ ref('toezegging') }} AS toezegging ON links.toezegging_id = toezegging.id
JOIN {{ ref('document') }} AS document ON links.document_id = document.id