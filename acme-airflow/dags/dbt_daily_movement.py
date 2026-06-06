"""
dbt_daily_movement — fact_daily_inventory_movement (daily close).

Cadence: daily at 05:00 (BRT), time-based (common does not run at that time). It uses
the existing common base / dimensions (from the last 22:00 run) — acceptable for a
daily snapshot, since dimensions change slowly.

Deliberate decision: this run REBUILDS ``inventory_movements`` (transactional, must be
fresh at 05:00). It is the only model built by two cadences (here at 05:00 and in the
3-hour inventory cycle), but NEVER at the same time.
``+fact_daily_inventory_movement`` already includes ``inventory_movements`` as an
ancestor; the ``--exclude`` only drops common/dimension/staging.
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import DEFAULT_ARGS, START_DATE, TZ, EXCLUDE_BASE, dbt_build_task

with DAG(
    dag_id="dbt_daily_movement",
    description="dbt: +fact_daily_inventory_movement (includes inventory_movements); daily 05:00",
    schedule=CronTriggerTimetable("0 5 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "inventory", "daily"],
    default_args=DEFAULT_ARGS,
) as dag:
    dbt_build_task(
        "build_daily_movement",
        select="+fact_daily_inventory_movement",
        exclude=EXCLUDE_BASE,
    )
