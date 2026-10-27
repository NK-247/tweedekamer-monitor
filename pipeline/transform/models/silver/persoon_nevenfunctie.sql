{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        persoon__ref AS persoon_id,
        omschrijving,
        is_actief,
        {{ parse_partial_datum('periode__van') }} AS periode_van_parsed,
        periode__van AS periode_van_ruw,
        {{ parse_partial_datum('periode__tot_en_met', is_end_date=true) }} AS periode_tot_en_met_parsed,
        periode__tot_en_met AS periode_tot_en_met_ruw,
        vergoeding__soort AS vergoeding_soort,
        vergoeding__toelichting AS vergoeding_toelichting,
        CAST(gewicht AS INTEGER) AS gewicht,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'persoon_nevenfunctie') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN persoon.id IS NOT NULL THEN latest.persoon_id END AS persoon_id,
        latest.omschrijving,
        latest.is_actief,
        latest.periode_van_parsed.datum AS periode_van,
        latest.periode_van_ruw,
        latest.periode_van_parsed.precisie AS periode_van_precisie,
        latest.periode_tot_en_met_parsed.datum AS periode_tot_en_met,
        latest.periode_tot_en_met_ruw,
        latest.periode_tot_en_met_parsed.precisie AS periode_tot_en_met_precisie,
        latest.vergoeding_soort,
        latest.vergoeding_toelichting,
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
    omschrijving,
    is_actief,
    periode_van,
    periode_van_ruw,
    periode_van_precisie,
    periode_tot_en_met,
    periode_tot_en_met_ruw,
    periode_tot_en_met_precisie,
    vergoeding_soort,
    vergoeding_toelichting,
    gewicht,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming