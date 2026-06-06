{{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
-- outgoing payments (OVPM) enriched with partner and branch
-- grain: one record per doc_entry — most recent version
-- translates enums (payment_type, canceled)
-- exposes a breakdown by payment method (cash, transfer, check, credit) on top of the total
-- links to the journal entry via ledger_transaction_id (TransId → OJDT.TransId)
with pgto_dedup as (
    select *,
        row_number() over (partition by doc_entry order by _ingested_at desc) as rn
    from {{ ref('outgoing_payment_ovpm') }}
)
select
    p.doc_entry,
    p.payment_number,
    case p.payment_type
        when 'A' then 'account'
        when 'C' then 'customer'
        when 'S' then 'supplier'
        else lower(p.payment_type)
    end                                                  as payment_type,
    p.payment_date,
    p.accrual_date,
    p.due_date,
    p.updated_date,
    case p.canceled
        when 'N' then 'no'
        when 'Y' then 'canceled'
        when 'C' then 'reversal'
        else lower(p.canceled)
    end                                                  as canceled,
    p.partner_code,
    lower(pn.partner_name)                              as partner_name,
    pn.partner_type,
    pn.group_code,
    lower(pn.group_name)                                 as group_name,
    pn.cpf_cnpj_official,
    pn.cpf_cnpj_normalized,
    p.branch_id,
    lower(f.branch_name)                                 as branch_name,
    lower(f.nomenclature)                                as branch_nomenclature,
    p.payment_total,
    p.currency,
    p.cash_amount,
    p.transfer_amount,
    p.check_amount,
    p.credit_amount,
    p.amount_without_document,
    p.ledger_transaction_id,
    lower(p.historical)                                   as historical,
    p._ingested_at
from pgto_dedup                                          p
left join {{ ref('partner') }}             pn on pn.partner_code = p.partner_code
left join {{ ref('branch_obpl') }}          f  on f.branch_id        = p.branch_id
where p.rn = 1
