{{ config(contract={'enforced': true}) }}

WITH current_documents AS (
    SELECT id, _dlt_id, feed_updated AS relatie_gewijzigd_op
    FROM {{ source('bronze', 'document') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),
links AS (
    SELECT DISTINCT
        parent.id AS document_id,
        link.ref AS agendapunt_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'document__agendapunt') }} AS link
    JOIN current_documents AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
)

SELECT links.*
FROM links
JOIN {{ ref('document') }} AS document ON links.document_id = document.id
JOIN {{ ref('agendapunt') }} AS agendapunt ON links.agendapunt_id = agendapunt.id