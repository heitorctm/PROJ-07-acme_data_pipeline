{{ config(post_hook=clustered_unique_index(['channel', 'date', 'original_goal_salesperson', 'original_goal_store'])) }}
-- =============================================================================
-- sales_goals — consolidation of the goal spreadsheets (wholesale + retail)
--
-- UNION of the two spreadsheets with a `channel` discriminator, salesperson resolved by
-- salesperson_bridge on (normalized_name, date BETWEEN valid_from AND valid_to), with
-- homonym tie-breaking by store_code (goal store = store of the code in the
-- master data). Preserves the original goal text for auditing.
--
-- Granularity: 1 line per (channel, date, original_goal_salesperson,
-- original_goal_store). The spreadsheet `Loja` column is part of the key because the
-- same salesperson can have goals under different allocations on the same day
-- (e.g. Maria Souza on 2026-01-06: FRANQUIA R$ 15k + ATACADO SP R$ 8,333).
--
-- Defensive dedup: the wholesale spreadsheet had 62 duplicated rows on
-- (channel, date, salesperson, store) with distinct Daily Goal values, concentrated in
-- 2024 and Jan/2025 (it stabilized in Feb/2025). row_number() by _ingested_at
-- desc keeps only the most recent one. The unique_combination_of_columns test
-- ensures that if the problem comes back, the build breaks.
--
-- Filters applied:
--   - year(date) >= 2024 (keeps history for visibility; the bridge only
--     resolves from the 2025-10-01 baseline onward, so earlier goals end up
--     with salesperson_code NULL — fact_goals restricts to 2026)
--   - salesperson IS NOT NULL
--   - salesperson NOT LIKE 'FRANQUIA%' (category discontinued in 2024)
--
-- Goals with no match in the bridge come in with salesperson_code = NULL — this
-- preserves visibility. These records will not join with invoices but show up in
-- quality reports.
-- =============================================================================

with unified_goals as (
    select
        'wholesale' as channel,
        date,
        salesperson as original_goal_salesperson,
        store     as original_goal_store,
        daily_goal,
        _ingested_at
    from {{ ref('wholesale_goals') }}
    where year(date) >= 2024
      and salesperson is not null
      and salesperson not like 'FRANQUIA%'

    union all

    select
        'retail' as channel,
        date,
        salesperson,
        store,
        daily_goal,
        _ingested_at
    from {{ ref('retail_goals') }}
    where year(date) >= 2024
      and salesperson is not null
      and salesperson not like 'FRANQUIA%'
),

goals_dedup as (
    select *,
        row_number() over (
            partition by channel, date, original_goal_salesperson, original_goal_store
            order by _ingested_at desc
        ) as rn
    from unified_goals
),

parsed_goals as (
    -- Same normalization used in the bridge: lowercase + accent-insensitive
    -- over the segment before the first " - " of the free text.
    -- Also extracts store_text (segment between the 1st and 2nd " - ", or after the
    -- 1st " - " to the end) to break ties on the JOIN with the bridge when the person has
    -- multiple parallel series in different stores (multi-store).
    select
        channel,
        date,
        original_goal_salesperson,
        original_goal_store,
        daily_goal,
        lower(ltrim(rtrim(
            case when charindex(' - ', original_goal_salesperson) > 0
                 then substring(original_goal_salesperson, 1, charindex(' - ', original_goal_salesperson) - 1)
                 else original_goal_salesperson
            end
        ))) collate Latin1_General_CI_AI as normalized_name,
        ltrim(rtrim(
            case
                when charindex(' - ', original_goal_salesperson) = 0
                    then null
                when charindex(' - ', original_goal_salesperson, charindex(' - ', original_goal_salesperson) + 1) > 0
                    then substring(
                            original_goal_salesperson,
                            charindex(' - ', original_goal_salesperson) + 3,
                            charindex(' - ', original_goal_salesperson, charindex(' - ', original_goal_salesperson) + 1)
                            - charindex(' - ', original_goal_salesperson) - 3
                         )
                else substring(
                        original_goal_salesperson,
                        charindex(' - ', original_goal_salesperson) + 3,
                        len(original_goal_salesperson)
                     )
            end
        )) as goal_store_text
    from goals_dedup
    where rn = 1
),

-- Goal store resolved from the spreadsheet `Loja` column (original_goal_store)
-- against the SAP master data via standardized_store. Resolved BEFORE the join with the
-- bridge because the multi-store tie-break is now by canonical store_code
-- (keyed by code; the store label is derived from the code).
-- Exception: the spreadsheet uses "BONSUCESSO - RJ" but in SAP it is just "BONSUCESSO".
goals_with_store as (
    select
        m.*,
        lp.store_code                  as goal_store_code,
        lp.new_store_name               as goal_store_name
    from parsed_goals                                           m
    left join {{ ref('standardized_store') }}                     lp
        on lp.old_store_name =
            case
                when ltrim(rtrim(m.original_goal_store)) = 'BONSUCESSO - RJ' then 'bonsucesso'
                else lower(ltrim(rtrim(m.original_goal_store)))
            end
),

-- Resolve the goal's salesperson_code via the bridge (normalized_name + date window).
-- Homonym / multi-store tie-break by PRIORITY: prefers the series whose
-- store_code matches the goal store (goal_store_code); when there is no store
-- match, it falls back to the most recent series covering the date. row_number guarantees 1
-- line per goal (grain key) even with overlapping parallel series.
goals_resolved as (
    select
        m.channel,
        m.date,
        m.original_goal_salesperson,
        m.original_goal_store,
        m.daily_goal,
        m.normalized_name,
        m.goal_store_text,
        m.goal_store_code,
        m.goal_store_name,
        b.salesperson_code,
        b.salesperson_name,
        b.source                         as bridge_source,
        row_number() over (
            partition by m.channel, m.date, m.original_goal_salesperson, m.original_goal_store
            order by
                case when b.store_code = m.goal_store_code then 0 else 1 end,
                b.valid_from desc
        )                               as rn
    from goals_with_store                                       m
    left join {{ ref('salesperson_bridge') }}                      b
        on  b.normalized_name collate Latin1_General_CI_AI = m.normalized_name
        and m.date >= b.valid_from
        and m.date <= coalesce(b.valid_to, '9999-12-31')
)

select
    channel,
    date,
    original_goal_salesperson,
    original_goal_store,
    daily_goal,
    normalized_name,
    goal_store_text,
    salesperson_code,
    salesperson_name,
    goal_store_code,
    goal_store_name,
    bridge_source
from goals_resolved
where rn = 1
