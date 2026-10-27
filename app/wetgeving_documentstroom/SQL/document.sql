SELECT id, kamerstukdossier_id, document_nummer, titel, soort,
       vergaderjaar, datum, datum_registratie, datum_ontvangst
FROM silver.document
WHERE kamerstukdossier_id IN (
  SELECT id FROM silver.kamerstukdossier ORDER BY hash(id) LIMIT 500
);