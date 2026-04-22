/**
 * UserImageSourceDAO.cfc
 *
 * Responsible for: database access only.
 * No filesystem access, no business logic.
 * All SQL for UserImageSources lives here.
 */
component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    /**
     * Return all source records for a user, newest first within each key.
     */
    public array function getSourcesForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserImageSources WHERE UserID = :id ORDER BY SourceKey, CreatedAt DESC",
            { id = { value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    /**
     * Return active source counts grouped by user.
     */
    public array function getActiveSourceCountsByUser() {
        var qry = executeQueryWithRetry(
            "
            SELECT UserID,
                   COUNT(*) AS ActiveSourceCount
            FROM UserImageSources
            WHERE IsActive = 1
            GROUP BY UserID
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    /**
     * Return a single source record by its primary key.
     * Returns an empty struct when not found.
     */
    public struct function getSourceByID( required numeric sourceID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserImageSources WHERE UserImageSourceID = :id",
            { id = { value=sourceID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );
        return (qry.recordCount GT 0) ? qry.getRow(1) : {};
    }

    /**
     * Insert a new source record.
     * IsActive defaults to 1 (active) on insert.
     * Returns the new UserImageSourceID.
     */
    public numeric function insertSource( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserImageSources
                (UserID, SourceKey, DropboxPath, Notes, IsActive, CropOffsetX, CropOffsetY, CreatedAt, ModifiedAt)
            VALUES
                (:UserID, :SourceKey, :DropboxPath, :Notes, 1, :CropOffsetX, :CropOffsetY, GETDATE(), GETDATE());
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            {
                UserID      = { value = arguments.data.UserID,                                                    cfsqltype = "cf_sql_integer" },
                SourceKey   = { value = arguments.data.SourceKey,                                                 cfsqltype = "cf_sql_nvarchar" },
                DropboxPath = { value = arguments.data.SourcePath,                                                cfsqltype = "cf_sql_nvarchar" },
                Notes       = { value = (arguments.data.Notes ?: ""),                                            cfsqltype = "cf_sql_nvarchar",  null = !len(arguments.data.Notes ?: "") },
                CropOffsetX = { value = (isNumeric(arguments.data.CropOffsetX ?: "") ? val(arguments.data.CropOffsetX) : 0), cfsqltype = "cf_sql_integer" },
                CropOffsetY = { value = (isNumeric(arguments.data.CropOffsetY ?: "") ? val(arguments.data.CropOffsetY) : 0), cfsqltype = "cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    /**
     * Update the SourceKey and SourcePath of an existing record.
     * Bumps ModifiedAt.
     */
    public void function updateSource( required numeric sourceID, required struct data ) {
        executeQueryWithRetry(
            "
            UPDATE UserImageSources
            SET    SourceKey   = :SourceKey,
                   DropboxPath = :DropboxPath,
                   Notes       = :Notes,
                   ModifiedAt  = GETDATE()
            WHERE  UserImageSourceID = :id
            ",
            {
                id          = { value = arguments.sourceID,                  cfsqltype = "cf_sql_integer" },
                SourceKey   = { value = arguments.data.SourceKey,            cfsqltype = "cf_sql_nvarchar" },
                DropboxPath = { value = arguments.data.SourcePath,           cfsqltype = "cf_sql_nvarchar" },
                Notes       = { value = (arguments.data.Notes ?: ""),        cfsqltype = "cf_sql_nvarchar", null = !len(arguments.data.Notes ?: "") }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Flip the IsActive flag for a source record.
     * The service layer always passes false (deactivate); reactivation is not yet exposed.
     */
    public void function setActiveStatus( required numeric sourceID, required boolean isActive ) {
        executeQueryWithRetry(
            "UPDATE UserImageSources SET IsActive = :isActive, ModifiedAt = GETDATE() WHERE UserImageSourceID = :id",
            {
                id       = { value = arguments.sourceID, cfsqltype = "cf_sql_integer" },
                isActive = { value = arguments.isActive, cfsqltype = "cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Hard-delete a source record by primary key.
     * The service layer is responsible for ownership checks before calling this.
     */
    public void function deleteSource( required numeric sourceID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImageSources WHERE UserImageSourceID = :id",
            { id = { value = arguments.sourceID, cfsqltype = "cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Mark all variants for a given user + sourceKey as STALE.
     * Called by the service after any source add, update, or deactivation.
     * Variants are never regenerated automatically — this is a status marker only.
     */
    public void function markVariantsStale( required numeric userID, required string sourceKey ) {
        // JOIN through UserImageSources because UserImageVariants has no UserID or SourceKey column.
        // Silently no-ops when the UserImageVariants table does not yet exist (catch in service).
        executeQueryWithRetry(
            "
            UPDATE uiv
            SET    uiv.Status = 'stale'
            FROM   UserImageVariants uiv
            JOIN   UserImageSources  uis ON uis.UserImageSourceID = uiv.UserImageSourceID
            WHERE  uis.UserID    = :userID
            AND    uis.SourceKey = :sourceKey
            ",
            {
                userID    = { value = arguments.userID,    cfsqltype = "cf_sql_integer" },
                sourceKey = { value = arguments.sourceKey, cfsqltype = "cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
