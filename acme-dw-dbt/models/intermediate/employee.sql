{{ config(post_hook=clustered_unique_index(['employee_code']), tags=['common']) }}
-- employee — people registered in OSLP (salespeople, managers, b2b executives...).
-- granularity: one record per SlpCode.
-- cross-domain brick: sales (order authorship), goals, commission.
--
-- the SAP name comes in the format 'Name - Store - Role' (or variations). here we
-- only extract the parts — the "current store" is the responsibility of salesperson_bridge
-- (it changes over time). employee is the stable master record.
--
-- status:
--   active   — SlpName does not start with 'NÃO UTILIZAR'
--   inactive — SlpName starts with 'NÃO UTILIZAR' (5 cases today: soft-retired in SAP)
--
-- scope: all OSLP SlpCode >= 0 (active + inactive). salesperson_bridge is more
-- restrictive (only codes with a store in the master data) — those without a store
-- appear here but not in the bridge.
--
-- employee_name: extracts the first real part of the name before the first ' - '.
-- for inactive ones ('NÃO UTILIZAR - João Silva - Mega Loja RJ - Vendedor'), the
-- prefix is removed before extraction — otherwise 5 salespeople would carry the
-- label 'não utilizar' in the BI, indistinguishable from one another.
with cleaned as (
    select
        salesperson.salesperson_code,
        salesperson.salesperson_name                                  as sap_full_name,
        -- strips the 'NÃO UTILIZAR - ' prefix for the canonical name calculation;
        -- the status is still derived from the original sap_full_name.
        case
            when salesperson.salesperson_name like 'NÃO UTILIZAR - %' collate Latin1_General_CI_AI
                then ltrim(substring(salesperson.salesperson_name, len('NÃO UTILIZAR - ') + 1, len(salesperson.salesperson_name)))
            else salesperson.salesperson_name
        end                                                     as name_without_prefix
    from {{ ref('salesperson_oslp') }} salesperson
    where salesperson.salesperson_code >= 0  -- SAP uses -1 as the "no salesperson" sentinel
)

select
    salesperson_code                                             as employee_code,

    lower(
        case when charindex(' - ', name_without_prefix) > 0
             then substring(name_without_prefix, 1, charindex(' - ', name_without_prefix) - 1)
             else name_without_prefix
        end
    ) collate Latin1_General_CI_AI                              as employee_name,

    sap_full_name,

    case
        when sap_full_name like 'NÃO UTILIZAR%' collate Latin1_General_CI_AI
            then 'inactive'
        else 'active'
    end                                                         as status

from cleaned
