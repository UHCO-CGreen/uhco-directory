SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
Phase 3 identity authority foundation.
- enforce one primary email per user
- enforce one active primary alias per user
- add normalized external ID lookup support
*/

IF OBJECT_ID(N'dbo.UserEmails', N'U') IS NOT NULL
BEGIN
    ;WITH RankedPrimaryEmails AS (
        SELECT
            EmailID,
            UserID,
            ROW_NUMBER() OVER (
                PARTITION BY UserID
                ORDER BY
                    CASE WHEN ISNULL(IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                    ISNULL(SortOrder, 2147483647),
                    EmailID
            ) AS RowNum,
            SUM(CASE WHEN ISNULL(IsPrimary, 0) = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY UserID) AS PrimaryCount
        FROM dbo.UserEmails
    )
    UPDATE ue
    SET IsPrimary = CASE WHEN r.PrimaryCount > 0 AND r.RowNum = 1 THEN 1 ELSE 0 END
    FROM dbo.UserEmails ue
    INNER JOIN RankedPrimaryEmails r ON r.EmailID = ue.EmailID
    WHERE r.PrimaryCount > 0
      AND ISNULL(ue.IsPrimary, 0) <> CASE WHEN r.PrimaryCount > 0 AND r.RowNum = 1 THEN 1 ELSE 0 END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'UX_UserEmails_UserID_Primary'
          AND object_id = OBJECT_ID(N'dbo.UserEmails')
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_UserEmails_UserID_Primary
            ON dbo.UserEmails (UserID)
            WHERE IsPrimary = 1;
    END
END
GO

IF OBJECT_ID(N'dbo.UserAliases', N'U') IS NOT NULL
BEGIN
    ;WITH RankedPrimaryAliases AS (
        SELECT
            AliasID,
            ROW_NUMBER() OVER (
                PARTITION BY UserID
                ORDER BY ISNULL(SortOrder, 2147483647), AliasID
            ) AS RowNum
        FROM dbo.UserAliases
        WHERE ISNULL(IsPrimary, 0) = 1
          AND ISNULL(IsActive, 0) = 1
    )
    UPDATE ua
    SET IsPrimary = 0
    FROM dbo.UserAliases ua
    INNER JOIN RankedPrimaryAliases r ON r.AliasID = ua.AliasID
    WHERE r.RowNum > 1;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'UX_UserAliases_UserID_PrimaryActive'
          AND object_id = OBJECT_ID(N'dbo.UserAliases')
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_UserAliases_UserID_PrimaryActive
            ON dbo.UserAliases (UserID)
                        WHERE IsPrimary = 1
                            AND IsActive = 1;
    END
END
GO

IF OBJECT_ID(N'dbo.UserExternalIDs', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'dbo.UserExternalIDs', N'NormalizedExternalValue') IS NULL
    BEGIN
        ALTER TABLE dbo.UserExternalIDs
        ADD NormalizedExternalValue AS LOWER(LTRIM(RTRIM(ISNULL(ExternalValue, ''))));
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = N'IX_UserExternalIDs_SystemID_NormalizedExternalValue'
          AND object_id = OBJECT_ID(N'dbo.UserExternalIDs')
    )
    BEGIN
        EXEC(N'CREATE NONCLUSTERED INDEX IX_UserExternalIDs_SystemID_NormalizedExternalValue
            ON dbo.UserExternalIDs (SystemID, NormalizedExternalValue)');
    END
END
GO