import streamlit as st

st.set_page_config(page_title="Kabinet · Tweede Kamer Monitor", page_icon=":material/account_balance:", layout="wide")

st.title("Kabinet")
st.write("Samenstelling en portefeuilleoverzicht. Alle cijfers op deze pagina zijn mockdata.")

columns = st.columns(3)
columns[0].metric("Bewindspersonen", "29")
columns[1].metric("Ministeries", "12")
columns[2].metric("Openstaande toezeggingen", "143", "8 deze maand afgerond")

st.divider()
left, right = st.columns([1, 1.2])
with left:
    st.subheader("Bewindspersonen per ministerie")
    st.bar_chart(
        {
            "Ministerie": ["AZ", "BZ", "Defensie", "EZ", "Financiën", "IenW"],
            "Bewindspersonen": [4, 3, 3, 2, 2, 2],
        },
        x="Ministerie",
        y="Bewindspersonen",
        color="#18836b",
        horizontal=True,
    )
with right:
    st.subheader("Portefeuilles")
    st.dataframe(
        [
            {"Ministerie": "Algemene Zaken", "Bewindspersonen": 4, "Toezeggingen": 18, "Status": "Actief"},
            {"Ministerie": "Buitenlandse Zaken", "Bewindspersonen": 3, "Toezeggingen": 24, "Status": "Actief"},
            {"Ministerie": "Defensie", "Bewindspersonen": 3, "Toezeggingen": 11, "Status": "Actief"},
            {"Ministerie": "Financiën", "Bewindspersonen": 2, "Toezeggingen": 16, "Status": "Actief"},
            {"Ministerie": "Infrastructuur en Waterstaat", "Bewindspersonen": 2, "Toezeggingen": 9, "Status": "Actief"},
        ],
        hide_index=True,
        width="stretch",
    )