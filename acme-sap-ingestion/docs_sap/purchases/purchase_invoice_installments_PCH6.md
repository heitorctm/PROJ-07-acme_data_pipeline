# PCH6 — A/P Invoice Installments

**SAP table:** PCH6  
**Bronze name:** purchase_invoice_installments_pch6  
**Total raw columns:** 7

## Description

Stores the payment installments of A/P invoices (A/P Invoice Installments in SAP B1). Each row represents one installment of a purchase document. The `Status` field changes over time as payments are made — that is why the strategy is a daily snapshot, which preserves the state history without truncating prior records.

## Relationships

**Parent table — join on `DocEntry`:**
- OPCH (`purchase_invoice_opch`) — A/P invoice header

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
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### Status — source: SAP SDK
| Code | SAP meaning | Count in database |
|---|---|---|
| O | Open | 5,221 |
| C | Closed | 76,435 |

## Database notes

- 81,656 installments for 72,326 distinct invoices — most invoices have only 1 installment
- Snapshot strategy: do not truncate this table; historical records are needed to analyze payment evolution
