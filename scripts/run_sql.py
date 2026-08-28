"""로컬에 보관된 보호 대상 CSV를 기준으로 DuckDB 분석 스크립트를 실행한다."""

from __future__ import annotations

import argparse
from pathlib import Path

import duckdb


SQL_DIR = Path(__file__).resolve().parents[1] / "sql"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run HIRA SQL analysis scripts")
    parser.add_argument(
        "--data-root",
        type=Path,
        required=True,
        help="Original directory containing the CP949 CSVs; reads from <data-root>/utf8",
    )
    return parser.parse_args()


def print_result(connection: duckdb.DuckDBPyConnection, statement: str) -> None:
    result = connection.execute(statement)
    if result.description is None:
        return
    columns = [column[0] for column in result.description]
    print(" | ".join(columns))
    for row in result.fetchall():
        print(" | ".join("" if value is None else str(value) for value in row))
    print()


def is_query(statement: str) -> bool:
    """결과 출력 여부를 판단할 때 선행 SQL 주석을 무시한다."""
    executable_lines = [
        line for line in statement.splitlines() if line.strip() and not line.lstrip().startswith("--")
    ]
    return bool(executable_lines) and executable_lines[0].lstrip().upper().startswith(("SELECT", "WITH"))


def split_sql_statements(sql: str) -> list[str]:
    """주석과 인용 리터럴 밖의 세미콜론을 기준으로 SQL을 분리한다."""
    statements: list[str] = []
    statement_start = 0
    index = 0
    quote: str | None = None
    in_line_comment = False
    in_block_comment = False

    while index < len(sql):
        character = sql[index]
        next_character = sql[index + 1] if index + 1 < len(sql) else ""

        if in_line_comment:
            if character in "\r\n":
                in_line_comment = False
            index += 1
            continue

        if in_block_comment:
            if character == "*" and next_character == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue

        if quote is not None:
            if character == quote:
                if next_character == quote:
                    index += 2
                    continue
                quote = None
            index += 1
            continue

        if character == "-" and next_character == "-":
            in_line_comment = True
            index += 2
            continue
        if character == "/" and next_character == "*":
            in_block_comment = True
            index += 2
            continue
        if character in ("'", '"'):
            quote = character
            index += 1
            continue
        if character == ";":
            statement = sql[statement_start:index].strip()
            if statement:
                statements.append(statement)
            statement_start = index + 1
        index += 1

    statement = sql[statement_start:].strip()
    if statement:
        statements.append(statement)
    return statements


def main() -> None:
    args = parse_args()
    data_root = args.data_root.resolve().as_posix().replace("'", "''")
    connection = duckdb.connect()
    try:
        for sql_path in sorted(SQL_DIR.glob("[0-9][0-9]_*.sql")):
            print(f"\n=== {sql_path.name} ===")
            sql = sql_path.read_text(encoding="utf-8").replace("{{DATA_ROOT}}", data_root)
            # DuckDB는 여러 문장을 한 번에 실행하지 않으므로 문장별로 실행한다.
            # SELECT 결과만 출력해 모든 출력이 집계 수준에 머물도록 한다.
            statements = split_sql_statements(sql)
            for statement in statements:
                if is_query(statement):
                    print_result(connection, statement)
                else:
                    connection.execute(statement)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
