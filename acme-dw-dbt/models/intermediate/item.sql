{{ config(post_hook=clustered_unique_index(['item_code']), tags=['common']) }}
-- item enriched with hierarchy, manufacturer, usage flags and physical attributes.
-- granularity: one record per item_code.
-- cross-domain brick: used by sales, purchases and inventory.
--
-- the flag names reflect the literal SAP meaning:
--   valid_for_use (validFor)  = item is enabled in the master data.
--   blocked       (frozenFor) = item is frozen (discontinued/blocked for
--                                 transactions). it is not mutually exclusive with
--                                 valid_for_use — an item can be valid and blocked at the same time.
select
    item.item_code,
    lower(item.item_name)                                       as item_name,

    -- hierarchy
    item.family                                                as family_code,
    lower(fam.family_name)                                     as family_name,
    item.class                                                 as class_code,
    lower(cls.class_name)                                      as class_name,
    item.sub_class                                             as sub_class_code,
    lower(sub.sub_class_name)                                  as sub_class_name,
    lower(item.abc_curve)                                       as abc_curve,

    -- physical attributes
    lower(item.unit_of_measure)                                  as unit_of_measure,
    item.gross_weight                                             as unit_weight_kg,
    try_cast(item.lead_time_days as int)                        as lead_time_days,

    -- usage flags (Y/N → yes/no)
    case item.inventory_item
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.inventory_item)
    end                                                         as is_stockable,
    case item.sales_item
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.sales_item)
    end                                                         as is_sellable,
    case item.purchase_item
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.purchase_item)
    end                                                         as is_purchased,
    case item.made_to_order
        when 'S' then 'yes'
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.made_to_order)
    end                                                         as is_made_to_order,

    -- master data status
    case item.active
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.active)
    end                                                         as valid_for_use,
    case item.inactive
        when 'Y' then 'yes'
        when 'N' then 'no'
        else lower(item.inactive)
    end                                                         as blocked,

    -- manufacturer
    item.manufacturer_code,
    lower(fab.manufacturer_name)                                  as manufacturer_name

from {{ ref('item_master_oitm') }}     item
left join {{ ref('item_family') }}      fam on fam.family_code      = item.family
left join {{ ref('item_class') }}       cls on cls.class_code       = item.class
left join {{ ref('item_sub_class') }}   sub on sub.sub_class_code   = item.sub_class
left join {{ ref('manufacturer_omrc') }}   fab on fab.manufacturer_code   = item.manufacturer_code
