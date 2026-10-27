{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        zaak__ref AS zaak_id,
        persoon__ref AS persoon_id,
        fractie__ref AS fractie_id,
        commissie__ref AS commissie_id,
        actor_naam,
        actor_fractie,
        actor_afkorting,
        functie,
        relatie,
        sid_actor,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'zaak_actor') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN zaak.id IS NOT NULL THEN latest.zaak_id END AS zaak_id,
        CASE WHEN person.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        CASE WHEN faction.id IS NOT NULL THEN latest.fractie_id END AS fractie_id,
        CASE WHEN committee.id IS NOT NULL THEN latest.commissie_id END AS commissie_id,
        latest.actor_naam,
        latest.actor_fractie,
        latest.actor_afkorting,
        latest.functie,
        latest.relatie,
        latest.sid_actor,
        latest.gewijzigd_op,
        latest.api_gewijzigd_op
    FROM latest
    LEFT JOIN {{ ref('zaak') }} AS zaak ON latest.zaak_id = zaak.id
    LEFT JOIN {{ ref('persoon') }} AS person ON latest.persoon_id = person.id
    LEFT JOIN {{ ref('fractie') }} AS faction ON latest.fractie_id = faction.id
    LEFT JOIN {{ ref('commissie') }} AS committee ON latest.commissie_id = committee.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT
    id,
    zaak_id,
    persoon_id,
    fractie_id,
    commissie_id,
    actor_naam,
    actor_fractie,
    actor_afkorting,
    functie,
    relatie,
    sid_actor,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming