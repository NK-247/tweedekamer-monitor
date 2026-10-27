# Tweede Kamer Monitor

This repository contains an open-source data pipeline and dashboard for studying the work of the Dutch House of Representatives (Tweede Kamer).

The pipeline can be found in the `pipeline/` folder and ingests the public Tweede Kamer Open Data feed into a local DuckDB database and transforms the data into clean silver and gold tables. The `eda/` folder contains Jupyter notebooks for exploring themes such as voting, documents, commitments, and parliamentary activity. The code for the dashboard can be found in the `app/` folder.

## Quick start

Install Conda, then clone the repository or your fork:

```bash
git clone https://github.com/afvanwoudenberg/tweedekamer-monitor.git
cd tweedekamer-monitor
```

Create and activate the environment defined in `environment.yml`:

```bash
conda env create --file environment.yml
conda activate tweedekamer_monitor
```

## Run the data pipeline

Run the pipeline to ingest the live public feed and build the silver models:

```bash
python pipeline/run_pipeline.py
```

This can take some time (several hours) because it reads the entire feed. You can limit ingestion like this:

```bash
python pipeline/run_pipeline.py --max-pages 2000
```

The pipeline writes `tweedekamer.duckdb` in the repository root. This local database is ignored by Git and is not included when you clone the repository.

## Explore the data

Start JupyterLab from the repository folder:

```bash
jupyter lab
```

The notebooks in `eda/` query the local DuckDB database and are intended for exploration and analysis.

## Run the dashboard

From the repository root, with the Conda environment active, start the Streamlit app:

```bash
streamlit run app/app.py
```

## Project layout

- `pipeline/ingest/` contains the dlt feed ingestion code and source XSD schemas.
- `pipeline/transform/` contains the dbt project, silver and gold models, and macros.
- `app/` contains the dashboard.
- `eda/` contains the exploratory Jupyter notebooks.
- `utils/` contains helper scripts.

For the data architecture and layer descriptions, see [ARCHITECTURE.md](ARCHITECTURE.md). For contribution steps, see [CONTRIBUTING.md](CONTRIBUTING.md). 

## License

This project is released under the [MIT License](LICENSE).

