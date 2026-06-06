# acme-sharepoint-connector — SharePoint ⇄ SQL Server (ingest + publish)

A two-way **SharePoint integration** over the Microsoft Graph API. It **ingests** Excel spreadsheets
from SharePoint into SQL Server (the **`raw_sharepoint`** layer of the medallion architecture, alongside
`raw_sap`) **and publishes** files back to SharePoint (e.g. an HTML report to a stable link). The same
app registration and Graph client serve both directions — hence "connector", not just "extract".

> **Portfolio note.** This is a real production project, **anonymized** and translated to English for
> publication. "Acme" is a fictitious stand-in for the real company; the SharePoint tenant/site URLs,
> credentials and identifiers were replaced or removed (Microsoft Graph credentials are injected via
> environment variables, never committed). The engineering is that of the original project. The
> downstream dbt warehouse and the SAP ingestion are sibling folders in this monorepo.

---

## Overview

```
SharePoint (example.sharepoint.com / AnalyticsSite)
        ↓  download via Microsoft Graph (sharing URL)
Pandas + openpyxl
        ↓  type inference
SQL Server → raw_sharepoint schema (mirror of the spreadsheets)
           → audit schema (same audit.ingestion_log as raw_sap)
```

Every run is **full_reload**: complete DROP + CREATE + INSERT. Idempotent.

---

## Project Structure

```
acme-sharepoint-connector/
├── ingestion/
│   ├── config.py       # .env + tables.yaml
│   ├── connections.py  # Microsoft Graph token + SQL Server connection
│   ├── sharepoint.py   # download via the Graph /shares endpoint
│   ├── excel.py        # xlsx reading + SQL type inference
│   ├── loader.py       # DDL, DROP+CREATE, chunked INSERT
│   ├── upload.py       # publish a local file back to SharePoint
│   └── audit.py        # records start, success and error in audit.ingestion_log
├── main.py             # ingestion entry point
├── publish.py          # publishing entry point
├── tables.yaml         # list of spreadsheets with URL + sheet
├── requirements.txt
└── .env                # credentials (not versioned)
```

---

## Configuration

### Environment variables (.env)

```env
# Microsoft Graph (app registration in Azure AD)
GRAPH_TENANT_ID=
GRAPH_CLIENT_ID=
GRAPH_CLIENT_SECRET=

# SQL Server (same database as raw_sap)
SQLSERVER_SERVER=
SQLSERVER_DATABASE=
SQLSERVER_DRIVER=ODBC Driver 18 for SQL Server
SQLSERVER_USER=
SQLSERVER_PASSWORD=
```

### App registration (Azure AD)

The pipeline uses the **client credentials flow**. Required permission on the app registration:

- **Microsoft Graph → Application permissions → `Files.ReadWrite.All`** (admin consent granted)

`Files.ReadWrite.All` covers both uses of the same app: **reading** (extracting the spreadsheets via
`/shares/{id}/driveItem/content`) and **writing** (publishing a report back to SharePoint via
`createUploadSession` + PUT — see `publish.py`). It does not need `Sites.*` because everything is
addressed by sharing URL (`/shares/{id}/driveItem`), without manually resolving the site/drive.

### Installation

```bash
pip install -r requirements.txt
```

### ODBC Driver

Same as the SAP project — `ODBC Driver 18 for SQL Server`. Check with:

```powershell
Get-OdbcDriver | Select-Object Name, Platform
```

---

## SQL Server prerequisites

The `raw_sharepoint` schema is created automatically. The `audit` schema and the `audit.ingestion_log` table must already exist (created by the `acme-sap-ingestion` project).

If they don't exist yet, create them:

```sql
CREATE SCHEMA audit
GO

CREATE TABLE audit.ingestion_log (
    id                INT IDENTITY(1,1) PRIMARY KEY,
    execution_id      UNIQUEIDENTIFIER NOT NULL,
    table_name        NVARCHAR(100) NOT NULL,
    strategy          NVARCHAR(50) NOT NULL,
    frequency         NVARCHAR(20) NOT NULL,
    started_at        DATETIME2 NOT NULL,
    finished_at       DATETIME2,
    row_count         INT,
    status            NVARCHAR(20) NOT NULL,
    error_message     NVARCHAR(MAX)
)
```

---

## Table Configuration (tables.yaml)

Each table has 3 fields:

```yaml
wholesale_goals:
  url: "https://example.sharepoint.com/:x:/s/.../IQD..."  # file sharing URL
  sheet: "Wholesale Goals"                                # null = first sheet in the file
  header: 0                                               # header row (default 0)
```

### How to get the sharing URL

In SharePoint, right-click the file → **Share** → **Copy link**. The trailing `?e=...` can be removed (it's tracking) — the code already strips it automatically before encoding.

---

## Running

```bash
# all tables
python main.py

# specific tables only
python main.py --select wholesale_goals store_mapping
```

Each run:

1. Authenticates with Graph (client credentials)
2. Connects to SQL Server
3. For each table in the YAML:
   - Downloads the `.xlsx` from SharePoint
   - Reads the specified sheet with pandas
   - Infers SQL Server types
   - **DROP** + **CREATE** + **INSERT** in chunks of 50,000 rows
   - Records the result in `audit.ingestion_log`

The `_ingested_at DATETIME2 DEFAULT GETDATE()` column is added automatically to every table.

---

## Type Inference

| Pandas dtype | SQL Server |
|---|---|
| `bool` | `BIT` |
| `int*` | `BIGINT` |
| `float*` | `FLOAT` |
| `datetime64[ns]` | `DATETIME2` |
| `object` (text) with max ≤ 4000 | `NVARCHAR(4000)` |
| `object` (text) with max > 4000 | `NVARCHAR(MAX)` |

Columns that are 100% empty keep the dtype inferred by pandas (usually `float64` → `FLOAT NULL`).

---

## Configured Tables

| SQL Server table | Excel file | Sheet | Rows (~) | Notes |
|---|---|---|---|---|
| `raw_sharepoint.wholesale_goals` | Wholesale Goals.xlsx | Wholesale Goals | 97k | Includes 100% blank columns (raw) |
| `raw_sharepoint.retail_goals` | Retail_Goals.xlsx | Retail Goals | 95k | File has 3 sheets; we use only the first |
| `raw_sharepoint.store_mapping` | Store Renaming.xlsx | Sheet1 | 37 | Mapping of old store names → new ones |

---

## Monitoring

```sql
-- latest run
SELECT table_name, row_count,
       DATEDIFF(SECOND, started_at, finished_at) AS seconds,
       status
FROM audit.ingestion_log
WHERE execution_id = (
    SELECT TOP 1 execution_id FROM audit.ingestion_log
    WHERE strategy = 'full_reload'
    ORDER BY started_at DESC
)
ORDER BY started_at
```
