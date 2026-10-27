{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        agendapunt__ref AS agendapunt_id,
        stemmings_soort,
        besluit_soort,
        besluit_tekst,
        opmerking,
        status,
        CAST(agendapunt_zaak_besluit_volgorde AS INTEGER) AS agendapunt_zaak_besluit_volgorde,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'besluit') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, agendapunt_id),
        CASE WHEN agendapunt.id IS NOT NULL THEN latest.agendapunt_id END AS agendapunt_id
    FROM latest
    LEFT JOIN {{ ref('agendapunt') }} AS agendapunt
        ON latest.agendapunt_id = agendapunt.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming