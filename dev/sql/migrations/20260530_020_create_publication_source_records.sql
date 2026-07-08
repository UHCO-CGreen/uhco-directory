-- =============================================================================
-- Migration 020: Create publication source records
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.PublicationSourceRecords', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PublicationSourceRecords (
            PublicationSourceRecordID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            PublicationID INT NULL,
            UserID INT NOT NULL,
            PublicationServiceID INT NOT NULL,
            SourceRecordKey VARCHAR(255) NOT NULL,
            SourceTitle NVARCHAR(1000) NULL,
            SourceAuthorsText NVARCHAR(MAX) NULL,
            SourcePublicationYear INT NULL,
            SourceJournalOrSource NVARCHAR(500) NULL,
            SourceDOI VARCHAR(255) NULL,
            SourcePMID VARCHAR(50) NULL,
            SourcePMCID VARCHAR(50) NULL,
            SourceURL VARCHAR(1000) NULL,
            MatchConfidence DECIMAL(5,2) NULL,
            MatchStatus VARCHAR(50) NOT NULL CONSTRAINT DF_PublicationSourceRecords_MatchStatus DEFAULT ('pending'),
            LastSeenAt DATETIME NOT NULL CONSTRAINT DF_PublicationSourceRecords_LastSeenAt DEFAULT (GETDATE()),
            CreatedAt DATETIME NOT NULL CONSTRAINT DF_PublicationSourceRecords_CreatedAt DEFAULT (GETDATE()),
            UpdatedAt DATETIME NOT NULL CONSTRAINT DF_PublicationSourceRecords_UpdatedAt DEFAULT (GETDATE())
        );

        ALTER TABLE dbo.PublicationSourceRecords
            ADD CONSTRAINT FK_PublicationSourceRecords_Users
            FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID);

        ALTER TABLE dbo.PublicationSourceRecords
            ADD CONSTRAINT FK_PublicationSourceRecords_PublicationServices
            FOREIGN KEY (PublicationServiceID) REFERENCES dbo.PublicationServices(PublicationServiceID);

        ALTER TABLE dbo.PublicationSourceRecords
            ADD CONSTRAINT FK_PublicationSourceRecords_Publications
            FOREIGN KEY (PublicationID) REFERENCES dbo.Publications(PublicationID);

        CREATE UNIQUE INDEX UX_PublicationSourceRecords_User_Service_Record
            ON dbo.PublicationSourceRecords(UserID, PublicationServiceID, SourceRecordKey);

        CREATE INDEX IX_PublicationSourceRecords_Publication_MatchStatus
            ON dbo.PublicationSourceRecords(PublicationID, MatchStatus);

        PRINT 'Created dbo.PublicationSourceRecords.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.PublicationSourceRecords already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 020 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;