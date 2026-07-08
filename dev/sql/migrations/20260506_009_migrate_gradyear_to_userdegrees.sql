-- =============================================================================
-- Migration 009: Backfill UHCO degree metadata from UserAcademicInfo
-- Date: 2026-05-06
-- Description:
--   One-time data migration. For each user whose UserAcademicInfo.CurrentGradYear
--   is set, finds matching UserDegrees rows that meet BOTH eligibility conditions
--   and sets the new UHCO enrollment fields accordingly.
--
--   Eligibility conditions (BOTH must be true):
--     1. DegreeName normalizes to OD, PHD, or MS (strips dots/spaces, uppercase)
--     2. University matches UHCO, University of Houston, or
--        University of Houston College of Optometry (case-insensitive)
--
--   If enrolled (has current-student flag):
--     -> IsEnrolled = 1, ExpectedGradYear = CurrentGradYear
--   If not enrolled (alumni or no flag):
--     -> IsEnrolled = 0, GraduationYear = CurrentGradYear (if GraduationYear is empty)
--
--   Rows that do not match either condition are left untouched.
--   UserAcademicInfo data is preserved in all cases (legacy fallback).
-- =============================================================================

UPDATE d
SET
    d.IsUHCO     = 1,
    d.Program    = CASE
                       WHEN REPLACE(REPLACE(UPPER(LTRIM(RTRIM(d.DegreeName))), '.', ''), ' ', '') = 'OD'  THEN 'OD'
                       WHEN REPLACE(REPLACE(UPPER(LTRIM(RTRIM(d.DegreeName))), '.', ''), ' ', '') = 'PHD' THEN 'PhD'
                       WHEN REPLACE(REPLACE(UPPER(LTRIM(RTRIM(d.DegreeName))), '.', ''), ' ', '') = 'MS'  THEN 'MS'
                       ELSE NULL
                   END,
    d.IsEnrolled = CASE WHEN studentFlag.UserID IS NOT NULL THEN 1 ELSE 0 END,
    d.ExpectedGradYear = CASE
                             WHEN studentFlag.UserID IS NOT NULL
                             THEN uai.CurrentGradYear
                             ELSE NULL
                         END,
    d.GraduationYear   = CASE
                             WHEN studentFlag.UserID IS NULL
                              AND ISNULL(LTRIM(RTRIM(d.GraduationYear)), '') = ''
                             THEN CAST(uai.CurrentGradYear AS NVARCHAR(10))
                             ELSE d.GraduationYear
                         END
FROM UserDegrees d
INNER JOIN UserAcademicInfo uai
    ON uai.UserID = d.UserID
   AND uai.CurrentGradYear IS NOT NULL
   AND uai.CurrentGradYear > 0
-- Left join to check current-student flag
OUTER APPLY (
    SELECT TOP 1 ufa.UserID
    FROM UserFlagAssignments ufa
    INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
    WHERE ufa.UserID = d.UserID
      AND LOWER(LTRIM(RTRIM(uf.FlagName))) = 'current-student'
) AS studentFlag
-- Condition 1: degree name normalizes to OD, PhD, or MS
WHERE REPLACE(REPLACE(UPPER(LTRIM(RTRIM(d.DegreeName))), '.', ''), ' ', '')
      IN ('OD', 'PHD', 'MS')
-- Condition 2: university matches UHCO names
  AND UPPER(LTRIM(RTRIM(d.University)))
      IN ('UHCO', 'UNIVERSITY OF HOUSTON', 'UNIVERSITY OF HOUSTON COLLEGE OF OPTOMETRY')
-- Only update rows not already marked as UHCO
  AND d.IsUHCO = 0;
GO

-- Report: how many rows were migrated
SELECT
    COUNT(*) AS MigratedRows,
    SUM(CASE WHEN IsEnrolled = 1 THEN 1 ELSE 0 END) AS EnrolledRows,
    SUM(CASE WHEN IsEnrolled = 0 THEN 1 ELSE 0 END) AS AlumniRows
FROM UserDegrees
WHERE IsUHCO = 1;
GO
