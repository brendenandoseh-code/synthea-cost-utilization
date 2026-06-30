# Tableau Dashboard Build Guide — Cost & Utilization (Synthea)

Goal: a **"Synthetic Claims: Cost & Utilization"** dashboard for Tableau Public. ~30–45 min. Each sheet uses one of the `outputs/*.csv` files (run `py build.py` first).

## Connect the data
1. Run `py build.py` to generate `outputs/`.
2. Tableau Public → **Connect → Text file** → `outputs/by_encounter_class.csv` (first source).
3. Add the others as **separate** data sources: `by_payer.csv`, `high_cost_patients.csv`, `top_procedures_by_charges.csv`, `cost_by_age_sex.csv`.

## Sheet 1 — "Where the spend goes" (bar, from `by_encounter_class.csv`)
- Columns: `total_cost` · Rows: `encounter_class` (sort descending). Label with `pct_of_total_cost`.
- Title: **"Ambulatory care drives most spend."**

## Sheet 2 — "Payer mix & coverage" (stacked bar, from `by_payer.csv`)
- Rows: `payer_name` (sorted by `total_cost`). Columns: `payer_covered` and `patient_responsibility` (drag both to Columns → Measure Values, or build a stacked bar). Color by measure.
- Add `pct_covered` as a label or tooltip. Color `payer_type` if you prefer Government vs. Private vs. Uninsured.
- Title: **"Coverage ranges from 98% (Medicaid) to 0% (uninsured)."**

## Sheet 3 — "High-cost cohort" (Pareto, from `high_cost_patients.csv`)
- Columns: `patient_id` sorted descending by `total_cost`. Rows: `total_cost` (bars).
- Add a **running-total** of `pct_of_total_cost` as a second axis (line) → a Pareto curve showing the top decile's share.
- Title: **"The costliest ~9% of patients drive ~39% of cost."**

## Sheet 4 — "Top procedures by charges" (bar, from `top_procedures_by_charges.csv`)
- Columns: `total_charged` · Rows: `description` (sort descending). Tooltip: `procedure_code`, `claim_lines`.
- Title: **"A few recurring procedures dominate charges."**

## Sheet 5 — "Cost by age & sex" (highlight table, from `cost_by_age_sex.csv`)
- Rows: `age_band` · Columns: `gender` · Color & label: `avg_cost_per_patient`.
- Title: **"Cost per patient rises with age."**

## Assemble
1. Dashboard 1200×900. Sheet 1 top-left, Sheet 2 top-right, Sheet 3 across the middle (it's the hero), Sheets 4–5 along the bottom.
2. Dashboard title: **"Synthetic Claims — Cost & Utilization (Synthea)."**
3. Footer (the honesty that builds credibility):
   *"Source: Synthea (MITRE) synthetic patient records — 113 patients, fictional data, no PHI. Built to demonstrate claims SQL/BI workflow; not for clinical or actuarial conclusions."*

## Publish
- **File → Save to Tableau Public.** Copy the URL into your resume, LinkedIn **Featured**, and the top of this README.

## Talking point (for interviews)
> "I wanted hands-on reps with claims-shaped data, so I used Synthea's synthetic records — encounters with payer-coverage splits, SNOMED diagnoses, and 118K claim-line transactions — and built the analysis a payer team would run: spend by site of care, payer mix and coverage, the high-cost cohort, and top procedures by charges. The clearest pattern was concentration — the costliest ~9% of patients drove ~39% of cost, which is the case for care management. I'm explicit that it's synthetic, so I treat it as a workflow demonstration, not a real-world finding."
