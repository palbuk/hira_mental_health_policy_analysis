-- 러너는 {{DATA_ROOT}}를 --data-root 값으로 치환하고, 스키마 및 분석 스크립트와
-- 같은 연결에서 이 파일을 실행한다. 먼저 scripts/convert_encoding.py를 실행해야 하며,
-- DuckDB는 별도로 생성된 UTF-8 파일을 읽는다.

DELETE FROM edu200;
DELETE FROM edu300;
DELETE FROM edu400;
DELETE FROM edu530;

INSERT INTO edu200 BY NAME
SELECT * FROM read_csv('{{DATA_ROOT}}/utf8/EDU200.csv', header=true);
INSERT INTO edu300 BY NAME
SELECT * FROM read_csv('{{DATA_ROOT}}/utf8/EDU300.csv', header=true);
INSERT INTO edu400 BY NAME
SELECT * FROM read_csv('{{DATA_ROOT}}/utf8/EDU400.csv', header=true);
INSERT INTO edu530 BY NAME
SELECT * FROM read_csv('{{DATA_ROOT}}/utf8/EDU530.csv', header=true);
