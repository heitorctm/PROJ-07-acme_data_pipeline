# RIN3 — Sales Invoice Return Additional Charges

**SAP table:** RIN3  
**Bronze name:** sales_return_expenses_rin3  
**Total columns in raw:** 5

## Description

Stores the additional charges (freight, insurance, etc.) linked to sales invoice returns (A/R Credit Memo Freight in SAP B1). Each row represents one type of additional charge associated with a return. Unlike INV3, it has `LineNum` as part of the composite key.

## Relationships

**Parent table — join on `DocEntry`:**
- ORIN (`sales_return_orin`) — return header

**Referenced tables:**
- OEXD via `ExpnsCode` — master record of additional charge types

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| LineNum | Line Num | line_number | int | rename |
| ExpnsCode | Freight Code | expense_code | int | rename |
| LineTotal | Total | expense_amount | decimal(18,2) | cast |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 155 records in total, only 2 charge types: code 1 (149) and code 3 (6)
- The meaning of each code is in the OEXD table (`oexd_despesas_adicionais`)
- Difference from INV3: RIN3 has an additional `LineNum` in the key
