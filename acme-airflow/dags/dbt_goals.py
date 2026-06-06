"""
dbt_goals — fact_goals plus its private lineage (sales_goals).

Cadence: twice a week — Monday 10:00 and Thursday 07:00 (BRT), after common —
triggered by the ``goals_window`` asset. It does not rebuild the common base /
dimensions / staging (standardized_store and salesperson_bridge come from common).
"""
from __future__ import annotations

from airflow.sdk import DAG

from dbt_lib import DEFAULT_ARGS, START_DATE, EXCLUDE_BASE, GOALS_WINDOW, dbt_build_task

with DAG(
    dag_id="dbt_goals",
    description="dbt: +fact_goals (no common/dimension/staging); Mon 10:00 and Thu 07:00 after common",
    schedule=[GOALS_WINDOW],
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "goals"],
    default_args=DEFAULT_ARGS,
) as dag:
    dbt_build_task("build_goals", select="+fact_goals", exclude=EXCLUDE_BASE)
