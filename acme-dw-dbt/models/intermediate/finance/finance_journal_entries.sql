{{ config(post_hook=clustered_unique_index(['transaction_id', 'line_number'])) }}
-- journal entry lines (JDT1) with header (OJDT) + chart of accounts + partner
-- grain: one line per (transaction_id, line_number)
-- enriches the debit account and the offsetting account (two joins with OACT)
-- partner only populated when ShortName references a BP — for pure GL accounts it comes through NULL
with ojdt_dedup as (
    select *,
        row_number() over (partition by transaction_id order by _ingested_at desc) as rn
    from {{ ref('journal_entry_ojdt') }}
),
jdt1_dedup as (
    select *,
        row_number() over (partition by transaction_id, line_number order by _ingested_at desc) as rn
    from {{ ref('journal_entry_lines_jdt1') }}
),
ojdt as (
    select * from ojdt_dedup where rn = 1
),
jdt1 as (
    select * from jdt1_dedup where rn = 1
)
select
    l.transaction_id,
    l.line_number,
    cab.reference_date,
    cab.transaction_type,
    lower(cab.historical)                            as historical,
    cab.document_reference,
    l.ledger_account,
    lower(c1.account_name)                            as account_name,
    l.offset_account,
    lower(c2.account_name)                            as offset_account_name,
    l.debit,
    l.credit,
    l.partner_code,
    lower(pn.partner_name)                         as partner_name,
    pn.partner_type,
    pn.group_code,
    lower(pn.group_name)                            as group_name,
    l._ingested_at
from jdt1                                           l
left join ojdt                                      cab on cab.transaction_id    = l.transaction_id
left join {{ ref('chart_of_accounts_oact') }}            c1  on c1.account_code     = l.ledger_account
left join {{ ref('chart_of_accounts_oact') }}            c2  on c2.account_code     = l.offset_account
left join {{ ref('partner') }}                     pn  on pn.partner_code  = l.partner_code
