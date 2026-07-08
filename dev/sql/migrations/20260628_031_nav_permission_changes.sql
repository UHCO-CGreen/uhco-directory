-- Migration: 20260628_031_nav_permission_changes
-- Renames settings-namespaced permission keys to standalone keys as part of
-- promoting Statistics, User Review, Migrations, and Rosters out of the
-- Settings hub and into the main sidebar navigation.
--
-- Rollback:
--   UPDATE dbo.AdminPermissions SET permission_key = 'settings.user_review.manage', updated_at = GETDATE() WHERE permission_key = 'user_review.manage';
--   UPDATE dbo.AdminPermissions SET permission_key = 'settings.rosters.manage',     updated_at = GETDATE() WHERE permission_key = 'rosters.manage';
--   DELETE FROM dbo.AdminPermissions WHERE permission_key IN ('stats.manage', 'migrations.manage');

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Rename settings.user_review.manage → user_review.manage
    IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.user_review.manage')
    AND NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'user_review.manage')
    BEGIN
        UPDATE dbo.AdminPermissions
        SET permission_key = 'user_review.manage',
            display_name   = 'Manage User Review',
            category       = 'user_review',
            updated_at     = GETDATE()
        WHERE permission_key = 'settings.user_review.manage';
        PRINT 'Renamed permission: settings.user_review.manage → user_review.manage';
    END
    ELSE
    BEGIN
        PRINT 'Skipped user_review.manage rename (already exists or source not found)';
    END;

    -- Rename settings.rosters.manage → rosters.manage
    IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.rosters.manage')
    AND NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'rosters.manage')
    BEGIN
        UPDATE dbo.AdminPermissions
        SET permission_key = 'rosters.manage',
            display_name   = 'Manage Rosters',
            category       = 'rosters',
            updated_at     = GETDATE()
        WHERE permission_key = 'settings.rosters.manage';
        PRINT 'Renamed permission: settings.rosters.manage → rosters.manage';
    END
    ELSE
    BEGIN
        PRINT 'Skipped rosters.manage rename (already exists or source not found)';
    END;

    -- Seed stats.manage (new — no prior key)
    IF NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'stats.manage')
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key, display_name, category, description,
            is_system, is_active, sort_order, created_at, updated_at
        )
        VALUES (
            'stats.manage',
            'View Statistics',
            'statistics',
            'Access the statistics dashboard',
            1, 1, 200,
            GETDATE(), GETDATE()
        );
        PRINT 'Seeded permission: stats.manage';
    END
    ELSE
    BEGIN
        PRINT 'Permission stats.manage already exists — skipped';
    END;

    -- Seed migrations.manage (new — no prior key)
    IF NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'migrations.manage')
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key, display_name, category, description,
            is_system, is_active, sort_order, created_at, updated_at
        )
        VALUES (
            'migrations.manage',
            'Run Migrations',
            'migrations',
            'Access data migration tools for lifecycle transitions and graduation workflows',
            1, 1, 210,
            GETDATE(), GETDATE()
        );
        PRINT 'Seeded permission: migrations.manage';
    END
    ELSE
    BEGIN
        PRINT 'Permission migrations.manage already exists — skipped';
    END;

    COMMIT TRANSACTION;
    PRINT 'Migration 031 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
