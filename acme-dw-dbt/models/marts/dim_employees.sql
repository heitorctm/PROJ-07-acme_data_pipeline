{{ config(post_hook=clustered_unique_index(['employee_code']), tags=['dimension']) }}
-- dim_employees — people dimension (salespeople, managers, b2b executives...)
-- granularity: 1 record per employee_code.
--
-- broad-purpose scope: covers anyone who appears as the author of a
-- sale/quote/order in SAP, not just store salespeople. When the BI wants
-- "sales by manager" or "goals by executive", the same dim handles it.
--
-- the store where the person works is a fact (changes over time) — it is not here. For that,
-- join via salesperson_bridge using the fact's date.
--
-- hire_date: the earliest valid_from in salesperson_bridge for the person's NAME
-- (not by code — when moving to another store a person may get a new code, but it is the
-- same hire). The valid_from of the bridge baseline is now dated by the salesperson's
-- 1st GOAL (floor 2025-01-01), so hire_date = month of the 1st goal; anyone who joined
-- before 2025 lands on 2025-01-01. It is an ONBOARDING proxy to flag recent /
-- "up-and-coming" salespeople — it is NOT an HR hire date. Anyone who never had a goal
-- (manager/executive) inherits the bridge's 2025-10-01 fallback.
select
    employee.employee_code,
    employee.employee_name,
    employee.sap_full_name,
    employee.status,
    hires.hire_date

from {{ ref('employee') }} employee
left join (
    select normalized_name, min(valid_from) as hire_date
    from {{ ref('salesperson_bridge') }}
    group by normalized_name
) hires
    on hires.normalized_name collate Latin1_General_CI_AI
       = employee.employee_name collate Latin1_General_CI_AI
