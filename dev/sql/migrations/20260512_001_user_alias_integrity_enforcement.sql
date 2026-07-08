SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;

    -- Ensure IsPrimary exists and is non-null so ranking logic is deterministic.
    IF COL_LENGTH('dbo.UserAliases', 'IsPrimary') IS NULL
    BEGIN
        ALTER TABLE dbo.UserAliases
        ADD IsPrimary BIT NOT NULL
            CONSTRAINT DF_UserAliases_IsPrimary DEFAULT (0);
    END;

    -- Optional helper index for deterministic alias ranking/lookups.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.UserAliases')
          AND name = 'IX_UserAliases_UserID_IsPrimary_IsActive'
    )
    BEGIN
        CREATE INDEX IX_UserAliases_UserID_IsPrimary_IsActive
            ON dbo.UserAliases (UserID, IsPrimary, IsActive, SortOrder, AliasID);
    END;

    -- Backfill one alias for any user that currently has none.
    ;WITH UsersWithoutAliases AS (
        SELECT
            u.UserID,
            NULLIF(LTRIM(RTRIM(ISNULL(u.FirstName, ''))), '') AS FirstName,
            NULLIF(LTRIM(RTRIM(ISNULL(u.MiddleName, ''))), '') AS MiddleName,
            NULLIF(LTRIM(RTRIM(ISNULL(u.LastName, ''))), '') AS LastName,
            NULLIF(
                LTRIM(RTRIM(CONCAT(
                    CASE WHEN LTRIM(RTRIM(ISNULL(u.FirstName, ''))) <> '' THEN LTRIM(RTRIM(u.FirstName)) ELSE '' END,
                    CASE WHEN LTRIM(RTRIM(ISNULL(u.MiddleName, ''))) <> '' THEN ' ' + LTRIM(RTRIM(u.MiddleName)) ELSE '' END,
                    CASE WHEN LTRIM(RTRIM(ISNULL(u.LastName, ''))) <> '' THEN ' ' + LTRIM(RTRIM(u.LastName)) ELSE '' END
                ))),
                ''
            ) AS DisplayNameFromUsers,
            NULLIF(LTRIM(RTRIM(ISNULL(u.EmailPrimary, ''))), '') AS EmailPrimary
        FROM dbo.Users u
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.UserAliases ua
            WHERE ua.UserID = u.UserID
        )
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
        uwa.UserID,
        uwa.FirstName,
        uwa.MiddleName,
        uwa.LastName,
        COALESCE(uwa.DisplayNameFromUsers, uwa.EmailPrimary, CONCAT('User ', uwa.UserID)),
        'SOURCE_VARIANT',
        'UH API (Integrity Backfill)',
        1,
        1,
        0,
        GETDATE()
    FROM UsersWithoutAliases uwa;

    -- Enforce exactly one primary alias per user.
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
    SET ua.IsPrimary = CASE WHEN ra.rn = 1 THEN 1 ELSE 0 END
    FROM dbo.UserAliases ua
    INNER JOIN RankedAliases ra
        ON ra.AliasID = ua.AliasID;

    -- Add a hard guardrail: only one primary alias per user.
    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.UserAliases')
          AND name = 'UX_UserAliases_OnePrimaryPerUser'
    )
    BEGIN
        CREATE UNIQUE INDEX UX_UserAliases_OnePrimaryPerUser
            ON dbo.UserAliases (UserID)
            WHERE IsPrimary = 1;
    END;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    THROW;
END CATCH;

-- Post-apply verification summary
SELECT
    (SELECT COUNT(*) FROM dbo.Users) AS TotalUsers,
    (SELECT COUNT(*) FROM dbo.Users u WHERE NOT EXISTS (SELECT 1 FROM dbo.UserAliases ua WHERE ua.UserID = u.UserID)) AS UsersMissingAnyAlias,
    (SELECT COUNT(*) FROM (
        SELECT ua.UserID
        FROM dbo.UserAliases ua
        GROUP BY ua.UserID
        HAVING SUM(CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 1 ELSE 0 END) <> 1
    ) x) AS UsersWithInvalidPrimaryCount;

-- Detailed exception reports (should both be empty after successful apply)
SELECT u.UserID
FROM dbo.Users u
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.UserAliases ua
    WHERE ua.UserID = u.UserID
)
ORDER BY u.UserID;

SELECT
    ua.UserID,
    SUM(CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 1 ELSE 0 END) AS PrimaryAliasCount,
    COUNT(*) AS AliasCount
FROM dbo.UserAliases ua
GROUP BY ua.UserID
HAVING SUM(CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 1 ELSE 0 END) <> 1
ORDER BY ua.UserID;
