"""Streamlit connection for querying SQL and DuckDB semantic views.

Usage in a page:

    from connection import SemanticLayerConnection

    conn = st.connection(
        "semantic_layer",
        type=SemanticLayerConnection,
        database=":memory:",                 # or a DuckDB file; optional
        init_script="semantic_layer.sql",    # optional
        config={"allow_unsigned_extensions": True},  # optional DuckDB settings
    )
    df = conn.query("SELECT * FROM mart.Fractie")
    df = conn.semantic_view(
        "sv.Fracties",
        dimensions=["FractieNaam"],
        metrics=["AantalPersonen"],
    )
"""

import re
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import duckdb
import pandas as pd
import streamlit as st
from streamlit.connections import BaseConnection


def _literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _list_literal(values: Sequence[str]) -> str:
    return "[" + ", ".join(_literal(v) for v in values) + "]"


def _split_statements(script: str) -> list[str]:
    """Split a SQL script on semicolons that end a line; drops comment-only chunks."""
    statements = []
    for chunk in re.split(r";[ \t]*(?:\n|$)", script):
        lines = [line for line in chunk.splitlines() if not line.lstrip().startswith("--")]
        if any(line.strip() for line in lines):
            statements.append(chunk.strip())
    return statements


class SemanticLayerConnection(BaseConnection[duckdb.DuckDBPyConnection]):
    """DuckDB connection for any semantic layer built with SQL and DuckDB semantic views.

    Keyword arguments to `st.connection(...)`:
        database: DuckDB file path or ":memory:" (default).
        init_script: optional path to a SQL script run once when connecting, for
            example to load extensions, attach sources and create views.
        config: optional DuckDB configuration dict, for example
            {"allow_unsigned_extensions": True}.
        show_spinner: text shown while a query runs and the result is not cached
            yet, or False to hide the spinner. Defaults to "Gegevens ophalen...".
    """

    def _connect(self, **kwargs: Any) -> duckdb.DuckDBPyConnection:
        database = str(kwargs.pop("database", ":memory:"))
        init_script = kwargs.pop("init_script", None)
        self._show_spinner: str | bool = kwargs.pop("show_spinner", "Gegevens ophalen...")
        conn = duckdb.connect(database, config=kwargs.pop("config", None) or {})
        if init_script is not None:
            # The semantic_views parser extension only handles statements sent one at a time.
            for statement in _split_statements(Path(init_script).read_text(encoding="utf-8")):
                conn.execute(statement)
        return conn

    def cursor(self) -> duckdb.DuckDBPyConnection:
        """Return a cursor; use one per query because the connection is shared across sessions."""
        return self._instance.cursor()

    def query(
        self,
        sql: str,
        *,
        params: Sequence[Any] | dict[str, Any] | None = None,
        ttl: float | int | None = 3600,
    ) -> pd.DataFrame:
        """Run a SQL query and return a cached DataFrame.

        `params` are bound as DuckDB parameters (`?` or `$name`). `ttl` is the cache
        lifetime in seconds (`None` caches forever, `0` disables caching).
        """

        @st.cache_data(ttl=ttl, show_spinner=self._show_spinner)
        def _query(connection_name: str, sql: str, params: Any) -> pd.DataFrame:
            return self.cursor().execute(sql, params).df()

        return _query(self._connection_name, sql, params)

    def semantic_view(
        self,
        name: str,
        *,
        dimensions: Sequence[str] = (),
        metrics: Sequence[str] = (),
        facts: Sequence[str] = (),
        where: str | None = None,
        order_by: str | None = None,
        limit: int | None = None,
        ttl: float | int | None = 3600,
    ) -> pd.DataFrame:
        """Query a semantic view, e.g. `sv.Fracties`, and return a cached DataFrame.

        `where` is a SQL condition on dimensions applied before aggregation. `order_by`
        and `limit` are applied to the result. Pass trusted values only for `where`
        and `order_by`; names and lists are quoted automatically.
        """
        if not (dimensions or metrics or facts):
            raise ValueError("Geef minimaal één dimensie, metric of fact op.")

        args = [_literal(name)]
        for key, values in (("dimensions", dimensions), ("metrics", metrics), ("facts", facts)):
            if values:
                args.append(f"{key} := {_list_literal(values)}")
        if where:
            args.append(f"where_clause := {_literal(where)}")

        sql = f"SELECT * FROM semantic_view({', '.join(args)})"
        if order_by:
            sql += f" ORDER BY {order_by}"
        if limit is not None:
            sql += f" LIMIT {int(limit)}"
        return self.query(sql, ttl=ttl)

    def explain_semantic_view(
        self,
        name: str,
        *,
        dimensions: Sequence[str] = (),
        metrics: Sequence[str] = (),
        facts: Sequence[str] = (),
    ) -> str:
        """Return the SQL that a semantic view query expands to, for debugging."""
        args = [_literal(name)]
        for key, values in (("dimensions", dimensions), ("metrics", metrics), ("facts", facts)):
            if values:
                args.append(f"{key} := {_list_literal(values)}")
        rows = self.cursor().execute(
            f"SELECT * FROM explain_semantic_view({', '.join(args)})"
        ).fetchall()
        return "\n".join(str(row[0]) for row in rows)
