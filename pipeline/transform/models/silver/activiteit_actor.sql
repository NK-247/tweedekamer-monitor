{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        activiteit__ref AS activiteit_id,
        commissie__ref AS commissie_id,
        persoon__ref AS persoon_id,
        fractie__ref AS fractie_id,
        actor_naam,
        actor_fractie,
        relatie,
        CAST(volgorde AS INTEGER) AS volgorde,
        functie,
        spreektijd,
        sid_actor,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'activiteit_actor') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN activity.id IS NOT NULL THEN latest.activiteit_id END AS activiteit_id,
        CASE WHEN committee.id IS NOT NULL THEN latest.commissie_id END AS commissie_id,
        CASE WHEN person.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        CASE WHEN faction.id IS NOT NULL THEN latest.fractie_id END AS fractie_id,
        latest.actor_naam,
        latest.actor_fractie,
        latest.relatie,
        latest.volgorde,
        latest.functie,
        latest.spreektijd,
        latest.sid_actor,
        latest.gewijzigd_op,
        latest.api_gewijzigd_op
    FROM latest
    LEFT JOIN {{ ref('activiteit') }} AS activity
        ON latest.activiteit_id = activity.id
    LEFT JOIN {{ ref('commissie') }} AS committee
        ON latest.commissie_id = committee.id
    LEFT JOIN {{ ref('persoon') }} AS person
        ON latest.persoon_id = person.id
    LEFT JOIN {{ ref('fractie') }} AS faction
        ON latest.fractie_id = faction.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT
    id,
    activiteit_id,
    commissie_id,
    persoon_id,
    fractie_id,
    actor_naam,
    actor_fractie,
    relatie,
    volgorde,
    functie,
    spreektijd,
    sid_actor,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming