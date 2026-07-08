-- Migration 032: Rename import and query-builder permission keys to remove "settings." prefix
-- Preserves all existing role/user assignments via in-place UPDATE.

BEGIN TRANSACTION;

-- Rename settings.import.manage -> import.manage
IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.import.manage')
    AND NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'import.manage')
BEGIN
    UPDATE dbo.AdminPermissions
    SET permission_key = 'import.manage', updated_at = GETDATE()
    WHERE permission_key = 'settings.import.manage';
END

-- Rename settings.query_builder.use -> query_builder.use
IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.query_builder.use')
    AND NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'query_builder.use')
BEGIN
    UPDATE dbo.AdminPermissions
    SET permission_key = 'query_builder.use', updated_at = GETDATE()
    WHERE permission_key = 'settings.query_builder.use';
END

COMMIT TRANSACTION;
