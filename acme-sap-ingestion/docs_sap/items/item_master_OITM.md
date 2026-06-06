# OITM — Item Master

**SAP table:** OITM  
**Bronze name:** item_master_oitm  
**Total columns in raw:** 22

## Description

Stores the item master data (Items Master Data in SAP B1). Each row represents a registered product, service or material. It is the central reference table for item code and description — referenced by virtually all document line tables (INV1, PCH1, RIN1, RDR1, DLN1, POR1, PRQ1).

The `U_CLASS`, `U_FAMILY` and `U_SUB_CLASS` fields are keys into the custom tables `@ITEM_CLASS`, `@ITEM_FAMILY` and `@ITEM_SUB_CLASS`, which detail the item classification hierarchy.

## Relationships

**Child tables — join on `ItemCode`:**
- ITM1 (`item_price_itm1`) — item prices per price list
- OITW (`warehouse_stock_oitw`) — item stock per warehouse

**Referenced custom tables:**
- @ITEM_FAMILY via `U_FAMILY` — item family hierarchy
- @ITEM_CLASS via `U_CLASS` — item class hierarchy
- @ITEM_SUB_CLASS via `U_SUB_CLASS` — item subclass hierarchy

**Tables that reference OITM:**
- INV1, RIN1, QUT1, RDR1, DLN1, PCH1, POR1, PRQ1 via `ItemCode`

## Column mapping

Source of descriptions: SAP Business One SDK 10.0 — confirmed via `/Inventory_and_Production/OITM.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ItemCode | Item No. | item_code | nvarchar | rename — primary key |
| ItemName | Item Description | item_name | nvarchar | rename |
| UpdateDate | Date of Update | updated_date | date | cast |
| UpdateTS | Update Full Time | update_ts | int | rename — second-level watermark, do not convert |
| FirmCode | Manufacturer | manufacturer_code | smallint | rename |
| InvntryUom | Inventory UoM | unit_of_measure | nvarchar | rename |
| InvntItem | Inventory Item | item_estoque | nvarchar | CASE (see enums) |
| SellItem | Sales Item | item_venda | nvarchar | CASE (see enums) |
| PrchseItem | Purchase Item | item_compra | nvarchar | CASE (see enums) |
| OnHand | In Stock | inventory_quantity | decimal(18,6) | cast |
| ItmsGrpCod | Item Group | item_group_code | smallint | rename |
| frozenFor | Inactive | inactive | nvarchar | CASE (see enums) |
| validFor | Active | active | nvarchar | CASE (see enums) |
| U_CLASS | — | class | nvarchar | rename — key into @ITEM_CLASS |
| U_FAMILY | — | family | nvarchar | rename — key into @ITEM_FAMILY |
| U_SUB_CLASS | — | sub_classe | nvarchar | rename — key into @ITEM_SUB_CLASS |
| U_CURVE | — | abc_curve | nvarchar | rename — item importance classification (A/B/C), filled in by management |
| U_MADE_TO_ORDER | — | made_to_order | nvarchar | rename — field not currently used; to be reassessed or removed |
| U_LEAD_TIME | — | lead_time_days | nvarchar | rename — delivery lead time in days |
| U_SCORE | — | score | nvarchar | rename — score calculated by management; internal criteria not documented |
| SWeight1 | Gross Weight | gross_weight | decimal(18,6) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### InvntItem — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| Y | Yes | 2,051 |
| N | No | 257 |

### SellItem — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| Y | Yes | 2,056 |
| N | No | 252 |

### PrchseItem — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| Y | Yes | 2,267 |
| N | No | 41 |

### frozenFor — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No (active) | 2,198 |
| Y | Yes (inactive) | 110 |

### validFor — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| Y | Yes (valid) | 2,199 |
| N | No (invalid) | 109 |

## Database notes

- 2,308 registered items; 21 distinct groups via `ItmsGrpCod` — meaning in OITB (not imported)
- `frozenFor` and `validFor` are complementary: Y/N inverted — an active item has `frozenFor=N` and `validFor=Y`
- `OnHand` is the consolidated balance across all branches — per-warehouse detail is in OITW
- `SWeight1` (gross weight in kg) has only 3 of 2,308 records filled in — field rarely used in the current registry
