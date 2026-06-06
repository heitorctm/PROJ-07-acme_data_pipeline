# PCH12 — A/P Invoice Tax Extension

**SAP table:** PCH12  
**Bronze name:** purchase_invoice_usage_pch12  
**Total raw columns:** 3

## Description

Stores the main tax usage/destination of A/P invoices (A/P Invoice Tax Extension in SAP B1). Each row links an A/P invoice to its main tax usage code. The code references the OUSG table.

## Relationships

**Parent table — join on `DocEntry`:**
- OPCH (`purchase_invoice_opch`) — A/P invoice header

**Referenced tables:**
- OUSG via `MainUsage` — master record of operation tax usages/destinations

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| MainUsage | Main Usage Code of Document | main_usage | int | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 72,449 records; 37 with null `MainUsage`
- 30 distinct `MainUsage` values in use — the meaning of each code is in the OUSG table (`ousg_usos_operacao`)
- Most frequent codes: 19 (35,224), 3 (21,706), 5 (8,787)
- Different profile from the sales tables: in purchases code 19 dominates, while in INV12 code 10 dominates and in RIN12 code 24 dominates
