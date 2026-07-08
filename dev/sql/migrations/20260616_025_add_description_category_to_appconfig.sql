-- =============================================================================
-- Migration 025: Add Description and Category columns to AppConfig; seed known keys
-- Date: 2026-06-16
--
-- NOTE: Part B uses EXEC() for all UPDATE statements so SQL Server compiles
-- them at runtime (after the ALTER TABLE in Part A), not at batch-parse time.
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Part A: Add new nullable columns (idempotent)
    IF COL_LENGTH('dbo.AppConfig', 'Description') IS NULL
    BEGIN
        ALTER TABLE dbo.AppConfig ADD [Description] NVARCHAR(500) NULL;
        PRINT 'Added Description column to AppConfig.';
    END
    ELSE
        PRINT 'Description column already exists.';

    IF COL_LENGTH('dbo.AppConfig', 'Category') IS NULL
    BEGIN
        ALTER TABLE dbo.AppConfig ADD [Category] NVARCHAR(100) NULL;
        PRINT 'Added Category column to AppConfig.';
    END
    ELSE
        PRINT 'Category column already exists.';

    -- Part B: Seed category and description for known keys.
    -- EXEC() is required so these statements compile after Part A runs,
    -- not at batch-parse time when the columns may not yet exist.

    -- Dashboard
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dashboard'', Description = ''Rows per page in the dashboard user list.'' WHERE ConfigKey = ''dashboard.list_page_size''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dashboard'', Description = ''Age in months before a user record is flagged as stale.'' WHERE ConfigKey = ''dashboard.stale_months''');

    -- LDAP
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''CougarNet LDAP server hostname.'' WHERE ConfigKey = ''ldap.cougarnet.server''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Base Distinguished Name for CougarNet LDAP queries.'' WHERE ConfigKey = ''ldap.cougarnet.start_dn''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Timeout in seconds for LDAP connection attempts.'' WHERE ConfigKey = ''ldap.cougarnet.timeout_seconds''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Username for LDAP bind authentication (e.g. COUGARNET\svc-opt-cfserv).'' WHERE ConfigKey = ''ldap.cougarnet.bind_username''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Password for LDAP bind authentication. Sensitive — stored encrypted when encryption key is configured.'' WHERE ConfigKey = ''ldap.cougarnet.bind_password''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Pipe-delimited list of LDAP group DNs that identify faculty members.'' WHERE ConfigKey = ''ldap.cougarnet.groups.faculty''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Pipe-delimited list of LDAP group DNs that identify staff members.'' WHERE ConfigKey = ''ldap.cougarnet.groups.staff''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''LDAP'', Description = ''Pipe-delimited list of LDAP group DNs that identify current students.'' WHERE ConfigKey = ''ldap.cougarnet.groups.current_student''');

    -- Dropbox
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Dropbox application secret. Sensitive — stored encrypted when encryption key is configured.'' WHERE ConfigKey = ''dropbox.app_secret''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Dropbox OAuth refresh token. Sensitive — stored encrypted when encryption key is configured.'' WHERE ConfigKey = ''dropbox.refresh_token''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Dropbox file browser mode setting.'' WHERE ConfigKey = ''dropbox.browse_mode''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Comma-separated list of Dropbox folder paths available for browsing.'' WHERE ConfigKey = ''dropbox.folder_browse_folders''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Dropbox namespace ID for the root folder path.'' WHERE ConfigKey = ''dropbox.path_root_namespace_id''');
    EXEC('UPDATE dbo.AppConfig SET Category = ''Dropbox'', Description = ''Dropbox member ID of the user account used for file operations.'' WHERE ConfigKey = ''dropbox.select_user_member_id''');

    -- Media
    EXEC('UPDATE dbo.AppConfig SET Category = ''Media'', Description = ''Comma-delimited list of media source keys used for image ingestion.'' WHERE ConfigKey = ''media.source_keys''');

    -- Publications
    EXEC('UPDATE dbo.AppConfig SET Category = ''Publications'', Description = ''Maximum number of publications a user can showcase on their profile.'' WHERE ConfigKey = ''publications.max_showcased_per_user''');

    -- Test Mode
    EXEC('UPDATE dbo.AppConfig SET Category = ''Test Mode'', Description = ''Enables test mode across the application (1 = enabled, 0 = disabled).'' WHERE ConfigKey = ''test_mode.enabled''');

    PRINT 'Category and Description seeded for known AppConfig keys.';

    COMMIT TRANSACTION;
    PRINT 'Migration 025 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;
