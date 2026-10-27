import pandas as pd
import numpy as np
import streamlit as st
import plotly.express as px
from pathlib import Path


DATA = Path(__file__).resolve().parent.parent / "wetgeving_documentstroom" / "data"

st.title("Levensduur en doorlooptijd.") 
BLAUW = "#1F4E79"
ORANJE = "#E07B00"
GRIJS = "#7A8794"

px.defaults.template = "plotly_white"
px.defaults.color_discrete_sequence = [BLAUW, ORANJE, GRIJS]
px.defaults.height = 400


st.markdown(
    """
    Dit dashboard laat zien **hoe lang dossiers en documenten van de Tweede Kamer
    meegaan** en hoe snel documenten worden verwerkt. Gebruik de filters aan de
    linkerkant om te kijken naar een bepaalde fractie, een bepaald vergaderjaar,
    een Kamer of een soort document. Alle cijfers en grafieken passen zich direct aan.
    """
)


with st.expander("Hoe lees je dit dashboard? (begrippen en uitleg)"):
    st.markdown(
        """
        **Wat is een dossier?**
        Een kamerstukdossier is een verzameling documenten die bij elkaar horen,
        bijvoorbeeld alle stukken rond één wetsvoorstel.

        **Wat is de doorlooptijd van een document?**
        Het aantal dagen tussen de *registratiedatum* en de *ontvangstdatum* van een
        document. Een lage doorlooptijd betekent dat een document snel is verwerkt.
        Negatieve waarden (ontvangst vóór registratie) zijn ongeldig en tellen niet mee.

        **Wat is de looptijd van een dossier?**
        Het aantal dagen tussen het eerste en het laatste document in een dossier.
        Dit zegt hoe lang een onderwerp "leeft" in de Kamer.

        **Mediaan, gemiddelde en 90e percentiel**
        - *Mediaan*: de middelste waarde. De helft van de documenten is sneller, de helft trager.
        - *Gemiddelde*: wordt omhooggetrokken door een paar zeer trage documenten.
        - *90e percentiel*: 90% van de documenten is sneller dan deze waarde. Hiermee zie je hoe lang de traagste documenten erover doen.

        **Let op: de data is een steekproef**
        De cijfers zijn gebaseerd op een willekeurige selectie van 500 dossiers
        en de bijbehorende documenten, niet op alle dossiers van de Tweede Kamer.
        Publicatiedatums zijn niet gebruikt, omdat een groot deel daarvan door een
        bulkverwerking dezelfde datum heeft en dus niet betrouwbaar is.
        """
    )

# Data inlezen
dossier = pd.read_csv(DATA / "kamerstukdossier.csv")
documenten = pd.read_csv(DATA / "document.csv")
document_actor = pd.read_csv(DATA / "document_actor.csv")
fracties = pd.read_csv(DATA / "fractie.csv")

# Datums omzetten
for kolom in ["datum", "datum_registratie", "datum_ontvangst"]: 
    documenten[kolom]= pd.to_datetime(documenten[kolom], errors="coerce") 


# Sleutels hetzelfde datatype geven
documenten["id"] = documenten["id"].astype("string").str.strip()
dossier["id"] = dossier["id"].astype("string").str.strip()
documenten["id"] = documenten["id"].astype("string").str.strip()
documenten["kamerstukdossier_id"] = (
    documenten["kamerstukdossier_id"].astype("string").str.strip()
)
document_actor["document_id"] = document_actor["document_id"].astype("string").str.strip()
document_actor["fractie_id"] = document_actor["fractie_id"].astype("string").str.strip()
fracties["id"] = fracties["id"].astype("string").str.strip()


# Doorlooptijd: 
# hele dagen tussen registratie en ontvangst en negatieve waarden zijn ongeldig
documenten["doorlooptijd"] = (
    documenten["datum_ontvangst"] - documenten["datum_registratie"]
).dt.days
aantal_negatief = int((documenten["doorlooptijd"] < 0).sum())
documenten.loc[documenten["doorlooptijd"] < 0, "doorlooptijd"] = np.nan

