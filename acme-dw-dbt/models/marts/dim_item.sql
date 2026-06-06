{{ config(post_hook=clustered_unique_index(['item_code']), tags=['dimension']) }}
-- dim_item — item dimension for Power BI.
-- granularity: 1 record per item_code.
--
-- factual attributes (hierarchy, flags, weight, lead_time, manufacturer) come
-- ready from int_common.item. This mart adds only the BI "display"
-- categorizations:
--
--   item_type     — nature of the item (product / service / administrative purchase / others)
--                   derived from the is_sellable × is_stockable × is_purchased flags.
--   code_prefix   — first 2 chars of the code (DA, SV, DW, ...).
--   category_code — coarse bucket based on the prefix (administrative expense / service / product).
--
-- known coverage (jan/2026): ~60% of items have no family/class, ~88% no ABC curve.
-- this is the state of the master data in SAP — items "without a family" are mostly
-- administrative expenses (DA), services (SV) and new items pending classification.
select
    item.item_code,
    item.item_name,

    -- hierarchy
    item.family_code,
    item.family_name,
    item.class_code,
    item.class_name,
    item.sub_class_code,
    item.sub_class_name,
    item.abc_curve,

    -- physical attributes
    item.unit_of_measure,
    item.unit_weight_kg,
    item.lead_time_days,

    -- usage flags
    item.is_stockable,
    item.is_sellable,
    item.is_purchased,
    item.is_made_to_order,

    -- master data status
    item.valid_for_use,
    item.blocked,

    -- manufacturer
    item.manufacturer_code,
    item.manufacturer_name,

    -- ── mart derivations ───────────────────────────────────────────────────

    -- item_type: macro lens for the BI based on the flags. Ignores blocking
    -- (blocked is a separate flag — it describes status, not the nature of the item).
    case
        when item.is_sellable = 'yes' and item.is_stockable = 'yes' then 'product'
        when item.is_sellable = 'yes' and item.is_stockable = 'no' then 'service'
        when item.is_sellable = 'no' and item.is_purchased  = 'yes' then 'administrative purchase'
        else 'others'
    end                                                         as item_type,

    -- 2-char prefix: DA, SV, DW, SF, AC, FE, FX, FR, PI, IR...
    substring(item.item_code, 1, 2)                           as code_prefix,

    -- coarse bucket by prefix. Once the meaning of the remaining prefixes
    -- is cataloged, expand this case to reflect the commercial family.
    case substring(item.item_code, 1, 2)
        when 'DA' then 'administrative expense'
        when 'SV' then 'service'
        else 'product'
    end                                                         as category_code

from {{ ref('item') }} item
