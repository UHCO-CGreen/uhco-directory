-- Migration: 20260708_035_create_cors_whitelist_tables
-- Adds admin-configurable CORS whitelist entries (allowed origins and
-- allowed IP/CIDR ranges) consumed by api/v1/Application.cfc via cors_service.cfc.
-- Both tables ship empty — no origin/range is seeded by this migration.
--
-- Rollback:
--   DROP TABLE IF EXISTS dbo.CORSAllowedOrigins;
--   DROP TABLE IF EXISTS dbo.CORSAllowedIPRanges;

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.CORSAllowedOrigins', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.CORSAllowedOrigins (
            OriginID      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            OriginPattern NVARCHAR(255) NOT NULL,   -- 'exact': full "scheme://host[:port]"; 'wildcard': bare base domain (e.g. "partner.example.edu")
            MatchType     VARCHAR(10)   NOT NULL CONSTRAINT DF_CORSAllowedOrigins_MatchType DEFAULT 'exact'
                              CONSTRAINT CK_CORSAllowedOrigins_MatchType CHECK (MatchType IN ('exact','wildcard')),
            Description   NVARCHAR(255) NULL,
            IsActive      BIT NOT NULL CONSTRAINT DF_CORSAllowedOrigins_IsActive DEFAULT 1,
            CreatedAt     DATETIME2(0)  NOT NULL CONSTRAINT DF_CORSAllowedOrigins_CreatedAt DEFAULT SYSUTCDATETIME(),
            UpdatedAt     DATETIME2(0)  NULL
        );
        CREATE UNIQUE INDEX UX_CORSAllowedOrigins_Pattern ON dbo.CORSAllowedOrigins (OriginPattern, MatchType);
        CREATE INDEX IX_CORSAllowedOrigins_IsActive ON dbo.CORSAllowedOrigins (IsActive);
        PRINT 'Created table: CORSAllowedOrigins';
    END
    ELSE
        PRINT 'Table CORSAllowedOrigins already exists — skipped';

    IF OBJECT_ID('dbo.CORSAllowedIPRanges', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.CORSAllowedIPRanges (
            RangeID     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            CIDR        NVARCHAR(50)  NOT NULL,     -- e.g. "129.7.0.0/16" or an exact IP such as "10.0.0.5"
            Description NVARCHAR(255) NULL,
            IsActive    BIT NOT NULL CONSTRAINT DF_CORSAllowedIPRanges_IsActive DEFAULT 1,
            CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_CORSAllowedIPRanges_CreatedAt DEFAULT SYSUTCDATETIME(),
            UpdatedAt   DATETIME2(0)  NULL
        );
        CREATE UNIQUE INDEX UX_CORSAllowedIPRanges_CIDR ON dbo.CORSAllowedIPRanges (CIDR);
        CREATE INDEX IX_CORSAllowedIPRanges_IsActive ON dbo.CORSAllowedIPRanges (IsActive);
        PRINT 'Created table: CORSAllowedIPRanges';
    END
    ELSE
        PRINT 'Table CORSAllowedIPRanges already exists — skipped';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
