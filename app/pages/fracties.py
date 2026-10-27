import altair as alt
import streamlit as st

from db import get_connection

st.set_page_config(page_title="Fracties · Tweede Kamer Monitor", page_icon=":material/account_balance:", layout="wide")

st.title("Fracties")
st.write("Zetelverdeling en vertegenwoordiging in de Tweede Kamer.")

conn = get_connection()
fracties = conn.semantic_view(
    "sv.Fracties",
    dimensions=["FractieNaam", "FractieAfkorting", "FractieAantalZetels"],
    metrics=["AantalPersonen"],
    order_by="AantalPersonen DESC, FractieNaam",
).rename(
    columns={
        "FractieNaam": "Fractie",
        "FractieAfkorting": "Afkorting",
        "FractieAantalZetels": "Zetels",
        "AantalPersonen": "Kamerleden",
    }
)

if fracties.empty:
    st.warning("Er zijn geen fracties gevonden.")
    st.stop()

grootste = fracties.iloc[0]
columns = st.columns(3)
columns[0].metric("Fracties", len(fracties))
columns[1].metric("Kamerleden", int(fracties["Kamerleden"].sum()))
columns[2].metric("Grootste fractie", f"{grootste['Kamerleden']} Kamerleden", grootste["Fractie"], delta_color="off")

st.divider()
st.subheader("Zetelverdeling")

fracties["Volgorde"] = range(len(fracties))
fracties["Midden"] = fracties["Kamerleden"].cumsum() - fracties["Kamerleden"] / 2
bar = alt.Chart(fracties).encode(
    x=alt.X("Kamerleden:Q", stack="zero", axis=None),
    y=alt.value(25),
    order=alt.Order("Volgorde:Q"),
    tooltip=["Fractie", "Afkorting", "Kamerleden"],
)
segments = bar.mark_bar(height=50).encode(
    color=alt.Color(
        "Afkorting:N",
        sort=alt.EncodingSortField("Volgorde"),
        scale=alt.Scale(scheme="tableau20"),
        legend=alt.Legend(title="Fractie", orient="bottom", columns=9),
    )
)
labels = (
    alt.Chart(fracties)
    .mark_text(fontWeight="bold", baseline="middle", color="white")
    .encode(x=alt.X("Midden:Q", axis=None), y=alt.value(25), text="Kamerleden:Q")
)
st.altair_chart((segments + labels).properties(height=140).configure_view(stroke=None), width="stretch")

st.subheader("Fractieoverzicht")
st.dataframe(
    fracties[["Fractie", "Afkorting", "Zetels"]],
    hide_index=True,
    width="stretch",
    height="content",
)
