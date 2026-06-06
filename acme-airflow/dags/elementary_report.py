"""
elementary_report — generates the Elementary HTML report and publishes it to SharePoint.

Runs ``edr report`` against the SQL Server ``elementary`` schema (which the dbt DAGs
populate on every build via the ``on-run-end`` hook) and writes the HTML to
``/opt/acme/dbt/edr_target/elementary_report.html``; it then **publishes to SharePoint**
(task ``publish_sharepoint``) under a stable link the team opens directly.

Cadence: daily at 22:30 BRT — after the last ``dbt_common`` run (22:00) and the facts it
triggers, so the report reflects the day's runs. ``edr_report`` uses the ``dbt`` pool
(it reads the database), so it only runs once the day's builds have finished (without
competing with them on the small server).

Credentials (runtime, Fernet-encrypted, masked in logs):
- ``edr_report``: ``acme_sqlserver_prod`` Connection (same ``DBT_PROD_*`` as the dbt
  tasks); ``edr`` uses the ``prod`` target of the ``elementary`` profile. Only READS the
  ``elementary`` schema.
- ``publish_sharepoint``: ``graph_sharepoint`` Connection (Microsoft Graph, app-only).

Publishing: the ``publish_sharepoint`` task (venv ``extract``, downstream of ``edr_report``)
uploads the HTML to SharePoint via Microsoft Graph (``Files.ReadWrite.All`` permission; egress
confirmed 2026-06-02). It overwrites the same file (``conflictBehavior=replace``) → stable
link + SharePoint versioning. If ``edr_report`` fails, the publish is skipped (no
stale/missing report gets uploaded).
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import DEFAULT_ARGS, START_DATE, TZ, DBT_ENV, DBT_POOL, PROJECT_DIR

EDR = "/opt/venvs/dbt/bin/edr"
REPORT = f"{PROJECT_DIR}/edr_target/elementary_report.html"

# SharePoint publishing (task publish_sharepoint) — uses the SharePoint extractor
# (venv `extract`, code mounted at /opt/acme/extract-sharepoint), which already speaks Graph.
EXTRACT_PY = "/opt/venvs/extract/bin/python"
EXTRACT_DIR = "/opt/acme/extract-sharepoint"
DEST_NAME = "elementary_report.html"

# Publish env: Graph credentials (encrypted `graph_sharepoint` Connection) + the destination
# FOLDER, which comes from an Airflow Variable `elementary_report_dest_url` — also Fernet-encrypted
# and editable from the UI (Admin → Variables) WITHOUT touching the code or redeploying (changing
# folders = editing the Variable). Everything is resolved at runtime; the secrets masker hides the secret in logs.
PUBLISH_ENV = {
    "GRAPH_TENANT_ID": "{{ conn.graph_sharepoint.extra_dejson.get('tenant_id') }}",
    "GRAPH_CLIENT_ID": "{{ conn.graph_sharepoint.login }}",
    "GRAPH_CLIENT_SECRET": "{{ conn.graph_sharepoint.password }}",
    "ELEMENTARY_DEST_URL": "{{ var.value.elementary_report_dest_url }}",
}

with DAG(
    dag_id="elementary_report",
    description="edr report -> Elementary HTML -> publishes to SharePoint",
    schedule=CronTriggerTimetable("30 22 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "elementary", "observability"],
    default_args=DEFAULT_ARGS,
) as dag:
    edr_report = BashOperator(
        task_id="edr_report",
        bash_command=(
            f"cd {PROJECT_DIR} && mkdir -p edr_target && "
            f"{EDR} report --profiles-dir {PROJECT_DIR} --profile-target prod "
            f"--file-path {REPORT}"
        ),
        env=DBT_ENV,
        append_env=True,
        pool=DBT_POOL,
    )

    # Publishes the HTML to SharePoint. No pool: it's network I/O, doesn't contend for CPU with the builds.
    publish_sharepoint = BashOperator(
        task_id="publish_sharepoint",
        bash_command=(
            f"cd {EXTRACT_DIR} && {EXTRACT_PY} publish.py "
            f'--file {REPORT} --name {DEST_NAME} --dest-url "$ELEMENTARY_DEST_URL"'
        ),
        env=PUBLISH_ENV,
        append_env=True,
    )

    edr_report >> publish_sharepoint
