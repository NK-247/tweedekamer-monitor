SELECT document_id, fractie_id, relatie
FROM silver.document_actor
Where document_id in (
    select id 
    From silver.document
    Where kamerstukdossier_id in (
    Select id from silver.kamerstukdossier order by hash(id) limit 500));