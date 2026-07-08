-- =============================================================================
-- Migration 024: Seed publications AppConfig defaults
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.AppConfig', 'U') IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.AppConfig WHERE ConfigKey = 'publications.max_showcased_per_user')
        BEGIN
            INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
            VALUES ('publications.max_showcased_per_user', '10', GETDATE());

            PRINT 'Seeded publications.max_showcased_per_user.';
        END
        ELSE
        BEGIN
            PRINT 'publications.max_showcased_per_user already exists.';
        END
    END
    ELSE
    BEGIN
        PRINT 'dbo.AppConfig does not exist yet.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 024 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;