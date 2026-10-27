{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        persoon__ref AS persoon_id,
        functie,
        werkgever,
        omschrijving_nl,
        omschrijving_en,
        plaats,
        {{ parse_partial_datum('van') }} AS van_parsed,
        van AS van_ruw,
        {{ parse_partial_datum('tot_en_met', is_end_date=true) }} AS tot_en_met_parsed,
        tot_en_met AS tot_en_met_ruw,
        CAST(gewicht AS INTEGER) AS gewicht,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'persoon_loopbaan') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN persoon.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        latest.functie,
        latest.werkgever,
        latest.omschrijving_nl,
        latest.omschrijving_en,
        latest.plaats,
        latest.van_parsed.datum AS van,
        latest.van_ruw,
        latest.van_parsed.precisie AS van_precisie,
        latest.tot_en_met_parsed.datum AS tot_en_met,
        latest.tot_en_met_ruw,
        latest.tot_en_met_parsed.precisie AS tot_en_met_precisie,
        latest.gewicht,
        latest.gewijzigd_op,
        latest.api_gewijzigd_op
    FROM latest
    LEFT JOIN {{ ref('persoon') }} AS persoon ON latest.persoon_id = persoon.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT
    id,
    persoon_id,
    functie,
    werkgever,
    omschrijving_nl,
    omschrijving_en,
    plaats,
    van,
    van_ruw,
    van_precisie,
    tot_en_met,
    tot_en_met_ruw,
    tot_en_met_precisie,
    gewicht,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming