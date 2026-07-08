-- =============================================================================
-- Migration 010: Add DissertationThesis to UserStudentProfile
-- Date: 2026-05-06
-- Description:
--   Adds a nullable long-text field to store dissertation/thesis titles for
--   student/alumni profile data maintained in admin/users/edit.cfm.
-- =============================================================================

IF COL_LENGTH('UserStudentProfile', 'DissertationThesis') IS NULL
BEGIN
    ALTER TABLE UserStudentProfile
        ADD DissertationThesis NVARCHAR(MAX) NULL;
END;
GO
