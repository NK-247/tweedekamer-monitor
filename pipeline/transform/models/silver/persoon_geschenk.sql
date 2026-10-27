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
        {{ parse_partial_datum('datum') }} AS datum_parsed,
        datum AS datum_ruw,
        CAST(gewicht AS INTEGER) AS gewicht,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'persoon_geschenk') }}
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
        latest.datum_parsed.datum AS datum,
        latest.datum_ruw,
        latest.datum_parsed.precisie AS datum_precisie,
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
    datum,
    datum_ruw,
    datum_precisie,
    gewicht,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming