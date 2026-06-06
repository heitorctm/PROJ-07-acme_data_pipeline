# @ITEM_SUB_CLASS — Item Subclass

**SAP table:** @ITEM_SUB_CLASS  
**Bronze name:** item_sub_class  
**Total columns in raw:** 3

## Description

Custom table (User-Defined Table in SAP B1) that stores Acme's product subclass registry. It is the most granular level of the item classification hierarchy: Family → Class → Subclass. The `U_SUB_CLASS` field of OITM references the `Code` of this table.

Not documented in the SAP SDK — table created by Acme.

## Relationships

**Tables that reference @ITEM_SUB_CLASS:**
- OITM via `U_SUB_CLASS` — each item belongs to a subclass

## Column mapping

Source: raw database (no SDK — custom table).

| Raw column | Bronze name | Bronze type | Transformation |
|---|---|---|---|
| Code | sub_class_code | nvarchar | rename — primary key |
| Name | sub_class_name | nvarchar | rename |
| _ingestao_em | _ingestao_em | datetime2 | rename — ingestion audit column |

## Database notes

- 73 records total; 72 valid subclasses + 1 junk record (Code='-', Name='-')
- The numbering in the name reflects the hierarchy: the prefix indicates the parent family and class (e.g., '1.1.1.' belongs to class '01 - 1.1. BOARDS', which belongs to family '01 - DRYWALL')
- Recommendation: filter `sub_class_code != '-'` when building the silver layer
- Full list of subclasses available in the database via `SELECT Code, Name FROM raw_sap.[@ITEM_SUB_CLASS] WHERE Code != '-' ORDER BY Code`
