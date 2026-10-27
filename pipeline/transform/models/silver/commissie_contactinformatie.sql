{{
    config(
        contract={'enforced': true}
    )
}}

WITH latest AS (
    SELECT
        id,
        commissie__ref AS commissie_id,
        soort,
        waarde,
        CAST(gewicht AS INTEGER) AS gewicht,
        verwijderd,
        bijgewerkt AS gewijzigd_op,
        feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'commissie_contactinformatie') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.id,
        CASE WHEN parent.id IS NOT NULL THEN latest.commissie_id END AS commissie_id,
        latest.soort,
        latest.waarde,
        latest.gewicht,
        latest.gewijzigd_op,
        latest.api_gewijzigd_op
    FROM latest
    LEFT JOIN {{ ref('commissie') }} AS parent
        ON latest.commissie_id = parent.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT
    id,
    commissie_id,
    soort,
    waarde,
    gewicht,
    gewijzigd_op,
    api_gewijzigd_op
FROM incoming