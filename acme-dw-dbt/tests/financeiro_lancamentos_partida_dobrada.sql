-- validates the double-entry bookkeeping accounting principle (Luca Pacioli, 1494):
-- for each accounting entry (transaction_id), the sum of debits must equal
-- the sum of credits.
--
-- tolerates a difference of up to R$ 0.01 to absorb cent-level rounding
-- from decimal conversions.
--
-- returns the transactions that violate the rule. the test passes if it returns 0 rows.
select
    transaction_id,
    cast(sum(debit)  as decimal(20, 2)) as total_debit,
    cast(sum(credit) as decimal(20, 2)) as total_credit,
    cast(sum(debit) - sum(credit) as decimal(20, 2)) as difference
from {{ ref('finance_journal_entries') }}
group by transaction_id
having abs(sum(debit) - sum(credit)) > 0.01
