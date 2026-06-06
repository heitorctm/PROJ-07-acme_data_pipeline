# POR1 — Purchase Order Lines

**SAP table:** POR1  
**Bronze name:** purchase_order_lines_por1  
**Total raw columns:** 11

## Description

Stores the item rows of purchase orders (Purchase Order Rows in SAP B1). Each row represents a product requested from the vendor. It has `OpenQty` for tracking the quantity not yet received — useful for monitoring pending deliveries. The `BaseEntry` field points to the source purchase requisition when present, but `BaseType` was not imported into raw.

## Relationships

**Parent table — join on `DocEntry`:**
- OPOR (`purchase_order_opor`) — purchase order header

**Tables referenced per row:**
- OITM via `ItemCode` — master record of the requested item
- OWHS via `WhsCode` — destination warehouse

**Traceability:**
- `BaseEntry` points to the source purchase requisition (OPRQ) when populated — 1,283 rows with a confirmed source, 49,363 with no source

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Row Number | line_number | int | rename |
| BaseEntry | Base Document Internal ID | doc_entry_origem | int | rename |
| ItemCode | Item No. | item_code | nvarchar | rename |
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename |
| Quantity | Quantity | quantity | decimal(18,6) | cast |
| OpenQty | Remaining Open Quantity | open_quantity | decimal(18,6) | cast |
| LineStatus | Row Status | line_status | nvarchar | CASE (see enums) |
| Price | Price | unit_price | decimal(18,2) | cast |
| LineTotal | Row Total | total_linha | decimal(18,2) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### LineStatus — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 6,033 |
| C | Closed | 44,613 |

## Database notes

- 50,646 rows for 19,850 distinct orders
- `BaseType` was not imported into raw — the source document object_type cannot be confirmed via direct query
- 49,363 rows with no `BaseEntry` (null) — most orders are created directly, without a purchase requisition as their base
- `OpenQty` useful for building pending-purchases metrics in the silver/gold layers
