# NFN1 — Fiscal Numbering Series

**SAP table:** NFN1  
**Bronze name:** invoice_series_nfn1  
**Total columns in raw:** 5

## Description

Stores the master data of numbering series for fiscal documents (Nota Fiscal Sequence in SAP B1). Each row represents a numbering sequence linked to a document type and branch. It is referenced by the headers of sales documents (OINV, OQUT) via `SeqCode`.

## Relationships

**Tables that reference NFN1:**
- OINV via `SeqCode` — series of the outbound invoice
- OQUT via `SeqCode` — series of the quotation

## Column mapping

Source of the descriptions: SAP Business One SDK 10.0 — confirmed via `/Administration/NFN1.htm`.

| Raw column | SAP description | Bronze name | Bronze type | Transformation |
|---|---|---|---|---|
| ObjectCode | Document | object_code | nvarchar | rename |
| DocSubType | Document Sub-Type | subtipo_documento | nvarchar | rename |
| SeqCode | Seq. Code | series_code | smallint | rename — primary key |
| SeqName | Seq. Name | series_name | nvarchar | rename |
| _ingestao_em | — | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 85 series registered
- `ObjectCode = '0'` covers 84 series (standard documents); `ObjectCode = '13'` covers 1 series (cancellation type)
- `DocSubType = '--'` in all records — default subtype
- Naming pattern: `NFe{STATE}` for NF-e, `CUPOM_{STATE}` for NFC-e/fiscal receipt, `CUP_{ABBR}` for specific branches
- `SeqCode` is the join key with `OINV.SeqCode` and `OQUT.SeqCode` — it allows identifying the issuing branch by the series name
