-- 잘못된 쿼리는 중복 합산을 의도적으로 보여준다. EDU200은 MID당 한 행이지만
-- EDU400은 MID당 여러 행일 수 있으므로 명세서 금액이 상병 수만큼 반복된다.
-- 두 쿼리는 같은 코호트 테이블을 사용하고, 추가 상세 조인의 유무만 다르다.
-- COUNT(DISTINCT)는 중복 합산의 영향을 받지 않지만 SUM은 금액을 반복해서 더한다.
-- 이 비대칭 때문에 건수만 확인하면 문제를 놓치기 쉽다.
-- AVG는 중복 합산 배수만큼 직접 커지지는 않지만 상병 수에 따라 가중된다.
-- 따라서 조용히 편향되며 SUM의 부풀림보다 발견하기 어렵다.
CREATE OR REPLACE TEMP TABLE cost_wrong AS
SELECT co.cohort,
       COUNT(DISTINCT c.mid) AS claim_count,
       COUNT(DISTINCT c.jid) AS patient_count,
       SUM(c.rvd_rpe_tamt_amt) AS total_care_cost,
       AVG(c.rvd_slf_brdn_amt) AS avg_patient_cost
FROM edu200 c
JOIN mental_cohort_mid co ON c.mid = co.mid
JOIN edu400 d ON c.mid = d.mid
GROUP BY co.cohort;

-- 올바른 집계 단위 정렬 방식이다. 03번에서 상병 행을 MID당 코호트 한 행으로
-- 줄인 다음 EDU200과 1:1로 결합하고, 그 뒤 금액을 합산한다.
CREATE OR REPLACE TEMP TABLE cost_correct AS
SELECT co.cohort, COUNT(*) AS claim_count, COUNT(DISTINCT c.jid) AS patient_count,
       SUM(c.rvd_rpe_tamt_amt) AS total_care_cost,
       AVG(c.rvd_slf_brdn_amt) AS avg_patient_cost
FROM edu200 c
JOIN mental_cohort_mid co ON c.mid = co.mid
GROUP BY co.cohort;

-- 집계 결과만 출력하며, 환자 단위나 명세서 단위의 개별 행은 노출하지 않는다.
SELECT 'wrong_fanout' AS method, * FROM cost_wrong
UNION ALL
SELECT 'correct_mid_first', * FROM cost_correct
ORDER BY method, cohort;

-- 두 방식의 차이를 통해 코호트별 금액 중복 합산 오류를 확인한다.
SELECT w.cohort, w.total_care_cost AS wrong_total,
       c.total_care_cost AS correct_total,
       w.total_care_cost - c.total_care_cost AS inflated_amount,
       CASE WHEN c.total_care_cost = 0 THEN NULL
            ELSE w.total_care_cost / c.total_care_cost END AS inflation_ratio
FROM cost_wrong w
JOIN cost_correct c USING (cohort)
ORDER BY w.cohort;
