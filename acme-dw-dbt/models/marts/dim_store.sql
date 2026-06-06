{{ config(post_hook=clustered_unique_index(['store_code']), tags=['dimension']) }}
-- dim_store — store dimension for Power BI.
-- granularity: 1 record per store_code (Code of @STORES in SAP).
--
-- store_name: commercial standardization (with a state prefix) coming from the
-- mapping table maintained in SharePoint. For operational/internal stores without
-- a mapping (administrative, non-commercial units), it falls back to
-- the old SAP name — guarantees a non-null label for every store referenced
-- by a fact.
--
-- NOTE: the mapping table has 3 merges (2 old names → 1 new name). This
-- means some distinct stores (different store_code) share
-- the same store_name in the BI:
--   "RJ-Bonsucesso"     (codes 02 + another)
--   "MG-Juiz de Fora"   (codes 14 + another)
--   "RJ-Executivo B2B"  (codes 26 + 29)
-- confirmed business behavior — the commercial team unified the stores.
select
    store.store_code,
    coalesce(store.new_store_name, store.old_store_name)        as store_name
from {{ ref('standardized_store') }} store
