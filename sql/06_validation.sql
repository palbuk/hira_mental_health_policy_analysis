-- 모든 검증은 집계 결과만 사용한다. 각 항목은 실측값, 기대값, PASS 또는 FAIL 결과를
-- 함께 출력한다. 기대값은 실제 원천 데이터 확인 결과를 사용한다.

SELECT 'edu200_row_count' AS check_name, COUNT(*) AS observed,
       153538 AS expected, CASE WHEN COUNT(*) = 153538 THEN 'PASS' ELSE 'FAIL' END AS result
FROM edu200
UNION ALL
SELECT 'edu200_distinct_mid', COUNT(DISTINCT mid), 153538,
       CASE WHEN COUNT(DISTINCT mid) = 153538 THEN 'PASS' ELSE 'FAIL' END
FROM edu200
UNION ALL
SELECT 'edu200_distinct_jid', COUNT(DISTINCT jid), 1553,
       CASE WHEN COUNT(DISTINCT jid) = 1553 THEN 'PASS' ELSE 'FAIL' END
FROM edu200
UNION ALL
SELECT 'edu400_row_count', COUNT(*), 519724,
       CASE WHEN COUNT(*) = 519724 THEN 'PASS' ELSE 'FAIL' END
FROM edu400
UNION ALL
SELECT 'edu400_distinct_mid', COUNT(DISTINCT mid), 153538,
       CASE WHEN COUNT(DISTINCT mid) = 153538 THEN 'PASS' ELSE 'FAIL' END
FROM edu400
UNION ALL
SELECT 'edu300_row_count', COUNT(*), 1436664,
       CASE WHEN COUNT(*) = 1436664 THEN 'PASS' ELSE 'FAIL' END
FROM edu300
UNION ALL
SELECT 'edu530_row_count', COUNT(*), 209007,
       CASE WHEN COUNT(*) = 209007 THEN 'PASS' ELSE 'FAIL' END
FROM edu530;

-- EDU400은 의도된 1:N 구조이므로 MID 중복 그룹이 발생하는 것이 정상이다.
SELECT 'edu400_mid_duplicate_groups' AS check_name, COUNT(*) AS observed,
       NULL AS expected, 'INFO' AS result
FROM (SELECT mid FROM edu400 GROUP BY mid HAVING COUNT(*) > 1)
UNION ALL
SELECT 'edu200_missing_mid', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM edu200 WHERE mid IS NULL OR TRIM(mid) = ''
UNION ALL
SELECT 'edu200_missing_jid', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM edu200 WHERE jid IS NULL OR TRIM(jid) = ''
UNION ALL
SELECT 'edu400_missing_mid', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM edu400 WHERE mid IS NULL OR TRIM(mid) = ''
UNION ALL
SELECT 'edu400_missing_jid', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM edu400 WHERE jid IS NULL OR TRIM(jid) = '';

-- MID에서 JID로의 관계는 1:1인지 검증한다. JID가 두 개 이상인 MID는 0건이어야 한다.
SELECT 'mid_to_jid_not_one_to_one' AS check_name, COUNT(*) AS observed,
       0 AS expected, CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (SELECT mid FROM edu200 GROUP BY mid HAVING COUNT(DISTINCT jid) > 1);

-- 모든 상세 테이블의 MID가 EDU200을 참조하는지 검증한다. 확인된 기대 위반 건수는 0건이다.
SELECT 'edu300_mid_fk_violations' AS check_name, COUNT(*) AS observed, 0 AS expected,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (SELECT DISTINCT d.mid FROM edu300 d LEFT JOIN edu200 c USING (mid) WHERE c.mid IS NULL)
UNION ALL
SELECT 'edu400_mid_fk_violations', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT DISTINCT d.mid FROM edu400 d LEFT JOIN edu200 c USING (mid) WHERE c.mid IS NULL)
UNION ALL
SELECT 'edu530_mid_fk_violations', COUNT(*), 0,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT DISTINCT d.mid FROM edu530 d LEFT JOIN edu200 c USING (mid) WHERE c.mid IS NULL);

