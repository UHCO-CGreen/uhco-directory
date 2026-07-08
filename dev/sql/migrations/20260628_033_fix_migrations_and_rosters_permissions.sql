-- Migration 033: Fix migrations.manage duplicate and seed rosters.manage
--
-- Problem 1: Migration 031 seeded a new migrations.manage row instead of renaming
--   settings.migrations.manage, leaving two rows. Drop the orphaned seeded row,
--   then rename the original to preserve any existing role/user assignments.
--
-- Problem 2: settings.rosters.manage never existed in the seed file, so migration
--   031's rename was a no-op. Seed rosters.manage fresh.

BEGIN TRANSACTION;

-- Fix migrations permission duplicate --
-- Step 1: Remove the orphaned migrations.manage row seeded by migration 031
IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'migrations.manage')
   AND EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.migrations.manage')
BEGIN
    DELETE FROM dbo.AdminPermissions WHERE permission_key = 'migrations.manage';
    PRINT 'Deleted orphaned migrations.manage row';
END

-- Step 2: Rename settings.migrations.manage -> migrations.manage
IF EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'settings.migrations.manage')
   AND NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'migrations.manage')
BEGIN
    UPDATE dbo.AdminPermissions
    SET permission_key = 'migrations.manage', updated_at = GETDATE()
    WHERE permission_key = 'settings.migrations.manage';
    PRINT 'Renamed settings.migrations.manage -> migrations.manage';
END

-- Seed rosters.manage --
IF NOT EXISTS (SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'rosters.manage')
BEGIN
    INSERT INTO dbo.AdminPermissions
        (permission_key, display_name, category, description, is_system, is_active, sort_order, created_at, updated_at)
    VALUES
        ('rosters.manage', 'Manage Rosters', 'rosters', 'Generate and publish class roster PDFs', 1, 1, 220, GETDATE(), GETDATE());
    PRINT 'Seeded permission: rosters.manage';
END

COMMIT TRANSACTION;
