from pathlib import Path
import duckdb

map_hier = Path(__file__).resolve().parent
hoofdmap = map_hier.parent.parent          # tweedekamer-monitor
database = hoofdmap / "tweedekamer.duckdb"
sql_map = map_hier / "SQL"

if not database.exists():
    raise FileNotFoundError(f"Database niet gevonden: {database}")
if not sql_map.exists():
    raise FileNotFoundError(f"SQL-map niet gevonden: {sql_map}")

connection = duckdb.connect(str(database), read_only=True)

data_map = map_hier / "data"
data_map.mkdir(exist_ok=True)

for sql_bestand in sorted(sql_map.glob("*.sql")):
    df = connection.execute(sql_bestand.read_text(encoding="utf-8")).fetchdf()
    df.to_csv(data_map / f"{sql_bestand.stem}.csv", index=False)
    print(f"{sql_bestand.stem}: {len(df)} rijen opgeslagen")