-- =============================================================================
-- Migration 014: Seed scoped admin user roles
-- Date: 2026-05-28
-- Description:
--   Adds fixed admin roles for scoped user administration and assigns the
--   standard user-management permission bundle used by the new
--   org/flag-based authorization policy in CFML.
--
-- Rollback:
--   DELETE arp
--   FROM dbo.AdminRolePermissions arp
--   INNER JOIN dbo.AdminRoles ar ON ar.role_id = arp.role_id
--   INNER JOIN dbo.AdminPermissions ap ON ap.permission_id = arp.permission_id
--   WHERE ar.role_name IN (
--       'OD_STUDENT_ADMIN',
--       'PHD_MS_STUDENT_ADMIN',
--       'ALUMNI_ADMIN',
--       'CLINICAL_FACULTY_ADMIN',
--       'CLINICAL_STAFF_ADMIN',
--       'COLLEGE_STAFF_ADMIN',
--       'RESEARCH_FACULTY_ADMIN'
--   )
--     AND ap.permission_key IN (
--       'admin.view',
--       'users.view',
--       'users.edit',
--       'users.delete',
--       'flags.manage',
--       'orgs.manage',
--       'external_ids.manage'
--   );
--
--   DELETE FROM dbo.AdminRoles
--   WHERE role_name IN (
--       'OD_STUDENT_ADMIN',
--       'PHD_MS_STUDENT_ADMIN',
--       'ALUMNI_ADMIN',
--       'CLINICAL_FACULTY_ADMIN',
--       'CLINICAL_STAFF_ADMIN',
--       'COLLEGE_STAFF_ADMIN',
--       'RESEARCH_FACULTY_ADMIN'
--   );
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ScopedRoles TABLE (
        role_name VARCHAR(100) NOT NULL PRIMARY KEY
    );

    INSERT INTO @ScopedRoles (role_name)
    VALUES
        ('OD_STUDENT_ADMIN'),
        ('PHD_MS_STUDENT_ADMIN'),
        ('ALUMNI_ADMIN'),
        ('CLINICAL_FACULTY_ADMIN'),
        ('CLINICAL_STAFF_ADMIN'),
        ('COLLEGE_STAFF_ADMIN'),
        ('RESEARCH_FACULTY_ADMIN');

    INSERT INTO dbo.AdminRoles (role_name)
    SELECT sr.role_name
    FROM @ScopedRoles sr
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.AdminRoles ar
        WHERE ar.role_name = sr.role_name
    );
    PRINT 'Seeded scoped AdminRoles (or already present).';

    DECLARE @ScopedRolePermissions TABLE (
        role_name VARCHAR(100) NOT NULL,
        permission_key VARCHAR(100) NOT NULL,
        PRIMARY KEY (role_name, permission_key)
    );

    INSERT INTO @ScopedRolePermissions (role_name, permission_key)
    VALUES
        ('OD_STUDENT_ADMIN', 'admin.view'),
        ('OD_STUDENT_ADMIN', 'users.view'),
        ('OD_STUDENT_ADMIN', 'users.edit'),
        ('OD_STUDENT_ADMIN', 'users.delete'),
        ('OD_STUDENT_ADMIN', 'flags.manage'),
        ('OD_STUDENT_ADMIN', 'orgs.manage'),
        ('OD_STUDENT_ADMIN', 'external_ids.manage'),

        ('PHD_MS_STUDENT_ADMIN', 'admin.view'),
        ('PHD_MS_STUDENT_ADMIN', 'users.view'),
        ('PHD_MS_STUDENT_ADMIN', 'users.edit'),
        ('PHD_MS_STUDENT_ADMIN', 'users.delete'),
        ('PHD_MS_STUDENT_ADMIN', 'flags.manage'),
        ('PHD_MS_STUDENT_ADMIN', 'orgs.manage'),
        ('PHD_MS_STUDENT_ADMIN', 'external_ids.manage'),

        ('ALUMNI_ADMIN', 'admin.view'),
        ('ALUMNI_ADMIN', 'users.view'),
        ('ALUMNI_ADMIN', 'users.edit'),
        ('ALUMNI_ADMIN', 'users.delete'),
        ('ALUMNI_ADMIN', 'flags.manage'),
        ('ALUMNI_ADMIN', 'orgs.manage'),
        ('ALUMNI_ADMIN', 'external_ids.manage'),

        ('CLINICAL_FACULTY_ADMIN', 'admin.view'),
        ('CLINICAL_FACULTY_ADMIN', 'users.view'),
        ('CLINICAL_FACULTY_ADMIN', 'users.edit'),
        ('CLINICAL_FACULTY_ADMIN', 'users.delete'),
        ('CLINICAL_FACULTY_ADMIN', 'flags.manage'),
        ('CLINICAL_FACULTY_ADMIN', 'orgs.manage'),
        ('CLINICAL_FACULTY_ADMIN', 'external_ids.manage'),

        ('CLINICAL_STAFF_ADMIN', 'admin.view'),
        ('CLINICAL_STAFF_ADMIN', 'users.view'),
        ('CLINICAL_STAFF_ADMIN', 'users.edit'),
        ('CLINICAL_STAFF_ADMIN', 'users.delete'),
        ('CLINICAL_STAFF_ADMIN', 'flags.manage'),
        ('CLINICAL_STAFF_ADMIN', 'orgs.manage'),
        ('CLINICAL_STAFF_ADMIN', 'external_ids.manage'),

        ('COLLEGE_STAFF_ADMIN', 'admin.view'),
        ('COLLEGE_STAFF_ADMIN', 'users.view'),
        ('COLLEGE_STAFF_ADMIN', 'users.edit'),
        ('COLLEGE_STAFF_ADMIN', 'users.delete'),
        ('COLLEGE_STAFF_ADMIN', 'flags.manage'),
        ('COLLEGE_STAFF_ADMIN', 'orgs.manage'),
        ('COLLEGE_STAFF_ADMIN', 'external_ids.manage'),

        ('RESEARCH_FACULTY_ADMIN', 'admin.view'),
        ('RESEARCH_FACULTY_ADMIN', 'users.view'),
        ('RESEARCH_FACULTY_ADMIN', 'users.edit'),
        ('RESEARCH_FACULTY_ADMIN', 'users.delete'),
        ('RESEARCH_FACULTY_ADMIN', 'flags.manage'),
        ('RESEARCH_FACULTY_ADMIN', 'orgs.manage'),
        ('RESEARCH_FACULTY_ADMIN', 'external_ids.manage');

    INSERT INTO dbo.AdminRolePermissions (role_id, permission_id)
    SELECT ar.role_id, ap.permission_id
    FROM @ScopedRolePermissions srp
    INNER JOIN dbo.AdminRoles ar
        ON ar.role_name = srp.role_name
    INNER JOIN dbo.AdminPermissions ap
        ON ap.permission_key = srp.permission_key
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.AdminRolePermissions arp
        WHERE arp.role_id = ar.role_id
          AND arp.permission_id = ap.permission_id
    );
    PRINT 'Seeded scoped AdminRolePermissions (or already present).';

    COMMIT TRANSACTION;
    PRINT 'Migration 014 complete.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END

    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;
