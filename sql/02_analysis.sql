-- 02_analysis.sql
-- Six analysis queries. build.py runs each query and writes its result to the
-- CSV named in the marker line that precedes it.

-- Where does utilization and spend concentrate, by site of care?
-- >>> by_encounter_class.csv
SELECT
    encounter_class,
    COUNT(*)                                                         AS encounters,
    ROUND(SUM(total_cost), 0)                                        AS total_cost,
    ROUND(AVG(total_cost), 0)                                        AS avg_cost,
    ROUND(SUM(payer_coverage), 0)                                    AS payer_covered,
    ROUND(SUM(patient_resp), 0)                                      AS patient_responsibility,
    ROUND(100.0 * SUM(total_cost) / (SELECT SUM(total_cost) FROM enc), 1) AS pct_of_total_cost
FROM enc
GROUP BY encounter_class
ORDER BY total_cost DESC;

-- Payer mix: how much does each payer cover vs. leave to the patient?
-- >>> by_payer.csv
SELECT
    payer_name,
    payer_type,
    COUNT(*)                                                         AS encounters,
    ROUND(SUM(total_cost), 0)                                        AS total_cost,
    ROUND(SUM(payer_coverage), 0)                                    AS payer_covered,
    ROUND(SUM(patient_resp), 0)                                      AS patient_responsibility,
    ROUND(100.0 * SUM(payer_coverage) / NULLIF(SUM(total_cost), 0), 1) AS pct_covered
FROM enc
GROUP BY payer_name, payer_type
ORDER BY total_cost DESC;

-- Which diagnoses carry the most encounter cost? (SNOMED-coded conditions joined
-- to the cost of the encounter they were recorded in.)
-- >>> top_conditions_by_cost.csv
SELECT
    c.DESCRIPTION              AS condition,
    c.CODE                     AS snomed_code,
    COUNT(DISTINCT c.PATIENT)  AS patients,
    COUNT(*)                   AS condition_records,
    ROUND(SUM(enc.total_cost), 0) AS encounter_cost
FROM conditions c
JOIN enc ON c.ENCOUNTER = enc.encounter_id
GROUP BY c.DESCRIPTION, c.CODE
ORDER BY encounter_cost DESC
LIMIT 20;

-- Cost concentration: every patient ranked by total cost, with their share of
-- the total (a Pareto / high-cost-cohort view).
-- >>> high_cost_patients.csv
SELECT
    patient_id,
    gender,
    age,
    encounters,
    ROUND(total_cost, 0) AS total_cost,
    ROUND(100.0 * total_cost / (SELECT SUM(total_cost) FROM patient_cost), 2) AS pct_of_total_cost
FROM patient_cost
ORDER BY total_cost DESC;

-- The procedures generating the most in charges, at the claim-line level
-- (CHARGE rows in claims_transactions, grouped by procedure code).
-- >>> top_procedures_by_charges.csv
SELECT
    PROCEDURECODE                                   AS procedure_code,
    MAX(NOTES)                                      AS description,
    COUNT(*)                                        AS claim_lines,
    ROUND(SUM(CAST(NULLIF(AMOUNT, '') AS REAL)), 0) AS total_charged
FROM claims_transactions
WHERE TYPE = 'CHARGE' AND PROCEDURECODE <> ''
GROUP BY PROCEDURECODE
ORDER BY total_charged DESC
LIMIT 20;

-- Average cost per patient by age band and sex.
-- >>> cost_by_age_sex.csv
SELECT
    CASE WHEN age < 18 THEN '0-17'
         WHEN age < 35 THEN '18-34'
         WHEN age < 50 THEN '35-49'
         WHEN age < 65 THEN '50-64'
         ELSE '65+' END AS age_band,
    gender,
    COUNT(*)                          AS patients,
    ROUND(SUM(total_cost), 0)         AS total_cost,
    ROUND(AVG(total_cost), 0)         AS avg_cost_per_patient
FROM patient_cost
GROUP BY age_band, gender
ORDER BY age_band, gender;
