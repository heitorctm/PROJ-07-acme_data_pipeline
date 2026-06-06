{{ config(post_hook=clustered_unique_index(['partner_code']), tags=['dimension']) }}
-- dim_partner — business partner dimension (customers, suppliers, leads).
-- granularity: 1 record per partner_code (CardCode).
--
-- scope: today (jan/2026) 72,893 partners — 71,262 customers, 1,630 suppliers,
-- 1 lead. The same dim serves sales (customer) and purchases (supplier) — filtering
-- by type is the BI's responsibility.
--
-- attributes come ready from int_common.partner. Mart-specific derivations:
--
--   cpf_cnpj_type — buckets the document by the length of the normalized value.
--                   'cpf' (11), 'cnpj' (14), 'no document' (SAP% fallback) and
--                   'irregular' (any other length — poorly maintained master data).
--                   Today 14% of partners (10,174) fall into 'irregular' — a sign
--                   of master-data quality, useful for B2B vs B2C in the BI.
--
-- FULL scope: the dim does NOT filter by show_in_bi. A dimension is a complete
-- lookup, and the fact may reference a hidden partner via the GLOBAL "force display"
-- override on the document (see fact_sales: document_show_in_bi='yes' bypasses
-- every BI filter). Filtering the dim here
-- would leave those FKs orphaned. The flag is exposed as a `show_in_bi` attribute so the
-- BI can segment/hide the ~16 internal/test partners when it wants.
select
    partner.partner_code,
    partner.partner_name,
    partner.partner_type,

    -- group
    partner.group_code,
    partner.group_name,

    -- responsible salesperson (name resolved via the relationship with dim_employees)
    partner.salesperson_code,

    -- franchise / channel
    partner.franchise_name,
    partner.presale_channel,

    -- document
    partner.cpf_cnpj_official,
    partner.cpf_cnpj_normalized,

    -- ── mart derivations ───────────────────────────────────────────────────

    -- buckets the document by the length of the normalized value
    case
        when partner.cpf_cnpj_normalized like 'SAP%'      then 'no document'
        when len(partner.cpf_cnpj_normalized) = 11        then 'cpf'
        when len(partner.cpf_cnpj_normalized) = 14        then 'cnpj'
        else 'irregular'
    end                                                         as cpf_cnpj_type,

    -- master data dates
    partner.registration_date,
    partner.updated_date,

    -- visibility in the BI — ATTRIBUTE, not a filter (see header)
    partner.show_in_bi

from {{ ref('partner') }} partner
