-- ============================================================
-- Synthetic Claims Cost & Utilization — BigQuery Standard SQL
-- Adapted from ../sql/. Dataset assumed: `synthea`.
-- Tables (loaded by load.sh): patients, encounters, conditions, payers, claims_transactions.
-- SAFE_CAST handles typing; age uses the 4-char year prefix to avoid date-format assumptions.
-- ============================================================

-- Encounter-level claims view.
CREATE OR REPLACE VIEW synthea.enc AS
SELECT
    e.Id                                    AS encounter_id,
    e.PATIENT                               AS patient_id,
    SUBSTR(CAST(e.START AS STRING), 1, 4)   AS year,
    e.ENCOUNTERCLASS                        AS encounter_class,
    SAFE_CAST(e.TOTAL_CLAIM_COST AS FLOAT64) AS total_cost,
    SAFE_CAST(e.PAYER_COVERAGE   AS FLOAT64) AS payer_coverage,
    SAFE_CAST(e.TOTAL_CLAIM_COST AS FLOAT64)
      - SAFE_CAST(e.PAYER_COVERAGE AS FLOAT64) AS patient_resp,
    p.NAME                                  AS payer_name,
    CASE
        WHEN p.NAME = 'NO_INSURANCE'    THEN 'Uninsured'
        WHEN p.OWNERSHIP = 'GOVERNMENT' THEN 'Government'
        ELSE 'Private'
    END                                     AS payer_type,
    pt.GENDER                               AS gender,
    pt.BIRTHDATE                            AS birthdate
FROM synthea.encounters e
LEFT JOIN synthea.payers   p  ON e.PAYER   = p.Id
LEFT JOIN synthea.patients pt ON e.PATIENT = pt.Id;

-- Patient-level rollup. Age = (latest encounter year) - (birth year).
CREATE OR REPLACE VIEW synthea.patient_cost AS
SELECT
    pt.Id     AS patient_id,
    pt.GENDER AS gender,
    SAFE_CAST(SUBSTR(CAST((SELECT MAX(START) FROM synthea.encounters) AS STRING), 1, 4) AS INT64)
      - SAFE_CAST(SUBSTR(CAST(pt.BIRTHDATE AS STRING), 1, 4) AS INT64) AS age,
    COUNT(e.Id)                                                    AS encounters,
    COALESCE(SUM(SAFE_CAST(e.TOTAL_CLAIM_COST AS FLOAT64)), 0)     AS total_cost
FROM synthea.patients pt
LEFT JOIN synthea.encounters e ON e.PATIENT = pt.Id
GROUP BY pt.Id, pt.GENDER, pt.BIRTHDATE;

-- Q1. Spend & utilization by site of care.
SELECT encounter_class,
       COUNT(*)                  AS encounters,
       ROUND(SUM(total_cost), 0) AS total_cost,
       ROUND(AVG(total_cost), 0) AS avg_cost,
       ROUND(SUM(payer_coverage), 0) AS payer_covered,
       ROUND(SUM(patient_resp), 0)   AS patient_responsibility,
       ROUND(100.0 * SUM(total_cost) / (SELECT SUM(total_cost) FROM synthea.enc), 1) AS pct_of_total_cost
FROM synthea.enc GROUP BY encounter_class ORDER BY total_cost DESC;

-- Q2. Payer mix & coverage.
SELECT payer_name, payer_type,
       COUNT(*)                  AS encounters,
       ROUND(SUM(total_cost), 0) AS total_cost,
       ROUND(SUM(payer_coverage), 0) AS payer_covered,
       ROUND(SUM(patient_resp), 0)   AS patient_responsibility,
       ROUND(100.0 * SUM(payer_coverage) / NULLIF(SUM(total_cost), 0), 1) AS pct_covered
FROM synthea.enc GROUP BY payer_name, payer_type ORDER BY total_cost DESC;

-- Q3. Diagnoses by encounter cost (SNOMED-coded conditions).
SELECT c.DESCRIPTION AS condition, c.CODE AS snomed_code,
       COUNT(DISTINCT c.PATIENT) AS patients,
       COUNT(*)                  AS condition_records,
       ROUND(SUM(enc.total_cost), 0) AS encounter_cost
FROM synthea.conditions c
JOIN synthea.enc ON c.ENCOUNTER = enc.encounter_id
GROUP BY c.DESCRIPTION, c.CODE ORDER BY encounter_cost DESC LIMIT 20;

-- Q4. Cost concentration: every patient ranked by total cost.
SELECT patient_id, gender, age, encounters, ROUND(total_cost, 0) AS total_cost,
       ROUND(100.0 * total_cost / (SELECT SUM(total_cost) FROM synthea.patient_cost), 2) AS pct_of_total_cost
FROM synthea.patient_cost ORDER BY total_cost DESC;

-- Q5. Top procedures by charges (claim-line CHARGE rows).
SELECT PROCEDURECODE AS procedure_code,
       MAX(NOTES)    AS description,
       COUNT(*)      AS claim_lines,
       ROUND(SUM(SAFE_CAST(AMOUNT AS FLOAT64)), 0) AS total_charged
FROM synthea.claims_transactions
WHERE TYPE = 'CHARGE' AND PROCEDURECODE IS NOT NULL   -- empty codes load as NULL under auto-detect
GROUP BY PROCEDURECODE ORDER BY total_charged DESC LIMIT 20;

-- Q6. Cost per patient by age band and sex.
SELECT CASE WHEN age < 18 THEN '0-17'
            WHEN age < 35 THEN '18-34'
            WHEN age < 50 THEN '35-49'
            WHEN age < 65 THEN '50-64'
            ELSE '65+' END AS age_band,
       gender,
       COUNT(*)                  AS patients,
       ROUND(SUM(total_cost), 0) AS total_cost,
       ROUND(AVG(total_cost), 0) AS avg_cost_per_patient
FROM synthea.patient_cost GROUP BY age_band, gender ORDER BY age_band, gender;
