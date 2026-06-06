# INV6 — Sales Invoice Installments

**SAP table:** INV6  
**Bronze name:** sales_invoice_installments_inv6  
**Total columns in raw:** 7

## Description

Stores the payment installments of sales invoices (A/R Invoice Installments in SAP B1). Each row represents an installment with its due date, amount, and payment status. Because it is `daily_snapshot`, it accumulates history over time — the status of each installment can change as payments are made. Never truncate this table.

## Relationships

**Parent table — join on `DocEntry`:**
- OINV (`sales_invoice_oinv`) — invoice header

## Column mapping

Source of descriptions: SAP Business One SDK 10.0.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| DocEntry | Document Internal ID | doc_entry | int | rename |
| InstlmntID | Installment ID | installment_number | smallint | rename |
| DueDate | Due Date | due_date | date | cast |
| InsTotal | Total Installment | installment_amount | decimal(18,2) | cast |
| Paid | Paid | paid_amount | decimal(18,2) | cast |
| Status | Installment Status | installment_status | nvarchar | CASE (see enums) |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — audit column and snapshot marker |

## Enums

### Status — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 4,418 |
| C | Closed | 204,704 |
