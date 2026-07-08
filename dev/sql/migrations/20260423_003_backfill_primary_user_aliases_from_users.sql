SET NOCOUNT ON;

-- Ensure IsPrimary exists for deterministic display-name selection.
IF COL_LENGTH('dbo.UserAliases', 'IsPrimary') IS NULL
BEGIN
    ALTER TABLE dbo.UserAliases
    ADD IsPrimary BIT NOT NULL
        CONSTRAINT DF_UserAliases_IsPrimary DEFAULT (0);
END;

-- Optional supporting index for primary-alias lookups.
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.UserAliases')
      AND name = 'IX_UserAliases_UserID_IsPrimary'
)
BEGIN
    CREATE INDEX IX_UserAliases_UserID_IsPrimary
        ON dbo.UserAliases (UserID, IsPrimary, IsActive);
END;

-- Backfill UH API source-variant aliases from legacy Users name columns.
;WITH SourceNames AS (
    SELECT
        u.UserID,
        LTRIM(RTRIM(ISNULL(u.FirstName, '')))  AS FirstName,
        LTRIM(RTRIM(ISNULL(u.MiddleName, ''))) AS MiddleName,
        LTRIM(RTRIM(ISNULL(u.LastName, '')))   AS LastName,
        LTRIM(RTRIM(
            CONCAT(
                CASE WHEN LTRIM(RTRIM(ISNULL(u.FirstName, ''))) <> '' THEN LTRIM(RTRIM(u.FirstName)) ELSE '' END,
                CASE WHEN LTRIM(RTRIM(ISNULL(u.MiddleName, ''))) <> '' THEN ' ' + LTRIM(RTRIM(u.MiddleName)) ELSE '' END,
                CASE WHEN LTRIM(RTRIM(ISNULL(u.LastName, ''))) <> '' THEN ' ' + LTRIM(RTRIM(u.LastName)) ELSE '' END
            )
        )) AS DisplayName
    FROM dbo.Users u
    WHERE
        ISNULL(LTRIM(RTRIM(u.FirstName)), '') <> ''
        OR ISNULL(LTRIM(RTRIM(u.MiddleName)), '') <> ''
        OR ISNULL(LTRIM(RTRIM(u.LastName)), '') <> ''
)
INSERT INTO dbo.UserAliases (
    UserID,
    FirstName,
    MiddleName,
    LastName,
    DisplayName,
    AliasType,
    SourceSystem,
    IsActive,
    IsPrimary,
    SortOrder,
    CreatedAt
)
SELECT
    s.UserID,
    NULLIF(s.FirstName, ''),
    NULLIF(s.MiddleName, ''),
    NULLIF(s.LastName, ''),
    s.DisplayName,
    'SOURCE_VARIANT',
    'UH API',
    1,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM dbo.UserAliases p
            WHERE p.UserID = s.UserID
              AND ISNULL(p.IsPrimary, 0) = 1
        ) THEN 0
        ELSE 1
    END,
    ISNULL((
        SELECT MAX(ISNULL(ua.SortOrder, 0)) + 1
        FROM dbo.UserAliases ua
        WHERE ua.UserID = s.UserID
    ), 0),
    GETDATE()
FROM SourceNames s
WHERE
    s.DisplayName <> ''
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.UserAliases ua
        WHERE ua.UserID = s.UserID
          AND ISNULL(ua.AliasType, '') = 'SOURCE_VARIANT'
          AND ISNULL(ua.SourceSystem, '') = 'UH API'
          AND ISNULL(LTRIM(RTRIM(ua.FirstName)), '') = ISNULL(s.FirstName, '')
          AND ISNULL(LTRIM(RTRIM(ua.MiddleName)), '') = ISNULL(s.MiddleName, '')
          AND ISNULL(LTRIM(RTRIM(ua.LastName)), '') = ISNULL(s.LastName, '')
    );

-- Enforce one primary alias per user (deterministic tie-break).
;WITH RankedAliases AS (
    SELECT
        ua.AliasID,
        ua.UserID,
        ROW_NUMBER() OVER (
            PARTITION BY ua.UserID
            ORDER BY
                CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                CASE WHEN ISNULL(ua.IsActive, 0) = 1 THEN 0 ELSE 1 END,
                ISNULL(ua.SortOrder, 2147483647),
                ua.AliasID
        ) AS rn
    FROM dbo.UserAliases ua
)
UPDATE ua
SET ua.IsPrimary = CASE WHEN r.rn = 1 THEN 1 ELSE 0 END
FROM dbo.UserAliases ua
INNER JOIN RankedAliases r
    ON r.AliasID = ua.AliasID;
