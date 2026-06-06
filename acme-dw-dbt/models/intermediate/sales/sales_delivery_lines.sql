{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- delivery lines (DLN1) enriched with item hierarchy
-- granularity: one line per (doc_entry, line_number)
-- source traceability via BaseEntry + BaseType
-- BaseType can be: 13=OINV (originating invoice), 15=ODLN (another delivery), 17=ORDR (order), 23=OQUT (quote), -1=no source
select
    l.doc_entry,
    l.line_number,
    l.item_code,
    l.warehouse_code,
    l.quantity,
    l.line_status,
    l.source_doc_entry,
    l.source_line_number,
    l.source_document_type,
    h.item_name,
    h.family_code,
    h.family_name,
    h.class_code,
    h.class_name,
    h.sub_class_code,
    h.sub_class_name,
    h.abc_curve,
    h.unit_of_measure,
    h.manufacturer_code,
    l._ingested_at
from {{ ref('delivery_lines_dln1') }}   l
left join {{ ref('item') }}             h on h.item_code = l.item_code
