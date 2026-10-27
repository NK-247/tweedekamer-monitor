{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        activiteit__ref AS activiteit_id,
        nummer,
        onderwerp,
        CAST(aanvangstijd AS TIMESTAMP) AS aanvangstijd,
        CAST(eindtijd AS TIMESTAMP) AS eindtijd,
        CAST(volgorde AS INTEGER) AS volgorde,
        rubriek,
        noot,
        status,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'agendapunt') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN activity.id IS NOT NULL THEN latest.activiteit_id END AS activiteit_id,
        latest.nummer,
        latest.onderwerp,
        latest.aanvangstijd,
        latest.eindtijd,
        latest.volgorde,
        latest.rubriek,
        latest.noot,
        latest.status,
        latest.gewijzigd_op,
        latest.api_gewijzigd_op
    FROM latest
    LEFT JOIN {{ ref('activiteit') }} AS activity
        ON latest.activiteit_id = activity.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT
    id,
    activiteit_id,
    nummer,
    onderwerp,
    aanvangstijd,
    eindtijd,
    volgorde,
    rubriek,
    noot,
    status,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming