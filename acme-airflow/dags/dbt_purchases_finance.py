"""
dbt_purchases_finance — fact_purchases + fact_accounts_receivable (workstreams outside the
hourly plan, grouped into a single overnight daily run).

Cadence: daily at 06:00 (BRT), time-based (common does not run at that time). It uses the
existing common base and the int_sales chain (from the previous day's 22:00 run).

Important: ``fact_accounts_receivable`` depends on the ``int_sales`` chain (owned by the
hourly sales DAG). That is why this run EXCLUDES ``tag:sales`` — it does not rebuild
int_sales, it reuses what sales materialized. Consequence: the 06:00 accounts
receivable reflects sales up to the previous day's 22:00.

NOTE: ``int_finance`` (finance_journal_entries/pagamentos) currently feeds no fact →
it is not built by this (or any) DAG. Open item.
"""
from __future__ import annotations

from airflow.sdk import DAG
from airflow.timetables.trigger import CronTriggerTimetable

from dbt_lib import DEFAULT_ARGS, START_DATE, TZ, dbt_build_task

with DAG(
    dag_id="dbt_purchases_finance",
    description="dbt: +fact_purchases +fact_accounts_receivable (no common/dimension/staging/sales); daily 06:00",
    schedule=CronTriggerTimetable("0 6 * * *", timezone=TZ),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "acme", "purchases", "finance", "daily"],
    default_args=DEFAULT_ARGS,
) as dag:
    dbt_build_task(
        "build_purchases_finance",
        select="+fact_purchases +fact_accounts_receivable",
        exclude="tag:common tag:dimension tag:staging tag:sales",
    )
