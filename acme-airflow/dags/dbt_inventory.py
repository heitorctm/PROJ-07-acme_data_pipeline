"""
dbt_inventory — fact_inventory plus its private lineage (int_inventory, item_price_list).

Cadence: every 3 hours, from 07:00 to 22:00, always after common — triggered by the
``inventory_window`` asset (which common emits only at hours 7, 10, 13, 16, 19, 22).
It does not rebuild the common base / dimensions / staging.
"""
from __future__ import annotations

from airflow.sdk import DAG

from dbt_lib import DEFAULT_ARGS, START_DATE, EXCLUDE_BASE, INVENTORY_WINDOW, dbt_build_task

with DAG(
    dag_id="dbt_inventory",
    description="dbt: +fact_inventory (no common/dimension/staging); triggered every 3h after common",
    schedule=[INVENTORY_WINDOW],
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "inventory"],
    default_args=DEFAULT_ARGS,
) as dag:
    dbt_build_task("build_inventory", select="+fact_inventory", exclude=EXCLUDE_BASE)
