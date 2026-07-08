-- =============================================================================
-- Migration 015: Add run duration to UHSyncRuns
-- Date: 2026-05-29
-- Description:
--   Adds DurationMs to dbo.UHSyncRuns so UH API Sync Report executions can
--   store elapsed runtime in milliseconds.
--
-- Rollback:
--   ALTER TABLE dbo.UHSyncRuns DROP COLUMN DurationMs;
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH('dbo.UHSyncRuns', 'DurationMs') IS NULL
    BEGIN
        ALTER TABLE dbo.UHSyncRuns
        ADD DurationMs INT NULL;

        PRINT 'Added dbo.UHSyncRuns.DurationMs.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.UHSyncRuns.DurationMs already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 015 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END

    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;