# OHEM — Employee Master Data (HR)

**SAP table:** OHEM
**Bronze name:** — (not yet consumed by dbt)
**Total columns in raw:** 11 (+ `_ingestao_em`)

## Description

SAP B1 employee master data (Employee Master Data). Each row is an employee, with
name, hire/termination dates and the department, position and branch links. The
`salesPrson` links the employee to the corresponding salesperson in OSLP when applicable.

## Relationships

- **OSLP** (`salesperson_oslp`) — salesperson, join on `salesPrson`
- **OBPL** (`branch_obpl`) — branch, join on `branch`
- **AHEM** (`employee_log_ahem`) — change history of this master record

## Column mapping

| Raw column | SAP description | Type | Note |
|---|---|---|---|
| empID | Employee ID | int | primary key |
| salesPrson | Sales Employee Code | int | link to OSLP |
| firstName | First Name | nvarchar(50) | |
| middleName | Middle Name | nvarchar(50) | |
| lastName | Last Name | nvarchar(50) | |
| startDate | Start Date | datetime2 | hire date |
| termDate | Termination Date | datetime2 | termination (null = active) |
| dept | Department | smallint | department code |
| position | Employee Position | int | position code |
| branch | Branch | smallint | branch code |
| Active | Active | nvarchar(1) | Y/N |
| _ingestao_em | — | datetime2 | ingestion audit column |

## Notes

- `dept`, `position` and `branch` are codes; the descriptions live in dedicated SAP tables (HR).
- Small table → daily `full_reload`. There is not yet a dbt model consuming OHEM.