# fractie en rol
fracties_koppeling = fracties[["id", "afkorting"]].rename(columns={"id": "fractie_id"})
actor_met_fractie = document_actor.merge(fracties_koppeling, on="fractie_id", how="left")

# alleen eerste ondertekenaars, anders tel je medeondertekenaars mee
if "relatie" in actor_met_fractie.columns:
    actor_met_fractie = actor_met_fractie[
        actor_met_fractie["relatie"] == "Eerste ondertekenaar"
    ]

# documentsoorten groeperen
soort_mapping = {
    "Advies Afdeling advisering Raad van State": "Advies Raad van State",
    "Advies Afdeling advisering Raad van State en Nader rapport": "Advies Raad van State",
    "Advies Afdeling advisering Raad van State en Reactie van de initiatiefnemer(s)": "Advies Raad van State",
    "Voorlichting Afdeling advisering Raad van State": "Advies Raad van State",
    "Advies van andere adviesorganen": "Advies overige adviesorganen",

    "Amendement": "Amendement",
    "Amendement (gewijzigd/nader/vervangend)": "Amendement",

    "Begrotingstoelichting": "Begroting en financiën",
    "Raming van de uitgaven": "Begroting en financiën",

    "Brief Algemene Rekenkamer": "Brief",
    "Brief commissie": "Brief",
    "Brief Eerste Kamer": "Brief",
    "Brief Europese Commissie": "Brief",
    "Brief Kamer": "Brief",
    "Brief lid / fractie": "Brief",
    "Brief Nationale ombudsman": "Brief",
    "Brief Presidium": "Brief",
    "Brief regering": "Brief",

    "EU-voorstel": "EU-voorstel",
    "Geleidende brief": "Geleidende brief",
    "Initiatiefnota": "Nota en initiatiefnota",
    "Jaarverslag": "Jaarverslag",
    "Koninklijke boodschap": "Koninklijke boodschap",

    "Lijst van vragen en antwoorden": "Vragen en antwoorden",
    "Verslag houdende een lijst van vragen en antwoorden": "Vragen en antwoorden",

    "Mededeling": "Mededeling",

    "Memorie van toelichting": "Memorie van toelichting",
    "Memorie van toelichting (initiatiefvoorstel)": "Memorie van toelichting",

    "Motie": "Motie",
    "Motie (gewijzigd/nader)": "Motie",

    "Nader rapport": "Nader rapport",

    "Nota": "Nota en initiatiefnota",
    "Nota n.a.v. het (nader/tweede nader/enz.) verslag": "Nota naar aanleiding van verslag",
    "Nota van verbetering": "Nota van wijziging en verbetering",
    "Nota van wijziging": "Nota van wijziging en verbetering",
    "Nota van wijziging (initiatiefvoorstel)": "Nota van wijziging en verbetering",

    "Oorspronkelijke tekst": "Wettekst en wetsvoorstel",
    "Voorstel van wet": "Wettekst en wetsvoorstel",
    "Voorstel van wet (initiatiefvoorstel)": "Wettekst en wetsvoorstel",
    "Voorstel van wet (tweede lezing)": "Wettekst en wetsvoorstel",
    "Verslag (initiatief)wetsvoorstel (nader)": "Verslag wetsvoorstel",

    "Rapport": "Rapport",
    "Rapport Algemene Rekenkamer": "Rapport",

    "Verslag van een algemeen overleg": "Verslag overleg",
    "Verslag van een commissiedebat": "Verslag overleg",
    "Verslag van een notaoverleg": "Verslag overleg",
    "Verslag van een schriftelijk overleg": "Verslag overleg",
    "Verslag van een wetgevingsoverleg": "Verslag overleg",

    "Verslag van een bijeenkomst": "Verslag overige activiteiten",
    "Verslag van een hoorzitting / rondetafelgesprek": "Verslag overige activiteiten",
    "Verslag van een rapporteur": "Verslag overige activiteiten",
    "Verslag van een werkbezoek": "Verslag overige activiteiten",

    "Voordracht": "Voordracht",
    "Voorstel tot wijziging Reglement van Orde": "Wijziging Reglement van Orde",

    "Overig": "Overig",
}

