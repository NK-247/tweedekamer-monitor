{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        v.id,
        v.status,
        v.versienummer,
        v.bestandsgrootte,
        v.extensie,
        CAST(v.datum AS DATE) AS datum,
        v.externeidentifier,
        v.document__ref AS document_id,
        v.verwijderd,
        v.bijgewerkt AS gewijzigd_op,
        v.feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'document_versie') }} AS v
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY v.id
        ORDER BY v.bijgewerkt DESC, v.feed_updated DESC, v._dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, document_id),
        CASE WHEN document.id IS NOT NULL THEN latest.document_id END AS document_id
    FROM latest
    LEFT JOIN {{ ref('document') }} AS document ON latest.document_id = document.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming