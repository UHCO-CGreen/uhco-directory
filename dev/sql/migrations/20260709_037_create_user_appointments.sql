-- =============================================================================
-- Migration 037: Create UserAppointments table
-- Date: 2026-07-09
-- Description:
--   Adds a repeatable UserAppointments table to replace the flat Users.Title2
--   and Users.Title3 columns, which only supported two fixed appointment slots
--   with no way to label their type. Backfills one row per non-blank
--   Title2/Title3 value. Title1 (official UH title, synced separately) and
--   the Title2/Title3 columns themselves are left untouched/frozen for
--   historical reference.
-- =============================================================================

IF OBJECT_ID('dbo.UserAppointments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserAppointments
    (
        AppointmentID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UserID INT NOT NULL,
        AppointmentName NVARCHAR(255) NULL,
        AppointmentType NVARCHAR(100) NULL,
        SortOrder INT NOT NULL CONSTRAINT DF_UserAppointments_SortOrder DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UserAppointments_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NULL,
        CONSTRAINT FK_UserAppointments_Users
            FOREIGN KEY (UserID)
            REFERENCES dbo.Users(UserID)
            ON DELETE CASCADE
    );

    CREATE INDEX IX_UserAppointments_UserID
        ON dbo.UserAppointments(UserID);
END;
GO

-- Backfill: one row per non-blank Title2, one row per non-blank Title3, per user.
-- AppointmentType is left blank for migrated legacy data; only newly-added
-- appointments get a type via the admin UI going forward.
IF NOT EXISTS (SELECT 1 FROM dbo.UserAppointments)
BEGIN
    INSERT INTO dbo.UserAppointments (UserID, AppointmentName, AppointmentType, SortOrder)
    SELECT UserID, LTRIM(RTRIM(Title2)), '', 0
    FROM dbo.Users
    WHERE Title2 IS NOT NULL AND LTRIM(RTRIM(Title2)) <> '';

    INSERT INTO dbo.UserAppointments (UserID, AppointmentName, AppointmentType, SortOrder)
    SELECT UserID, LTRIM(RTRIM(Title3)), '', 1
    FROM dbo.Users
    WHERE Title3 IS NOT NULL AND LTRIM(RTRIM(Title3)) <> '';
END;
GO
