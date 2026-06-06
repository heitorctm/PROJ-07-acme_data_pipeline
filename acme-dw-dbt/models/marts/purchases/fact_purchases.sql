{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry', 'line_number']), tags=['fact']) }}
-- fact_purchases — line granularity (1 fact per item purchased).
--
-- scope: inbound invoice ('invoice') with the "Commercial Purchase" fiscal usage (usage_id = 3).
-- orders ('order') and requisitions ('requisition') are out of scope — they become a separate
-- purchasing-funnel fact when needed.
--
-- ## "commercial purchase" scope
--
-- Acme uses several OUSG codes in purchases (3 Commercial Purchase, 5 Transfer,
-- 7 Consumption Purchase, 8 Fixed Asset Purchase, 13 Energy, 14 Telephony, 18 Service,
-- 19 Expenses, etc.). For the KPI "how much merchandise did I buy for resale", only
-- 'Commercial Purchase' (3) makes sense — the rest are administrative expenses,
-- internal consumption, fixed assets or transfers.
--
-- when "total purchases" (including consumption/assets) is needed, we create a
-- total-purchases variant or widen the whitelist via a parameter.
--
-- ## differences vs fact_sales
--
-- - NO returns: Acme's SAP currently has no dedicated purchase-return table
--   (OPDN). When one is created, it becomes a separate purchase-return fact.
-- - NO aggregated freight: a salesperson charges freight, a supplier does not — the INV3
--   equivalent (PCH3) is not used in purchases at Acme. Confirm if it shows up as relevant.
-- - NO salesperson (employee_code): a purchase invoice is entered by the purchasing
--   USER (user_id), not by a salesperson.
--
-- ## filters applied
--
-- macros/filtros_bi.sql:
--   - canceled = 'no' (excludes 'canceled' and 'reversal')
--   - partner_show_in_bi = 'yes' (excludes suppliers flagged as hidden)
--   - excludes intercompany (group_code = 111) — no exception (unlike sales)
--
-- + scope filter: l.usage_id = 3 (Commercial Purchase)
with lines as (
    select
        l.document_type,
        l.doc_entry,
        l.line_number,
        l.item_code,
        l.warehouse_code,
        l.usage_id,
        l.main_usage_id,
        l.main_usage_description,
        l.quantity,
        l.unit_price,
        l.price_before_discount,
        l.discount_percentage,
        l.line_total,
        l.total_taxes,
        l.inventory_cost_price,
        l.ledger_account
    from {{ ref('purchases_fiscal_lines') }} l
    where l.document_type = 'invoice'
),

documents as (
    select
        d.document_id,
        d.document_type,
        d.doc_entry,
        d.document_number,
        d.issue_date,
        d.accrual_date,
        d.due_date,
        d.supplier_code,
        d.store_code,
        d.canceled,
        d.partner_show_in_bi,
        d.group_code,
        d.branch_id,
        d.payment_method
    from {{ ref('purchases_fiscal_documents') }} d
    where d.document_type = 'invoice'
),

joined as (
    select
        d.document_id,
        l.document_type,
        l.doc_entry,
        l.line_number,
        d.document_number,

        -- dimension keys
        d.issue_date,
        d.accrual_date,
        d.due_date,
        l.item_code,
        d.supplier_code                                             as partner_code,
        d.store_code,
        l.warehouse_code,
        d.branch_id,

        -- descriptive attributes (degenerate dims)
        l.usage_id,
        l.main_usage_id,
        l.main_usage_description,
        l.ledger_account,
        d.payment_method,

        -- additive metrics (a purchase is always positive — no sign)
        l.quantity,
        l.line_total,
        l.total_taxes,
        l.inventory_cost_price,

        -- unit metrics (non-additive)
        l.unit_price,
        l.price_before_discount,
        l.discount_percentage

    from lines l
    join documents d on d.document_type = l.document_type
                    and d.doc_entry      = l.doc_entry
    where 1=1
      {{ apply_purchases_bi_filters('d') }}
      and l.usage_id = 3  -- Commercial Purchase
)

select
    document_id,
    document_type,
    doc_entry,
    line_number,
    document_number,

    issue_date,
    accrual_date,
    due_date,
    item_code,
    partner_code,
    store_code,
    warehouse_code,
    branch_id,

    usage_id,
    main_usage_id,
    main_usage_description,
    ledger_account,
    payment_method,

    -- additive
    quantity,
    line_total,
    total_taxes,
    quantity * inventory_cost_price                                    as total_cost,

    -- non-additive (weighted average in the BI)
    unit_price,
    price_before_discount,
    discount_percentage,
    inventory_cost_price

from joined
