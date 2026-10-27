{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        besluit__ref AS besluit_id,
        soort,
        CAST(fractie_grootte AS INTEGER) AS fractie_grootte,
        actor_naam,
        actor_fractie,
        vergissing,
        sid_actor_lid,
        sid_actor_fractie,
        persoon__ref AS persoon_id,
        fractie__ref AS fractie_id,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'stemming') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, besluit_id, persoon_id, fractie_id),
        CASE WHEN besluit.id IS NOT NULL THEN latest.besluit_id END AS besluit_id,
        CASE WHEN persoon.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        CASE WHEN fractie.id IS NOT NULL THEN latest.fractie_id END AS fractie_id
    FROM latest
    LEFT JOIN {{ ref('besluit') }} AS besluit
        ON latest.besluit_id = besluit.id
    LEFT JOIN {{ ref('persoon') }} AS persoon
        ON latest.persoon_id = persoon.id
    LEFT JOIN {{ ref('fractie') }} AS fractie
        ON latest.fractie_id = fractie.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming