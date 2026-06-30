# Run this analysis on BigQuery

The SQLite pipeline (`../sql/`) ported to **BigQuery Standard SQL**. Runs on the **free BigQuery sandbox** (no billing).

> Adapted from the tested SQLite version. BigQuery-dialect changes: `SAFE_CAST` for typing, year-prefix math for patient age (instead of SQLite's `julianday`), `CREATE OR REPLACE VIEW`, and dataset-qualified names. Confirm on first run.

## Prerequisite
Download the Synthea sample CSVs into `data/` first (see the main `../README.md` → "Reproduce it").

## Option A — Command line (`bq`) — recommended here
The `bq` CLI handles the large `claims_transactions.csv` (~50 MB) that the web console's direct upload may reject.
```bash
bash bigquery/load.sh
```
Loads the 5 tables, creates the `enc` + `patient_cost` views, and runs the six analyses.

## Option B — Web console (no install)
1. Open the **BigQuery console** (`console.cloud.google.com/bigquery`) — first visit enables a free **sandbox** project.
2. **Create dataset** → ID `synthea` (location US).
3. **Create table** (Upload → Auto-detect schema) for each CSV, using these exact table names:
   `patients`, `encounters`, `conditions`, `payers`, `claims_transactions`.
   - ⚠️ `claims_transactions.csv` is ~50 MB. If the console upload rejects it, either use **Option A**, or load it from a **GCS bucket** (Drive/GCS → BigQuery). The other five queries run without it; only **Q5 (top procedures)** needs it.
4. New query tab → paste **`analysis.sql`** → Run.

## Notes
- `dataset.table` references resolve to your default/sandbox project — no project ID hard-coded.
- Patient age is computed as `(latest encounter year) − (birth year)` to avoid assumptions about how BigQuery typed the timestamp/date columns on load.
