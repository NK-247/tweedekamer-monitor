{{ config(contract={'enforced': true}) }}
WITH current_zaken AS (
    SELECT id, _dlt_id, feed_updated AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'zaak') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1 AND NOT verwijderd
),
links AS (
    SELECT DISTINCT parent.id AS zaak_id, link.ref AS gerelateerd_vanuit_id, parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'zaak__gerelateerd_vanuit') }} AS link
    JOIN current_zaken AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
)
SELECT links.* FROM links
JOIN {{ ref('zaak') }} zaak ON links.zaak_id = zaak.id
JOIN {{ ref('zaak') }} parent ON links.gerelateerd_vanuit_id = parent.id