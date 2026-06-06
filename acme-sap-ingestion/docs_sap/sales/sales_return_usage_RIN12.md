# RIN12 — Sales Invoice Return Fiscal Extension

**SAP table:** RIN12  
**Bronze name:** sales_return_usage_rin12  
**Total columns in raw:** 3

## Description

Stores the main fiscal usage/destination of sales invoice returns (A/R Credit Memo Tax Extension in SAP B1). Each row associates a return with its main fiscal usage code. The code references the OUSG table.

## Relationships

**Parent table — join on `DocEntry`:**
- ORIN (`sales_return_orin`) — return header

**Referenced tables:**
- OUSG via `MainUsage` — master record of fiscal usages/destinations of the operation

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| MainUsage | Main Usage Code of Document | main_usage | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 8 distinct `MainUsage` values in use, plus nulls (610 records)
- Most frequent code: 24 (3,046) — the meaning is in the OUSG table (`ousg_usos_operacao`)
- Different profile from INV12: here code 24 dominates, whereas in INV12 code 10 dominates
