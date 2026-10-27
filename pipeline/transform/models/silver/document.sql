{{
    config(
        contract={'enforced': true}
    )
}}

WITH links AS (
    SELECT
        _dlt_parent_id,
        MAX(CASE WHEN rel = 'enclosure' THEN href END) AS document_url
    FROM {{ source('bronze', 'document__atom_links') }}
    GROUP BY 1
),

current_versions AS (
    SELECT id
    FROM {{ source('bronze', 'document_versie') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY id
        ORDER BY bijgewerkt DESC, feed_updated DESC, _dlt_id DESC
    ) = 1
       AND NOT verwijderd
),

latest AS (
    SELECT
        d.id,
        d.content_type,
        d.content_length,
        d.soort,
        d.document_nummer,
        d.titel,
        d.onderwerp,
        CAST(d.datum AS DATE) AS datum,
        d.volgnummer,
        d.vergaderjaar,
        d.kamer,
        CAST(d.datum_registratie AS DATE) AS datum_registratie,
        CAST(d.datum_ontvangst AS DATE) AS datum_ontvangst,
        d.organisatie,
        d.kamerstukdossier__ref AS kamerstukdossier_id,
        d.huidige_document_versie__ref AS huidige_document_versie_id,
        d.kenmerk_afzender,
        d.aanhangselnummer,
        d.alias,
        d.citeertitel,
        l.document_url,
        d.verwijderd,
        d.bijgewerkt AS gewijzigd_op,
        d.feed_updated AS api_gewijzigd_op
    FROM {{ source('bronze', 'document') }} AS d
    LEFT JOIN links AS l ON d._dlt_id = l._dlt_parent_id
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY d.id
        ORDER BY d.bijgewerkt DESC, d.feed_updated DESC, d._dlt_id DESC
    ) = 1
),

incoming AS (
    SELECT
        latest.* EXCLUDE (verwijderd, kamerstukdossier_id, huidige_document_versie_id),
        CASE WHEN dossier.id IS NOT NULL THEN latest.kamerstukdossier_id END AS kamerstukdossier_id,
        CASE WHEN current_version.id IS NOT NULL THEN latest.huidige_document_versie_id END AS huidige_document_versie_id
    FROM latest
    LEFT JOIN {{ ref('kamerstukdossier') }} AS dossier
        ON latest.kamerstukdossier_id = dossier.id
    LEFT JOIN current_versions AS current_version
        ON latest.huidige_document_versie_id = current_version.id
    WHERE NOT latest.verwijderd
        {% if is_incremental() %}
        AND (
            latest.api_gewijzigd_op > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
            OR EXISTS (
                SELECT 1
                FROM {{ source('bronze', 'document_versie') }} AS version_change
                WHERE version_change.id = latest.huidige_document_versie_id
                  AND version_change.feed_updated > (SELECT MAX(api_gewijzigd_op) FROM {{ this }})
            )
        )
        {% endif %}
)

SELECT * FROM incoming