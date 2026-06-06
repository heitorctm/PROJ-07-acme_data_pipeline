{#
    converts text in pt-BR decimal format to a numeric decimal
    handles 3 formats:
      - "1.058,50" (pt-BR with thousands separator): strip the dot, swap comma for dot
      - "1058,50"  (decimal comma): swap comma for dot
      - "1058.50"  (US decimal point): keep as is
    values that match none of the formats return NULL via TRY_CAST
#}
{% macro normalize_brazilian_decimal(column, precision=18, scale=2) %}
    TRY_CAST(
        CASE
            WHEN {{ column }} LIKE '%,%' AND {{ column }} LIKE '%.%'
                THEN REPLACE(REPLACE({{ column }}, '.', ''), ',', '.')
            WHEN {{ column }} LIKE '%,%'
                THEN REPLACE({{ column }}, ',', '.')
            ELSE {{ column }}
        END
        as decimal({{ precision }}, {{ scale }})
    )
{% endmacro %}
