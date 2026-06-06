{{
    config(
        tags=['common'],
        materialized='incremental',
        incremental_strategy='append',
        unique_key=['salesperson_code', 'store_code', 'valid_from'],
        pre_hook=[
            "{% if is_incremental() %}"
              "update {{ this }} "
              "set valid_to = cast(dateadd(day, -1, getdate()) as date) "
              "where valid_to is null "
                "and exists ( "
                  "select 1 from {{ ref('salesperson_oslp') }} o "
                  "where o.salesperson_code = {{ this }}.salesperson_code "
                    "and o.store_code is not null and ltrim(rtrim(o.store_code)) <> '' "
                    "and ltrim(rtrim(o.store_code)) <> {{ this }}.store_code "
                ");"
            "{% endif %}"
        ],
        post_hook=clustered_unique_index(['salesperson_code', 'store_code', 'valid_from'])
    )
}}
-- =============================================================================
-- salesperson_bridge — SCD Type 2 of "which store each salesperson code is in",
-- 100% from the SAP MASTER DATA (OSLP). Cross-domain brick: sales (goal vs actual),
-- HR (career path), commission.
--
-- UNIT = code (SlpCode). One code = one salesperson. The same person with 2
-- codes (serving different stores) counts as 2 distinct salespeople.
--
-- STORE = OSLP.U_STORE (master data), NEVER the invoice's store nor the goal
-- allocation. A cross-store sale (billing through another store that has the
-- material) and a goal allocated to the B2B channel do not change the
-- salesperson's store — those are other concepts (the goal allocation lives in
-- `sales_goals.goal_store_code`).
--
-- HISTORY: OSLP is a snapshot of the present — there is no log (ASLP table) in HANA.
-- So:
--   - Baseline (1st load): each code enters with the current store from the master
--     data and valid_from = date of the salesperson's FIRST GOAL (by name, via
--     goal_name_entry), with a floor of 2025-01-01. Those without a registered goal
--     (manager/executive) keep the old baseline 2025-10-01. valid_to = NULL.
--     This makes valid_from approximate the salesperson's START — consumed by
--     dim_employees.hire_date — and, since sales_goals resolves the code by
--     `date >= valid_from`, it extends code resolution back to 2025 (previously only
--     Oct/2025+). Signal = the goal only; it serves to flag recent hires.
--   - Forward (each incremental run): if the code's U_STORE changes, the pre_hook
--     closes the current version (valid_to = yesterday) and the SELECT inserts the new
--     one (valid_from = the run's date). Changes are tracked from that point on.
--
-- Assumption: the code is stable (a store change usually becomes a new code), so
-- "current store since the baseline" is a good approximation of the code's period.
-- LIMITATION: a salesperson who acted (sold) before receiving their 1st goal is dated
-- by the goal (e.g. ana lima code 43) — a ceiling for any ruler based on the goal alone.
--
-- Granularity: 1 row per (salesperson_code, store_code, valid_from).
-- Excluded: SlpCode < 0, 'NÃO UTILIZAR%', 184 (Billing), 188, and codes
-- without a store in the master data (U_STORE null/empty — we can't state where they are).
-- =============================================================================
with oslp as (
    select
        salesperson_code,
        salesperson_name,
        ltrim(rtrim(store_code))                                   as store_code,
        lower(ltrim(rtrim(
            case when charindex(' - ', salesperson_name) > 0
                 then substring(salesperson_name, 1, charindex(' - ', salesperson_name) - 1)
                 else salesperson_name
            end
        ))) collate Latin1_General_CI_AI                            as normalized_name,
        ltrim(rtrim(
            case
                when charindex(' - ', salesperson_name) = 0
                    then null
                when charindex(' - ', salesperson_name, charindex(' - ', salesperson_name) + 1) > 0
                    then substring(
                            salesperson_name,
                            charindex(' - ', salesperson_name) + 3,
                            charindex(' - ', salesperson_name, charindex(' - ', salesperson_name) + 1)
                            - charindex(' - ', salesperson_name) - 3
                         )
                else substring(salesperson_name, charindex(' - ', salesperson_name) + 3, len(salesperson_name))
            end
        ))                                                          as store_text,
        ltrim(rtrim(
            case when charindex(' - ', salesperson_name, charindex(' - ', salesperson_name) + 1) > 0
                 then substring(
                          salesperson_name,
                          charindex(' - ', salesperson_name, charindex(' - ', salesperson_name) + 1) + 3,
                          len(salesperson_name)
                      )
                 else null
            end
        ))                                                          as role
    from {{ ref('salesperson_oslp') }}
    where salesperson_code >= 0
      and salesperson_name not like 'NÃO UTILIZAR%' collate Latin1_General_CI_AI
      and salesperson_code not in (184, 188)
      and store_code is not null
      and ltrim(rtrim(store_code)) <> ''
)

select
    o.salesperson_code,
    o.salesperson_name,
    o.normalized_name,
    o.store_code,
    coalesce(lp.new_store_name, lp.old_store_name)                as store_name,
    o.store_text,
    o.role,
    {% if is_incremental() %}
    cast(getdate() as date)                                         as valid_from,
    {% else %}
    -- baseline: salesperson's start = 1st goal (by name), floor 2025-01-01.
    -- without a registered goal (manager/executive) keeps the old baseline 2025-10-01.
    cast(
        case
            when me.first_goal is null         then '2025-10-01'
            when me.first_goal < '2025-01-01'  then '2025-01-01'
            else me.first_goal
        end as date)                                                as valid_from,
    {% endif %}
    cast(null as date)                                              as valid_to,
    cast('sap_oslp' as varchar(20))                                 as source
from oslp o
left join {{ ref('standardized_store') }} lp
    on lp.store_code = o.store_code
left join {{ ref('goal_name_entry') }} me
    on me.normalized_name = o.normalized_name
{% if is_incremental() %}
-- forward: only inserts a code without a current version (new, or just closed by the
-- pre_hook due to a store change). Codes whose store did not change already have a
-- current version and do not re-enter.
where not exists (
    select 1 from {{ this }} b
    where b.salesperson_code = o.salesperson_code and b.valid_to is null
)
{% endif %}
