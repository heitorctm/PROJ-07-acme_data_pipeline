import argparse
import sys
import time
import traceback
from uuid import uuid4

from ingestion.audit import log_error, log_start, log_success
from ingestion.config import load_tables
from ingestion.connections import (
    create_sqlserver_connection,
    test_graph_connection,
    test_sqlserver_connection,
)
from ingestion.excel import build_metadata, read_excel, rows_to_insert
from ingestion.loader import (
    ensure_raw_schema,
    insert_in_chunks,
    build_insert,
    recreate_table,
)
from ingestion.sharepoint import download_file


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--select",
        nargs="+",
        default=None,
        metavar="TABLE",
        help="List of tables to load (e.g., --select wholesale_goals). Without arguments, runs all of them.",
    )
    args = parser.parse_args()

    sql_conn = None

    try:
        print("Testing Microsoft Graph authentication...")
        test_graph_connection()
        print("Microsoft Graph authenticated successfully.")

        print("Connecting to SQL Server...")
        sql_conn = create_sqlserver_connection()

        print("Testing SQL Server connection...")
        test_sqlserver_connection(sql_conn)
        print("SQL Server connected successfully.")

    except Exception as e:
        print("\nCONNECTION/ENVIRONMENT ERROR")
        print(str(e))
        print("\nTechnical details:")
        print(traceback.format_exc())

        if sql_conn is not None:
            sql_conn.close()
        sys.exit(1)

    ensure_raw_schema(sql_conn)

    execution_id = uuid4()
    tables = load_tables()

    if args.select:
        requested = list(dict.fromkeys(args.select))
        invalid = [t for t in requested if t not in tables]
        valid = [t for t in requested if t in tables]

        if invalid:
            print(f"\nWARNING: tables not found in tables.yaml (ignored): {', '.join(invalid)}")

        if not valid:
            print("\nNo valid table selected. Aborting.")
            sql_conn.close()
            sys.exit(1)

        tables = {t: tables[t] for t in valid}

    total = len(tables)
    success_count = 0
    errors: list[tuple[str, str, str]] = []

    filter_label = f"select: {', '.join(tables)}" if args.select else "all"
    print(f"\nStarting SharePoint ingestion [{filter_label}] — {total} tables...\n")

    start_total = time.perf_counter()

    try:
        for i, (table, cfg) in enumerate(tables.items(), 1):
            prefix = f"[{i:>2}/{total}] {table:<20}"
            try:
                log_start(sql_conn, execution_id, table)
                start_table = time.perf_counter()

                print(f"{prefix} downloading from SharePoint...", end="", flush=True)
                file = download_file(cfg["url"])

                print(f"\r{prefix} reading Excel (sheet: {cfg['sheet'] or '<first>'})...", end="", flush=True)
                df = read_excel(file, cfg["sheet"], cfg["header"])

                metadata = build_metadata(df)
                recreate_table(sql_conn, table, metadata)

                sql_insert = build_insert(table, metadata)
                rows = rows_to_insert(df)

                print(f"\r{prefix} inserting {len(rows)} rows...", end="", flush=True)
                total_rows = insert_in_chunks(sql_conn, sql_insert, rows)

                seconds = time.perf_counter() - start_table
                print(
                    f"\r{prefix} OK — {total_rows:>7} rows, "
                    f"{len(metadata)} columns — {seconds:.2f}s"
                )

                log_success(sql_conn, execution_id, table, total_rows)
                success_count += 1

            except Exception as e:
                full_error = traceback.format_exc()
                log_error(sql_conn, execution_id, table, full_error)
                print(f"\r{prefix} ERROR: {e}")
                errors.append((table, str(e), full_error))

    finally:
        if sql_conn is not None:
            sql_conn.close()

    total_seconds = time.perf_counter() - start_total

    print(f"\n{'─' * 70}")
    print(f"Completed: {success_count}/{total} tables loaded — {total_seconds:.1f}s")

    if errors:
        print(f"\nTables with errors ({len(errors)}):")
        for table, msg, detail in errors:
            print(f"\n  {table}: {msg}")
            print("  Technical details:")
            print("  " + detail.replace("\n", "\n  ").rstrip())

    # Exit with an error code if ANY table failed, so the orchestrator (Airflow)
    # marks the task as failed instead of "green" — otherwise a partial error would
    # go unnoticed and dbt would run on stale/incomplete data.
    if errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
