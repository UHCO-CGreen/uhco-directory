-- =============================================================================
-- Migration 017: Create user publication profiles
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.UserPublicationProfiles', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.UserPublicationProfiles (
            UserPublicationProfileID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            UserID INT NOT NULL,
            PublicationServiceID INT NOT NULL,
            ProfileIdentifier VARCHAR(255) NULL,
            ProfileURL VARCHAR(1000) NULL,
            SearchQuery VARCHAR(1000) NULL,
            IsEnabled BIT NOT NULL CONSTRAINT DF_UserPublicationProfiles_IsEnabled DEFAULT (1),
            LastFetchAt DATETIME NULL,
            LastSuccessfulFetchAt DATETIME NULL,
            LastFetchStatus VARCHAR(50) NULL,
            LastFetchMessage VARCHAR(1000) NULL,
            CreatedAt DATETIME NOT NULL CONSTRAINT DF_UserPublicationProfiles_CreatedAt DEFAULT (GETDATE()),
            UpdatedAt DATETIME NOT NULL CONSTRAINT DF_UserPublicationProfiles_UpdatedAt DEFAULT (GETDATE())
        );

        ALTER TABLE dbo.UserPublicationProfiles
            ADD CONSTRAINT FK_UserPublicationProfiles_Users
            FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID);

        ALTER TABLE dbo.UserPublicationProfiles
            ADD CONSTRAINT FK_UserPublicationProfiles_PublicationServices
            FOREIGN KEY (PublicationServiceID) REFERENCES dbo.PublicationServices(PublicationServiceID);

        CREATE UNIQUE INDEX UX_UserPublicationProfiles_User_Service
            ON dbo.UserPublicationProfiles(UserID, PublicationServiceID);

        CREATE INDEX IX_UserPublicationProfiles_Service_Identifier
            ON dbo.UserPublicationProfiles(PublicationServiceID, ProfileIdentifier);

        PRINT 'Created dbo.UserPublicationProfiles.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.UserPublicationProfiles already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 017 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;