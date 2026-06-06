{{ config(post_hook=clustered_unique_index(['item_code', 'price_list_number'])) }}
-- unit price of the item in each registered price list.
-- granularity: 1 row per (item_code, price_list_number).
--
-- project rule: intermediate models DO NOT FILTER — preserves ALL lists from ITM1.
-- the mart chooses which list to use (usually via the `current_price_list` var).
--
-- enrichment: the list's text name (OPLN.ListName).
--
-- cross-domain brick. today consumed by mart_inventory.fact_inventory filtering by the
-- current list. it stays available to compare lists, track price history, etc.

select
    p.item_code,
    p.price_list_number,
    op.price_list_name,
    p.price                                                         as list_price
from {{ ref('item_price_itm1') }}            p
left join {{ ref('price_list_opln') }}      op on op.price_list_number = p.price_list_number
