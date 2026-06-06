# OEXD — Additional Expense

**SAP table:** OEXD  
**Bronze name:** additional_expense_oexd  
**Total columns in raw:** 3

## Description

Stores the master data of additional expense types (Freight Setup in SAP B1). Each row represents a type of additional cost that can be linked to purchase and sales documents — such as freight, insurance and taxes. It is referenced by the additional-expense tables INV3 and RIN3 via `ExpnsCode`.

## Relationships

**Tables that reference OEXD:**
- INV3 (`sales_invoice_expenses_inv3`) via `ExpnsCode` — additional expenses of the outbound invoice
- RIN3 (`sales_return_expenses_rin3`) via `ExpnsCode` — additional expenses of the return

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Administration/OEXD.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ExpnsCode | Internal Number | expense_code | int | rename — primary key |
| ExpnsName | Name | expense_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered types

| ExpnsCode | ExpnsName |
|---|---|
| 1 | Freight |
| 2 | Insurance |
| 3 | Other |
| 4 | Import Expense |
| 5 | IPI |
| 6 | ICMS ST |

## Database notes

- 6 expense types registered
- In use in INV3: codes 1, 3 and 5; in RIN3: codes 1 and 3
