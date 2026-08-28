-- 비용을 결합하기 전에 상병 상세를 MID당 한 행으로 축약한다.
-- SICK_TY_CD는 분류 규칙에 사용한다. 주상병은 일반적으로 '1', 부상병은 일반적으로
-- '2'다. '$'는 1,105행에서 확인되지만 의미가 확인되지 않았으므로 부상병으로 취급한다.
-- 주상병이 없는 MID는 459건이며, 이런 경우 부상병 중 첫 번째 상병을 사용한다.
--
-- 원 분석에서 사용한 제외 목록은 남아 있지 않다. 아래 목록은 이번 재구현에서 정한
-- 규칙이므로 원 분석과 정확히 일치하지 않을 수 있다.

CREATE OR REPLACE TEMP TABLE diagnosis_rules AS
SELECT * FROM (VALUES
    ('F20', 'schizophrenia'), ('F31', 'bipolar_disorder'),
    ('F32', 'depression'), ('F33', 'depression'),
    ('F40', 'anxiety_disorder'), ('F41', 'anxiety_disorder')
) AS t(code_prefix, disease_group);

CREATE OR REPLACE TEMP TABLE comparison_exclusion_rules AS
SELECT * FROM (VALUES
    ('G20', 'parkinsons_disease'), ('K50', 'crohns_disease'), ('K51', 'ulcerative_colitis'),
    ('I21', 'acute_myocardial_infarction'), ('I63', 'cerebral_infarction')
) AS t(code_prefix, disease_name);

CREATE OR REPLACE TEMP TABLE mental_cohort_mid AS
WITH classified AS (
    SELECT d.mid, d.jid, d.sick_ty_cd, r.disease_group,
           CASE WHEN r.code_prefix IS NOT NULL THEN 1 ELSE 0 END AS is_mental,
           CASE WHEN (UPPER(TRIM(d.sick_cd)) >= 'C00'
                           AND UPPER(TRIM(d.sick_cd)) < 'C98')
                          OR e.code_prefix IS NOT NULL THEN 1 ELSE 0 END AS is_excluded,
           ROW_NUMBER() OVER (
               PARTITION BY d.mid
               ORDER BY CASE WHEN r.code_prefix IS NOT NULL THEN 0 ELSE 1 END,
                        CASE WHEN d.sick_ty_cd = '1' THEN 0 ELSE 1 END,
                        d.sick_sno NULLS LAST
           ) AS diagnosis_order
    FROM edu400 d
    LEFT JOIN diagnosis_rules r
      ON LEFT(UPPER(TRIM(d.sick_cd)), LENGTH(r.code_prefix)) = r.code_prefix
    LEFT JOIN comparison_exclusion_rules e
      ON LEFT(UPPER(TRIM(d.sick_cd)), LENGTH(e.code_prefix)) = e.code_prefix
), by_mid AS (
    SELECT mid, MAX(jid) AS jid, MAX(is_mental) AS is_mental,
           MAX(is_excluded) AS is_excluded,
            MAX(CASE WHEN is_mental = 1 AND diagnosis_order = 1
                  THEN disease_group END) AS disease_group
    FROM classified
    GROUP BY mid
)
SELECT mid, jid,
        CASE WHEN is_mental = 1 THEN 'mental_health' ELSE 'comparison' END AS cohort,
       COALESCE(disease_group, 'comparison') AS disease_group
FROM by_mid
        -- 암이나 기타 제외 질환이 정신질환군에는 남고 비교군에서만 빠지지 않도록
        -- 두 집단에 동일한 제외 규칙을 적용한다.
    WHERE is_excluded = 0;
