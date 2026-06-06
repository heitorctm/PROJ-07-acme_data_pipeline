{{ config(post_hook=clustered_unique_index(['date']), tags=['dimension']) }}
-- date dimension — native SQL Server, no external dependencies
-- range: 2023-01-01 to 2035-12-31 (covers the entire lifespan of the Acme data +
-- long-term inbound invoice due dates that run out to 2034)
--
-- technical decision: do NOT use dbt_utils.date_spine here because it generates
-- a nested CTE (with...with...) that SQL Server rejects. The dbt_date package
-- was also ruled out because it lacks a sqlserver__ implementation for several
-- macros (date_part, to_char). The tally table below generates 65k numbers via
-- 5 cross joins of a 2-row table — more than enough for 13 years.

with
    l0 as (select 1 as c union all select 1),
    l1 as (select 1 as c from l0 a cross join l0 b),
    l2 as (select 1 as c from l1 a cross join l1 b),
    l3 as (select 1 as c from l2 a cross join l2 b),
    l4 as (select 1 as c from l3 a cross join l3 b),
    numbers as (
        select row_number() over (order by (select null)) - 1 as n
        from l4
    ),
    dates as (
        select dateadd(day, n, cast('2023-01-01' as date)) as date
        from numbers
        where dateadd(day, n, cast('2023-01-01' as date)) <= cast('2035-12-31' as date)
    )
select
    date,
    year(date)                                                                as year,
    datepart(quarter, date)                                                   as quarter,
    month(date)                                                               as month,
    case month(date)
        when 1  then 'january'
        when 2  then 'february'
        when 3  then 'march'
        when 4  then 'april'
        when 5  then 'may'
        when 6  then 'june'
        when 7  then 'july'
        when 8  then 'august'
        when 9  then 'september'
        when 10 then 'october'
        when 11 then 'november'
        when 12 then 'december'
    end                                                                       as month_name,
    case month(date)
        when 1  then 'jan'
        when 2  then 'feb'
        when 3  then 'mar'
        when 4  then 'apr'
        when 5  then 'may'
        when 6  then 'jun'
        when 7  then 'jul'
        when 8  then 'aug'
        when 9  then 'sep'
        when 10 then 'oct'
        when 11 then 'nov'
        when 12 then 'dec'
    end                                                                       as month_short_name,
    -- 'may/2026' format, ready for a chart axis in Power BI
    case month(date)
        when 1  then 'jan'
        when 2  then 'feb'
        when 3  then 'mar'
        when 4  then 'apr'
        when 5  then 'may'
        when 6  then 'jun'
        when 7  then 'jul'
        when 8  then 'aug'
        when 9  then 'sep'
        when 10 then 'oct'
        when 11 then 'nov'
        when 12 then 'dec'
    end + '/' + cast(year(date) as varchar(4))                                as month_year,
    day(date)                                                                 as day,
    datepart(dayofyear, date)                                                 as day_of_year,
    -- DATEPART(weekday) depends on the server's DATEFIRST setting.
    -- SQL Server Brazilian default: Sunday=1, Saturday=7.
    datepart(weekday, date)                                                   as day_of_week,
    case datepart(weekday, date)
        when 1 then 'sunday'
        when 2 then 'monday'
        when 3 then 'tuesday'
        when 4 then 'wednesday'
        when 5 then 'thursday'
        when 6 then 'friday'
        when 7 then 'saturday'
    end                                                                       as day_of_week_name,
    case datepart(weekday, date)
        when 1 then 'sun'
        when 2 then 'mon'
        when 3 then 'tue'
        when 4 then 'wed'
        when 5 then 'thu'
        when 6 then 'fri'
        when 7 then 'sat'
    end                                                                       as day_of_week_short_name,
    case when datepart(weekday, date) in (1, 7) then 'yes' else 'no' end     as weekend,
    datepart(week, date)                                                      as week_of_year,
    datepart(iso_week, date)                                                  as iso_week,
    cast(dateadd(week, datediff(week, 0, date), 0) as date)                   as week_start,
    cast(dateadd(week, datediff(week, 0, date) + 1, -1) as date)              as week_end,
    cast(dateadd(month, datediff(month, 0, date), 0) as date)                 as month_start,
    eomonth(date)                                                             as month_end,
    cast(dateadd(quarter, datediff(quarter, 0, date), 0) as date)             as quarter_start,
    cast(dateadd(quarter, datediff(quarter, 0, date) + 1, -1) as date)        as quarter_end,
    cast(dateadd(year, datediff(year, 0, date), 0) as date)                   as year_start,
    cast(dateadd(year, datediff(year, 0, date) + 1, -1) as date)              as year_end,
    dateadd(day, -1, date)                                                    as previous_day,
    dateadd(day, 1, date)                                                     as next_day,
    dateadd(year, -1, date)                                                   as same_day_previous_year
from dates
