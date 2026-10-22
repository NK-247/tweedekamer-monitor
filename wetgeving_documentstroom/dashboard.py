import pandas as pd
import streamlit as st
from pathlib import Path

DATA = Path(__file__).parent / "data"

st.title("Levensduur en doorlooptijd") 

# Data inlezen
dossier = pd.read_csv(DATA / "kamerstukdossier.csv")
documenten = pd.read_csv(DATA / "document.csv", parse_dates=["datum", "datum_registratie", "datum_ontvangst"],) 

# Doorlooptijd per document in dagen
documenten["doorlooptijd"] = (
    documenten["datum_ontvangst"] - documenten["datum_registratie"]).dt.days

# Filter op vergaderjaar
jaren = sorted(documenten["vergaderjaar"].dropna().unique())
jaar = st.sidebar.selectbox("Vergaderjaar", ["Alle"] + jaren)
if jaar != "Alle": 
    documenten = documenten[documenten["vergaderjaar"] == jaar] 

# Filter op documenten
soorten = sorted(documenten["soort"].dropna().unique())
soort = st.sidebar.selectbox("Soort document", ["Alle"] + soorten)
if soort != "Alle": 
    documenten = documenten[documenten["soort"] == soort]

# Looptijd per dossier: eerste tot laatste documentdatum
per_dossier = documenten.groupby("kamerstukdossier_id")["datum"].agg(["min", "max"])
per_dossier["looptijd"] = (per_dossier["max"] - per_dossier["min"]).dt.days

# kengetallen
kolom1, kolom2, kolom3 = st.columns(3)
kolom1.metric("Mediane looptijd dossier", f"{per_dossier['looptijd'].median():.0f} dagen")
kolom2.metric("Mediane doorlooptijd document", f"{documenten['doorlooptijd'].median():.0f} dagen")
doorlooptijden = documenten["doorlooptijd"].dropna()
kolom3.metric("binnen 7 dagen", f"{(doorlooptijden <= 7).mean() * 100:.0f}%")

# Dossiers per looptijdcategorie
st.subheader("Dossiers per looptijdcategorie") 
categorie = pd.cut(
    per_dossier["looptijd"], 
    bins=[-1, 30, 182, 365, 1826, 100000], 
    labels=["1. < 1 mnd", "2. 1-6 mnd", "3. 6-12 mnd", "4. 1-5 jaar", "5. > 5 jaar"],)
st.bar_chart(categorie.value_counts().sort_index())


# Grafiek: doorlooptijd per soort document
st.subheader("Mediane doorlooptijd per soort document")
st.bar_chart(documenten.groupby("soort")["doorlooptijd"].median())

# mediane doorlooptijd per jaar
st.subheader("Mediane doorlooptijd per jaar")
st.line_chart(documenten.groupby(documenten["datum_registratie"].dt.year)["doorlooptijd"].median())

# tabel: langstlopende dossiers
st.subheader("Langstlopende dossiers")
langste = per_dossier.sort_values("looptijd", ascending=False).head(10)
langste = langste.merge(dossier, left_index=True, right_on="id")
st.dataframe(langste[["nummer", "titel", "looptijd"]]) 