/* =====================================================================
   00_infra / 04 - DDL baseline: OHEM, AHEM, @PROFIT_RANKING
   Reproduces the REAL schema already present in raw_sap (read from SAP_MIRROR).
   Idempotent: only creates if it does NOT exist -- does not recreate or delete anything.

   In the current environment all 3 already exist and are intact (with DEFAULT GETDATE()
   on _ingestao_em). This script serves as a versioned baseline / for reprovisioning.
   ===================================================================== */
USE SAP_MIRROR;
GO

IF OBJECT_ID('raw_sap.OHEM', 'U') IS NULL
CREATE TABLE raw_sap.[OHEM] (
    [empID]        INT          NULL,
    [salesPrson]   INT          NULL,
    [firstName]    NVARCHAR(50) NULL,
    [middleName]   NVARCHAR(50) NULL,
    [lastName]     NVARCHAR(50) NULL,
    [startDate]    DATETIME2(7) NULL,
    [termDate]     DATETIME2(7) NULL,
    [dept]         SMALLINT     NULL,
    [position]     INT          NULL,
    [branch]       SMALLINT     NULL,
    [Active]       NVARCHAR(1)  NULL,
    [_ingestao_em] DATETIME2(7) NULL CONSTRAINT DF_raw_OHEM_ingestao DEFAULT GETDATE()
);
GO

IF OBJECT_ID('raw_sap.AHEM', 'U') IS NULL
CREATE TABLE raw_sap.[AHEM] (
    [LogInstanc]   INT          NULL,
    [empID]        INT          NULL,
    [salesPrson]   INT          NULL,
    [firstName]    NVARCHAR(50) NULL,
    [middleName]   NVARCHAR(50) NULL,
    [lastName]     NVARCHAR(50) NULL,
    [startDate]    DATETIME2(7) NULL,
    [termDate]     DATETIME2(7) NULL,
    [dept]         SMALLINT     NULL,
    [position]     INT          NULL,
    [branch]       SMALLINT     NULL,
    [Active]       NVARCHAR(1)  NULL,
    [UserSign]     SMALLINT     NULL,
    [UpdateDate]   DATETIME2(7) NULL,
    [CreateDate]   DATETIME2(7) NULL,
    [_ingestao_em] DATETIME2(7) NULL CONSTRAINT DF_raw_AHEM_ingestao DEFAULT GETDATE()
);
GO

IF OBJECT_ID('raw_sap.[@PROFIT_RANKING]', 'U') IS NULL
CREATE TABLE raw_sap.[@PROFIT_RANKING] (
    [U_Store]       NVARCHAR(50) NULL,
    [U_Date]       DATETIME2(7) NULL,
    [U_Profit]      NVARCHAR(10) NULL,
    [_ingestao_em] DATETIME2(7) NULL CONSTRAINT DF_raw_PROFIT_RANKING_ingestao DEFAULT GETDATE()
);
GO
