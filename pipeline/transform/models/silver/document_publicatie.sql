{{
    config(
        contract={'enforced': true}
    )
}}

WITH links AS (
    SELECT
        _dlt_parent_id,
        MAX(CASE WHEN rel = 'enclosure' THEN href END) AS document_url
    FROM {{ source('bronze', 'document_publicatie__atom_links') }}
    GROUP BY 1
),

latest AS (
    SELECT
        p.id,
        p.content_type,
        p.content_length,
        p.identifier,
        p.document_type,
        p.file_name,
        p.source,
        CAST(p.publicatie_datum AS DATE) AS publicatie_datum,
        p.url,
        l.document_url,
        p.document_versie__ref AS document_versie_id,
        p.verwijderd,
        p.bijgewerkt AS gewijzigd_op,
        p.feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'document_publicatie') }} AS p
    LEFT JOIN links AS l ON p._dlt_id = l._dlt_parent_id
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY p.id
        ORDER BY p.bijgewerkt DESC, p.feed_updated DESC, p._dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, document_versie_id),
        CASE WHEN version.id IS NOT NULL THEN latest.document_versie_id END AS document_versie_id
    FROM latest
    LEFT JOIN {{ ref('document_versie') }} AS version
        ON latest.document_versie_id = version.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
        {% endif %}
)

SELECT * FROM incoming