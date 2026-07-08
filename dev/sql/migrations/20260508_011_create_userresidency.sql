-- =============================================================================
-- Migration 011: Create UserResidency table
-- Date: 2026-05-08
-- Description:
--   Adds a repeatable residency table for student profile records.
--   Used by the Biographical Information tab (Student Data section) modal autosave UI.
-- =============================================================================

IF OBJECT_ID('dbo.UserResidency', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserResidency
    (
        ResidencyID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UserID INT NOT NULL,
        Location NVARCHAR(255) NULL,
        Specialty NVARCHAR(255) NULL,
        StartingYear INT NULL,
        IsUHCO BIT NOT NULL CONSTRAINT DF_UserResidency_IsUHCO DEFAULT (0),
        IsCurrent BIT NOT NULL CONSTRAINT DF_UserResidency_IsCurrent DEFAULT (0),
        SortOrder INT NOT NULL CONSTRAINT DF_UserResidency_SortOrder DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UserResidency_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NULL,
        CONSTRAINT FK_UserResidency_Users
            FOREIGN KEY (UserID)
            REFERENCES dbo.Users(UserID)
            ON DELETE CASCADE
    );

    CREATE INDEX IX_UserResidency_UserID
        ON dbo.UserResidency(UserID);
END;
GO

-- Example data shape:
-- Location     = University of Houston College of Optometry
-- Specialty    = Pediatric Optometry
-- StartingYear = 2026
-- IsUHCO       = 1 or 0
-- IsCurrent    = 1 or 0
--
-- Example insert:
-- INSERT INTO dbo.UserResidency (UserID, Location, Specialty, StartingYear, IsUHCO, IsCurrent, SortOrder)
-- VALUES
-- (12345, N'University of Houston College of Optometry', N'Pediatric Optometry', 2026, 1, 1, 0),
-- (12345, N'University of Houston College of Optometry', N'Contact Lens', 2024, 1, 0, 1);
