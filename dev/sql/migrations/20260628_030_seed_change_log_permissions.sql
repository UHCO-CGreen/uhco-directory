-- Migration: 20260628_030_seed_change_log_permissions
-- Seeds the two new permissions for the admin change log / revert feature.
--
--   change_log.view   — View the change log (can be granted to any admin)
--   change_log.revert — Revert changes (super admin only)
--
-- Rollback:
--   DELETE FROM dbo.AdminRolePermissions WHERE permission_id IN (
--       SELECT permission_id FROM dbo.AdminPermissions
--       WHERE permission_key IN ('change_log.view', 'change_log.revert')
--   );
--   DELETE FROM dbo.AdminUserPermissions WHERE permission_id IN (
--       SELECT permission_id FROM dbo.AdminPermissions
--       WHERE permission_key IN ('change_log.view', 'change_log.revert')
--   );
--   DELETE FROM dbo.AdminPermissions
--   WHERE permission_key IN ('change_log.view', 'change_log.revert');

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'change_log.view'
    )
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key, display_name, category, description,
            is_system, is_active, sort_order, created_at, updated_at
        )
        VALUES (
            'change_log.view',
            'View Change Log',
            'change_log',
            'View the admin change log and audit trail',
            1, 1, 900,
            GETDATE(), GETDATE()
        );
        PRINT 'Seeded permission: change_log.view';
    END
    ELSE
    BEGIN
        PRINT 'Permission change_log.view already exists — skipped';
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'change_log.revert'
    )
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key, display_name, category, description,
            is_system, is_active, sort_order, created_at, updated_at
        )
        VALUES (
            'change_log.revert',
            'Revert Changes',
            'change_log',
            'Revert changes recorded in the admin change log (super admin only)',
            1, 1, 901,
            GETDATE(), GETDATE()
        );
        PRINT 'Seeded permission: change_log.revert';
    END
    ELSE
    BEGIN
        PRINT 'Permission change_log.revert already exists — skipped';
    END;

    COMMIT TRANSACTION;
    PRINT 'Migration 030 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
