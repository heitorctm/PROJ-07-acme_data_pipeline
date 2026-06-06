{{ config(post_hook=clustered_unique_index(['document_type', 'doc_entry', 'line_number']), tags=['fact']) }}
-- fact_sales — line granularity (1 fact per item sold/returned).
--
-- scope: outbound invoice ('invoice') + invoice return ('return'). Quotes and orders
-- are out of scope — they become a separate funnel/pipeline fact when needed.
--
-- ## canonical date column
--
-- the fact exposes ONE date column: `date`, derived from SAP's `CreateDate`
-- (arriving here as the int's `creation_date`). It reflects the date the record
-- was actually created in the system — it aligns with what the official BI and the
-- commercial operation see day by day. It is the source of truth for grouping
-- revenue by month.
--
-- consequence of the rule: a canceled invoice + reversal do NOT net to zero in the same month.
-- the original invoice lands in the month it was created; the reversal lands in the month it
-- was canceled (usually the following month). The lifetime sum remains
-- correct. A closed month can change retroactively when an old invoice is
-- canceled (it leaves the original month with +1 of the invoice and enters the cancellation month
-- with -1 of the reversal).
--
-- ## sign convention
--
-- all raw metrics come in positive from the int (the model follows SAP — return
-- quantity is also positive in the int). Here we apply a sign by document_type
-- × canceled on the ADDITIVE METRICS:
--   quantity, line_total, total_taxes, total_cost, gross_profit.
--
-- | document_type | canceled    | sign | effect on revenue      |
-- |----------------|--------------|------:|------------------------|
-- | invoice        | no           |   +1  | enters as revenue      |
-- | invoice        | canceled    |   +1  | invoice creation month |
-- | invoice        | reversal     |   -1  | cancellation month     |
-- | return         | no           |   -1  | leaves revenue         |
-- | return         | canceled    |   --  | FILTERED (excluded)    |
-- | return         | reversal     |   --  | FILTERED (excluded)    |
--
-- a canceled RETURN and its reversal are EXCLUDED in the filter below: the pair sums to zero
-- in the net, but dated by CreateDate it would leak across months. A canceled/reversed invoice
-- still enters with opposite signs (the -1 sign for the return reversal becomes dead
-- code, kept defensively).
-- thus, the direct sum in the BI already delivers the net (invoice + canceled - reversal - active return).
--
-- NON-additive metrics (unit_price, inventory_cost_price, bdi_price,
-- cost_price, discount_percentage, margin) stay positive —
-- they are per-unit rates/quotes, aggregated as a weighted average in the BI.
--
-- ## filters applied (canonical BI)
--
-- macros/filtros_bi.sql + per-type rule:
--   - partner_show_in_bi = 'yes' (partner visibility)
--   - excludes intercompany (group_code = 111), except branch 9 (contribution)
--   - GLOBAL OVERRIDE: document_show_in_bi = 'yes' ("force display" of the doc) bypasses
--     ALL the filters above (and fiscal usage and canceled) — see the WHERE of the filtered CTE.
--   - invoice: line usage_id in (9, 10, 20, 22, 37, 46, 56)
--   - return: header main_usage_id = 24 AND canceled = 'no'
--          (canceled/reversed returns are excluded — see below)
--
-- canceled is a PARTIAL filter: for invoices, the canceled and reversal halves enter with opposite
-- signs (the official BI also keeps both halves of the invoice). For returns, canceled
-- and reversal are EXCLUDED — the pair would sum to zero in the net, but dated by
-- CreateDate it would leak across months; excluding them stabilizes the monthly close and
-- replicates the official BI, which omits canceled returns.
--
-- the detailed documentation of the rules is in
-- models/intermediate/sales/_vendas__docs.md (doc block vendas_politica_filtros).
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
        l.cfop,
        l.quantity,
        l.unit_price,
        l.price_before_discount,
        l.discount_percentage,
        l.line_total,
        l.total_taxes,
        l.inventory_cost_price,
        l.bdi_price,
        l.cost_price,
        l.margin
    from {{ ref('sales_fiscal_lines') }} l
    where l.document_type in ('invoice', 'return')
),

