"""
dbt_docs — generates the static dbt documentation and publishes it to SharePoint.

Runs ``dbt docs generate --static`` (prod target), which produces a SINGLE
self-contained ``target/static_index.html`` (~7 MB: model/column catalog +
lineage graph + compiled SQL), and publishes it to SharePoint in the SAME folder
as the Elementary report, under the stable link ``dbt_docs.html``.

Cadence: daily at 22:45 BRT — right after the Elementary report (22:30). The
generation READS the database (catalog queries for column types), so it uses the
``dbt`` pool to serialize against the builds on the small server. If generation
fails, the publish is skipped (no stale/missing doc gets uploaded).

Note: ``static_index.html`` is a single-page (JS) document — SharePoint does not
render it inline (the preview opens blank); the team downloads and opens it. Same
limitation as the Elementary report.

Credentials (runtime, Fernet-encrypted, masked in logs):
- ``docs_generate``: ``acme_sqlserver_prod`` Connection (same ``DBT_PROD_*``).
- ``publish_docs``: ``graph_sharepoint`` Connection (Microsoft Graph, app-only); the
  destination folder comes from the ``elementary_report_dest_url`` Variable (same
  folder as Elementary, reused on purpose).
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import DEFAULT_ARGS, START_DATE, TZ, DBT, DBT_ENV, DBT_POOL, PROJECT_DIR

DOCS = f"{PROJECT_DIR}/target/static_index.html"

# SharePoint publishing — reuses the extractor (venv `extract`) that already speaks Graph.
EXTRACT_PY = "/opt/venvs/extract/bin/python"
EXTRACT_DIR = "/opt/acme/extract-sharepoint"
DEST_NAME = "dbt_docs.html"

PUBLISH_ENV = {
    "GRAPH_TENANT_ID": "{{ conn.graph_sharepoint.extra_dejson.get('tenant_id') }}",
    "GRAPH_CLIENT_ID": "{{ conn.graph_sharepoint.login }}",
    "GRAPH_CLIENT_SECRET": "{{ conn.graph_sharepoint.password }}",
    # Same folder as Elementary -> reuses the existing Variable (Fernet-encrypted).
    "DEST_URL": "{{ var.value.elementary_report_dest_url }}",
}

with DAG(
    dag_id="dbt_docs",
    description="dbt docs generate --static -> publishes to SharePoint",
    schedule=CronTriggerTimetable("45 22 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "docs", "observability"],
    default_args=DEFAULT_ARGS,
) as dag:
    docs_generate = BashOperator(
        task_id="docs_generate",
        bash_command=(
            f"cd {PROJECT_DIR} && {DBT} docs generate --static "
            f"--project-dir {PROJECT_DIR} --profiles-dir {PROJECT_DIR} --target prod"
        ),
        env=DBT_ENV,
        append_env=True,
        pool=DBT_POOL,
    )

    # Publishes the HTML to SharePoint. No pool: it's network I/O, doesn't contend for CPU with the builds.
    publish_docs = BashOperator(
        task_id="publish_docs",
        bash_command=(
            f"cd {EXTRACT_DIR} && {EXTRACT_PY} publish.py "
            f'--file {DOCS} --name {DEST_NAME} --dest-url "$DEST_URL"'
        ),
        env=PUBLISH_ENV,
        append_env=True,
    )

    docs_generate >> publish_docs
