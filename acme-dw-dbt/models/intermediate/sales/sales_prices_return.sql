{{ config(post_hook=clustered_unique_index(['doc_entry', 'line_number'])) }}
-- normalized prices of sales return lines
-- replicates the PRECOS_CORRIGIDOS_DEV CTE from vw_ranking_vendas_legada
-- decimal-comma normalization is already handled in the RIN1 staging
-- no status filter — the downstream model is responsible for filtering
select
    doc_entry,
    line_number,
    concat(doc_entry, '/', line_number)    as line_key,
    bdi_price,
    cost_price
from {{ ref('sales_return_lines_rin1') }}
