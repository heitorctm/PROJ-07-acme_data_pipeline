# @ITEM_FAMILY — Item Family

**SAP table:** @ITEM_FAMILY  
**Bronze name:** item_family  
**Total columns in raw:** 3

## Description

Custom table (User-Defined Table in SAP B1) that stores Acme's product family registry. It is the top level of the item classification hierarchy: Family → Class → Subclass. The `U_FAMILY` field of OITM references the `Code` of this table.

Not documented in the SAP SDK — table created by Acme.

## Relationships

**Tables that reference @ITEM_FAMILY:**
- OITM via `U_FAMILY` — each item belongs to a family

## Column mapping

Source: raw database (no SDK — custom table).

| Raw column | Bronze name | Bronze type | Transformation |
|---|---|---|---|
| Code | family_code | nvarchar | rename — primary key |
| Name | family_name | nvarchar | rename |
| _ingestao_em | _ingestao_em | datetime2 | rename — ingestion audit column |

## Registered families

| Code | Name |
|---|---|
| 01 | 1. DRYWALL |
| 02 | 2. STEEL FRAME |
| 03 | 3. ACOUSTICS |
| 04 | 4. FLOORING |
| 05 | 5. MORTARS AND WATERPROOFING |
| 06 | 6. ROOFING |
| 07 | 7. WINDOWS AND DOORS |
| 08 | 8. REMOVABLE CEILINGS |
| 09 | 9. TOOLS |
| 10 | 10. PREFABRICATED |

## Database notes

- 25 records total; only 10 are valid families (codes 01–10)
- Codes 11–25 contain invalid values (strings of quotes, commas, periods and "DO NOT CREATE ANYTHING NEW") — registry junk, filter out in silver
- Recommendation: filter `family_code IN ('01','02','03','04','05','06','07','08','09','10')` when building the silver layer
