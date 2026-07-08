-- =============================================================================
-- Migration 016: Create publication services lookup
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.PublicationServices', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PublicationServices (
            PublicationServiceID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            ServiceCode VARCHAR(50) NOT NULL,
            ServiceName VARCHAR(100) NOT NULL,
            IsActive BIT NOT NULL CONSTRAINT DF_PublicationServices_IsActive DEFAULT (1),
            SupportsManualFetch BIT NOT NULL CONSTRAINT DF_PublicationServices_SupportsManualFetch DEFAULT (1),
            SupportsScheduledFetch BIT NOT NULL CONSTRAINT DF_PublicationServices_SupportsScheduledFetch DEFAULT (0),
            RequiresCredential BIT NOT NULL CONSTRAINT DF_PublicationServices_RequiresCredential DEFAULT (0),
            CreatedAt DATETIME NOT NULL CONSTRAINT DF_PublicationServices_CreatedAt DEFAULT (GETDATE()),
            UpdatedAt DATETIME NOT NULL CONSTRAINT DF_PublicationServices_UpdatedAt DEFAULT (GETDATE())
        );

        CREATE UNIQUE INDEX UX_PublicationServices_ServiceCode
            ON dbo.PublicationServices(ServiceCode);

        PRINT 'Created dbo.PublicationServices.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.PublicationServices already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 016 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;