# OWHS — Warehouse

**SAP table:** OWHS  
**Bronze name:** warehouse_owhs  
**Total columns in raw:** 6

## Description

Stores the warehouse master data (Warehouses in SAP B1). Each row represents a physical warehouse linked to a branch. It is referenced by the line rows of every inventory-movement document (INV1, RIN1, QUT1, RDR1, DLN1, PCH1, POR1, PRQ1) and by the stock-per-warehouse table (OITW).

## Relationships

**Parent table — join on `BPLid`:**
- OBPL (`branch_obpl`) — branch the warehouse belongs to

**Tables that reference OWHS:**
- OITW via `WhsCode` — stock per warehouse
- INV1, RIN1, QUT1, RDR1, DLN1, PCH1, POR1, PRQ1 via `WhsCode` — warehouse of the document line

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Inventory_and_Production/OWHS.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| WhsCode | Warehouse Code | warehouse_code | nvarchar | rename — primary key |
| WhsName | Warehouse Name | warehouse_name | nvarchar | rename |
| BPLid | Business Place ID | id_filial | int | rename |
| U_STORE | — | store_code | nvarchar | rename — references @STORES.Code |
| Inactive | Inactive | inactive | nvarchar | CASE (see enums) |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### Inactive — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| N | No (active) | 72 |
| Y | Yes (inactive) | 0 — no inactive warehouse in the database |

## Database notes

- 72 active warehouses for 41 branches — average of ~1.75 warehouses per branch
- All warehouses are active (`Inactive = 'N'` in 100% of records)
