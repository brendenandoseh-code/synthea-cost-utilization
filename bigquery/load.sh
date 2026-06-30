#!/usr/bin/env bash
# Load the Synthea synthetic-claims tables into BigQuery, create the views, and run the analyses.
# Works on the free BigQuery sandbox. Prereqs: Google Cloud SDK (gcloud + bq),
# `gcloud auth login`, `gcloud config set project YOUR_PROJECT_ID`, and the Synthea
# CSVs already downloaded into data/ (see ../README.md "Reproduce it").
# Run from the repo root:  bash bigquery/load.sh
set -euo pipefail
DATASET=synthea

bq --location=US mk -f --dataset "$DATASET"

# Auto-detect keeps Synthea's clean header names (Id, START, TOTAL_CLAIM_COST, ...),
# which is what bigquery/analysis.sql references.
for t in patients encounters conditions payers claims_transactions; do
    echo "loading ${t}..."
    bq load --replace --autodetect --source_format=CSV --skip_leading_rows=1 \
        "${DATASET}.${t}" "data/${t}.csv"
done

# Creates the enc + patient_cost views and runs the six analyses.
bq query --use_legacy_sql=false < "bigquery/analysis.sql"

echo "Done — explore dataset '${DATASET}' in the BigQuery console."
