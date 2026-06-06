{{ config(post_hook=clustered_unique_index(['store_code']), tags=['common']) }}
-- store enriched with the new name (commercial standardization) coming from the
-- mapping maintained in SharePoint.
-- granularity: one record per store_code (Code from @STORES).
-- cross-domain brick: used by sales, purchases, inventory, HR.
--
-- the store master data in SAP (@STORES) uses historical names (e.g. "BONSUCESSO",
-- "MEGA LOJA JF", "ATACADO SP"). the commercial team standardized new names with a
-- state (UF) prefix (e.g. "RJ-BONSUCESSO", "MG-JUIZ DE FORA", "SP-EXECUTIVO B2B")
-- and maintains the map in raw_sharepoint.store_mapping.
--
-- some stores have no mapping (administrative/internal units, not commercial ones).
-- new_store_name is NULL for those; the mart falls back to old_store_name to
-- guarantee that every store referenced by a fact has a label.
--
-- 3 merges exist in the mapping (2 old names → 1 new):
--   "Bonsucesso" + "Bonsucesso - RJ" → "RJ-Bonsucesso"
--   "Juiz de Fora" + "Mega Loja JF"  → "MG-Juiz de Fora"
--   "Atacado RJ" + "RJ-Executivo B2B" → "RJ-Executivo B2B"
-- since the granularity here is store_code (not name), the merges appear
-- as N codes sharing the same new name — expected behavior.
select
    store.store_code,
    lower(store.store_name)                                       as old_store_name,
    lower(dp.new_store_name)                                    as new_store_name
from {{ ref('store') }} store
left join {{ ref('store_mapping') }} dp
       on dp.old_store_name = store.store_name
