import time

import pyodbc
import requests

from ingestion.config import (
    GRAPH_CLIENT_ID,
    GRAPH_CLIENT_SECRET,
    GRAPH_TENANT_ID,
    SQLSERVER_DATABASE,
    SQLSERVER_DRIVER,
    SQLSERVER_PASSWORD,
    SQLSERVER_SERVER,
    SQLSERVER_USER,
)

GRAPH_BASE = "https://graph.microsoft.com/v1.0"

_token_cache: dict = {"access_token": None, "expires_at": 0}


def get_graph_token() -> str:
    now = time.time()
    if _token_cache["access_token"] and _token_cache["expires_at"] - 60 > now:
        return _token_cache["access_token"]

    url = f"https://login.microsoftonline.com/{GRAPH_TENANT_ID}/oauth2/v2.0/token"
    resp = requests.post(
        url,
        data={
            "client_id": GRAPH_CLIENT_ID,
            "client_secret": GRAPH_CLIENT_SECRET,
            "scope": "https://graph.microsoft.com/.default",
            "grant_type": "client_credentials",
        },
        timeout=30,
    )
    resp.raise_for_status()
    payload = resp.json()

    _token_cache["access_token"] = payload["access_token"]
    _token_cache["expires_at"] = now + int(payload.get("expires_in", 3600))
    return _token_cache["access_token"]


def test_graph_connection() -> None:
    try:
        token = get_graph_token()
        resp = requests.get(
            f"{GRAPH_BASE}/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=15,
        )
        if resp.status_code not in (200, 400):
            resp.raise_for_status()
    except Exception as e:
        raise ConnectionError(
            "Failed to authenticate with Microsoft Graph. Check GRAPH_TENANT_ID, "
            "GRAPH_CLIENT_ID and GRAPH_CLIENT_SECRET in the .env file, and whether the "
            "app registration has been granted the Files.ReadWrite.All permission (admin consent)."
        ) from e


def create_sqlserver_connection() -> pyodbc.Connection:
    if SQLSERVER_USER and SQLSERVER_PASSWORD:
        conn_str = (
            f"DRIVER={{{SQLSERVER_DRIVER}}};"
            f"SERVER={SQLSERVER_SERVER};"
            f"DATABASE={SQLSERVER_DATABASE};"
            f"UID={SQLSERVER_USER};"
            f"PWD={SQLSERVER_PASSWORD};"
            "TrustServerCertificate=yes;"
        )
    else:
        conn_str = (
            f"DRIVER={{{SQLSERVER_DRIVER}}};"
            f"SERVER={SQLSERVER_SERVER};"
            f"DATABASE={SQLSERVER_DATABASE};"
            "Trusted_Connection=yes;"
            "TrustServerCertificate=yes;"
        )
    return pyodbc.connect(conn_str)


def test_sqlserver_connection(sql_conn: pyodbc.Connection) -> None:
    try:
        cursor = sql_conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
    except Exception as e:
        raise ConnectionError(
            "Failed to connect to SQL Server. Check that SQL Server is running, "
            "that the database exists, and that the ODBC driver is installed correctly."
        ) from e
