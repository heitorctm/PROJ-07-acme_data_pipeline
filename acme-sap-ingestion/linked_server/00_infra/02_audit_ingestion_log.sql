/* =====================================================================
   00_infra / 02 - audit.ingestion_log
   Same structure already used by the Python pipeline (kept for compatibility).
   Only creates if it does not exist -- does NOT recreate/delete historical data.
   ===================================================================== */
USE SAP_MIRROR;
GO

IF OBJECT_ID('audit.ingestion_log', 'U') IS NULL
BEGIN
    CREATE TABLE audit.ingestion_log (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        execution_id   UNIQUEIDENTIFIER NOT NULL,
        table_name        NVARCHAR(100) NOT NULL,
        strategy    NVARCHAR(50)  NOT NULL,
        frequency    NVARCHAR(20)  NOT NULL,
        started_at     DATETIME2     NOT NULL,
        finished_at        DATETIME2     NULL,
        row_count        INT           NULL,
        status        NVARCHAR(20)  NOT NULL,   -- running | success | error
        error_message NVARCHAR(MAX) NULL
    );
END
GO

-- index for the monitoring queries (by execution / most recent)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ingestion_log_exec' AND object_id = OBJECT_ID('audit.ingestion_log'))
    CREATE INDEX IX_ingestion_log_exec ON audit.ingestion_log (execution_id, started_at);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ingestion_log_table' AND object_id = OBJECT_ID('audit.ingestion_log'))
    CREATE INDEX IX_ingestion_log_table ON audit.ingestion_log (table_name, started_at);
GO
