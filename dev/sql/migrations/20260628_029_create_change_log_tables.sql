-- Migration: 20260628_029_create_change_log_tables
-- Creates the ChangeGroups and ChangeLog tables for the admin versioning/revert feature.
-- Changes made by admin users and scheduled tasks are captured as before/after JSON snapshots.
-- Super admins can revert any change group from the Change Log UI.

SET NOCOUNT ON;

-- ── ChangeGroups ──────────────────────────────────────────────────────────────
-- One row per logical operation (e.g., "save flags for user 42").
-- Groups related ChangeLog rows so they can be reviewed and reverted together.

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChangeGroups'
)
BEGIN
    CREATE TABLE dbo.ChangeGroups (
        GroupID         UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_ChangeGroups_GroupID DEFAULT NEWID(),
        EntityType      VARCHAR(50)      NOT NULL,   -- 'user', 'flag_def', 'access', 'app_config', 'scheduled_task'
        EntityID        VARCHAR(100)     NULL,        -- Primary key of the root entity (e.g., UserID as string)
        Source          VARCHAR(50)      NOT NULL,   -- 'admin', 'scheduled_task', 'revert'
        ChangedByID     INT              NULL,        -- AdminUsers.user_id; NULL for scheduled tasks
        ChangedBy       NVARCHAR(255)    NULL,        -- Display name or task name
        IPAddress       VARCHAR(50)      NULL,
        ChangeSection   VARCHAR(100)     NULL,        -- Human-readable: 'Flags', 'Degrees', 'Identity', etc.
        Description     NVARCHAR(500)    NULL,        -- Human-readable summary of the operation
        CreatedAt       DATETIME2(0)     NOT NULL CONSTRAINT DF_ChangeGroups_CreatedAt DEFAULT GETUTCDATE(),
        RevertedAt      DATETIME2(0)     NULL,
        RevertedByID    INT              NULL,
        RevertedBy      NVARCHAR(255)    NULL,

        CONSTRAINT PK_ChangeGroups PRIMARY KEY CLUSTERED (GroupID)
    );

    CREATE NONCLUSTERED INDEX IX_ChangeGroups_EntityType_ID
        ON dbo.ChangeGroups (EntityType, EntityID)
        WHERE EntityID IS NOT NULL;

    CREATE NONCLUSTERED INDEX IX_ChangeGroups_CreatedAt
        ON dbo.ChangeGroups (CreatedAt DESC);

    CREATE NONCLUSTERED INDEX IX_ChangeGroups_ChangedByID
        ON dbo.ChangeGroups (ChangedByID, CreatedAt DESC)
        WHERE ChangedByID IS NOT NULL;

    PRINT 'Created table dbo.ChangeGroups';
END
ELSE
BEGIN
    PRINT 'Table dbo.ChangeGroups already exists — skipped';
END;

-- ── ChangeLog ──────────────────────────────────────────────────────────────────
-- One row per affected table/row within a ChangeGroup.
-- BeforeJSON: full row state before the change (NULL for pure INSERT).
-- AfterJSON:  full row state after the change (NULL for pure DELETE).
-- For 'REPLACE' actions (delete-then-reinsert), both contain JSON arrays of rows.

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChangeLog'
)
BEGIN
    CREATE TABLE dbo.ChangeLog (
        ChangeID    INT              NOT NULL IDENTITY(1,1),
        GroupID     UNIQUEIDENTIFIER NOT NULL,
        TableName   VARCHAR(100)     NOT NULL,
        PKColumn    VARCHAR(100)     NOT NULL,   -- PK/FK column name used for targeting (e.g., 'UserID')
        RecordID    VARCHAR(255)     NOT NULL,   -- PK value(s) as string
        Action      VARCHAR(10)      NOT NULL,   -- 'UPDATE', 'INSERT', 'DELETE', 'REPLACE'
        BeforeJSON  NVARCHAR(MAX)    NULL,
        AfterJSON   NVARCHAR(MAX)    NULL,
        CreatedAt   DATETIME2(0)     NOT NULL CONSTRAINT DF_ChangeLog_CreatedAt DEFAULT GETUTCDATE(),

        CONSTRAINT PK_ChangeLog PRIMARY KEY CLUSTERED (ChangeID),
        CONSTRAINT FK_ChangeLog_GroupID FOREIGN KEY (GroupID) REFERENCES dbo.ChangeGroups(GroupID)
    );

    CREATE NONCLUSTERED INDEX IX_ChangeLog_GroupID
        ON dbo.ChangeLog (GroupID, ChangeID);

    PRINT 'Created table dbo.ChangeLog';
END
ELSE
BEGIN
    PRINT 'Table dbo.ChangeLog already exists — skipped';
END;