documenten["soort_groep"] = (
    documenten["soort"].astype("string").str.strip().map(soort_mapping).fillna("Overig")
)


# filters (sidebar)
# fractie: 
fracties_beschikbaar = sorted(actor_met_fractie["afkorting"].dropna().unique().tolist())
gekozen_fractie = st.sidebar.selectbox("Fractie (eerste ondertekenaar)", ["Alle"] + fracties_beschikbaar, help="Toont alleen documenten waarvan deze fractie de eerste ondertekenaar is.",)
if gekozen_fractie != "Alle":
    document_ids = actor_met_fractie.loc[
        actor_met_fractie["afkorting"] == gekozen_fractie, "document_id"
    ].dropna().unique()
    documenten = documenten[documenten["id"].isin(document_ids)]

# vergaderjaar
jaren = sorted(documenten["vergaderjaar"].dropna().unique())
jaar = st.sidebar.selectbox("Vergaderjaar", ["Alle"] + jaren, help="Een vergaderjaar loopt van september tot september.")
if jaar != "Alle":
    documenten = documenten[documenten["vergaderjaar"] == jaar]

# filter op kamer
kamers = sorted(dossier["kamer"].dropna().unique())
kamer = st.sidebar.selectbox("Kamer", ["Alle"] + kamers, help="De Kamer waar het dossier bij hoort.",)
if kamer != "Alle":
    dossier = dossier[dossier["kamer"] == kamer]
    documenten = documenten[documenten["kamerstukdossier_id"].isin(dossier["id"])]



# Filter op documentcategorie
soorten = sorted(documenten["soort_groep"].dropna().unique())
soort = st.sidebar.selectbox("Soort document", ["Alle"] + soorten, help="Bijvoorbeeld brief, motie, amendement of verslag. Soorten zijn in categorieën gegroepeerd.",)
if soort != "Alle":
    documenten = documenten[documenten["soort_groep"] == soort]

if documenten.empty:
    st.warning("Geen documenten gevonden met deze filters. Probeer een filter terug te zetten op 'Alle'")
    st.stop()

# Samenvatting van de huidige selectie
gekozen = [
    f"fractie **{gekozen_fractie}**" if gekozen_fractie != "Alle" else None,
    f"vergaderjaar **{jaar}**" if jaar != "Alle" else None,
    f"Kamer **{kamer}**" if kamer != "Alle" else None,
    f"soort **{soort}**" if soort != "Alle" else None,
]
gekozen = [g for g in gekozen if g]
st.info(
    "Je bekijkt nu: "
    + (", ".join(gekozen) if gekozen else "**alle documenten** (geen filters actief)")
    + f". Dit zijn **{len(documenten):,} documenten** in "
    f"**{documenten['kamerstukdossier_id'].nunique():,} dossiers**.".replace(",", ".")
)


# Looptijd per dossier: eerste tot laatste documentdatum
per_dossier = (
    documenten.dropna(subset=["kamerstukdossier_id", "datum"])
    .groupby("kamerstukdossier_id")["datum"]
    .agg(eerste_datum="min", laatste_datum="max")
    .reset_index()
)
per_dossier["looptijd"] = (per_dossier["laatste_datum"] - per_dossier["eerste_datum"]).dt.days
doorlooptijden = documenten["doorlooptijd"].dropna()


def dagen(waarde):
    return "n.v.t." if pd.isna(waarde) else f"{waarde:.0f} dagen"

# kengetallen
st.header("Kengetallen")
kolom1, kolom2, kolom3 = st.columns(3)
kolom1.metric(
    "Mediane looptijd dossier",
    dagen(per_dossier["looptijd"].median()),
    help="Middelste tijdsduur tussen het eerste en laatste document van een dossier.",
)
kolom2.metric(
    "Mediane doorlooptijd document",
    dagen(doorlooptijden.median()),
    help="Middelste aantal dagen tussen registratie en ontvangst van een document.",
)
kolom3.metric(
    "Documenten binnen 7 dagen",
    "n.v.t." if doorlooptijden.empty else f"{(doorlooptijden <= 7).mean() * 100:.0f}%",
    help="Percentage documenten waarvan de doorlooptijd 7 dagen of korter is.",
)
st.caption(
    f"{int(documenten['doorlooptijd'].isna().sum())} documenten hebben geen geldige "
    f"doorlooptijd (datum ontbreekt of is ongeldig) en tellen niet mee in de doorlooptijden. "
    f"In de hele dataset zijn {aantal_negatief} documenten met een negatieve doorlooptijd uitgesloten."
)


# Dossiers per looptijdcategorie
st.header("Hoe lang lopen dossiers?")
st.markdown(
    "De grafiek hieronder deelt dossiers in naar hun looptijd: de tijd tussen het eerste "
    "en het laatste document. Veel dossiers in de linkerkolommen betekent dat onderwerpen "
    "snel worden afgehandeld; veel dossiers rechts betekent dat ze lang blijven doorlopen."
)
categorie = pd.cut(
    per_dossier["looptijd"],
    bins=[-1, 30, 182, 365, 1826, 100000],
    labels=["1. < 1 mnd", "2. 1-6 mnd", "3. 6-12 mnd", "4. 1-5 jaar", "5. > 5 jaar"],
)
verdeling = categorie.value_counts().sort_index()
st.bar_chart(verdeling)
if not per_dossier.empty:
    grootste = verdeling.idxmax()
    st.caption(
        f"De meeste dossiers ({verdeling.max()} van {len(per_dossier)}) vallen in de categorie "
        f"**{grootste[3:]}**."
    )



# Mediane doorlooptijd per documentcategorie
# Alleen tonen als er geen enkele documentsoort is gekozen: bij één soort is er niets te vergelijken
if soort == "Alle":
    st.header("Welke documenten zijn snel of traag?")
    st.markdown(
        "Niet elk soort document wordt even snel verwerkt. De balken tonen de mediane "
        "doorlooptijd per categorie: hoe langer de balk, hoe langer het gemiddeld duurt "
        "voordat een document van registratie naar ontvangst gaat."
    )
    doorlooptijd_per_soort = (
        documenten.dropna(subset=["doorlooptijd"])
        .groupby("soort_groep", as_index=False)["doorlooptijd"]
        .median()
        .sort_values("doorlooptijd", ascending=False)
    )
    if doorlooptijd_per_soort.empty:
        st.warning("Geen doorlooptijden beschikbaar voor deze selectie.")
    else:
        fig = px.bar(
            doorlooptijd_per_soort,
            x="doorlooptijd",
            y="soort_groep",
            orientation="h",
            labels={"doorlooptijd": "Mediane doorlooptijd (dagen)", "soort_groep": "Documentcategorie"},
        )
        fig.update_traces(texttemplate="%{x:.0f}", textposition="outside")
        fig.update_yaxes(
            categoryorder="array",
            categoryarray=doorlooptijd_per_soort["soort_groep"].tolist(),
            autorange="reversed",
        )
        st.plotly_chart(fig, use_container_width=True)
        traagst = doorlooptijd_per_soort.iloc[0]
        snelst = doorlooptijd_per_soort.iloc[-1]
        st.caption(
            f"Traagste categorie: **{traagst['soort_groep']}** ({traagst['doorlooptijd']:.0f} dagen). "
            f"Snelste categorie: **{snelst['soort_groep']}** ({snelst['doorlooptijd']:.0f} dagen)."
        )




