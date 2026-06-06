/* =====================================================================
   02_procs / 01 - etl.usp_ingest_table
   GENERIC full_reload proc (TRUNCATE + INSERT) via OPENQUERY(HANA_LINK).
   Reads everything from meta.ingestion_table. Used by the tables in the cadence
   groups (hourly/inventory/purchases/nightly), called in a loop by etl.usp_ingest_group.
   (The incremental ones have their own dedicated proc in 02_procs/dedicated/.)

   Atomicity: TRUNCATE is transactional in SQL Server. If the INSERT fails,
   the ROLLBACK undoes the TRUNCATE -> the table keeps the previous data.

   Usage:
       EXEC etl.usp_ingest_table @table_name = 'OCRD';
       EXEC etl.usp_ingest_table @table_name = 'OCRD', @debug = 1;  -- only prints the SQL
   ===================================================================== */
USE SAP_MIRROR;
GO
CREATE OR ALTER PROCEDURE etl.usp_ingest_table
    @table_name      SYSNAME,
    @execution_id UNIQUEIDENTIFIER = NULL,
    @debug       BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @execution_id IS NULL SET @execution_id = NEWID();

    DECLARE @raw_schema    SYSNAME = N'raw_sap',
            @hana_schema   SYSNAME,
            @hana_name     SYSNAME,
            @hana_columns  NVARCHAR(MAX),
            @sql_columns   NVARCHAR(MAX),
            @hana_filter   NVARCHAR(MAX),
            @frequency    VARCHAR(20),
            @row_count        INT = 0,
            @log_id        INT,
            @remote_select NVARCHAR(MAX),
            @sql           NVARCHAR(MAX),
            @msg           NVARCHAR(2048),
            @dest          NVARCHAR(300),
            @sql_truncate  NVARCHAR(400);

    -- qualified name of the destination (QUOTENAME cannot go directly inside EXEC(...))
    SET @dest         = QUOTENAME(@raw_schema) + N'.' + QUOTENAME(@table_name);
    SET @sql_truncate = N'TRUNCATE TABLE ' + @dest + N';';

    SELECT
        @hana_schema  = hana_schema,
        @hana_name    = hana_name,
        @hana_columns = hana_columns,
        @sql_columns  = sql_columns,
        @hana_filter  = hana_filter,
        @frequency   = frequency
    FROM meta.ingestion_table
    WHERE table_name = @table_name AND active = 1;

    IF @hana_name IS NULL
    BEGIN
        SET @msg = N'Table not found (or inactive) in meta.ingestion_table: ' + @table_name;
        THROW 50001, @msg, 1;
    END

    -- prevents two simultaneous loads of the same table
    DECLARE @lock_res NVARCHAR(255) = N'etl.ingestion.' + @table_name, @lock INT;
    EXEC @lock = sp_getapplock @Resource = @lock_res, @LockMode = 'Exclusive',
                               @LockOwner = 'Session', @LockTimeout = 5000;
    IF @lock < 0
    BEGIN
        SET @msg = N'Ingestion already in progress for ' + @table_name + N'.';
        THROW 50002, @msg, 1;
    END

    -- SELECT that runs on HANA
    SET @remote_select =
        N'SELECT ' + @hana_columns +
        N' FROM "' + @hana_schema + N'"."' + @hana_name + N'"' +
        CASE WHEN NULLIF(@hana_filter, N'') IS NOT NULL
             THEN N' WHERE ' + @hana_filter ELSE N'' END;

    -- INSERT ... SELECT ... OPENQUERY (single quotes escaped for the literal)
    SET @sql =
        N'INSERT INTO ' + @dest +
        N' (' + @sql_columns + N') ' +
        N'SELECT ' + @sql_columns +
        N' FROM OPENQUERY(HANA_LINK, ''' + REPLACE(@remote_select, '''', '''''') + N''');';

    IF @debug = 1
    BEGIN
        PRINT N'--- remote SELECT (HANA) ---';
        PRINT @remote_select;
        PRINT N'--- INSERT (SQL Server) ---';
        PRINT @sql;
        EXEC sp_releaseapplock @Resource = @lock_res, @LockOwner = 'Session';
        RETURN;
    END

    -- self-heal: closes a previous stuck execution of this table (the applock guarantees it is dead)
    UPDATE audit.ingestion_log SET status = 'interrupted', finished_at = SYSDATETIME(),
           error_message = N'interrupted: previous execution did not finish (closed when starting a new load)'
    WHERE table_name = @table_name AND status = 'running';

    INSERT INTO audit.ingestion_log (execution_id, table_name, strategy, frequency, started_at, status)
    VALUES (@execution_id, @table_name, 'full_reload', @frequency, SYSDATETIME(), 'running');
    SET @log_id = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRAN;
            EXEC sp_executesql @sql_truncate;
            EXEC sp_executesql @sql;
            SET @row_count = @@ROWCOUNT;
        COMMIT;

        UPDATE audit.ingestion_log
            SET finished_at = SYSDATETIME(), row_count = @row_count, status = 'success'
            WHERE id = @log_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        SET @msg = LEFT(ERROR_MESSAGE(), 4000);
        UPDATE audit.ingestion_log
            SET finished_at = SYSDATETIME(), status = 'error', error_message = @msg
            WHERE id = @log_id;
        EXEC sp_releaseapplock @Resource = @lock_res, @LockOwner = 'Session';
        THROW;
    END CATCH

    EXEC sp_releaseapplock @Resource = @lock_res, @LockOwner = 'Session';
END
GO
