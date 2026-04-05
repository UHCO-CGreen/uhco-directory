IF OBJECT_ID('dbo.UHApiPeopleStaging', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UHApiPeopleStaging (
        StagingID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UHApiID NVARCHAR(255) NOT NULL,
        FirstName NVARCHAR(150) NOT NULL,
        LastName NVARCHAR(150) NOT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UHApiPeopleStaging_CreatedAt DEFAULT SYSUTCDATETIME()
    );

    CREATE UNIQUE INDEX UX_UHApiPeopleStaging_UHApiID
        ON dbo.UHApiPeopleStaging (UHApiID);

    CREATE INDEX IX_UHApiPeopleStaging_Name
        ON dbo.UHApiPeopleStaging (LastName, FirstName);
END;