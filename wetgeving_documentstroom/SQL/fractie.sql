SELECT id, afkorting
FROM silver.fractie
WHERE id IN (
    SELECT DISTINCT fractie_id
    FROM silver.document_actor
);