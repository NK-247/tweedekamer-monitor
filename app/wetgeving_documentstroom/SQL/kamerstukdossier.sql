SELECT id, titel, nummer, toevoeging, kamer
FROM silver.kamerstukdossier
ORDER BY hash(id)
LIMIT 500;