/* =====================================================================
   SAP HANA ingestion -> SQL Server  (linked server HANA_LINK)
   00_infra / 01 - Schemas
   Database: SAP_MIRROR
   Idempotent: safe to run as many times as needed.
   ===================================================================== */
USE SAP_MIRROR;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw_sap')
    EXEC('CREATE SCHEMA raw_sap');       -- mirror of the SAP tables (already exists)
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit');         -- execution log (already exists)
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'meta')
    EXEC('CREATE SCHEMA meta');          -- ingestion control table
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl');           -- ingestion procedures
GO
