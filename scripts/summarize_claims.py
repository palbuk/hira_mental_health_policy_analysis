#!/usr/bin/env python3
"""Recalculate portfolio-level aggregate metrics without exposing patient rows."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


CLAIM_FILES = {
    "comparison": Path("OK/200_400_no_c_r_m.csv"),
    "mental_health": Path("OK/200_400_no_c_r_only_mental.csv"),
}

MEDICATION_FILES = {
    "hospital": {
        "comparison": Path("c/300_no_c_r_m_f.csv"),
        "mental_health": Path("c/300_no_c_r_only_mental_f.csv"),
    },
    "pharmacy": {
        "comparison": Path("c/530_no_c_r_m_f.csv"),
        "mental_health": Path("c/530_no_c_r_only_mental_f.csv"),
    },
}


def numeric(value: str | None) -> float:
    if value is None or value.strip() in {"", "$"}:
        return 0.0
    return float(value)


def read_claim_summary(path: Path) -> dict[str, Any]:
    rows = 0
    claims: set[str] = set()
    total_cost = 0.0
    self_pay = 0.0

    with path.open(encoding="utf-8-sig", newline="") as file:
        for record in csv.DictReader(file):
            rows += 1
            claims.add(record["MID"])
            total_cost += numeric(record.get("RVD_RPE_TAMT_AMT"))
            self_pay += numeric(record.get("RVD_SLF_BRDN_AMT"))

    return {
        "records": rows,
        "claims": len(claims),
        "total_cost": round(total_cost),
        "self_pay": round(self_pay),
        "average_total_cost_per_record": round(total_cost / rows, 2),
        "average_self_pay_per_record": round(self_pay / rows, 2),
    }


def read_medication_summary(path: Path) -> dict[str, Any]:
    rows = 0
    claims: set[str] = set()
    amount = 0.0
    administration_days = 0.0

    with path.open(encoding="utf-8-sig", newline="") as file:
        for record in csv.DictReader(file):
            rows += 1
            claims.add(record["MID"])
            amount += numeric(record.get("AMT"))
            administration_days += numeric(record.get("TOT_INJC_DDCNT_EXEC_FQ"))

    return {
        "records": rows,
        "claims": len(claims),
        "total_medication_cost": round(amount),
        "total_administration_days": round(administration_days, 2),
        "medication_cost_per_claim": round(amount / len(claims), 2),
    }


def ratio(numerator: float, denominator: float) -> float:
    return round(numerator / denominator, 3)


def ensure_files(data_root: Path) -> None:
    required = list(CLAIM_FILES.values())
    for site_files in MEDICATION_FILES.values():
        required.extend(site_files.values())

    missing = [str(data_root / relative) for relative in required if not (data_root / relative).is_file()]
    if missing:
        raise SystemExit("Required files are missing:\n- " + "\n- ".join(missing))


def build_summary(data_root: Path) -> dict[str, Any]:
    claims = {
        group: read_claim_summary(data_root / relative)
        for group, relative in CLAIM_FILES.items()
    }
    medication = {
        site: {
            group: read_medication_summary(data_root / relative)
            for group, relative in site_files.items()
        }
        for site, site_files in MEDICATION_FILES.items()
    }

    comparisons = {
        "average_total_cost_ratio": ratio(
            claims["mental_health"]["average_total_cost_per_record"],
            claims["comparison"]["average_total_cost_per_record"],
        ),
        "average_self_pay_ratio": ratio(
            claims["mental_health"]["average_self_pay_per_record"],
            claims["comparison"]["average_self_pay_per_record"],
        ),
        "hospital_medication_cost_per_claim_ratio": ratio(
            medication["hospital"]["mental_health"]["medication_cost_per_claim"],
            medication["hospital"]["comparison"]["medication_cost_per_claim"],
        ),
        "pharmacy_medication_cost_per_claim_ratio": ratio(
            medication["pharmacy"]["mental_health"]["medication_cost_per_claim"],
            medication["pharmacy"]["comparison"]["medication_cost_per_claim"],
        ),
    }

    return {
        "data_root": str(data_root.resolve()),
        "claims": claims,
        "medication": medication,
        "comparisons": comparisons,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Aggregate the retained HIRA project CSV files into portfolio-level metrics."
    )
    parser.add_argument(
        "--data-root",
        type=Path,
        required=True,
        help="Directory containing the original OK/ and c/ folders.",
    )
    args = parser.parse_args()

    ensure_files(args.data_root)
    print(json.dumps(build_summary(args.data_root), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
