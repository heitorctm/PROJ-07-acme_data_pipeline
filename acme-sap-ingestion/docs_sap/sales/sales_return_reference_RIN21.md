# RIN21 — Return Document Reference

**SAP table:** RIN21  
**Bronze name:** sales_return_reference_rin21  
**Total columns in raw:** 2

## Description

Stores reference information for fiscal documents linked to sales invoice returns (A/R Credit Memo Document Reference in SAP B1). Used to trace the original invoice that the return refers to.

## ⚠️ Incomplete ingestion

Raw contains only `DocEntry` and `_ingestao_em`. The table in SAP has 21 relevant fields that were not imported, including: `LineNum`, `RefDocEntry`, `RefDocNum`, `RefObjType`, `IssueDate`, `IssuerCNPJ`, `Series`, `Number`, `RefAmount`, `AccessKey`. The existing views use RIN21 only as a join on `DocEntry` without selecting additional columns, so there is no current impact. Evaluate whether to expand the ingestion before building the silver layer.

## Relationships

**Parent table — join on `DocEntry`:**
- ORIN (`sales_return_orin`) — return header

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Internal Number | doc_entry | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 2,782 records for 2,507 distinct returns — some returns have more than one reference
