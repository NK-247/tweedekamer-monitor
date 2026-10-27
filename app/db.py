from pathlib import Path

import streamlit as st

from connection import SemanticLayerConnection

SEMANTIC_LAYER_SQL = Path(__file__).with_name("semantic_layer.sql")


def get_connection() -> SemanticLayerConnection:
    """Return the connection shared by all pages.

    Streamlit caches connections by name and arguments, so every page that calls
    this gets the same DuckDB instance; the init script runs once per server process.
    """
    return st.connection(
        "tweedekamer",
        type=SemanticLayerConnection,
        init_script=SEMANTIC_LAYER_SQL,
        config={"allow_unsigned_extensions": True},
        show_spinner="Gegevens van de Tweede Kamer ophalen...",
    )
