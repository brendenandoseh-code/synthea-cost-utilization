# Healthcare Cost & Utilization on Synthetic Claims Data (Synthea)

**Author:** Brenden Andoseh · [LinkedIn](https://www.linkedin.com/in/brenden-andoseh-189484177/)
**Stack:** SQL (SQLite) · Python (stdlib) · Tableau
**Data:** [Synthea](https://synthetichealth.github.io/synthea/) — MITRE's open-source synthetic patient generator (sample set: 113 patients · 7,210 encounters · 118,466 claim-line transactions)

> I built this to practice the claims-data work that U.S. healthcare-analyst roles assume — payer mix, cost and utilization, high-cost cohorts, and claim-line charges — on data I can share openly. Synthea generates realistic but entirely synthetic patients, so there's no PHI and nothing to conclude about real people; the point is the pipeline and the SQL, not the patients.

---

## Business problem
A payer or value-based-care team needs to know where spend and utilization concentrate — which sites of care, which payers, which patients — to target care management and contain cost. This project takes a synthetic claims dataset and answers those questions end to end in SQL.

## The data
Synthea's CSV export models a full claims footprint: `patients` (demographics, expenses), `encounters` (each with `TOTAL_CLAIM_COST` and `PAYER_COVERAGE`), `conditions` (SNOMED-coded diagnoses), `payers` (Medicare, Medicaid, Dual Eligible, and commercial plans), and `claims_transactions` (118,466 line-item CHARGE/PAYMENT rows with procedure codes). It's the same file structure and code systems a real analyst works with, without the privacy constraints.

## Method
1. **Load** the five relevant Synthea CSVs into SQLite (`build.py`, standard library only).
2. **Clean** with two SQL views (`sql/01_create_and_load.sql`) — cast the cost fields, split each encounter into payer-covered vs. patient-responsibility, classify payers as Government / Private / Uninsured, and roll cost up per patient.
3. **Analyze** with six queries (`sql/02_analysis.sql`) → six Tableau-ready CSVs.
4. **Visualize** in Tableau Public.

## Key findings *(synthetic data — illustrative, not real)*

**1. Spend concentrates in ambulatory care and in a few patients.** Across **$16.3M** in encounter charges (113 patients), ambulatory visits drove **58%** of spend and inpatient 13%. The costliest **~9% of patients (11 of 113) accounted for 39%** of total cost — one patient alone for 8.7%. That high-cost-cohort pattern is exactly what care-management programs are built around.

**2. Payer coverage varies widely, and the uninsured carry the gap.** Payer-covered share ran from **98%** (Medicaid, Dual Eligible) and ~80% (Medicare, UnitedHealthcare) down to **48%** (Humana), while uninsured encounters left the full **$1.43M** as patient responsibility. Overall: payers 71%, patients 29%.

**3. A few procedures dominate charges.** At the claim-line level, combined chemotherapy/radiation (**$1.18M**) and renal dialysis (**$1.13M across 1,355 lines**) led total charges — the high-cost, recurring services a cost-containment review looks at first.

**4. Cost rises with age, as a sanity check.** Average cost per patient climbed from ~$22K (under 18) to ~$237K (women 65+), confirming the synthetic population behaves plausibly before any of the above is trusted.

## How a payer / value-based team would use this
- Stand up **care management for the high-cost cohort** — the top decile is where intervention pays back.
- Watch the **uninsured / high-patient-responsibility** segment for access and bad-debt risk.
- Review the **high-charge recurring procedures** (dialysis, chemotherapy) for site-of-care and contracting decisions.

*(Framed as how the analysis would be used — the patients are synthetic, so these aren't real recommendations.)*

## Honest notes (data caveats)
- **Synthetic data.** Synthea generates statistically plausible but fictional patients. This demonstrates the pipeline and SQL; it is not a source of clinical or actuarial conclusions.
- **Small sample** (113 patients) — fine for exercising the queries, far too small for population inference.
- **SNOMED, not ICD-10.** Synthea codes diagnoses in SNOMED CT (e.g., `72892002` = normal pregnancy). The join-to-code-tables work is identical to ICD-10/CPT; only the code set differs.
- **Condition cost is attributed at the encounter level**, so when one encounter records several conditions they each carry that encounter's cost (which is why "Medication review due" shows for all 113 patients). Treat `top_conditions_by_cost` as directional.
- **Charges fully reconcile to payments** in Synthea (100% collection, split payer/patient); real claims carry denials and bad debt this data does not model.

## Reproduce it
```bash
# 1. Download the Synthea sample CSV set (~8 MB) and unzip the CSVs into data/:
#    https://synthetichealth.github.io/synthea-sample-data/downloads/latest/synthea_sample_data_csv_latest.zip
# 2. Run the pipeline:
py build.py        # loads to SQLite, runs the SQL, writes outputs/
# then build the dashboard in Tableau Public
```

## Files
```
synthea-cost-utilization/
├─ README.md
├─ build.py                       ← load → clean → analyze (stdlib only)
├─ data/                          ← Synthea CSVs (not committed; download — see above)
├─ sql/01_create_and_load.sql     ← cleaning views (cost split, payer type, per-patient rollup)
├─ sql/02_analysis.sql            ← 6 analysis queries
└─ outputs/                       ← Tableau-ready CSVs (generated)
```
