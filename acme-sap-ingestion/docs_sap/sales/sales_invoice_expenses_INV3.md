# INV3 — Sales Invoice Additional Charges

**SAP table:** INV3  
**Bronze name:** sales_invoice_expenses_inv3  
**Total columns in raw:** 4

## Description

Stores the additional charges (freight, insurance, etc.) linked to sales invoices (A/R Invoice Freight in SAP B1). Each row represents one type of additional charge associated with an invoice. The charge code (`ExpnsCode`) references the OEXD table, which holds the master record of charge types.

## Relationships

**Parent table — join on `DocEntry`:**
- OINV (`sales_invoice_oinv`) — invoice header

**Referenced tables:**
- OEXD via `ExpnsCode` — master record of additional charge types (freight, insurance, etc.)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| ExpnsCode | Freight Code | expense_code | int | rename |
| LineTotal | Total | expense_amount | decimal(18,2) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 8,380 records in total, spread across 8,353 distinct invoices
- Only 3 charge types in use: codes 1 (7,974 occurrences), 3 (402), and 5 (4)
- The meaning of each code is in the OEXD table (`oexd_despesas_adicionais`)