-- 상세 행이 없는 것은 참조 무결성 위반이 아니다. 이 검사는 EDU200에서 시작해 반대
-- 방향을 확인한다. EDU300 행이 없는 EDU200 MID는 209건이고 EDU530 행이 없는 MID는
-- 85,531건이다. 두 값은 FAIL이 아니라 INFO로 표시한다. 특히 후자는 원외처방이 발생하지
-- 않은 명세서이므로, 05번에서 LEFT JOIN과 COALESCE를 사용해 코호트 집계에 남긴다.
SELECT 'edu200_mid_without_edu300' AS check_name,
     COUNT(*) AS observed, 209 AS expected, 'INFO' AS result
FROM (SELECT c.mid FROM edu200 c
    LEFT JOIN (SELECT DISTINCT mid AS detail_mid FROM edu300) d ON c.mid = d.detail_mid
    WHERE d.detail_mid IS NULL)
UNION ALL
SELECT 'edu200_mid_without_edu530', COUNT(*), 85531, 'INFO'
FROM (SELECT c.mid FROM edu200 c
    LEFT JOIN (SELECT DISTINCT mid AS detail_mid FROM edu530) d ON c.mid = d.detail_mid
    WHERE d.detail_mid IS NULL);

-- 제외 규칙을 일관되게 적용한다. 원본 총액은 유지된 코호트 총액과 제외 명세서 총액의
-- 합과 같아야 한다. 기대 산술 차이는 0이다.
WITH totals AS (
    SELECT SUM(c.rvd_rpe_tamt_amt) AS source_total,
           SUM(CASE WHEN co.mid IS NOT NULL THEN c.rvd_rpe_tamt_amt ELSE 0 END) AS cohort_total,
           SUM(CASE WHEN co.mid IS NULL THEN c.rvd_rpe_tamt_amt ELSE 0 END) AS excluded_total
    FROM edu200 c LEFT JOIN mental_cohort_mid co USING (mid)
)
SELECT 'source_minus_cohort_minus_excluded' AS check_name,
       ABS(source_total - cohort_total - excluded_total) AS observed,
       0 AS expected,
       CASE WHEN source_total = cohort_total + excluded_total THEN 'PASS' ELSE 'FAIL' END AS result
FROM totals;

-- 확인된 원본 총액이다. 올바른 코호트 조인은 유지된 명세서의 금액을 보존하고,
-- 앞의 등식에서 제외 명세서의 금액을 별도로 반영한다.
SELECT 'edu200_total_cost' AS check_name,
    SUM(rvd_rpe_tamt_amt) AS observed, 8641758000 AS expected,
       CASE WHEN SUM(rvd_rpe_tamt_amt) = 8641758000 THEN 'PASS' ELSE 'FAIL' END AS result
FROM edu200;

-- EDU300의 투약 금액은 MID 단위 집계 전후에 변하지 않아야 한다. 필터링된 각 상세
-- 금액을 정확히 한 번씩 합산하기 때문이다.
WITH source_total AS (
    SELECT COALESCE(SUM(amt), 0) AS amount FROM edu300 WHERE div_ty_cd = '3'
), mid_total AS (
    SELECT COALESCE(SUM(hospital_amt), 0) AS amount FROM (
        SELECT mid, SUM(amt) AS hospital_amt
        FROM edu300 WHERE div_ty_cd = '3' GROUP BY mid
    )
)
SELECT 'edu300_medication_total_preserved' AS check_name,
    mid_total.amount AS observed, source_total.amount AS expected,
       CASE WHEN source_total.amount = mid_total.amount THEN 'PASS' ELSE 'FAIL' END AS result
FROM source_total, mid_total;

-- 행 수와 고유 키 수로 개별 행을 노출하지 않고 중복 합산 현상을 확인한다.
-- row_count는 DuckDB 윈도우 절의 예약어인 ROWS와 겹치지 않도록 사용한다.
SELECT 'edu200_before' AS stage, COUNT(*) AS row_count,
       COUNT(DISTINCT mid) AS mid_count, COUNT(DISTINCT jid) AS jid_count
FROM edu200
UNION ALL
SELECT 'edu200_edu400_wrong_join', COUNT(*), COUNT(DISTINCT c.mid), COUNT(DISTINCT c.jid)
FROM edu200 c JOIN edu400 d ON c.mid = d.mid
UNION ALL
SELECT 'mid_first_correct_join', COUNT(*), COUNT(DISTINCT c.mid), COUNT(DISTINCT c.jid)
FROM edu200 c JOIN mental_cohort_mid co ON c.mid = co.mid;
