{#
    centralized macros for the canonical BI filters.

    context: the architecture defines "int facts don't filter, marts filter".
    this works only if every consuming mart applies the SAME whitelist. these
    macros are the single source of truth — any change lives here, not scattered.

    canonical filters, in typical order of application:
      1. show_in_bi   -> partner = 'yes' (PARTNER visibility filter).
                          NOTE: this macro does NOT handle the DOCUMENT flag
                          (U_SHOW_IN_BI / document_show_in_bi). That flag is a
                          GLOBAL OVERRIDE applied in the WHERE of each fact (outside this
                          macro): document_show_in_bi='yes' makes the doc come in
                          REGARDLESS of partner/intercompany/fiscal usage/canceled
                          ("force display" — the BI exception rule). Do NOT use it as
                          the SOLE filter (default 'N' does not hide; it would drop 99.98%).
                          The composition `document='yes' OR (normal filters)` lives in
                          fact_sales.sql and fact_accounts_receivable.sql.
      2. intercompany  -> excludes group_code = 111, except for branch_id = 9 (contribution)
      3. uso_fiscal    -> context-specific whitelist (ranking, reconciliation, etc.)

    canceled IS NOT A FILTER in sales (unlike V3). The original invoice (canceled='Y')
    and the reversing invoice (canceled='C') both enter the fact — the fact applies sign +1
    for 'Y' and -1 for 'C', letting the BI sum them and get the correct net. Since the fact's
    date rule is `CreateDate`, the two land in different months (the invoice in the sale's
    month, the reversal in the cancellation's month). The net is only correct when summing
    over the entire history — a closed month can shift retroactively when an old invoice is
    canceled (same behavior as the official BI).

    the rationale for each rule lives in models/intermediate/sales/_vendas__docs.md
    (doc block `vendas_politica_filtros`). do not duplicate text here — only code.

    typical usage (document granularity):
        select ...
        from {{ ref('sales_fiscal_documents') }} d
        where 1=1
          {{ apply_sales_bi_filters('d') }}
          and d.main_usage_id in {{ sales_fiscal_usage_whitelist() }}

    usage at line granularity (needs a join with documents for the flags):
        select ...
        from {{ ref('sales_fiscal_lines') }} l
        join {{ ref('sales_fiscal_documents') }} d
          on d.document_type = l.document_type
         and d.doc_entry      = l.doc_entry
        where 1=1
          {{ apply_sales_bi_filters('d') }}
          and l.usage_id in {{ sales_fiscal_usage_whitelist() }}

    `sales_fiscal_documents` carries `partner_show_in_bi`,
    `document_show_in_bi`, `canceled`, `group_code` and `branch_id`
    directly (UNION ALL of the per-type building blocks). no join with partner needed.
    `sales_fiscal_lines` does NOT carry these flags (they are document
    attributes, not line attributes) — hence the join.
#}

{#-
    canonical whitelist of the fiscal usages considered "sale" in the standard ranking.
    applied to the LINE's Usage column (INV1/RIN1.Usage), mirroring the rule of
    the legacy view vw_ranking_vendas_legada:
      9   Sale of Own Product
      10  Sale of Goods Acquired from Third Parties
      20  Sale with Future Delivery
      22  Sale to End Consumer
      37  Sale by Order
      46  Sale with Suframa
      56  Sale by Order to End Consumer
    RETURNS use a different filter — main_usage_id (header) = 24
    (Merchandise Return). Applied directly in fact_sales, not in this macro.
-#}
{% macro sales_fiscal_usage_whitelist() %}
    (9, 10, 20, 22, 37, 46, 56)
{% endmacro %}


{#-
    standard BI visibility filters applied in sales marts.

    args:
      doc_alias      alias of the table/CTE with the document columns. must
                     expose canceled, document_show_in_bi, partner_show_in_bi,
                     group_code and branch_id. the consolidated facts
                     (`sales_fiscal_documents`, `sales_fiscal_lines`)
                     already carry everything directly — no extra joins needed.

    returns clauses starting with 'and ' to be chained after
    'where 1=1' (or another initial filter). does not include the fiscal usage filter —
    that one is use-case-specific and applied separately.
-#}
{% macro apply_sales_bi_filters(doc_alias) %}
    and {{ doc_alias }}.partner_show_in_bi = 'yes'
    and (
        {{ doc_alias }}.group_code <> 111
        or {{ doc_alias }}.branch_id = 9
    )
{% endmacro %}


{#-
    standard BI visibility filters applied in purchases marts.

    args:
      doc_alias      alias of the table/CTE with the document columns. must
                     expose canceled, partner_show_in_bi and group_code.

    differences vs sales:
      - there is no "branch 9 exception" rule — a purchase intercompany is a purchase
        of one Acme company by another Acme company, which makes less analytical sense
        than a sales intercompany
      - fiscal usage scope is decided in the fact (per-use-case whitelist)

    returns clauses starting with 'and ' to be chained after
    'where 1=1'. does not include the fiscal usage filter.
-#}
{% macro apply_purchases_bi_filters(doc_alias) %}
    and {{ doc_alias }}.canceled = 'no'
    and {{ doc_alias }}.partner_show_in_bi = 'yes'
    and {{ doc_alias }}.group_code <> 111
{% endmacro %}
