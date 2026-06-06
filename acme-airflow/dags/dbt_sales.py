"""
dbt_sales — fact_sales plus its private lineage (int_sales).

Cadence: hourly, from 07:00 to 22:00, RIGHT AFTER common — triggered by the
``common_ready`` asset (which common emits on every run). It does not rebuild the
common base, the dimensions, or staging (``--exclude``); only what is private to sales.
"""
from __future__ import annotations

from airflow.sdk import DAG

from dbt_lib import DEFAULT_ARGS, START_DATE, EXCLUDE_BASE, COMMON_READY, dbt_build_task

with DAG(
    dag_id="dbt_sales",
    description="dbt: +fact_sales (no common/dimension/staging); triggered after common",
    schedule=[COMMON_READY],
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "sales"],
    default_args=DEFAULT_ARGS,
) as dag:
    # High priority_weight: at peak hours (several DAGs compete for the single slot in the
    # dbt pool) sales (hourly cadence) drains ahead of inventory/goals (less frequent).
    dbt_build_task("build_sales", select="+fact_sales", exclude=EXCLUDE_BASE, priority_weight=10)
