{#
    overrides `last_day` for dbt-sqlserver, fixing two problems in the
    default adapter (which inherits from dbt-fabric):

    1. `fabric__last_day` does not handle `datepart='week'` (falls into the else).
    2. The `else` calls `dbt_utils.default_last_day(...)`, which NO LONGER exists
       in dbt_utils 1.3.3 — a bug that breaks `dbt_date.get_date_dimension`
       on SQL Server.

    this macro takes precedence over `fabric__last_day` in the dispatch because
    it is declared in the local project with the `sqlserver__` namespace.
#}
{% macro sqlserver__last_day(date, datepart) %}
    {%- if datepart == 'quarter' -%}
        cast(dateadd(quarter, datediff(quarter, 0, {{ date }}) + 1, -1) as date)
    {%- elif datepart == 'month' -%}
        eomonth({{ date }})
    {%- elif datepart == 'year' -%}
        cast(dateadd(year, datediff(year, 0, {{ date }}) + 1, -1) as date)
    {%- elif datepart == 'week' -%}
        cast(dateadd(week, datediff(week, 0, {{ date }}) + 1, -1) as date)
    {%- else -%}
        {{ exceptions.raise_compiler_error("sqlserver__last_day: datepart '" ~ datepart ~ "' not supported") }}
    {%- endif -%}
{% endmacro %}
