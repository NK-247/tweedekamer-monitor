{{ config(contract={'enforced': true}) }}

WITH current_besluiten AS (
    SELECT id, _dlt_id, feed_updated AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'besluit') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
       AND NOT verwijderd
),
links AS (
    SELECT DISTINCT
        parent.id AS besluit_id,
        link.ref AS zaak_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'besluit__zaak') }} AS link
    JOIN current_besluiten AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
)

SELECT links.*
FROM links
JOIN {{ ref('besluit') }} AS besluit ON links.besluit_id = besluit.id
JOIN {{ ref('zaak') }} AS zaak ON links.zaak_id = zaak.id