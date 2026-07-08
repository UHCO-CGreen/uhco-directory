-- =============================================================================
-- Migration 021: Create publication source payloads
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.PublicationSourcePayloads', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PublicationSourcePayloads (
            PublicationSourcePayloadID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            PublicationSourceRecordID INT NOT NULL,
            PayloadFormat VARCHAR(50) NOT NULL,
            PayloadText NVARCHAR(MAX) NOT NULL,
            FetchedAt DATETIME NOT NULL CONSTRAINT DF_PublicationSourcePayloads_FetchedAt DEFAULT (GETDATE()),
            ContentHash VARCHAR(128) NULL
        );

        ALTER TABLE dbo.PublicationSourcePayloads
            ADD CONSTRAINT FK_PublicationSourcePayloads_SourceRecord
            FOREIGN KEY (PublicationSourceRecordID) REFERENCES dbo.PublicationSourceRecords(PublicationSourceRecordID);

        CREATE INDEX IX_PublicationSourcePayloads_SourceRecord_FetchedAt
            ON dbo.PublicationSourcePayloads(PublicationSourceRecordID, FetchedAt DESC);

        PRINT 'Created dbo.PublicationSourcePayloads.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.PublicationSourcePayloads already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 021 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;