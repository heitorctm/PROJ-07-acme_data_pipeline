-- =============================================================================
-- goal_name_entry — first goal recorded per salesperson (key = normalized_name).
--
-- PURPOSE: give salesperson_bridge an entry-DATE signal for the baseline,
-- without creating a circular reference. The bridge cannot read sales_goals (which
-- already reads the bridge) — so the first goal is computed here, directly from the
-- staging of the spreadsheets (wholesale_goals / retail_goals), which sits ABOVE
-- the bridge in the DAG.
--   DAG: wholesale_goals/retail -> goal_name_entry -> salesperson_bridge -> sales_goals
--
-- normalized_name: same normalization as salesperson_bridge.sql and sales_goals.sql
-- (lowercase + accent-insensitive over the segment before the first " - ").
-- Candidate to become a macro in the future to avoid triplicating the logic.
--
-- Granularity: 1 line per normalized_name.
-- =============================================================================
with goals as (
    select date, salesperson
    from {{ ref('wholesale_goals') }}
    where year(date) >= 2024
      and salesperson is not null
      and salesperson not like 'FRANQUIA%'

    union all

    select date, salesperson
    from {{ ref('retail_goals') }}
    where year(date) >= 2024
      and salesperson is not null
      and salesperson not like 'FRANQUIA%'
),

parsed as (
    select
        lower(ltrim(rtrim(
            case when charindex(' - ', salesperson) > 0
                 then substring(salesperson, 1, charindex(' - ', salesperson) - 1)
                 else salesperson
            end
        ))) collate Latin1_General_CI_AI                            as normalized_name,
        date
    from goals
)

select
    normalized_name,
    min(date)                                                       as first_goal
from parsed
group by normalized_name
