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
        CAST(link._dlt_list_idx AS INTEGER) AS volgorde,
        link.persoon__ref AS persoon_id,
        link.fractie__ref AS fractie_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'toezegging__toegezegd_aan') }} AS link
    JOIN current_toezeggingen AS parent ON link._dlt_parent_id = parent._dlt_id
)

SELECT
    links.toezegging_id,
    links.volgorde,
    links.persoon_id,
    links.fractie_id,
    links.relatie_gewijzigd_op
FROM links
JOIN {{ ref('toezegging') }} AS toezegging ON links.toezegging_id = toezegging.id
LEFT JOIN {{ ref('persoon') }} AS persoon ON links.persoon_id = persoon.id
LEFT JOIN {{ ref('fractie') }} AS fractie ON links.fractie_id = fractie.id
WHERE (links.persoon_id IS NULL OR persoon.id IS NOT NULL)
  AND (links.fractie_id IS NULL OR fractie.id IS NOT NULL)