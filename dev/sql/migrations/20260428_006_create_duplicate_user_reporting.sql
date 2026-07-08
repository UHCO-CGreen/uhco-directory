SET NOCOUNT ON;

IF OBJECT_ID('dbo.DuplicateUserRuns', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DuplicateUserRuns (
        RunID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RunAt DATETIME NOT NULL CONSTRAINT DF_DuplicateUserRuns_RunAt DEFAULT (GETDATE()),
        CompletedAt DATETIME NULL,
        TriggeredBy VARCHAR(50) NOT NULL CONSTRAINT DF_DuplicateUserRuns_TriggeredBy DEFAULT ('manual'),
        TotalUsers INT NOT NULL CONSTRAINT DF_DuplicateUserRuns_TotalUsers DEFAULT (0),
        TotalPairs INT NOT NULL CONSTRAINT DF_DuplicateUserRuns_TotalPairs DEFAULT (0),
        Status VARCHAR(20) NOT NULL CONSTRAINT DF_DuplicateUserRuns_Status DEFAULT ('running'),
        ErrorMessage NVARCHAR(1000) NULL
    );
END;

IF OBJECT_ID('dbo.DuplicateUserPairs', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DuplicateUserPairs (
        PairID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        FirstSeenRunID INT NULL,
        LastSeenRunID INT NULL,
        UserID_A INT NOT NULL,
        UserID_B INT NOT NULL,
        ConfidenceScore INT NOT NULL CONSTRAINT DF_DuplicateUserPairs_ConfidenceScore DEFAULT (0),
        MatchSignals NVARCHAR(MAX) NOT NULL CONSTRAINT DF_DuplicateUserPairs_MatchSignals DEFAULT ('[]'),
        Status VARCHAR(20) NOT NULL CONSTRAINT DF_DuplicateUserPairs_Status DEFAULT ('pending'),
        LastSeenAt DATETIME NOT NULL CONSTRAINT DF_DuplicateUserPairs_LastSeenAt DEFAULT (GETDATE()),
        IgnoredReason NVARCHAR(500) NULL,
        CreatedAt DATETIME NOT NULL CONSTRAINT DF_DuplicateUserPairs_CreatedAt DEFAULT (GETDATE()),
        UpdatedAt DATETIME NOT NULL CONSTRAINT DF_DuplicateUserPairs_UpdatedAt DEFAULT (GETDATE()),
        CONSTRAINT CK_DuplicateUserPairs_UserOrder CHECK (UserID_A < UserID_B),
        CONSTRAINT CK_DuplicateUserPairs_Status CHECK (Status IN ('pending', 'ignored', 'merged')),
        CONSTRAINT UQ_DuplicateUserPairs_UserPair UNIQUE (UserID_A, UserID_B),
        CONSTRAINT FK_DuplicateUserPairs_FirstSeenRun FOREIGN KEY (FirstSeenRunID) REFERENCES dbo.DuplicateUserRuns(RunID),
        CONSTRAINT FK_DuplicateUserPairs_LastSeenRun FOREIGN KEY (LastSeenRunID) REFERENCES dbo.DuplicateUserRuns(RunID),
        CONSTRAINT FK_DuplicateUserPairs_UserA FOREIGN KEY (UserID_A) REFERENCES dbo.Users(UserID),
        CONSTRAINT FK_DuplicateUserPairs_UserB FOREIGN KEY (UserID_B) REFERENCES dbo.Users(UserID)
    );

    CREATE INDEX IX_DuplicateUserPairs_Status ON dbo.DuplicateUserPairs (Status, LastSeenAt DESC);
END;

IF OBJECT_ID('dbo.DuplicateUserMerges', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DuplicateUserMerges (
        MergeID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PairID INT NOT NULL,
        PrimaryUserID INT NOT NULL,
        SecondaryUserID INT NOT NULL,
        MergedByAdminUserID INT NULL,
        MergeChoices NVARCHAR(MAX) NOT NULL CONSTRAINT DF_DuplicateUserMerges_MergeChoices DEFAULT ('{}'),
        MergedAt DATETIME NOT NULL CONSTRAINT DF_DuplicateUserMerges_MergedAt DEFAULT (GETDATE()),
        Notes NVARCHAR(500) NULL,
        CONSTRAINT FK_DuplicateUserMerges_Pair FOREIGN KEY (PairID) REFERENCES dbo.DuplicateUserPairs(PairID),
        CONSTRAINT FK_DuplicateUserMerges_PrimaryUser FOREIGN KEY (PrimaryUserID) REFERENCES dbo.Users(UserID),
        CONSTRAINT FK_DuplicateUserMerges_SecondaryUser FOREIGN KEY (SecondaryUserID) REFERENCES dbo.Users(UserID),
        CONSTRAINT FK_DuplicateUserMerges_AdminUser FOREIGN KEY (MergedByAdminUserID) REFERENCES dbo.AdminUsers(user_id)
    );
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AdminPermissions
    WHERE permission_key = 'reporting.duplicate_users.manage'
)
BEGIN
    INSERT INTO dbo.AdminPermissions (
        permission_key,
        display_name,
        category,
        description,
        is_system,
        is_active,
        sort_order,
        created_at,
        updated_at
    )
    VALUES (
        'reporting.duplicate_users.manage',
        'Manage Duplicate User Report',
        'reporting',
        'Can run and review duplicate-user detection reports.',
        1,
        1,
        260,
        GETDATE(),
        GETDATE()
    );
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'duplicate_users.min_confidence'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('duplicate_users.min_confidence', '35', GETDATE());
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'scheduled_tasks.uhco_duplicateusersreport.start_time'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('scheduled_tasks.uhco_duplicateusersreport.start_time', '05:00 AM', GETDATE());
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'scheduled_tasks.uhco_duplicateusersreport.frequency'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('scheduled_tasks.uhco_duplicateusersreport.frequency', 'monthly', GETDATE());
END;
