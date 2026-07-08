-- Migration: 20260629_034_create_admin_section_permissions
-- Creates AdminSectionPermissions table — a central registry of admin sections
-- and the permission key required to access each one. Also seeds the
-- users.test_users.manage permission so test-user visibility can be
-- delegated without granting full SUPER_ADMIN.
--
-- Rollback:
--   DROP TABLE IF EXISTS dbo.AdminSectionPermissions;
--   DELETE FROM dbo.AdminPermissions WHERE permission_key = 'users.test_users.manage';

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── 1. Seed users.test_users.manage permission ────────────────────────
    IF NOT EXISTS (
        SELECT 1 FROM dbo.AdminPermissions WHERE permission_key = 'users.test_users.manage'
    )
    BEGIN
        INSERT INTO dbo.AdminPermissions (
            permission_key, display_name, category, description,
            is_system, is_active, sort_order, created_at, updated_at
        )
        VALUES (
            'users.test_users.manage',
            'Manage Test Users',
            'users',
            'View and manage TEST_USER flagged accounts. Granted to SUPER_ADMIN by default.',
            1, 1, 85,
            GETDATE(), GETDATE()
        );
        PRINT 'Seeded permission: users.test_users.manage';
    END
    ELSE
        PRINT 'Permission users.test_users.manage already exists — skipped';

    -- ── 2. Create AdminSectionPermissions table ───────────────────────────
    IF OBJECT_ID('dbo.AdminSectionPermissions', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.AdminSectionPermissions (
            section_id    INT IDENTITY(1,1) PRIMARY KEY,
            section_key   VARCHAR(100) NOT NULL,
            section_name  VARCHAR(150) NOT NULL,
            section_path  VARCHAR(255) NOT NULL,
            permission_id INT NOT NULL
                REFERENCES dbo.AdminPermissions(permission_id),
            description   VARCHAR(255),
            sort_order    INT NOT NULL DEFAULT 0,
            is_system     BIT NOT NULL DEFAULT 1,
            created_at    DATETIME NOT NULL DEFAULT GETDATE(),
            updated_at    DATETIME NOT NULL DEFAULT GETDATE(),
            CONSTRAINT UQ_AdminSectionPermissions_key UNIQUE (section_key)
        );
        PRINT 'Created table: AdminSectionPermissions';
    END
    ELSE
        PRINT 'Table AdminSectionPermissions already exists — skipped';

    -- ── 3. Seed main admin sections ───────────────────────────────────────
    -- Helper macro: insert a row only if section_key does not exist
    DECLARE @rows TABLE (
        section_key  VARCHAR(100),
        section_name VARCHAR(150),
        section_path VARCHAR(255),
        perm_key     VARCHAR(100),
        description  VARCHAR(255),
        sort_order   INT
    );

    INSERT INTO @rows VALUES
        ('users',                      'Users',              '/admin/users/',                           'users.view',                       'Main user listing and profile management', 10),
        ('user-media',                 'User Media',         '/admin/user-media/',                      'media.view',                       'User photo and media management',          20),
        ('statistics',                 'Statistics',         '/admin/statistics/',                      'stats.manage',                     'Dashboard statistics configuration',       30),
        ('user-review',                'User Review',        '/admin/user-review/',                     'user_review.manage',               'User-submitted profile review queue',      40),
        ('migrations',                 'Migrations',         '/admin/migrations/',                      'migrations.manage',                'Graduation and data migration tools',      50),
        ('rosters',                    'Rosters',            '/admin/rosters/',                         'rosters.manage',                   'Roster generation and publishing',         60),
        ('import',                     'Import Data',        '/admin/import/',                          'import.manage',                    'Bulk data import from CSV files',          70),
        ('query-builder',              'Query Builder',      '/admin/query-builder/',                   'query_builder.use',                'Visual SELECT query builder',              80),
        ('settings',                   'Settings',           '/admin/settings/',                        'settings.view',                    'Settings entry point',                    110),
        ('settings/admin-users',       'Admin Users',        '/admin/settings/admin-users/',            'settings.admin_users.manage',      'Manage admin user accounts',              120),
        ('settings/admin-roles',       'Admin Roles',        '/admin/settings/admin-roles/',            'settings.admin_roles.manage',      'Manage admin roles and role permissions', 130),
        ('settings/admin-permissions', 'Admin Permissions',  '/admin/settings/admin-permissions/',      'settings.admin_permissions.manage','Manage admin permission definitions',     140),
        ('settings/section-perms',     'Section Permissions','/admin/settings/section-permissions/',   'settings.admin_permissions.manage','Manage section-to-permission mapping',    150),
        ('settings/app-config',        'App Config',         '/admin/settings/app-config/',             'settings.app_config.manage',       'Application configuration',               160),
        ('settings/media-config',      'Media Config',       '/admin/settings/media-config/',           'settings.media_config.manage',     'Image variant types and media settings',  170),
        ('settings/bulk-exclusions',   'Bulk Exclusions',    '/admin/settings/bulk-exclusions/',        'settings.bulk_exclusions.manage',  'Bulk exclusion rule management',          180),
        ('settings/uh-sync',           'UH Sync',            '/admin/settings/uh-sync/',                'settings.uh_sync.view',            'UH API sync configuration and reports',   190),
        ('settings/user-permissions',  'User Permissions',   '/admin/settings/user-permissions/',       'settings.user_permissions.manage', 'Manage identity user access permissions', 200);

    INSERT INTO dbo.AdminSectionPermissions (
        section_key, section_name, section_path, permission_id,
        description, sort_order, is_system, created_at, updated_at
    )
    SELECT
        r.section_key,
        r.section_name,
        r.section_path,
        p.permission_id,
        r.description,
        r.sort_order,
        1,
        GETDATE(),
        GETDATE()
    FROM @rows r
    JOIN dbo.AdminPermissions p ON p.permission_key = r.perm_key
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AdminSectionPermissions s
        WHERE s.section_key = r.section_key
    );

    PRINT 'Seeded AdminSectionPermissions rows.';

    COMMIT TRANSACTION;
    PRINT 'Migration 034 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
