import pyodbc

from ingestion.config import CHUNK_SIZE, RAW_SCHEMA


def sqlserver_name(name: str) -> str:
    return "[" + str(name).replace("]", "]]") + "]"


def ensure_raw_schema(sql_conn: pyodbc.Connection) -> None:
    cursor = sql_conn.cursor()
    cursor.execute(
        f"""
        IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '{RAW_SCHEMA}')
        BEGIN
            EXEC('CREATE SCHEMA {RAW_SCHEMA}')
        END
        """
    )
    sql_conn.commit()


def _ddl_columns(metadata: list[dict]) -> str:
    sql_columns = [
        f"    {sqlserver_name(col['name'])} {col['sql_type']} NULL"
        for col in metadata
    ]
    sql_columns.append("    [_ingested_at] DATETIME2 DEFAULT GETDATE()")
    return ",\n".join(sql_columns)


def recreate_table(sql_conn: pyodbc.Connection, table: str, metadata: list[dict]) -> None:
    ddl_columns = _ddl_columns(metadata)
    cursor = sql_conn.cursor()
    cursor.execute(
        f"DROP TABLE IF EXISTS {sqlserver_name(RAW_SCHEMA)}.{sqlserver_name(table)}"
    )
    cursor.execute(
        f"""
        CREATE TABLE {sqlserver_name(RAW_SCHEMA)}.{sqlserver_name(table)} (
{ddl_columns}
        )
        """
    )
    sql_conn.commit()


def build_insert(table: str, metadata: list[dict]) -> str:
    columns = ", ".join(sqlserver_name(col["name"]) for col in metadata)
    placeholders = ", ".join("?" for _ in metadata)
    return (
        f"INSERT INTO {sqlserver_name(RAW_SCHEMA)}.{sqlserver_name(table)} "
        f"({columns}) VALUES ({placeholders})"
    )


def insert_in_chunks(
    sql_conn: pyodbc.Connection,
    sql_insert: str,
    rows: list[tuple],
) -> int:
    if not rows:
        return 0
    cursor = sql_conn.cursor()
    cursor.fast_executemany = True
    total = 0
    for i in range(0, len(rows), CHUNK_SIZE):
        chunk = rows[i:i + CHUNK_SIZE]
        cursor.executemany(sql_insert, chunk)
        total += len(chunk)
    sql_conn.commit()
    return total
