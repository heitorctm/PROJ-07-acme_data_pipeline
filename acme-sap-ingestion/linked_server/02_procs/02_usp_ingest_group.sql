/* =====================================================================
   02_procs / 02 - etl.usp_ingest_group
   Runs full_reload on all the tables of a cadence group, one by one.
   Valid groups: 'hourly', 'inventory', 'purchases', 'nightly' (see _generator/generate_sql.py).
   Each table does its own transactional TRUNCATE+INSERT; an error in one
   does NOT bring down the others (unless @stop_on_error = 1). All tables
   in the run share the same execution_id (for monitoring).

   @group is required (no default) -- prevents running a nonexistent group by mistake.

   Usage:
       EXEC etl.usp_ingest_group @group = 'hourly';
       EXEC etl.usp_ingest_group @group = 'purchases';
   ===================================================================== */
USE SAP_MIRROR;
GO
CREATE OR ALTER PROCEDURE etl.usp_ingest_group
    @group         VARCHAR(40),
    @stop_on_error BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @execution_id UNIQUEIDENTIFIER = NEWID();
    DECLARE @table_name SYSNAME, @ok INT = 0, @errors INT = 0;
    DECLARE @t0 DATETIME2 = SYSDATETIME();

    PRINT CONCAT('Group "', @group, '" -- execution_id = ', CONVERT(varchar(36), @execution_id));

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT table_name
        FROM meta.ingestion_table
        WHERE active = 1 AND load_group = @group
        ORDER BY sort_order, table_name;

    OPEN cur;
    FETCH NEXT FROM cur INTO @table_name;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC etl.usp_ingest_table @table_name = @table_name, @execution_id = @execution_id;
            SET @ok += 1;
        END TRY
        BEGIN CATCH
            SET @errors += 1;
            PRINT CONCAT('  ERROR on ', @table_name, ': ', ERROR_MESSAGE());
            IF @stop_on_error = 1
            BEGIN
                CLOSE cur; DEALLOCATE cur;
                THROW;
            END
        END CATCH
        FETCH NEXT FROM cur INTO @table_name;
    END
    CLOSE cur; DEALLOCATE cur;

    PRINT CONCAT('Group "', @group, '" finished: ', @ok, ' ok, ', @errors,
                 ' error(s) in ', DATEDIFF(SECOND, @t0, SYSDATETIME()), 's.');

    -- If ANY table failed, propagate the failure to the caller (SQL Agent).
    -- Without this the job step ends "OK" even with errors, @retry_attempts
    -- never fires and audit.vw_jobs shows a false success. The per-table errors
    -- are already logged in audit.ingestion_log (see audit.vw_issues).
    IF @errors > 0
    BEGIN
        DECLARE @msg NVARCHAR(400) = CONCAT(
            N'Group "', @group, N'": ', @errors, N' table(s) failed (', @ok,
            N' ok). Details in audit.vw_issues / audit.ingestion_log execution_id ',
            CONVERT(varchar(36), @execution_id), N'.');
        THROW 50001, @msg, 1;
    END
END
GO
