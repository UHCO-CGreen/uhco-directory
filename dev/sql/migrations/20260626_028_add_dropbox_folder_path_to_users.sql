-- =============================================================================
-- Migration 028: Add DropboxFolderPath to Users
-- Date: 2026-06-26
-- Description:
--   Stores the verified Dropbox folder path for a user so the admin edit page
--   can display folder status on load without an API call.
--
-- Rollback:
--   ALTER TABLE dbo.Users DROP COLUMN DropboxFolderPath;
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH('dbo.Users', 'DropboxFolderPath') IS NULL
    BEGIN
        ALTER TABLE dbo.Users
        ADD DropboxFolderPath NVARCHAR(500) NULL;

        PRINT 'Added dbo.Users.DropboxFolderPath.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.Users.DropboxFolderPath already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 028 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END

    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;
