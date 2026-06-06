from datetime import datetime
from uuid import UUID

import pyodbc

STRATEGY = "full_reload"
FREQUENCY = "daily"


def log_start(sql_conn: pyodbc.Connection, execution_id: UUID, table: str) -> None:
    try:
        cursor = sql_conn.cursor()
        cursor.execute(
            """
            INSERT INTO audit.ingestion_log (execution_id, table_name, strategy, frequency, started_at, status)
            VALUES (?, ?, ?, ?, ?, 'running')
            """,
            str(execution_id), table, STRATEGY, FREQUENCY, datetime.now(),
        )
        sql_conn.commit()
    except Exception as e:
        print(f"[audit] failed to log start of {table}: {e}")


def log_success(sql_conn: pyodbc.Connection, execution_id: UUID, table: str, row_count: int) -> None:
    try:
        cursor = sql_conn.cursor()
        cursor.execute(
            """
            UPDATE audit.ingestion_log
            SET finished_at = ?, row_count = ?, status = 'success'
            WHERE execution_id = ? AND table_name = ?
            """,
            datetime.now(), row_count, str(execution_id), table,
        )
        sql_conn.commit()
    except Exception as e:
        print(f"[audit] failed to log success of {table}: {e}")


def log_error(sql_conn: pyodbc.Connection, execution_id: UUID, table: str, message: str) -> None:
    try:
        cursor = sql_conn.cursor()
        cursor.execute(
            """
            UPDATE audit.ingestion_log
            SET finished_at = ?, status = 'error', error_message = ?
            WHERE execution_id = ? AND table_name = ?
            """,
            datetime.now(), message[:4000], str(execution_id), table,
        )
        sql_conn.commit()
    except Exception as e:
        print(f"[audit] failed to log error of {table}: {e}")
