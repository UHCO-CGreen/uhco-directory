-- =============================================================================
-- Migration 022: Create publication fetch runs
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.PublicationFetchRuns', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PublicationFetchRuns (
            PublicationFetchRunID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            UserID INT NOT NULL,
            PublicationServiceID INT NOT NULL,
            TriggeredByAdminUserID INT NULL,
            RunMode VARCHAR(50) NOT NULL CONSTRAINT DF_PublicationFetchRuns_RunMode DEFAULT ('manual'),
            StartedAt DATETIME NOT NULL CONSTRAINT DF_PublicationFetchRuns_StartedAt DEFAULT (GETDATE()),
            CompletedAt DATETIME NULL,
            Status VARCHAR(50) NOT NULL CONSTRAINT DF_PublicationFetchRuns_Status DEFAULT ('running'),
            Message NVARCHAR(2000) NULL,
            RecordsFetched INT NOT NULL CONSTRAINT DF_PublicationFetchRuns_RecordsFetched DEFAULT (0),
            RecordsMatched INT NOT NULL CONSTRAINT DF_PublicationFetchRuns_RecordsMatched DEFAULT (0),
            RecordsInserted INT NOT NULL CONSTRAINT DF_PublicationFetchRuns_RecordsInserted DEFAULT (0),
            RecordsUpdated INT NOT NULL CONSTRAINT DF_PublicationFetchRuns_RecordsUpdated DEFAULT (0)
        );

        ALTER TABLE dbo.PublicationFetchRuns
            ADD CONSTRAINT FK_PublicationFetchRuns_Users
            FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID);

        ALTER TABLE dbo.PublicationFetchRuns
            ADD CONSTRAINT FK_PublicationFetchRuns_PublicationServices
            FOREIGN KEY (PublicationServiceID) REFERENCES dbo.PublicationServices(PublicationServiceID);

        CREATE INDEX IX_PublicationFetchRuns_User_Service_StartedAt
            ON dbo.PublicationFetchRuns(UserID, PublicationServiceID, StartedAt DESC);

        PRINT 'Created dbo.PublicationFetchRuns.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.PublicationFetchRuns already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 022 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;