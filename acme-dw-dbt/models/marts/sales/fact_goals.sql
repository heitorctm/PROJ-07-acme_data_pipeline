{{ config(post_hook=clustered_unique_index(['channel', 'date', 'employee_code', 'original_goal_store']), tags=['fact']) }}
-- fact_goals — daily sales goals by channel, salesperson and store allocation.
--
-- ## granularity
--
-- (channel, date, employee_code, original_goal_store) — 1 row per daily
-- goal. The store is part of the key because a salesperson can have parallel goals
-- in more than one store/allocation on the same day and channel (e.g. João Silva on
-- 2026-04-30: ACME HOMES R$ 3,000 + ACME OBRAS R$ 5,000).
--
-- ## source
--
-- a SharePoint spreadsheet maintained by the commercial team (wholesale_goals and retail_goals),
-- consolidated into [[sales_goals]] in the int. It covers 2024-01-01 onward. The fact brings
-- year(date) >= 2025: with the bridge baseline dated by the 1st goal (floor
-- 2025-01-01), the salesperson_code resolves from 2025-01-01 onward, so 2025
-- enters with the salesperson populated. Goals still without a code (names outside OSLP /
-- 2024) remain excluded by the NOT NULL filter, preserving a non-null PK.
--
-- ## channel × load_kit
--
-- `channel` comes from the spreadsheet — it is where the salesperson HAS a goal registered
-- ('wholesale'/'retail'). It is NOT the same as `load_kit` in [[fact_sales]], which comes
-- from SAP (the invoice's fiscal classification). Divergences are useful information
-- (a wholesale salesperson selling retail, etc.) and are visible in the BI by cross-referencing
-- the two facts.
--
-- ## joins
--
--   fact_goals.employee_code  -> dim_employees
--   fact_goals.date           -> dim_date
--
-- metrics:
--   daily_goal — planned sales value on the date, for that allocation
select
    m.channel,
    m.date,
    m.salesperson_code                                           as employee_code,
    m.original_goal_store,

    -- descriptive attributes (audit — preserves the original text)
    m.original_goal_salesperson,
    m.normalized_name,
    m.goal_store_text,

    -- store where the goal was allocated (resolved via original_goal_store ->
    -- standardized_store). It is the source of truth for goal-per-store aggregation —
    -- not to be confused with the salesperson's SAP master-data store.
    m.goal_store_code,
    m.goal_store_name,
    m.bridge_source,

    -- metric
    -- NULL in the spreadsheet represents a salesperson with no goal on the day (vacation, leave,
    -- or not filled in). Semantically it is equivalent to 0 — coalesce avoids a NULL
    -- in the fact and allows direct aggregation without a case.
    coalesce(m.daily_goal, 0)                                  as daily_goal

from {{ ref('sales_goals') }} m
where year(m.date) >= 2025
  and m.salesperson_code is not null
