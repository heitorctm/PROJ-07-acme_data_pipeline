# OJDT — Journal Entry (header)

**SAP table:** OJDT  
**Bronze name:** journal_entry_ojdt  
**Total raw columns:** 6

## Description

Stores the headers of journal entries (Journal Entry in SAP B1). Each row represents a financial transaction that generates accounting movement. Every document issued in SAP (invoice, payment, return, etc.) automatically generates a journal entry here. The `TransType` field identifies the origin of the entry.

OJDT has no `UpdateTS` in raw — the watermark has daily precision.

## Relationships

**Child table — join on `TransId`:**
- JDT1 (`journal_entry_lines_jdt1`) — debit/credit rows of the entry

**Traceability (via TransType + BaseRef):**
- OINV via `TransId` — A/R invoice referenced in OINV.TransId (TransType = 13)
- OPCH via `BaseRef` — A/P invoice (TransType = 18)
- OVPM via `BaseRef` — outgoing payment (TransType = 46)

## Column mapping

Source of descriptions: SAP Business One SDK 10.0 — confirmed via `/Finance/OJDT.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| TransId | Transaction Number | id_transacao | int | rename — primary key |
| RefDate | Posting Date | entry_date | date | cast — watermark |
| TransType | Origin | source_type | nvarchar | CASE (see enums) |
| Memo | Remarks | notes | nvarchar | rename |
| BaseRef | Origin No. | source_document_number | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Enums

### TransType — source: SAP SDK + database
| Code | SAP meaning | Count in database |
|---|---|---|
| 24 | Incoming Payment | 258,466 |
| 13 | A/R Invoice | 204,980 |
| 18 | A/P Invoice | 72,356 |
| 46 | Outgoing Payment | 70,083 |
| 30 | Journal Entry (manual) | 49,677 |
| 15 | Delivery | 21,469 |
| 203 | A/R Down Payment Invoice | 6,565 |
| 67 | Inventory Transfer | 5,041 |
| 14 | A/R Credit Memo | 3,923 |
| 321 | — | 2,654 |
| 10000071 | — | 2,234 |
| 204 | A/P Down Payment Invoice | 703 |
| 69 | Landed Costs | 294 |
| 19 | A/P Credit Memo | 231 |
| 162 | — | 85 |
| 20 | A/P Down Payment | 59 |
| 16 | Return | 41 |
| 182 | — | 40 |
| 310000001 | — | 17 |
| -2 | — | 4 |
| 21 | — | 2 |
| 59 | Goods Receipt PO | 2 |
| 60 | Goods Issue | 1 |

> Codes 321, 10000071, 162, 182, 310000001 are not documented in SDK 10.0 — they may be custom types or Brazilian extensions.

## Database notes

- 698,927 journal entries — one for each transaction recorded in SAP
- Join with JDT1 confirmed: all 698,927 entries have rows
- OJDT has no `UpdateTS` in raw — watermark with daily granularity only
