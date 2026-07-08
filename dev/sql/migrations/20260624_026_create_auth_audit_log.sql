-- Migration: 20260624_026_create_auth_audit_log
-- Creates the AuthAuditLog table for tracking admin and UserReview authentication events.
-- Events are written by model/services/authAudit_service.cfc and streamed via the
-- "authEvents" WebSocket channel to the admin/observability/index.cfm dashboard.

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'AuthAuditLog'
)
BEGIN
    CREATE TABLE dbo.AuthAuditLog (
        LogID       INT           IDENTITY(1,1) NOT NULL,
        Source      VARCHAR(20)   NOT NULL,           -- 'admin' | 'userreview'
        EventType   VARCHAR(30)   NOT NULL,           -- LOGIN, LOGIN_FAILED, LOGOUT, TRUSTED_LAUNCH,
                                                      -- IMPERSONATE_START, IMPERSONATE_END,
                                                      -- UR_LOGIN, UR_LOGIN_FAILED, UR_LOGOUT,
                                                      -- UR_EXTERNAL_AUTH, UR_EXTERNAL_AUTH_FAILED
        AdminUserID INT           NULL,               -- FK to AdminUsers; NULL for UserReview events or failed logins
        Username    NVARCHAR(50)  NULL,               -- CougarNet username (all events)
        EventAt     DATETIME2(0)  NOT NULL CONSTRAINT DF_AuthAuditLog_EventAt DEFAULT GETUTCDATE(),
        IPAddress   VARCHAR(50)   NULL,
        UserAgent   NVARCHAR(500) NULL,
        Details     NVARCHAR(500) NULL,

        CONSTRAINT PK_AuthAuditLog PRIMARY KEY CLUSTERED (LogID)
    );

    CREATE NONCLUSTERED INDEX IX_AuthAuditLog_EventAt
        ON dbo.AuthAuditLog (EventAt DESC);

    CREATE NONCLUSTERED INDEX IX_AuthAuditLog_AdminUserID
        ON dbo.AuthAuditLog (AdminUserID, EventAt DESC)
        WHERE AdminUserID IS NOT NULL;

    PRINT 'Created table dbo.AuthAuditLog';
END
ELSE
BEGIN
    PRINT 'Table dbo.AuthAuditLog already exists — skipped';
END