# mediane doorlooptijd per jaar
st.header("Is de doorlooptijd door de jaren heen veranderd?")
st.markdown(
    "De mediaan blijft vaak laag omdat de meeste documenten snel worden verwerkt. "
    "Daarom staan hier ook het gemiddelde en het 90e percentiel: die laten zien of "
    "de traagste documenten er langer over gaan doen. Het lopende vergaderjaar is "
    "weggelaten, omdat dat nog niet compleet is. Beweeg met je muis over een punt "
    "om het aantal documenten te zien."
)
per_jaar = (
    documenten.dropna(subset=["doorlooptijd", "vergaderjaar"])
    .groupby("vergaderjaar")["doorlooptijd"]
    .agg(
        mediaan="median",
        gemiddelde="mean",
        p90=lambda s: s.quantile(0.9),
        aantal="count",
    )
    .reset_index()
    .sort_values("vergaderjaar")
)
if len(per_jaar) > 1:
    per_jaar = per_jaar.iloc[:-1]

if len(per_jaar) < 2:
    st.info("Voor deze selectie zijn te weinig vergaderjaren om een verloop te tonen.")
else:
    per_jaar_lang = per_jaar.melt(
        id_vars=["vergaderjaar", "aantal"],
        value_vars=["mediaan", "gemiddelde", "p90"],
        var_name="maat",
        value_name="dagen",
    ).replace({"maat": {
        "mediaan": "Mediaan",
        "gemiddelde": "Gemiddelde",
        "p90": "90e percentiel (traagste 10%)",
    }})
    fig = px.line(
        per_jaar_lang,
        x="vergaderjaar",
        y="dagen",
        color="maat",
        markers=True,
        hover_data={"aantal": True},
        labels={"vergaderjaar": "Vergaderjaar", "dagen": "Doorlooptijd (dagen)", "maat": ""},
    )
    fig.update_layout(
        legend=dict(orientation="h", yanchor="bottom", y=1.02, x=0),
        margin=dict(t=40),
    )
    fig.update_xaxes(tickangle=-45)
    fig.update_yaxes(rangemode="tozero")
    st.plotly_chart(fig, use_container_width=True)
    st.caption(
        "Jaren met weinig documenten zijn minder betrouwbaar: één uitschieter kan dan "
        "het beeld flink beïnvloeden.")





# Tabel: langstlopende dossiers
st.header("Langstlopende dossiers")
st.markdown(
    "Deze tien dossiers hebben de langste looptijd in de huidige selectie. "
    "De looptijd is het aantal dagen tussen het eerste en het laatste document."
)
langste = (
    per_dossier[per_dossier["looptijd"] >= 0]
    .merge(dossier, left_on="kamerstukdossier_id", right_on="id", how="left")
    .sort_values("looptijd", ascending=False)
    .head(10)
    .rename(columns={
        "nummer": "Kamerstuknummer",
        "titel": "Titel dossier",
        "looptijd": "Looptijd (dagen)",
    })
)
if langste.empty:
    st.warning("Geen dossiers gevonden. Controleer of dossier-ID's overeenkomen en of er geldige datums zijn.")
else:
    st.dataframe(
        langste[["Kamerstuknummer", "Titel dossier", "Looptijd (dagen)"]],
        use_container_width=True,
        hide_index=True,
    )


# samenvatting
st.header("Belangrijkste inzichten")
inzichten = []
if not per_dossier.empty:
    inzichten.append(
        f"De helft van de dossiers loopt korter dan **{per_dossier['looptijd'].median():.0f} dagen**."
    )
if not doorlooptijden.empty:
    inzichten.append(
        f"De helft van de documenten is binnen **{doorlooptijden.median():.0f} dagen** verwerkt, "
        f"en **{(doorlooptijden <= 7).mean() * 100:.0f}%** binnen een week."
    )
if soort == "Alle" and not doorlooptijd_per_soort.empty:
    inzichten.append(
        f"**{doorlooptijd_per_soort.iloc[0]['soort_groep']}** heeft de langste mediane doorlooptijd."
    )
for tekst in inzichten:
    st.markdown(f"- {tekst}")

st.caption("Bron: Tweede Kamer open data, steekproef van 500 dossiers.")
