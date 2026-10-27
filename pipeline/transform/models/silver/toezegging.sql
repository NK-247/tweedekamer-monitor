{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        CAST(aanmaakdatum AS DATE) AS aanmaakdatum,
        nummer,
        activiteit__ref AS activiteit_id,
        activiteit_nummer,
        naam,
        achternaam,
        initialen,
        tussenvoegsel,
        voornaam,
        achtervoegsel,
        titulatuur,
        functie,
        status,
        CAST(datum_nakoming AS DATE) AS datum_nakoming,
        ministerie,
        tekst,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'toezegging') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, activiteit_id),
        CASE WHEN activiteit.id IS NOT NULL THEN latest.activiteit_id END AS activiteit_id
    FROM latest
    LEFT JOIN {{ ref('activiteit') }} AS activiteit
        ON latest.activiteit_id = activiteit.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming