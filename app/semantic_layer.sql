-- semantic_layer.sql
-- To use from the command line, run: duckdb -unsigned :memory: --init semantic_layer.sql

-- Install the OData extension
INSTALL erpl_odata FROM 'http://get.erpl.io';
LOAD erpl_odata;

-- Install the semantic_views extension
INSTALL semantic_views FROM community;
LOAD semantic_views;

-- Attach the Tweede Kamer OData sources
ATTACH 'https://gegevensmagazijn.tweedekamer.nl/OData/v5' AS tk (TYPE odata);

-- Prevents the OData extension from pushing GUID range filters to the server (HTTP 400)
SET disabled_optimizers = 'join_filter_pushdown';

-- Create schemas
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS sv;

-- Create views for all OData entities
CREATE OR REPLACE VIEW mart.Activiteit AS
SELECT
    Id,
    Soort,
    Nummer,
    Onderwerp,
    DatumSoort,
    Datum,
    Aanvangstijd,
    Eindtijd,
    Locatie,
    Besloten,
    Status,
    Vergaderjaar,
    Kamer,
    Notitie,
    VoortouwCommissieNaam,
    VoortouwCommissieAfkorting,
    VoortouwCommissieKorteNaam,
    VoortouwCommissie_Id AS VoortouwCommissieId,
    Aanvraagdatum,
    DatumVerzoekEersteVerlenging,
    DatumMededelingEersteVerlenging,
    DatumVerzoekTweedeVerlenging,
    DatumMededelingTweedeVerlenging,
    Vervaldatum,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Activiteit
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitVervangenVanuit AS
SELECT 
    Id AS ActiviteitId, 
    unnest(VervangenVanuit).Id As VervangenVanuitId, 
    GewijzigdOp, 
    ApiGewijzigdOp 
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Activiteit', expand := 'VervangenVanuit') 
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitVoortgezetVanuit AS
SELECT
    Id AS ActiviteitId,
    unnest(VoortgezetVanuit).Id AS VoortgezetVanuitId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Activiteit', expand := 'VoortgezetVanuit')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitDocument AS
SELECT
    Id AS ActiviteitId,
    unnest(Document).Id AS DocumentId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Activiteit', expand := 'Document')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitReservering AS
SELECT
    Id AS ActiviteitId,
    unnest(Reservering).Id AS ReserveringId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Activiteit', expand := 'Reservering')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitToezegging AS
SELECT
    Id AS ActiviteitId,
    unnest(Toezegging).Id AS ToezeggingId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Activiteit', expand := 'Toezegging')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ActiviteitActor AS
SELECT
    Id,
    Activiteit_Id AS ActiviteitId,
    Naam,
    FractieNaam,
    Rol,
    Volgorde,
    Functie,
    Spreektijd,
    Persoon_Id AS PersoonId,
    Fractie_Id AS FractieId,
    Commissie_Id AS CommissieId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.ActiviteitActor
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Agendapunt AS
SELECT
    Id,
    Nummer,
    Onderwerp,
    Aanvangstijd,
    Eindtijd,
    Volgorde,
    Rubriek,
    Notitie,
    GewijzigdOp,
    ApiGewijzigdOp,
    Activiteit_Id AS ActiviteitId
FROM tk.Agendapunt
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.AgendapuntDocument AS
SELECT
    Id AS AgendapuntId,
    unnest(Document).Id AS DocumentId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Agendapunt', expand := 'Document')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.AgendapuntZaak AS
SELECT
    Id AS AgendapuntId,
    unnest(Zaak).Id AS ZaakId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Agendapunt', expand := 'Zaak')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Besluit AS
SELECT
    Id,
    Agendapunt_Id AS AgendapuntId,
    Tekst,
    Soort,
    BesluitTekst,
    Notitie,
    Status,
    Volgorde,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Besluit
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.BesluitZaak AS
SELECT
    Id AS BesluitId,
    unnest(Zaak).Id AS ZaakId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Besluit', expand := 'Zaak')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Commissie AS
SELECT
    Id,
    Nummer,
    Afkorting,
    NaamNL,
    NaamEN,
    Soort,
    DatumActief,
    DatumInactief,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Commissie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieContactinformatie AS
SELECT
    Id,
    Soort,
    Waarde,
    GewijzigdOp,
    ApiGewijzigdOp,
    Commissie_Id AS CommissieId
FROM tk.CommissieContactinformatie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieZetel AS
SELECT
    Id,
    GewijzigdOp,
    ApiGewijzigdOp,
    Commissie_Id AS CommissieId
FROM tk.CommissieZetel
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieZetelVastPersoon AS
SELECT
    Id,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    CommissieZetel_Id AS CommissieZetelId,
    Persoon_Id AS PersoonId
FROM tk.CommissieZetelVastPersoon
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieZetelVastVacature AS
SELECT
    Id,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    CommissieZetel_Id AS CommissieZetelId,
    Fractie_Id AS FractieId
FROM tk.CommissieZetelVastVacature
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieZetelVervangerPersoon AS
SELECT
    Id,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    CommissieZetel_Id AS CommissieZetelId,
    Persoon_Id AS PersoonId
FROM tk.CommissieZetelVervangerPersoon
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.CommissieZetelVervangerVacature AS
SELECT
    Id,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    CommissieZetel_Id AS CommissieZetelId,
    Fractie_Id AS FractieId
FROM tk.CommissieZetelVervangerVacature
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Document AS
SELECT
    Id,
    Soort,
    Nummer,
    Titel,
    Onderwerp,
    Datum,
    Vergaderjaar,
    Ondernummer,
    Citeertitel,
    Alias,
    Aanhangselnummer,
    Kamer,
    ContentType,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/Document(', Id, ')/resource')
    END AS Resource,
    GewijzigdOp,
    ApiGewijzigdOp,
    HuidigeDocumentVersie_Id AS HuidigeDocumentVersieId
FROM tk.Document
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentBronDocument AS
SELECT
    Id AS DocumentId,
    unnest(BronDocument).Id AS BronDocumentId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Document', expand := 'BronDocument')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentKamerstukdossier AS
SELECT
    Id AS DocumentId,
    unnest(Kamerstukdossier).Id AS KamerstukdossierId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Document', expand := 'Kamerstukdossier')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentActor AS
SELECT
    Id,
    Document_Id AS DocumentId,
    Naam,
    FractieNaam,
    Functie,
    Rol,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId,
    Fractie_Id AS FractieId,
    Commissie_Id AS CommissieId
FROM tk.DocumentActor
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentPublicatie AS
SELECT
    Id,
    Identifier,
    DocumentType,
    FileName,
    Source,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/DocumentPublicatie(', Id, ')/resource')
    END AS Resource,
    ContentType,
    Url,
    PublicatieDatum,
    GewijzigdOp,
    ApiGewijzigdOp,
    DocumentVersie_Id AS DocumentVersieId
FROM tk.DocumentPublicatie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentPublicatieMetadata AS
SELECT
    Id,
    Identifier,
    DocumentType,
    FileName,
    Source,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/DocumentPublicatieMetadata(', Id, ')/resource')
    END AS Resource,
    ContentType,
    Url,
    PublicatieDatum,
    GewijzigdOp,
    ApiGewijzigdOp,
    DocumentVersie_Id AS DocumentVersieId
FROM tk.DocumentPublicatieMetadata
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.DocumentVersie AS
SELECT
    Id,
    Versienummer,
    Bestandsgrootte,
    Bestandsformaat,
    Datum,
    GewijzigdOp,
    ApiGewijzigdOp,
    Document_Id AS DocumentId,
    ExterneIdentifier
FROM tk.DocumentVersie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Fractie AS
SELECT
    Id,
    Nummer,
    Afkorting,
    NaamNL,
    NaamEN,
    AantalZetels,
    AantalStemmen,
    DatumActief,
    DatumInactief,
    ContentType,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/Fractie(', Id, ')/resource')
    END AS Resource,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Fractie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.FractieZetel AS
SELECT
    Id,
    Fractie_Id AS FractieId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.FractieZetel
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.FractieZetelPersoon AS
SELECT
    Id,
    FractieZetel_Id AS FractieZetelId,
    Persoon_Id AS PersoonId,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.FractieZetelPersoon
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.FractieZetelVacature AS
SELECT
    Id,
    FractieZetel_Id AS FractieZetelId,
    Functie,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.FractieZetelVacature
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Kamerstukdossier AS
SELECT
    Id,
    Titel,
    Citeertitel,
    Alias,
    Nummer,
    Toevoeging,
    AantalDocumenten,
    Afgesloten,
    Kamer,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Kamerstukdossier
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Persoon AS
SELECT
    Id,
    Nummer,
    Titels,
    Initialen,
    Tussenvoegsel,
    Achternaam,
    Voornamen,
    Roepnaam,
    Geslacht,
    Functie,
    Geboortedatum,
    Geboorteplaats,
    Geboorteland,
    Overlijdensdatum,
    Overlijdensplaats,
    Woonplaats,
    Land,
    ContentType,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/Persoon(', Id, ')/resource')
    END AS Resource,
    GewijzigdOp,
    ApiGewijzigdOp,
    Fractielabel
FROM tk.Persoon
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonContactinformatie AS
SELECT
    Id,
    Soort,
    Waarde,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId
FROM tk.PersoonContactinformatie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonGeschenk AS
SELECT
    Id,
    Omschrijving,
    Datum,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId,
    Gewicht
FROM tk.PersoonGeschenk
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonLoopbaan AS
SELECT
    Id,
    Functie,
    Werkgever,
    OmschrijvingNL,
    OmschrijvingEN,
    Plaats,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId,
    Volgorde
FROM tk.PersoonLoopbaan
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonNevenfunctie AS
SELECT
    Id,
    Persoon_Id AS PersoonId,
    Omschrijving,
    Van,
    TotEnMet,
    Actief,
    Soort,
    Toelichting,
    GewijzigdOp,
    ApiGewijzigdOp,
    Volgorde
FROM tk.PersoonNevenfunctie
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonNevenfunctieInkomsten AS
SELECT
    Id,
    Jaar,
    BedragSoort,
    BedragVoorvoegsel,
    BedragValuta,
    Bedrag,
    BedragAchtervoegsel,
    Frequentie,
    FrequentieBeschrijving,
    Opmerking,
    GewijzigdOp,
    ApiGewijzigdOp,
    Nevenfunctie_Id AS NevenfunctieId
FROM tk.PersoonNevenfunctieInkomsten
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonOnderwijs AS
SELECT
    Id,
    OpleidingNL,
    OpleidingEN,
    Instelling,
    Plaats,
    Van,
    TotEnMet,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId,
    Volgorde
FROM tk.PersoonOnderwijs
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.PersoonReis AS
SELECT
    Id,
    Doel,
    Bestemming,
    Van,
    TotEnMet,
    BetaaldDoor,
    GewijzigdOp,
    ApiGewijzigdOp,
    Persoon_Id AS PersoonId,
    Volgorde
FROM tk.PersoonReis
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Reservering AS
SELECT
    Id,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Reservering
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Stemming AS
SELECT
    Id,
    Besluit_Id AS BesluitId,
    Soort,
    FractieGrootte,
    Naam,
    FractieNaam,
    Vergissing,
    Persoon_Id AS PersoonId,
    Fractie_Id AS FractieId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Stemming
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Toezegging AS
SELECT
    Id,
    Aanmaakdatum,
    Nummer,
    ActiviteitNummer,
    Naam,
    Achternaam,
    Initialen,
    Voornaam,
    Achtervoegsel,
    Titulatuur,
    Functie,
    Status,
    DatumNakoming,
    Ministerie,
    Tekst,
    GewijzigdOp,
    ApiGewijzigdOp,
    Tussenvoegsel
