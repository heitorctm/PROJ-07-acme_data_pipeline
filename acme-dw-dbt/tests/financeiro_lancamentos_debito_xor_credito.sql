-- validates a per-line accounting invariant: each JDT1 entry must be a
-- debit OR a credit, never both filled in. SAP B1 standard always puts
-- the amount in a single column (Debit or Credit); this test guards against
-- an ETL bug that violates that convention.
--
-- returns rows that violate the rule. the test passes if it returns 0 rows.
--
-- (alternative to dbt_utils.expression_is_true, which does not work on dbt-sqlserver
-- because it generates `select 1 ...` without an alias — an adapter bug)
select
    transaction_id,
    line_number,
    ledger_account,
    debit,
    credit
from {{ ref('finance_journal_entries') }}
where debit > 0 and credit > 0
