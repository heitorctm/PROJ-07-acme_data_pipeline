# AHEM — Employee Change History (log of OHEM)

**SAP table:** AHEM
**Bronze name:** — (not yet consumed by dbt)
**Total columns in raw:** 15 (+ `_ingestao_em`)

## Description

SAP B1 log table (prefix `A` = history) that records the state of the employee master data
(OHEM) at each change. Each row is a version of an employee at a point in time,
identified by `LogInstanc`, with who changed it (`UserSign`) and when (`UpdateDate`/`CreateDate`).
It allows reconstructing the timeline of changes in position, department and status.

## Relationships

- **OHEM** (`employee_ohem`) — current employee master data, join on `empID`
- **OUSR** (`user_ousr`) — user who made the change, join on `UserSign`

## Column mapping

| Raw column | SAP description | Type | Note |
|---|---|---|---|
| LogInstanc | Log Instance | int | primary key (log instance) |
| empID | Employee ID | int | employee, link to OHEM |
| salesPrson | Sales Employee Code | int | link to OSLP |
| firstName | First Name | nvarchar(50) | |
| middleName | Middle Name | nvarchar(50) | |
| lastName | Last Name | nvarchar(50) | |
| startDate | Start Date | datetime2 | hire date |
| termDate | Termination Date | datetime2 | termination |
| dept | Department | smallint | department code |
| position | Employee Position | int | position code |
| branch | Branch | smallint | branch code |
| Active | Active | nvarchar(1) | Y/N |
| UserSign | User Signature | smallint | user who recorded the change |
| UpdateDate | Update Date | datetime2 | date of the change |
| CreateDate | Create Date | datetime2 | creation date of the log record |
| _ingestao_em | — | datetime2 | ingestion audit column |

## Notes

- Same columns as OHEM + log identity (`LogInstanc`, `UserSign`, `UpdateDate`, `CreateDate`).
- Daily `full_reload`; there is not yet a dbt model consuming AHEM.
