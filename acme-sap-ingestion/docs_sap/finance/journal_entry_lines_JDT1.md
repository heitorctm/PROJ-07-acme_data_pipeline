# JDT1 — Journal Entry Lines

**SAP table:** JDT1  
**Bronze name:** journal_entry_lines_jdt1  
**Total raw columns:** 10

## Description

Stores the debit and credit rows of journal entries (Journal Entry Rows in SAP B1). Each row represents a movement on a G/L account. Every entry is balanced: sum of debits = sum of credits per `TransId`. The composite key is `TransId` + `Line_ID`.

## Relationships

**Parent table — join on `TransId`:**
- OJDT (`journal_entry_ojdt`) — journal entry header

## Column mapping

Source of descriptions: SAP Business One SDK 10.0 — confirmed via `/Finance/JDT1.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| TransId | Transaction Key | id_transacao | int | rename |
| Line_ID | Row Number | line_number | int | rename |
| Account | Account Code | account_code | nvarchar | rename |
| Debit | Debit Amount | debit | decimal(18,2) | cast |
| Credit | Credit Amount | credit | decimal(18,2) | cast |
| RefDate | Posting Date | entry_date | date | cast |
| ShortName | BP/Account Code | partner_account_code | nvarchar | rename |
| ContraAct | Offset Account | offset_account | nvarchar | rename |
| TransType | Original Journal | source_type | nvarchar | rename — same domain as OJDT.TransType |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 3,349,484 rows for 698,927 entries — average of ~4.8 rows per entry
- `ShortName` stores the business partner code (CardCode) when the row is linked to a BP, or the account code when it is a pure G/L account
- `TransType` repeats the same value as OJDT — useful for filtering rows by document object_type without joining the header
- Entries always balanced: `SUM(Debit) = SUM(Credit)` per `TransId`
