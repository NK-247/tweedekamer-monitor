{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        a.id,
        a.actor_naam,
        a.functie,
        a.relatie,
        a.sid_actor,
        a.persoon__ref AS persoon_id,
        a.document__ref AS document_id,
        a.actor_fractie,
        a.fractie__ref AS fractie_id,
        a.verwijderd,
        a.bijgewerkt AS gewijzigd_op,
        a.feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'document_actor') }} AS a
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY a.id
        ORDER BY a.bijgewerkt DESC, a.feed_updated DESC, a._dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, document_id, persoon_id, fractie_id),
        CASE WHEN document.id IS NOT NULL THEN latest.document_id END AS document_id,
        CASE WHEN person.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        CASE WHEN faction.id IS NOT NULL THEN latest.fractie_id END AS fractie_id
    FROM latest
    LEFT JOIN {{ ref('document') }} AS document ON latest.document_id = document.id
    LEFT JOIN {{ ref('persoon') }} AS person ON latest.persoon_id = person.id
    LEFT JOIN {{ ref('fractie') }} AS faction ON latest.fractie_id = faction.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming