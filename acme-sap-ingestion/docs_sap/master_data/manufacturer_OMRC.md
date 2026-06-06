# OMRC — Manufacturer

**SAP table:** OMRC  
**Bronze name:** manufacturer_omrc  
**Total columns in raw:** 3

## Description

Stores the manufacturer master data (Manufacturers in SAP B1). Each row represents a manufacturer or brand associated with products. It is referenced by the item master data (OITM) via `FirmCode`.

## Relationships

**Tables that reference OMRC:**
- OITM via `FirmCode` — manufacturer of the item

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Inventory_and_Production/OMRC.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| FirmCode | Manufacturer Code | manufacturer_code | smallint | rename — primary key |
| FirmName | Manufacturer Name | manufacturer_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 98 manufacturers registered