documents as (
    select
        d.document_id,
        d.document_type,
        d.doc_entry,
        d.document_number,
        d.creation_date                                                  as date,
        d.customer_code,
        -- SAP uses -1 as a "no salesperson" sentinel — we convert it to NULL
        -- (Kimball pattern: a missing FK ≠ a magic value in the fact).
        nullif(d.salesperson_code, -1)                                   as salesperson_code,
        d.store_code,
        d.presale_channel,
        d.load_kit,
        d.canceled,
        d.partner_show_in_bi,
        d.document_show_in_bi,
        d.group_code,
        d.branch_id
    from {{ ref('sales_fiscal_documents') }} d
    where d.document_type in ('invoice', 'return')
),

filtered as (
    select
        -- granularity key
        d.document_id,
        l.document_type,
        l.doc_entry,
        l.line_number,
        d.document_number,

        -- dimension keys
        d.date,
        l.item_code,
        d.customer_code                                                as partner_code,
        d.salesperson_code                                               as employee_code,
        d.store_code,
        l.warehouse_code,

        -- descriptive fact attributes (degenerate dims)
        l.usage_id,
        l.main_usage_id,
        l.main_usage_description,
        l.cfop,
        d.presale_channel,
        d.load_kit,
        d.canceled,

        -- sign by document_type × canceled:
        --   normal/canceled invoice:  +1   (enters as revenue)
        --   invoice reversal:         -1   (deducted in the cancellation month)
        --   normal/canceled return:   -1   (leaves revenue)
        --   return reversal:          +1   (cancels out the canceled return in the cancellation month)
        case
            when l.document_type = 'return' and d.canceled = 'reversal' then  1
            when l.document_type = 'return'                             then -1
            when d.canceled      = 'reversal'                         then -1
            else 1
        end                                                             as sign,

        -- raw metrics (sign applied further down)
        l.quantity,
        l.line_total,
        l.total_taxes,
        l.inventory_cost_price,

        -- unit metrics (rates — non-additive, no sign inversion)
        l.unit_price,
        l.price_before_discount,
        l.discount_percentage,
        l.bdi_price,
        l.cost_price,
        l.margin

    from lines     l
    join documents d on d.document_type = l.document_type
                    and d.doc_entry      = l.doc_entry
    -- "force display" is a GLOBAL BI OVERRIDE: a document flagged
    -- U_SHOW_IN_BI='S' (document_show_in_bi='yes') enters REGARDLESS of
    -- partner/intercompany/fiscal usage/canceled — exception rule: "if every
    -- filter would block it but the flag is 'yes', it appears". Mirrors the official BI.
    -- confirmed cases: invoice 176286 (hidden partner) and return 4055 (usage 36).
    where
      d.document_show_in_bi = 'yes'
      or (
          1=1
          {{ apply_sales_bi_filters('d') }}
          and (
              -- invoice: fiscal-usage whitelist on the LINE (replicates V3)
              (l.document_type = 'invoice'  and l.usage_id in {{ sales_fiscal_usage_whitelist() }})
              -- return: HEADER fiscal usage = 24 (Goods Return) (replicates V3)
              or (l.document_type = 'return' and l.main_usage_id = 24)
          )
          -- a canceled/reversed RETURN does NOT enter. The canceled+reversal pair sums to zero in
          -- the net, but since each document is dated by its own CreateDate, the
          -- two halves fall in different months and distort the monthly close.
          -- excluding both (keeping only the active return, canceled='no') stabilizes
          -- the month WITHOUT changing the total — and replicates the official BI, which omits a
          -- canceled return. A canceled/reversed invoice STILL enters (the BI also keeps both
          -- halves of the invoice). See _vendas__docs.md.
          and not (l.document_type = 'return' and d.canceled <> 'no')
      )
)

select
    document_id,
    document_type,
    doc_entry,
    line_number,
    document_number,

    date,
    item_code,
    partner_code,
    employee_code,
    store_code,
    warehouse_code,

    usage_id,
    main_usage_id,
    main_usage_description,
    cfop,
    presale_channel,
    load_kit,
    canceled,

    -- additive, with the sign already applied
    sign * quantity                                                  as quantity,
    sign * line_total                                                 as line_total,
    sign * total_taxes                                              as total_taxes,
    sign * (quantity * inventory_cost_price)                          as total_cost,
    sign * (line_total - quantity * inventory_cost_price)            as gross_profit,

    -- non-additive (per-unit rates/quotes — aggregate in the BI with a weighted average)
    unit_price,
    price_before_discount,
    discount_percentage,
    inventory_cost_price,
    bdi_price,
    cost_price,
    margin                                                              as sap_margin

from filtered
