-- DuckDB 스키마다. 원본 식별자에 앞자리 0이나 숫자가 아닌 값이 포함될 수 있으므로
-- 모든 식별자는 VARCHAR로 유지한다.
-- MID는 하나의 명세서를 식별하고, JID는 비식별 환자를 식별한다.
-- EDU200은 MID가 고유한 명세서 단위이고, JID는 여러 명세서에서 반복되는 환자 키다.
-- EDU300, EDU400, EDU530의 MID와 JID는 EDU200을 참조하는 상세 외래 키다.
-- 따라서 EDU200과 상세 테이블은 MID 기준 1:N 관계다.

CREATE TABLE IF NOT EXISTS edu200 (
    mid VARCHAR, jid VARCHAR, insup_tp_cd VARCHAR, sex_tp_cd VARCHAR,
    pat_age INTEGER, yid VARCHAR, cl_cd VARCHAR, rvd_plc_cd VARCHAR,
    fom_tp_cd VARCHAR, main_sick VARCHAR, sub_sick VARCHAR, dgsbjt_cd VARCHAR,
    recu_fr_dd VARCHAR, recu_to_dd VARCHAR, fst_dd VARCHAR, vst_ddcnt INTEGER,
    recu_ddcnt INTEGER, oprsc_ddcnt INTEGER, rvd_rpe_tamt_amt DECIMAL(18,2),
    rvd_slf_brdn_amt DECIMAL(18,2), rvd_insup_brdn_amt DECIMAL(18,2),
    sopr_yn VARCHAR, oinj_tp_cd VARCHAR, prcl_sym_tp_cd VARCHAR,
    inj_exa_tp_cd VARCHAR, dgrslt_tp_cd VARCHAR, ipat_ariv_pth_tp VARCHAR,
    maidcl_cd VARCHAR, dmd_tp_cd VARCHAR, dgtgtp_tp_cd VARCHAR, year INTEGER
);

CREATE TABLE IF NOT EXISTS edu300 (
    mid VARCHAR, jid VARCHAR, cz_item_cd VARCHAR, div_ty_cd VARCHAR,
    div_cd VARCHAR, fq1_mdct_qty DECIMAL(18,4), dy1_mdct_qty DECIMAL(18,4),
    dy1_injc_qty_exec_fq DECIMAL(18,4), tot_injc_ddcnt_exec_fq DECIMAL(18,4),
    tot_use_qty_or_exec_fq DECIMAL(18,4), unprc DECIMAL(18,2), amt DECIMAL(18,2),
    addc_adt_amt DECIMAL(18,2), meft_div_no VARCHAR, exp_tp_cd VARCHAR
);

CREATE TABLE IF NOT EXISTS edu400 (
    mid VARCHAR, jid VARCHAR, sick_sno INTEGER, sick_cd VARCHAR,
    sick_ty_cd VARCHAR, ifld_dtl_spc_sbjt_cd VARCHAR
);

CREATE TABLE IF NOT EXISTS edu530 (
    mid VARCHAR, jid VARCHAR, div_ty_cd VARCHAR, div_cd VARCHAR,
    fq1_mdct_qty DECIMAL(18,4), dy1_mdct_qty DECIMAL(18,4),
    tot_injc_ddcnt_exec_fq DECIMAL(18,4), tot_use_qty_or_exec_fq DECIMAL(18,4),
    unprc DECIMAL(18,2), amt DECIMAL(18,2), meft_div_no VARCHAR
);
