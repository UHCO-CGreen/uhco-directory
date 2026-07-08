-- =============================================================================
-- Migration 019: Create user publication links
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.UserPublications', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.UserPublications (
            UserPublicationID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
            UserID INT NOT NULL,
            PublicationID INT NOT NULL,
            DisplayOrder INT NOT NULL CONSTRAINT DF_UserPublications_DisplayOrder DEFAULT (0),
            IsShowcased BIT NOT NULL CONSTRAINT DF_UserPublications_IsShowcased DEFAULT (0),
            IsHidden BIT NOT NULL CONSTRAINT DF_UserPublications_IsHidden DEFAULT (0),
            FirstImportedAt DATETIME NOT NULL CONSTRAINT DF_UserPublications_FirstImportedAt DEFAULT (GETDATE()),
            LastSeenAt DATETIME NOT NULL CONSTRAINT DF_UserPublications_LastSeenAt DEFAULT (GETDATE()),
            CreatedAt DATETIME NOT NULL CONSTRAINT DF_UserPublications_CreatedAt DEFAULT (GETDATE()),
            UpdatedAt DATETIME NOT NULL CONSTRAINT DF_UserPublications_UpdatedAt DEFAULT (GETDATE())
        );

        ALTER TABLE dbo.UserPublications
            ADD CONSTRAINT FK_UserPublications_Users
            FOREIGN KEY (UserID) REFERENCES dbo.Users(UserID);

        ALTER TABLE dbo.UserPublications
            ADD CONSTRAINT FK_UserPublications_Publications
            FOREIGN KEY (PublicationID) REFERENCES dbo.Publications(PublicationID);

        CREATE UNIQUE INDEX UX_UserPublications_User_Publication
            ON dbo.UserPublications(UserID, PublicationID);

        CREATE INDEX IX_UserPublications_User_Showcased_Order
            ON dbo.UserPublications(UserID, IsShowcased, DisplayOrder);

        PRINT 'Created dbo.UserPublications.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.UserPublications already exists.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 019 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;