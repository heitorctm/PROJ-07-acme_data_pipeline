/* =====================================================================
   05_monitoring / 01 - orphan cleanup (stuck running)
   Marks as 'interrupted' the executions that have been 'running' for more
   than 60 min. The longest load is ~7 min, so 60 min is clearly stuck
   (run killed before the TRY/CATCH: cancellation, connection drop, restart).

   The procs already self-heal (they close the orphan of their own table on
   the next execution). This script: (a) clears the historical backlog in one
   shot, (b) covers tables that won't run again any time soon. Idempotent --
   run it whenever you want or schedule it (e.g. once a day before the nightly cycle).
   ===================================================================== */
USE SAP_MIRROR;
GO
UPDATE audit.ingestion_log
   SET status = N'interrupted', finished_at = SYSDATETIME(),
       error_message = N'interrupted: execution did not finish (closed by orphan cleanup)'
 WHERE status = N'running'
   AND DATEDIFF(MINUTE, started_at, SYSDATETIME()) > 60;
PRINT CONCAT(@@ROWCOUNT, ' orphan(s) marked as interrupted.');
GO
