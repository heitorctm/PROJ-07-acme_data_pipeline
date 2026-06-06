"""
dbt_build — manual FULL BUILD (contingency / backfill).

Rebuilds the ENTIRE dbt project (no ``--select`` → all models, in dependency
order) against the production SQL Server. ``schedule=None``: manual trigger only.
Use it for a general reprocessing or the initial load; day-to-day runs happen in
the per-group DAGs (dbt_common / dbt_sales / dbt_inventory / dbt_goals /
dbt_daily_movement / dbt_purchases_finance).
"""
from __future__ import annotations

from airflow.sdk import DAG

from dbt_lib import DEFAULT_ARGS, START_DATE, dbt_build_task

with DAG(
    dag_id="dbt_build",
    description="dbt build of the entire project (manual, contingency/backfill)",
    schedule=None,
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "full", "manual"],
    default_args=DEFAULT_ARGS,
) as dag:
    dbt_build_task("build_all")
