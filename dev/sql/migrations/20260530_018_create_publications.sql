-- =============================================================================
-- Migration 018: Create canonical publications
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.Publications', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Publications (
            PublicationID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            CanonicalTitle NVARCHAR(1000) NOT NULL,
            CanonicalAuthorsText NVARCHAR(MAX) NULL,
            PublicationYear INT NULL,
            PublicationMonth INT NULL,
            JournalOrSource NVARCHAR(500) NULL,
            Volume VARCHAR(50) NULL,
            Issue VARCHAR(50) NULL,
            PageRange VARCHAR(100) NULL,
            DOI VARCHAR(255) NULL,
            PMID VARCHAR(50) NULL,
            PMCID VARCHAR(50) NULL,
            Publisher NVARCHAR(255) NULL,
            PublicationType VARCHAR(100) NULL,
            AbstractText NVARCHAR(MAX) NULL,
            PrimaryURL VARCHAR(1000) NULL,
            CitationText NVARCHAR(MAX) NULL,
            IsActive BIT NOT NULL CONSTRAINT DF_Publications_IsActive DEFAULT (1),
            CreatedAt DATETIME NOT NULL CONSTRAINT DF_Publications_CreatedAt DEFAULT (GETDATE()),
            UpdatedAt DATETIME NOT NULL CONSTRAINT DF_Publications_UpdatedAt DEFAULT (GETDATE())
        );

        CREATE INDEX IX_Publications_DOI ON dbo.Publications(DOI);
        CREATE INDEX IX_Publications_PMID ON dbo.Publications(PMID);
        CREATE INDEX IX_Publications_PMCID ON dbo.Publications(PMCID);
        CREATE INDEX IX_Publications_Year_Title ON dbo.Publications(PublicationYear, CanonicalTitle);

        PRINT 'Created dbo.Publications.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.Publications already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 018 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;