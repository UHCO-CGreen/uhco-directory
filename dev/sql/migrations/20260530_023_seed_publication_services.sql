-- =============================================================================
-- Migration 023: Seed publication services
-- Date: 2026-05-30
-- =============================================================================

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.PublicationServices', 'U') IS NOT NULL
    BEGIN
        MERGE dbo.PublicationServices AS target
        USING (
            SELECT 'orcid' AS ServiceCode, 'ORCID' AS ServiceName, 0 AS RequiresCredential UNION ALL
            SELECT 'pubmed', 'PubMed', 0 UNION ALL
            SELECT 'scopus', 'Scopus', 1 UNION ALL
            SELECT 'google_scholar', 'Google Scholar', 0
        ) AS src
        ON target.ServiceCode = src.ServiceCode
        WHEN MATCHED THEN
            UPDATE SET
                ServiceName = src.ServiceName,
                RequiresCredential = src.RequiresCredential,
                UpdatedAt = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (ServiceCode, ServiceName, RequiresCredential, IsActive, SupportsManualFetch, SupportsScheduledFetch, CreatedAt, UpdatedAt)
            VALUES (src.ServiceCode, src.ServiceName, src.RequiresCredential, 1, 1, 0, GETDATE(), GETDATE());

        PRINT 'Seeded dbo.PublicationServices.';
    END
    ELSE
    BEGIN
        PRINT 'dbo.PublicationServices does not exist yet.';
    END

    COMMIT TRANSACTION;
    PRINT 'Migration 023 complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @errMsg NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@errMsg, 16, 1);
END CATCH;