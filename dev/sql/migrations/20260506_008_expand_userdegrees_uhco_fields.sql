-- =============================================================================
-- Migration 008: Expand UserDegrees with UHCO enrollment tracking fields
-- Date: 2026-05-06
-- Description:
--   Renames DegreeYear -> GraduationYear and adds UHCO-specific columns to
--   UserDegrees to support multi-program students (OD, MS, PhD, Residency)
--   with per-degree enrollment status and expected graduation year tracking.
-- =============================================================================

-- Step 1: Rename DegreeYear -> GraduationYear
EXEC sp_rename 'UserDegrees.DegreeYear', 'GraduationYear', 'COLUMN';
GO

-- Step 2: Add UHCO flag — marks a degree row as a UHCO-issued credential
ALTER TABLE UserDegrees
    ADD IsUHCO BIT NOT NULL DEFAULT 0;
GO

-- Step 3: Add enrollment flag — 1 = currently enrolled; only meaningful when IsUHCO = 1
ALTER TABLE UserDegrees
    ADD IsEnrolled BIT NULL;
GO

-- Step 4: Add year-change flag — 1 = expected grad year was revised; requires IsEnrolled = 1
ALTER TABLE UserDegrees
    ADD HasYearChange BIT NULL;
GO

-- Step 5: Original expected graduation year before any revision; requires HasYearChange = 1
ALTER TABLE UserDegrees
    ADD OriginalExpectedGradYear INT NULL;
GO

-- Step 6: Current expected graduation year for enrolled students; requires IsEnrolled = 1
ALTER TABLE UserDegrees
    ADD ExpectedGradYear INT NULL;
GO

-- Step 7: Program code — OD, MS, PhD, Residency, or NULL for non-UHCO degrees
ALTER TABLE UserDegrees
    ADD Program NVARCHAR(50) NULL;
GO
