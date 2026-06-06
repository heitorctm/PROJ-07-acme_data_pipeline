# OUSR — User

**SAP table:** OUSR  
**Bronze name:** user_ousr  
**Total columns in raw:** 5

## Description

Stores the SAP Business One user master data. Each row represents a system user. It is referenced by document and operation tables that record the responsible user via `UserSign` (internal key = `INTERNAL_K`).

## Relationships

**Tables that reference OUSR:**
- OPOR via `UserSign` — user who created the purchase order
- OPRQ via `UserSign` — user who created the purchase request
- OITW via `UserSign` — user of the last stock update

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Administration/OUSR.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| INTERNAL_K | Internal Number | internal_code | smallint | rename — primary key; equivalent to the UserSign in documents |
| USER_CODE | User Code | user_code | nvarchar | rename |
| U_NAME | User Name | user_name | nvarchar | rename |
| Department | Department | department_code | smallint | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 684 users registered across 23 distinct departments
- Join with documents: `OPOR.UserSign = OUSR.INTERNAL_K`
