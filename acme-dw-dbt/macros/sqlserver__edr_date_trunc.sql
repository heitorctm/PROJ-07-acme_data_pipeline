{#
    override of elementary.edr_date_trunc / edr_time_trunc for SQL Server.

    the elementary package has a `fabric__` implementation that calls DATETRUNC(),
    a function only available from SQL Server 2022 onward. On SQL Server 2019 it
    throws the error: "'datetrunc' is not a recognized built-in function name".

    here we use the classic DATEADD/DATEDIFF pattern, which works on all
    SQL Server versions. The dispatch configured in dbt_project.yml ensures
    that these macros are found before the `fabric__` implementation.
#}
{% macro sqlserver__edr_date_trunc(date_part, date_expression) %}
    dateadd({{ date_part }}, datediff({{ date_part }}, 0, {{ date_expression }}), 0)
{% endmacro %}

{% macro sqlserver__edr_time_trunc(date_part, date_expression) %}
    dateadd(
        {{ date_part }},
        datediff(
            {{ date_part }},
            cast('1900-01-01' as datetime2(6)),
            cast({{ date_expression }} as datetime2(6))
        ),
        cast('1900-01-01' as datetime2(6))
    )
{% endmacro %}
