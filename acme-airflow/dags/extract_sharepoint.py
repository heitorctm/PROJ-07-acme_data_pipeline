"""
extract_sharepoint — extracts the SharePoint spreadsheets into ``raw_sharepoint``.

Runs the ``acme-sharepoint-connector`` extractor (isolated venv ``/opt/venvs/extract``,
code mounted at ``/opt/acme/extract-sharepoint``) that downloads 3 spreadsheets via
Microsoft Graph — ``wholesale_goals``, ``retail_goals``, ``store_mapping`` — and
materializes them into ``raw_sharepoint`` on SQL Server (DROP+CREATE+INSERT per table).

DECOUPLED design (same pattern as the SAP ingestion via SQL Agent jobs): this DAG
only keeps ``raw_sharepoint`` fresh; the dbt DAGs read the data on their own cadence
(``common`` hourly, ``goals`` Mon 10:00 / Thu 07:00). It does NOT emit an asset or chain
into dbt — if the extraction fails, the task FAILS (turns red in the UI; automated
email/Teams alerting is not configured yet) without blocking the rest of the pipeline.

Cadence: daily at 04:30 BRT — before the first ``common`` run (07:00) and the goals
windows (Mon 10:00 / Thu 07:00), so the day's data is already fresh when dbt runs.
Outside the ``dbt`` pool on purpose: it runs before any build, doesn't contend for the slot.

Credentials (read at RUNTIME, Fernet-encrypted, masked in logs — see
[[airflow-credentials-pattern]]):
- ``graph_sharepoint``      — Graph app (client-credentials): login=client_id,
  password=client_secret, extra={"tenant_id": "..."}.
- ``acme_sqlserver_prod`` — same SQL Server as the dbt tasks (reused).

Egress: the server already has HTTPS egress to Graph (``login.microsoftonline.com`` /
``graph.microsoft.com``) — confirmed 2026-06-02, no proxy.
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import DEFAULT_ARGS, START_DATE, TZ

EXTRACT_PY = "/opt/venvs/extract/bin/python"
EXTRACT_DIR = "/opt/acme/extract-sharepoint"

# Credentials resolved at runtime via Jinja (they never enter the code or the
# serialized DAG). The extractor reads these env names in ingestion/config.py; its
# load_dotenv does NOT overwrite already-set env (override=False), so these
# values — coming from the encrypted Connection — take precedence over any .env on disk.
SHAREPOINT_ENV = {
    # Microsoft Graph app registration (client-credentials flow)
    "GRAPH_TENANT_ID": "{{ conn.graph_sharepoint.extra_dejson.get('tenant_id') }}",
    "GRAPH_CLIENT_ID": "{{ conn.graph_sharepoint.login }}",
    "GRAPH_CLIENT_SECRET": "{{ conn.graph_sharepoint.password }}",
    # Destination SQL Server — same Connection as the dbt tasks. The extractor uses
    # SERVER={host,port} (ODBC format); the Connection's `schema` field = database name.
    "SQLSERVER_SERVER": "{{ conn.acme_sqlserver_prod.host }},{{ conn.acme_sqlserver_prod.port }}",
    "SQLSERVER_DATABASE": "{{ conn.acme_sqlserver_prod.schema }}",
    "SQLSERVER_USER": "{{ conn.acme_sqlserver_prod.login }}",
    "SQLSERVER_PASSWORD": "{{ conn.acme_sqlserver_prod.password }}",
    # OPTIONAL override of the spreadsheet URLs (encrypted `sharepoint_urls` Variable,
    # JSON {table: url}). Empty if the Variable doesn't exist -> falls back to tables.yaml.
    "SHAREPOINT_URLS": "{{ var.value.get('sharepoint_urls', '') }}",
}

with DAG(
    dag_id="extract_sharepoint",
    description="Extracts SharePoint spreadsheets (Graph) -> raw_sharepoint",
    schedule=CronTriggerTimetable("30 4 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["extract", "acme", "sharepoint", "raw"],
    default_args=DEFAULT_ARGS,
) as dag:
    BashOperator(
        task_id="extract_sharepoint",
        bash_command=f"cd {EXTRACT_DIR} && {EXTRACT_PY} main.py",
        env=SHAREPOINT_ENV,
        append_env=True,
    )
