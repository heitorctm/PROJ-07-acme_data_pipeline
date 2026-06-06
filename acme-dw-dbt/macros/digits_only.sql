{% macro digits_only(column) %}
    -- strip non-numeric characters from a string (SQL Server)
    -- covers the most common formatters: dot, hyphen, space, slash, parentheses, comma, tab
    replace(replace(replace(replace(replace(replace(replace(replace(
        cast({{ column }} as nvarchar(255)),
        '.', ''),
        '-', ''),
        ' ', ''),
        '/', ''),
        '(', ''),
        ')', ''),
        ',', ''),
        char(9), '')
{% endmacro %}
