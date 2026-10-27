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
        link.ref AS activiteit_id,
        parent.relatie_gewijzigd_op
    FROM {{ source('bronze', 'document__activiteit') }} AS link
    JOIN current_documents AS parent ON link._dlt_parent_id = parent._dlt_id
    WHERE link.ref IS NOT NULL
)

SELECT links.*
FROM links
JOIN {{ ref('document') }} AS document ON links.document_id = document.id
JOIN {{ ref('activiteit') }} AS activiteit ON links.activiteit_id = activiteit.id