-- Migration: 20260624_027_create_admin_session_tracking
-- Creates AdminSessions and AdminSessionControl tables for the auth observability
-- active-sessions panel and the admin force-logout mechanism.
--
-- AdminSessions    — one row per login session; IsActive=1 while live.
-- AdminSessionControl — one row per user; holds the ForceLogout flag checked
--                       on every request in onRequestStart so any admin can be
--                       kicked out on their next page load.

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AdminSessions'
)
BEGIN
    CREATE TABLE dbo.AdminSessions (
        SessionID       INT           IDENTITY(1,1) NOT NULL,
        AdminUserID     INT           NOT NULL,
        LoginTime       DATETIME2(0)  NOT NULL CONSTRAINT DF_AdminSessions_LoginTime    DEFAULT GETUTCDATE(),
        LogoutTime      DATETIME2(0)  NULL,
        IsActive        BIT           NOT NULL CONSTRAINT DF_AdminSessions_IsActive     DEFAULT 1,
        IPAddress       VARCHAR(50)   NULL,
        UserAgent       NVARCHAR(500) NULL,
        LastVisitedPath NVARCHAR(500) NULL,
        UpdatedAt       DATETIME2(0)  NOT NULL CONSTRAINT DF_AdminSessions_UpdatedAt   DEFAULT GETUTCDATE(),

        CONSTRAINT PK_AdminSessions PRIMARY KEY CLUSTERED (SessionID),
        CONSTRAINT FK_AdminSessions_AdminUsers
            FOREIGN KEY (AdminUserID) REFERENCES dbo.AdminUsers(user_id)
    );

    CREATE NONCLUSTERED INDEX IX_AdminSessions_Active
        ON dbo.AdminSessions (AdminUserID, IsActive)
        INCLUDE (LoginTime, IPAddress, LastVisitedPath, UpdatedAt);

    PRINT 'Created table dbo.AdminSessions';
END
ELSE
    PRINT 'Table dbo.AdminSessions already exists — skipped';

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AdminSessionControl'
)
BEGIN
    CREATE TABLE dbo.AdminSessionControl (
        AdminUserID  INT          NOT NULL,
        ForceLogout  BIT          NOT NULL CONSTRAINT DF_AdminSessionControl_ForceLogout DEFAULT 0,
        LastActivity DATETIME2(0) NULL,
        LastLogout   DATETIME2(0) NULL,
        UpdatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_AdminSessionControl_UpdatedAt  DEFAULT GETUTCDATE(),

        CONSTRAINT PK_AdminSessionControl PRIMARY KEY CLUSTERED (AdminUserID),
        CONSTRAINT FK_AdminSessionControl_AdminUsers
            FOREIGN KEY (AdminUserID) REFERENCES dbo.AdminUsers(user_id)
    );

    PRINT 'Created table dbo.AdminSessionControl';
END
ELSE
    PRINT 'Table dbo.AdminSessionControl already exists — skipped';
