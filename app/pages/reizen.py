import streamlit as st

st.set_page_config(page_title="Reizen · Tweede Kamer Monitor", page_icon=":material/account_balance:", layout="wide")

st.title("Reizen")
st.write("Geregistreerde buitenlandse reizen van Kamerleden. Alle cijfers op deze pagina zijn mockdata.")

columns = st.columns(3)
columns[0].metric("Reizen dit jaar", "86")
columns[1].metric("Deelnemende Kamerleden", "52")
columns[2].metric("Meest bezochte bestemming", "Brussel", "18 reizen")

st.divider()
left, right = st.columns([1, 1.2])
with left:
    st.subheader("Bestemmingen")
    st.bar_chart(
        {
            "Bestemming": ["Brussel", "Berlijn", "Parijs", "Washington", "Kyiv", "Overig"],
            "Reizen": [18, 9, 7, 6, 5, 4],
        },
        x="Bestemming",
        y="Reizen",
        color="#18836b",
        horizontal=True,
    )
with right:
    st.subheader("Recente registraties")
    st.dataframe(
        [
            {"Bestemming": "Brussel", "Doel": "Interparlementair overleg", "Deelnemers": 4, "Periode": "12–14 sep"},
            {"Bestemming": "Berlijn", "Doel": "Werkbezoek energiebeleid", "Deelnemers": 3, "Periode": "03–05 sep"},
            {"Bestemming": "Parijs", "Doel": "Conferentie Europese samenwerking", "Deelnemers": 2, "Periode": "21–22 aug"},
            {"Bestemming": "Kyiv", "Doel": "Parlementair werkbezoek", "Deelnemers": 5, "Periode": "08–10 aug"},
        ],
        hide_index=True,
        width="stretch",
    )