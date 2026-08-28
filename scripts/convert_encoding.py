"""보호 대상 HIRA CSV를 별도 폴더에 CP949에서 UTF-8로 변환한다."""

from __future__ import annotations

import argparse
from pathlib import Path


CSV_NAMES = ("EDU200.csv", "EDU300.csv", "EDU400.csv", "EDU530.csv")
UTF8_DIRNAME = "utf8"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert HIRA CSV encoding to UTF-8")
    parser.add_argument(
        "--data-root",
        type=Path,
        required=True,
        help="Original directory containing the CP949 CSV files; output is <data-root>/utf8",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_root = args.data_root / UTF8_DIRNAME
    output_root.mkdir(parents=True, exist_ok=True)

    for name in CSV_NAMES:
        source = args.data_root / name
        destination = output_root / name
        with source.open("r", encoding="cp949", newline="") as source_file:
            content = source_file.read()
        with destination.open("w", encoding="utf-8", newline="") as destination_file:
            destination_file.write(content)
        print(f"converted: {source} -> {destination}")


if __name__ == "__main__":
    main()
