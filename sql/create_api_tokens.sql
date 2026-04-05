IF OBJECT_ID('dbo.APITokens', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.APITokens (
        TokenID       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TokenName     NVARCHAR(100)  NOT NULL,
        AppName       NVARCHAR(100)  NOT NULL,
        TokenHash     CHAR(64)       NOT NULL,   -- SHA-256 hex of raw token, never store raw
        Scopes        NVARCHAR(50)   NOT NULL CONSTRAINT DF_APITokens_Scopes DEFAULT 'read',
        AllowedIPs    NVARCHAR(500)  NULL,        -- comma-separated, NULL = unrestricted
        ExpiresAt     DATETIME2(0)   NULL,        -- NULL = non-expiring
        IsActive      BIT            NOT NULL CONSTRAINT DF_APITokens_IsActive DEFAULT 1,
        CreatedAt     DATETIME2(0)   NOT NULL CONSTRAINT DF_APITokens_CreatedAt DEFAULT SYSUTCDATETIME(),
        LastUsedAt    DATETIME2(0)   NULL
    );

    CREATE UNIQUE INDEX UX_APITokens_Hash
        ON dbo.APITokens (TokenHash);

    CREATE INDEX IX_APITokens_IsActive
        ON dbo.APITokens (IsActive);
END;
