# OSLP — Salesperson

**SAP table:** OSLP  
**Bronze name:** salesperson_oslp  
**Total columns in raw:** 4

## Description

Stores the salesperson master data (Sales Employees in SAP B1). Each row represents a salesperson or sales representative. It is referenced by the headers of sales documents (OINV, ORDR, OQUT, ORIN) and by the partner master data (OCRD) via `SlpCode`.

## Relationships

**Tables that reference OSLP:**
- OINV, ORDR, OQUT, ORIN via `SlpCode` — salesperson responsible for the document
- OCRD via `SlpCode` — salesperson responsible for the business partner

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Business_Partners/OSLP.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| SlpCode | Sales Employee Code | salesperson_code | int | rename — primary key |
| SlpName | Sales Employee Name | salesperson_name | nvarchar | rename |
| U_STORE | — | store_code | nvarchar | rename — references @STORES.Code |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 381 salespeople registered
- `U_STORE` is a numeric store code — references `@STORES.Code` (the same field present in OINV, OQUT and ORIN as `U_Store`)
