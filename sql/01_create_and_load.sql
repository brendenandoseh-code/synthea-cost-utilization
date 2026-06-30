-- 01_create_and_load.sql
-- Cleaning layer for the Synthea synthetic-claims analysis.
-- build.py loads the raw Synthea CSVs into base tables (all TEXT); these views
-- cast the numeric/cost fields and join encounters -> payers -> patients so the
-- analysis queries in 02_analysis.sql stay readable.

-- Encounter-level claims view: one row per encounter, with cost split into
-- payer coverage vs. patient responsibility, plus payer type and patient demographics.
DROP VIEW IF EXISTS enc;
CREATE VIEW enc AS
SELECT
    e.Id                                              AS encounter_id,
    e.PATIENT                                         AS patient_id,
    substr(e.START, 1, 4)                             AS year,
    e.ENCOUNTERCLASS                                  AS encounter_class,
    CAST(NULLIF(e.TOTAL_CLAIM_COST, '') AS REAL)      AS total_cost,
    CAST(NULLIF(e.PAYER_COVERAGE,   '') AS REAL)      AS payer_coverage,
    CAST(NULLIF(e.TOTAL_CLAIM_COST, '') AS REAL)
      - CAST(NULLIF(e.PAYER_COVERAGE, '') AS REAL)    AS patient_resp,
    p.NAME                                            AS payer_name,
    CASE
        WHEN p.NAME = 'NO_INSURANCE'   THEN 'Uninsured'
        WHEN p.OWNERSHIP = 'GOVERNMENT' THEN 'Government'
        ELSE 'Private'
    END                                               AS payer_type,
    pt.GENDER                                         AS gender,
    pt.BIRTHDATE                                      AS birthdate
FROM encounters e
LEFT JOIN payers   p  ON e.PAYER   = p.Id
LEFT JOIN patients pt ON e.PATIENT = pt.Id;

-- Patient-level rollup: total cost and utilization per patient, with age
-- computed as of the most recent encounter in the dataset (so it's data-consistent,
-- not tied to today's date).
DROP VIEW IF EXISTS patient_cost;
CREATE VIEW patient_cost AS
SELECT
    pt.Id     AS patient_id,
    pt.GENDER AS gender,
    CAST((julianday((SELECT MAX(START) FROM encounters)) - julianday(pt.BIRTHDATE)) / 365.25 AS INT) AS age,
    COUNT(e.Id)                                                        AS encounters,
    COALESCE(SUM(CAST(NULLIF(e.TOTAL_CLAIM_COST, '') AS REAL)), 0)     AS total_cost
FROM patients pt
LEFT JOIN encounters e ON e.PATIENT = pt.Id
GROUP BY pt.Id, pt.GENDER, pt.BIRTHDATE;
