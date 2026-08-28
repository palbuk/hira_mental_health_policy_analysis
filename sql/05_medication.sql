-- EDU530은 DIV_TY_CD 값이 있는 208,992행 전체가 '3'이므로 '3'을 약품 항목으로
-- 취급한다. 두 원천에 같은 필터를 명시해 일관성을 유지한다.
-- 먼저 상세 금액을 MID 단위로 집계한다. 이렇게 해야 EDU300이나 EDU530의 여러 행이
-- JID로 롤업되기 전에 서로를 중복시키지 않는다.
CREATE OR REPLACE TEMP TABLE medication_by_mid AS
SELECT c.mid, c.jid,
    COALESCE(h.hospital_amt, 0) AS hospital_amt,
    COALESCE(p.pharmacy_amt, 0) AS pharmacy_amt,
    COALESCE(h.hospital_amt, 0) + COALESCE(p.pharmacy_amt, 0) AS total_medication_amt,
    GREATEST(COALESCE(h.hospital_days, 0), COALESCE(p.pharmacy_days, 0)) AS medication_days
FROM edu200 c
LEFT JOIN (
    SELECT mid, SUM(amt) AS hospital_amt,
        MAX(COALESCE(tot_injc_ddcnt_exec_fq, 0)) AS hospital_days
    FROM edu300 WHERE div_ty_cd = '3' GROUP BY mid
) h USING (mid)
LEFT JOIN (
    SELECT mid, SUM(amt) AS pharmacy_amt,
        MAX(COALESCE(tot_injc_ddcnt_exec_fq, 0)) AS pharmacy_days
    FROM edu530 WHERE div_ty_cd = '3' GROUP BY mid
) p USING (mid);

-- TOT_INJC_DDCNT_EXEC_FQ는 총 투여일수 또는 실행 횟수를 의미한다.
-- MID별로 SUM 대신 MAX를 사용한다. 30일 처방 약이 세 종류라 해도 90일로 계산하지
-- 않기 위해서다. GREATEST는 병원과 약국의 기간이 겹칠 수 있으므로 두 기간을 더하지
-- 않게 한다. 이 값은 명시된 기간 대용 지표다.
-- MID 단위 집계가 끝난 뒤에만 롤업한다. 결과는 코호트별로 묶고, 환자 수는 상세 행 수가
-- 아니라 고유 JID 수로 계산한다.
-- 이는 MID 단위 질문이다. 정신질환 진료 명세서 자체의 투약비 특성을 비교한다.
-- 이 기준에서는 한 환자가 두 종류의 명세서를 모두 가지면 양쪽에 포함될 수 있다.
SELECT co.cohort, COUNT(DISTINCT m.mid) AS claim_count,
       COUNT(DISTINCT m.jid) AS patient_count,
    SUM(m.hospital_amt) AS hospital_medication_cost,
    SUM(m.pharmacy_amt) AS pharmacy_medication_cost,
    SUM(m.total_medication_amt) AS total_medication_cost,
    SUM(m.hospital_amt) / NULLIF(COUNT(DISTINCT m.jid), 0) AS hospital_cost_per_patient,
    SUM(m.pharmacy_amt) / NULLIF(COUNT(DISTINCT m.jid), 0) AS pharmacy_cost_per_patient,
    SUM(m.total_medication_amt) / NULLIF(COUNT(DISTINCT m.jid), 0) AS total_cost_per_patient,
    SUM(m.total_medication_amt) / NULLIF(SUM(m.medication_days), 0) AS medication_cost_per_day
FROM medication_by_mid m
JOIN mental_cohort_mid co ON m.mid = co.mid
GROUP BY co.cohort
ORDER BY co.cohort;

-- 서로 겹치지 않는 환자 코호트를 만든다. 먼저 명세서 단위인 MID에서 제외 명세서를
-- 제거한 뒤, 남은 MID 중 하나라도 mental_health이면 해당 환자를 정신질환군으로
-- 분류한다. 이렇게 제외 기준을 명확히 하고 한 환자가 두 집단에 동시에 배정되지 않게 한다.
CREATE OR REPLACE TEMP TABLE mental_cohort_jid AS
SELECT c.jid,
       CASE WHEN MAX(CASE WHEN co.cohort = 'mental_health' THEN 1 ELSE 0 END) = 1
            THEN 'mental_health' ELSE 'comparison' END AS cohort
FROM edu200 c
LEFT JOIN mental_cohort_mid co ON c.mid = co.mid
GROUP BY c.jid;

-- 제외되지 않은 MID의 모든 투약비를 JID별로 집계한다. LEFT JOIN은 남은 투약 상세가
-- 없는 환자도 유지하고, COALESCE는 그 금액을 0으로 처리한다.
CREATE OR REPLACE TEMP TABLE medication_by_jid AS
SELECT p.jid, p.cohort,
       COALESCE(SUM(m.hospital_amt), 0) AS hospital_amt,
       COALESCE(SUM(m.pharmacy_amt), 0) AS pharmacy_amt,
       COALESCE(SUM(m.total_medication_amt), 0) AS total_medication_amt,
       COALESCE(SUM(m.medication_days), 0) AS medication_days
FROM mental_cohort_jid p
LEFT JOIN (
    SELECT m.*
    FROM medication_by_mid m
    JOIN mental_cohort_mid co ON m.mid = co.mid
) m ON p.jid = m.jid
GROUP BY p.jid, p.cohort;

-- 이는 환자 단위 질문이다. 정신질환 이력이 있는 환자와 없는 환자의 전체 투약비 부담을
-- 비교한다. 기대 환자 수는 각각 525명과 1,028명이며, 전체 1,553명을 합산한 값이다.
SELECT cohort, COUNT(*) AS patient_count,
       SUM(hospital_amt) AS hospital_medication_cost,
       SUM(pharmacy_amt) AS pharmacy_medication_cost,
       SUM(total_medication_amt) AS total_medication_cost,
       SUM(hospital_amt) / NULLIF(COUNT(*), 0) AS hospital_cost_per_patient,
       SUM(pharmacy_amt) / NULLIF(COUNT(*), 0) AS pharmacy_cost_per_patient,
       SUM(total_medication_amt) / NULLIF(COUNT(*), 0) AS total_cost_per_patient,
       SUM(total_medication_amt) / NULLIF(SUM(medication_days), 0) AS medication_cost_per_day
FROM medication_by_jid
GROUP BY cohort
ORDER BY cohort;

SELECT 'mental_cohort_jid_count' AS check_name,
       SUM(CASE WHEN cohort = 'mental_health' THEN 1 ELSE 0 END) AS mental_health_patients,
       SUM(CASE WHEN cohort = 'comparison' THEN 1 ELSE 0 END) AS comparison_patients,
       COUNT(*) AS total_patients
FROM mental_cohort_jid;
