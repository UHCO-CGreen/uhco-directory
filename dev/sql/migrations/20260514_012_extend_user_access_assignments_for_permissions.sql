-- =============================================================================
-- Migration 012: Extend UserAccessAssignments for permission lifecycle
-- Date: 2026-05-14
-- Description:
--   Adds GrantedBy, ExpiresAt, and IsActive columns to UserAccessAssignments
--   to support permission expiry and soft-revoke tracking. Seeds standard
--   dot-notation permission definitions into AccessAreas and assigns dev test
--   permissions for userID 128. Also registers the
--   settings.user_permissions.manage admin permission definition.
--
-- Rollback:
--   ALTER TABLE dbo.UserAccessAssignments DROP COLUMN GrantedBy;
--   ALTER TABLE dbo.UserAccessAssignments DROP COLUMN ExpiresAt;
--   ALTER TABLE dbo.UserAccessAssignments DROP CONSTRAINT DF_UserAccessAssignments_IsActive;
--   ALTER TABLE dbo.UserAccessAssignments DROP COLUMN IsActive;
--   DROP INDEX IF EXISTS IX_UserAccessAssignments_UserID_Active ON dbo.UserAccessAssignments;
--   DELETE FROM dbo.UserAccessAssignments WHERE UserID = 128;
--   DELETE FROM dbo.AccessAreas WHERE AccessName IN (
--       'documents.view','documents.upload','directory.view','portal.admin');
--   DELETE FROM dbo.AdminPermissions WHERE permission_key = 'settings.user_permissions.manage';
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── Step 1: Add GrantedBy column ─────────────────────────────────────────
    IF COL_LENGTH('dbo.UserAccessAssignments', 'GrantedBy') IS NULL
    BEGIN
        ALTER TABLE dbo.UserAccessAssignments
            ADD GrantedBy INT NULL;
        PRINT 'Added GrantedBy column to UserAccessAssignments.';
    END

    -- ── Step 2: Add ExpiresAt column ─────────────────────────────────────────
    IF COL_LENGTH('dbo.UserAccessAssignments', 'ExpiresAt') IS NULL
    BEGIN
        ALTER TABLE dbo.UserAccessAssignments
            ADD ExpiresAt DATETIME NULL;
        PRINT 'Added ExpiresAt column to UserAccessAssignments.';
    END

    -- ── Step 3: Add IsActive column ───────────────────────────────────────────
    -- NOT NULL with DEFAULT: SQL Server backfills all existing rows to 1
    -- automatically during the ALTER TABLE operation.
    IF COL_LENGTH('dbo.UserAccessAssignments', 'IsActive') IS NULL
    BEGIN
        ALTER TABLE dbo.UserAccessAssignments
            ADD IsActive BIT NOT NULL
                CONSTRAINT DF_UserAccessAssignments_IsActive DEFAULT (1);
        PRINT 'Added IsActive column to UserAccessAssignments.';
    END

    -- ── Step 4: Filtered index on UserID for active assignments ──────────────
    -- Uses EXEC to defer column-name resolution to runtime, because IsActive
    -- is added in step 3 of the same batch and SQL Server would reject a static
    -- WHERE IsActive = 1 predicate at parse time if the column didn't exist yet.
    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE  name      = 'IX_UserAccessAssignments_UserID_Active'
          AND  object_id = OBJECT_ID('dbo.UserAccessAssignments')
    )
    BEGIN
        EXEC('CREATE NONCLUSTERED INDEX IX_UserAccessAssignments_UserID_Active
              ON dbo.UserAccessAssignments (UserID)
              WHERE IsActive = 1');
        PRINT 'Created index IX_UserAccessAssignments_UserID_Active.';
    END

    -- ── Step 5: Seed AccessAreas with dot-notation permission definitions ─────
    INSERT INTO dbo.AccessAreas (AccessName)
    SELECT v.Name
    FROM (VALUES
        ('documents.view'),
        ('documents.upload'),
        ('directory.view'),
        ('portal.admin')
    ) AS v (Name)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AccessAreas WHERE AccessName = v.Name
    );
    PRINT 'Seeded AccessAreas permission definitions (or already present).';

    -- ── Step 6: Seed dev test permissions for userID 128 ─────────────────────
    INSERT INTO dbo.UserAccessAssignments (UserID, AccessAreaID, GrantedAt)
    SELECT 128, AA.AccessAreaID, GETDATE()
    FROM   dbo.AccessAreas AA
    WHERE  AA.AccessName IN (
               'documents.view', 'documents.upload',
               'directory.view', 'portal.admin'
           )
      AND NOT EXISTS (
        SELECT 1 FROM dbo.UserAccessAssignments
        WHERE  UserID = 128 AND AccessAreaID = AA.AccessAreaID
    );
    PRINT 'Seeded UserAccessAssignments for dev userID 128 (or already present).';

    -- ── Step 7: Register admin permission definition ──────────────────────────
    IF NOT EXISTS (
        SELECT 1 FROM dbo.AdminPermissions
        WHERE  permission_key = 'settings.user_permissions.manage'
    )
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key,
            display_name,
            category,
            description,
            is_system,
            is_active,
            sort_order,
            updated_at
        )
        VALUES (
            'settings.user_permissions.manage',
            'Manage User Permissions',
            'Settings',
            'Grant or revoke module access permissions for identity users.',
            0,
            1,
            0,
            GETDATE()
        );
        PRINT 'Seeded AdminPermissions: settings.user_permissions.manage.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 012 complete.';

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;
