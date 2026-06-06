/* =====================================================================
   05_monitoring / 03 - audit.vw_jobs (SQL Agent-level)
   Latest execution of each ingestion_* job: did it run? success/failure/canceled?
   when? how long ago? Covers the blind spots that NEVER reach
   audit.ingestion_log: a job failure before the proc and "job did not fire"
   (there `last_run` stays old / `min_since` grows).

   Usage:  SELECT * FROM audit.vw_jobs ORDER BY job;
   step_id = 0 = result of the WHOLE JOB (not of a single step).
   ===================================================================== */
USE SAP_MIRROR;
GO
CREATE OR ALTER VIEW audit.vw_jobs AS
WITH h AS (
    SELECT
        j.name AS job,
        h.run_status,
        h.run_duration,
        h.message,
        DATETIMEFROMPARTS(h.run_date / 10000, (h.run_date / 100) % 100, h.run_date % 100,
                          h.run_time / 10000, (h.run_time / 100) % 100, h.run_time % 100, 0) AS last_run,
        ROW_NUMBER() OVER (PARTITION BY j.name
                           ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j ON j.job_id = h.job_id
    WHERE j.name LIKE N'ingestion\_%' ESCAPE N'\'
      AND h.step_id = 0
)
SELECT
    job,
    CASE run_status WHEN 1 THEN N'success'   WHEN 0 THEN N'failed'
                    WHEN 2 THEN N'retry'     WHEN 3 THEN N'canceled'
                    WHEN 4 THEN N'running'   ELSE N'?' END AS result,
    last_run,
    DATEDIFF(MINUTE, last_run, SYSDATETIME()) AS min_since,
    run_duration AS duration_hhmmss,   -- HHMMSS integer (e.g. 145 = 1m45s)
    message
FROM h
WHERE rn = 1;
GO
