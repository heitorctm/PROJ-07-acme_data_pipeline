"""
Shared helpers for Acme's dbt transformation DAGs.

Does NOT define a DAG (it's listed in .airflowignore so the dag-processor won't
treat it as a DAG file). It is imported by the ``dbt_<group>.py`` DAGs — the
``dags/`` folder is on Airflow's sys.path, so ``from dbt_lib import ...`` works.

Conventions:
- dbt runs from the image's ISOLATED venv (``/opt/venvs/dbt/bin/dbt``); the
  project is mounted at ``/opt/acme/dbt``.
- Credentials are read at RUNTIME from the Fernet-encrypted Connection via the
  Jinja ``{{ conn.acme_sqlserver_prod.* }}`` expressions — the secret never
  lands in the code or the serialized DAG; the secrets masker hides it in logs.
- Every dbt task uses the ``dbt`` pool (create it with 1 slot) to SERIALIZE the
  builds and protect the small server (2 vCPU) from running several invocations
  in parallel (e.g. at 7am common/sales/inventory/goals could all fire at once).
"""
from __future__ import annotations

from datetime import timedelta

import pendulum
from airflow.exceptions import AirflowSkipException
from airflow.sdk import Asset
from airflow.providers.standard.operators.bash import BashOperator

DBT = "/opt/venvs/dbt/bin/dbt"
PROJECT_DIR = "/opt/acme/dbt"
TZ = "America/Sao_Paulo"
DBT_POOL = "dbt"
START_DATE = pendulum.datetime(2026, 1, 1, tz=TZ)

# Default exclusion for the facts: never rebuild the common base, the dimensions,
# or the staging layer (views — live data, recreated only on deploy).
EXCLUDE_BASE = "tag:common tag:dimension tag:staging"

# Credentials resolved at runtime (see docstring).
DBT_ENV = {
    "DBT_PROD_HOST": "{{ conn.acme_sqlserver_prod.host }}",
    "DBT_PROD_PORT": "{{ conn.acme_sqlserver_prod.port }}",
    "DBT_PROD_DATABASE": "{{ conn.acme_sqlserver_prod.schema }}",
    "DBT_PROD_SCHEMA": "{{ conn.acme_sqlserver_prod.extra_dejson.get('dbt_schema', 'SAP_MIRROR') }}",
    "DBT_PROD_USER": "{{ conn.acme_sqlserver_prod.login }}",
    "DBT_PROD_PASSWORD": "{{ conn.acme_sqlserver_prod.password }}",
}

DEFAULT_ARGS = {
    "owner": "acme",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

# Assets that link the common DAG to the facts (Airflow 3.x data-aware scheduling).
# The "x-" URI scheme makes Airflow skip semantic URI validation/normalization
# (AIP-60) and treat it as a plain string — avoiding any silent normalization.
COMMON_READY = Asset("x-acme://dbt/common_ready")
INVENTORY_WINDOW = Asset("x-acme://dbt/inventory_window")
GOALS_WINDOW = Asset("x-acme://dbt/goals_window")


def dbt_build_cmd(select: str | None = None, exclude: str | None = None) -> str:
    """Assemble the ``dbt build`` command. ``select=None`` = whole project (full build)."""
    cmd = (
        f"{DBT} build "
        f"--project-dir {PROJECT_DIR} --profiles-dir {PROJECT_DIR} --target prod"
    )
    if select:
        cmd += f" --select {select}"
    if exclude:
        cmd += f" --exclude {exclude}"
    return cmd


def dbt_build_task(
    task_id: str,
    select: str | None = None,
    exclude: str | None = None,
    **kwargs,
) -> BashOperator:
    """Standard dbt BashOperator: credential env + ``dbt`` pool + append_env."""
    return BashOperator(
        task_id=task_id,
        bash_command=dbt_build_cmd(select, exclude),
        env=DBT_ENV,
        append_env=True,
        pool=DBT_POOL,
        **kwargs,
    )


def skip_unless(predicate):
    """Factory for a PythonOperator callable: raises AirflowSkipException outside
    the window. A skipped task does NOT emit its outlet asset (Airflow only marks
    an asset as updated on success) → the downstream fact won't fire outside the
    window.

    ``predicate`` receives the run's logical date already converted to BRT
    (America/Sao_Paulo).
    """
    def _fn(**context):
        # logical_date can be None on manual/asset/REST triggers (Airflow 3.x), and
        # accessing context["logical_date"] directly would raise KeyError. Read it
        # via dag_run; with no logical date, skip cleanly (don't emit the asset,
        # don't fail).
        dag_run = context.get("dag_run")
        ld_raw = getattr(dag_run, "logical_date", None)
        if ld_raw is None:
            raise AirflowSkipException("run without logical_date (manual/asset trigger) — window not evaluated")
        ld = pendulum.instance(ld_raw).in_timezone(TZ)
        if not predicate(ld):
            raise AirflowSkipException(f"outside the window ({ld.to_datetime_string()} {TZ})")

    return _fn