FROM tk.Toezegging
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ToezeggingKamerbriefNakoming AS
SELECT
    Id AS ToezeggingId,
    unnest(KamerbriefNakoming).Id AS KamerbriefNakomingId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Toezegging', expand := 'KamerbriefNakoming')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ToezeggingIsHerhalingVan AS
SELECT
    Id AS ToezeggingId,
    unnest(IsHerhalingVan).Id AS IsHerhalingVanId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Toezegging', expand := 'IsHerhalingVan')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ToezeggingIsWijzigingVan AS
SELECT
    Id AS ToezeggingId,
    unnest(IsWijzigingVan).Id AS IsWijzigingVanId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Toezegging', expand := 'IsWijzigingVan')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ToezeggingToegezegdAan AS
SELECT
    Id AS ToezeggingId,
    t.fractie_id AS FractieId,
    t.persoon_id AS PersoonId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM (
    SELECT Id, unnest(ToegezegdAan) AS t, GewijzigdOp, ApiGewijzigdOp, Verwijderd
    FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Toezegging', expand := 'ToegezegdAan')
)
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ToezeggingIsAanvullingOp AS
SELECT
    Id AS ToezeggingId,
    unnest(IsAanvullingOp).Id AS IsAanvullingOpId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Toezegging', expand := 'IsAanvullingOp')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Vergadering AS
SELECT
    Id,
    Soort,
    Titel,
    Zaal,
    Vergaderjaar,
    Nummer,
    Datum,
    Aanvangstijd,
    Eindtijd,
    Kamer,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Vergadering
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Verslag AS
SELECT
    Id,
    Soort,
    Status,
    ContentType,
    ContentLength,
    CASE WHEN ContentLength > 0
        THEN concat('https://gegevensmagazijn.tweedekamer.nl/OData/v4/2.0/Verslag(', Id, ')/resource')
    END AS Resource,
    GewijzigdOp,
    ApiGewijzigdOp,
    Vergadering_Id AS VergaderingId
FROM tk.Verslag
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Zaak AS
SELECT
    Id,
    Nummer,
    Soort,
    Titel,
    Citeertitel,
    Alias,
    Onderwerp,
    Datum,
    Kamer,
    Voorhang,
    Termijn,
    Vergaderjaar,
    Ondernummer,
    Afgedaan,
    GewijzigdOp,
    ApiGewijzigdOp,
    Kabinetsappreciatie
FROM tk.Zaak
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakActiviteit AS
SELECT
    Id AS ZaakId,
    unnest(Activiteit).Id AS ActiviteitId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'Activiteit')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakAgendapunt AS
SELECT
    Id AS ZaakId,
    unnest(Agendapunt).Id AS AgendapuntId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'Agendapunt')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakDocument AS
SELECT
    Id AS ZaakId,
    unnest(Document).Id AS DocumentId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'Document')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakKamerstukdossier AS
SELECT
    Id AS ZaakId,
    unnest(Kamerstukdossier).Id AS KamerstukdossierId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'Kamerstukdossier')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakVervangenVanuit AS
SELECT
    Id AS ZaakId,
    unnest(VervangenVanuit).Id AS VervangenVanuitId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'VervangenVanuit')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakGerelateerdVanuit AS
SELECT
    Id AS ZaakId,
    unnest(GerelateerdVanuit).Id AS GerelateerdVanuitId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaak', expand := 'GerelateerdVanuit')
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaakActor AS
SELECT
    Id,
    Zaak_Id AS ZaakId,
    Naam,
    FractieNaam,
    Afkorting,
    Functie,
    Rol,
    Persoon_Id AS PersoonId,
    Fractie_Id AS FractieId,
    Commissie_Id AS CommissieId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.ZaakActor
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.Zaal AS
SELECT
    Id,
    Naam,
    GewijzigdOp,
    ApiGewijzigdOp
FROM tk.Zaal
WHERE Verwijderd = FALSE;

