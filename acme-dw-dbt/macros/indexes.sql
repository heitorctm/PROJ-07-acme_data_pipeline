{#
    wrapper macro for defining indexing post-hooks in a DRY way.

    typical usage in the model header:
        {{ config(post_hook=clustered_unique_index(['doc_entry'])) }}
        {{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}

    what it does:
    1. drops all existing indexes on the table (required before recreating
       the table with a new schema/structure)
    2. creates a unique clustered index on the columns passed in

    architectural decision: we use ONLY a unique clustered index as the default index.
    "preventive" nonclustered indexes were removed from the project because, without a
    real consumer (power bi, mart, measured query), any nonclustered choice is a guess.
    when a slow query shows up in production, add a nonclustered index focused on that
    need — based on an execution plan, not a hunch.
#}
{% macro clustered_unique_index(columns) %}
    {{ return([
        "{{ drop_all_indexes_on_table() }}",
        "{{ create_clustered_index(columns=" ~ columns ~ ", unique=True) }}"
    ]) }}
{% endmacro %}
