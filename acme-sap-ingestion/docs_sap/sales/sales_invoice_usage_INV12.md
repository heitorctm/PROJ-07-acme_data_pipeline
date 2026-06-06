# INV12 — Sales Invoice Fiscal Extension

**SAP table:** INV12  
**Bronze name:** sales_invoice_usage_inv12  
**Total columns in raw:** 3

## Description

Stores the main fiscal usage/destination of sales invoices (A/R Invoice Tax Extension in SAP B1). Each row associates an invoice with its main fiscal usage code. The code references the OUSG table, which holds the master record of operation usages.

## Relationships

**Parent table — join on `DocEntry`:**
- OINV (`sales_invoice_oinv`) — invoice header

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

- 27 distinct `MainUsage` values in use, plus nulls (73,278 records with no usage defined)
- Most frequent codes: 10 (104,295), null (73,278), 20 (11,655), 5 (9,096), 37 (4,154)
- The meaning of each code is in the OUSG table (`ousg_usos_operacao`)