CREATE OR REPLACE VIEW mart.ZaalReservering AS
SELECT
    Id AS ZaalId,
    unnest(Reservering).Id AS ReserveringId,
    GewijzigdOp,
    ApiGewijzigdOp
FROM odata_read('https://gegevensmagazijn.tweedekamer.nl/OData/v5/Zaal', expand := 'Reservering')
WHERE Verwijderd = FALSE;

-- Create helper views for semantic views
CREATE OR REPLACE VIEW sv.Kamerlid AS
SELECT 
    Id,
    Nummer,
    Titels,
    Initialen,
    Tussenvoegsel,
    Achternaam,
    Voornamen,
    Roepnaam,
    Geslacht,
    Geboortedatum,
    Geboorteplaats,
    Geboorteland,
    Woonplaats,
    Land,
    ContentType,
    ContentLength,
    Resource,
    GewijzigdOp,
    ApiGewijzigdOp
FROM mart.Persoon 
WHERE Functie = 'Tweede Kamerlid';

CREATE OR REPLACE VIEW sv.Kamerfractie AS
SELECT
    Id,
    Nummer,
    Afkorting,
    NaamNL,
    NaamEN,
    AantalZetels,
    AantalStemmen,
    DatumActief,
    ContentType,
    ContentLength,
    Resource,
    GewijzigdOp,
    ApiGewijzigdOp
FROM mart.Fractie
WHERE DatumInactief IS NULL;

CREATE OR REPLACE VIEW sv.KamerfractieZetelPersoon AS
SELECT fzp.*
FROM mart.FractieZetelPersoon fzp
JOIN sv.Kamerlid k ON k.Id = fzp.PersoonId
WHERE fzp.TotEnMet IS NULL;

CREATE OR REPLACE VIEW sv.KamerfractieZetel AS
SELECT fz.*
FROM mart.FractieZetel fz
WHERE EXISTS (
    SELECT 1 FROM sv.KamerfractieZetelPersoon kzb WHERE kzb.FractieZetelId = fz.Id
);

-- Create semantic views
CREATE OR REPLACE SEMANTIC VIEW sv.Fracties AS
TABLES (
    kf AS sv.Kamerfractie PRIMARY KEY (Id),
    fz AS sv.KamerfractieZetel PRIMARY KEY (Id),
    fzp AS sv.KamerfractieZetelPersoon PRIMARY KEY (Id),
    k AS sv.Kamerlid PRIMARY KEY (Id)
)
RELATIONSHIPS (
    fz_f AS fz(FractieId) REFERENCES kf,
    fzp_fz AS fzp(FractieZetelId) REFERENCES fz,
    fzp_k AS fzp(PersoonId) REFERENCES k
)
DIMENSIONS (
    kf.FractieId AS kf.Id,
    kf.FractieAfkorting AS kf.Afkorting,
    kf.FractieNaam AS kf.NaamNL,
    kf.FractieDatumActief AS kf.DatumActief,
    kf.FractieAantalZetels AS kf.AantalZetels,
    kf.FractieAantalStemmen AS kf.AantalStemmen,
    fzp.ZetelFunctie AS fzp.Functie,
    fzp.ZetelVan AS fzp.Van,
    k.PersoonId AS k.Id,
    k.PersoonAchternaam AS k.Achternaam,
    k.PersoonRoepnaam AS k.Roepnaam,
    k.PersoonVoornamen AS k.Voornamen,
    k.PersoonGeslacht AS k.Geslacht,
    k.PersoonGeboortedatum AS k.Geboortedatum,
    k.PersoonGeboorteplaats AS k.Geboorteplaats,
    k.PersoonWoonplaats AS k.Woonplaats
)
METRICS (
    kf.AantalFracties AS COUNT(DISTINCT kf.Id),
    kf.AantalStemmen AS SUM(kf.AantalStemmen),
    fz.AantalZetels AS COUNT(DISTINCT fz.Id),
    fzp.AantalPersonen AS COUNT(DISTINCT fzp.PersoonId)
);
