import json
import os
from pathlib import Path

import yaml
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / ".env")

GRAPH_TENANT_ID = os.getenv("GRAPH_TENANT_ID")
GRAPH_CLIENT_ID = os.getenv("GRAPH_CLIENT_ID")
GRAPH_CLIENT_SECRET = os.getenv("GRAPH_CLIENT_SECRET")

SQLSERVER_SERVER = os.getenv("SQLSERVER_SERVER")
SQLSERVER_DATABASE = os.getenv("SQLSERVER_DATABASE")
SQLSERVER_DRIVER = os.getenv("SQLSERVER_DRIVER", "ODBC Driver 18 for SQL Server")
SQLSERVER_USER = os.getenv("SQLSERVER_USER")
SQLSERVER_PASSWORD = os.getenv("SQLSERVER_PASSWORD")

CHUNK_SIZE = 50000
RAW_SCHEMA = "raw_sharepoint"


def load_tables() -> dict[str, dict]:
    path = Path(__file__).parent.parent / "tables.yaml"
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    # URLs can be overridden by the Airflow `sharepoint_urls` Variable (JSON
    # {table: url}), injected via the SHAREPOINT_URLS env var. Missing/empty = use tables.yaml.
    overrides = json.loads(os.getenv("SHAREPOINT_URLS") or "{}")
    return {
        table: {
            "url": overrides.get(table, cfg["url"]),
            "sheet": cfg.get("sheet"),
            "header": cfg.get("header", 0),
        }
        for table, cfg in (data or {}).items()
    }
