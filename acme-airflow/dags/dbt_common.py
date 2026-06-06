"""
dbt_common — ``int_common`` base + dimensions.

Cadence: hourly, from 7am to 10pm (BRT). This is the pipeline's "pacemaker":
it builds the shared foundation (which NO fact rebuilds) and, on completion,
emits the assets that trigger the facts at the right time, always AFTER common:

- ``common_ready``  — emitted ALWAYS (every run) → triggers ``dbt_sales`` (hourly).
- ``inventory_window`` — only at hours {7,10,13,16,19,22} → triggers ``dbt_inventory`` (every 3h).
- ``goals_window``   — only Mon 10am and Thu 7am → triggers ``dbt_goals`` (twice a week).

The windows use tasks that SELF-SKIP outside their hours (AirflowSkipException);
a skipped task doesn't emit its asset, so the fact won't fire. This way each fact
runs on its own cadence and never races with the dimension rebuild.
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import (
    DEFAULT_ARGS,
    START_DATE,
    TZ,
    COMMON_READY,
    INVENTORY_WINDOW,
    GOALS_WINDOW,
    dbt_build_task,
    skip_unless,
)

with DAG(
    dag_id="dbt_common",
    description="dbt: int_common base + dimensions (tag:common tag:dimension); emits the fact assets",
    schedule=CronTriggerTimetable("0 7-22 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "common"],
    default_args=DEFAULT_ARGS,
) as dag:
    build_common = dbt_build_task(
        "build_common",
        select="tag:common tag:dimension",
        outlets=[COMMON_READY],
        priority_weight=20,  # pacemaker: takes priority in the dbt pool over the facts
    )

    emit_inventory_window = PythonOperator(
        task_id="emit_inventory_window",
        python_callable=skip_unless(lambda d: d.hour in {7, 10, 13, 16, 19, 22}),
        outlets=[INVENTORY_WINDOW],
    )

    emit_goals_window = PythonOperator(
        task_id="emit_goals_window",
        python_callable=skip_unless(
            lambda d: (d.isoweekday() == 1 and d.hour == 10)  # Monday 10am
            or (d.isoweekday() == 4 and d.hour == 7)          # Thursday 7am
        ),
        outlets=[GOALS_WINDOW],
    )

    build_common >> [emit_inventory_window, emit_goals_window]
