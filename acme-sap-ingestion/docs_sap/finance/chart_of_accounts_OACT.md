# OACT — Chart of Accounts

**SAP table:** OACT  
**Bronze name:** chart_of_accounts_oact  
**Total raw columns:** 3

## Description

Stores the chart of accounts (G/L Accounts in SAP B1). Each row represents a general ledger account. It is the reference table for the account codes used in the journal entry rows (JDT1) via `Account` and `ContraAct`.

## Relationships

**Tables that reference OACT:**
- JDT1 via `Account` — G/L account of the entry row
- JDT1 via `ContraAct` — offset account of the entry
- PCH1 via `AcctCode` — G/L account of the A/P invoice row

## Column mapping

Source of descriptions: SAP Business One SDK 10.0 — confirmed via `/Finance/OACT.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| AcctCode | Account Code | account_code | nvarchar | rename — primary key |
| AcctName | Account Name | account_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 636 G/L accounts registered
