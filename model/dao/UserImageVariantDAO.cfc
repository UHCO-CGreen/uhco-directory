/**
 * UserImageVariantDAO.cfc
 *
 * Responsible for: database access only.
 * No filesystem access, no business logic.
 * All SQL for ImageVariantTypes and UserImageVariants lives here.
 *
 * ── Expected schema ────────────────────────────────────────────────────────
 *
 *   ImageVariantTypes
 *   -----------------
 *   VariantTypeCode  NVARCHAR(50)  PK
 *   VariantName      NVARCHAR(100)
 *   Audience         NVARCHAR(50)   e.g. "web", "kiosk", "print"
 *   SourceKey        NVARCHAR(50)   which UserImageSource.SourceKey feeds this type
 *   OutputWidth      INT            NULL = no resize
 *   OutputHeight     INT            NULL = no resize
 *   Description      NVARCHAR(500)  NULL
 *   IsActive         BIT            DEFAULT 1
 *   SortOrder        INT            DEFAULT 0
 *
 *   UserImageVariants
 *   -----------------
 *   UserImageVariantID  INT IDENTITY  PK
 *   UserID              INT           FK → directory users table
 *   VariantTypeCode     NVARCHAR(50)  FK → ImageVariantTypes
 *   SourceKey           NVARCHAR(50)  denormalized from ImageVariantTypes for fast stale queries
 *   SourceID            INT           NULL FK → UserImageSources (the assigned source)
 *   LocalPath           NVARCHAR(500) NULL output file path (POC; swap for Dropbox path later)
 *   Status              NVARCHAR(20)  'stale' | 'current' | 'error'
 *   ErrorMessage        NVARCHAR(MAX) NULL
 *   GeneratedAt         DATETIME      NULL
 *   CreatedAt           DATETIME      DEFAULT GETDATE()
 *   ModifiedAt          DATETIME      DEFAULT GETDATE()
 *   UNIQUE (UserID, VariantTypeCode)
 *
 * ───────────────────────────────────────────────────────────────────────────
 */
component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }


    // ── ImageVariantTypes ──────────────────────────────────────────────────

    /**
     * Return all active variant type definitions, ordered by Code.
     * Real columns: ImageVariantTypeID, Code, Description, Audience,
     *               OutputFormat, WidthPx, HeightPx, AllowTransparency,
     *               AllowOffsets, IsActive
     */
    public array function getVariantTypesAll() {
        var qry = executeQueryWithRetry(
            "
            SELECT ImageVariantTypeID, Code, Description, Audience,
                   OutputFormat, WidthPx, HeightPx,
                   Mode, IsActive
            FROM   ImageVariantTypes
            WHERE  IsActive = 1
            ORDER  BY Code
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    /**
     * Return ALL variant types including inactive, for the admin management page.
     */
    public array function getVariantTypesAllAdmin() {
        var qry = executeQueryWithRetry(
            "
            SELECT ImageVariantTypeID, Code, Description, Audience,
                   OutputFormat, WidthPx, HeightPx,
                   Mode, IsActive
            FROM   ImageVariantTypes
            ORDER  BY Code
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    /**
     * Return a single variant type by its integer primary key.
     * Returns an empty struct when not found (includes inactive for admin editing).
     */
    public struct function getVariantTypeByID( required numeric imageVariantTypeID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM ImageVariantTypes WHERE ImageVariantTypeID = :id",
            { id = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );
        return (qry.recordCount GT 0) ? qry.getRow(1) : {};
    }

    /**
     * Insert a new variant type.
     */
    public numeric function insertVariantType(
        required string  code,
        required string  description,
        string  audience       = "",
        string  outputFormat   = "jpg",
        numeric widthPx        = 0,
        numeric heightPx       = 0,
        string  mode            = "resize_only",
        boolean isActive        = true
    ) {
        var qry = executeQueryWithRetry(
            "
            INSERT INTO ImageVariantTypes
                (Code, Description, Audience, OutputFormat, WidthPx, HeightPx,
                 Mode, IsActive)
            VALUES
                (:code, :description, :audience, :outputFormat, :widthPx, :heightPx,
                 :mode, :isActive);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            {
                code            = { value=arguments.code,            cfsqltype="cf_sql_nvarchar" },
                description     = { value=arguments.description,     cfsqltype="cf_sql_nvarchar" },
                audience        = { value=arguments.audience,        cfsqltype="cf_sql_nvarchar" },
                outputFormat    = { value=arguments.outputFormat,     cfsqltype="cf_sql_nvarchar" },
                widthPx         = { value=arguments.widthPx GT 0 ? arguments.widthPx : javaCast("null",""), cfsqltype="cf_sql_integer", null=(arguments.widthPx LTE 0) },
                heightPx        = { value=arguments.heightPx GT 0 ? arguments.heightPx : javaCast("null",""), cfsqltype="cf_sql_integer", null=(arguments.heightPx LTE 0) },
                mode            = { value=arguments.mode,            cfsqltype="cf_sql_nvarchar" },
                isActive        = { value=arguments.isActive,        cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.newID);
    }

    /**
     * Update an existing variant type.
     */
    public void function updateVariantType(
        required numeric imageVariantTypeID,
        required string  code,
        required string  description,
        string  audience       = "",
        string  outputFormat   = "jpg",
        numeric widthPx        = 0,
        numeric heightPx       = 0,
        string  mode            = "resize_only",
        boolean isActive        = true
    ) {
        executeQueryWithRetry(
            "
            UPDATE ImageVariantTypes
            SET    Code            = :code,
                   Description     = :description,
                   Audience        = :audience,
                   OutputFormat    = :outputFormat,
                   WidthPx         = :widthPx,
                   HeightPx        = :heightPx,
                   Mode            = :mode,
                   IsActive        = :isActive
            WHERE  ImageVariantTypeID = :id
            ",
            {
                id              = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" },
                code            = { value=arguments.code,              cfsqltype="cf_sql_nvarchar" },
                description     = { value=arguments.description,       cfsqltype="cf_sql_nvarchar" },
                audience        = { value=arguments.audience,          cfsqltype="cf_sql_nvarchar" },
                outputFormat    = { value=arguments.outputFormat,       cfsqltype="cf_sql_nvarchar" },
                widthPx         = { value=arguments.widthPx GT 0 ? arguments.widthPx : javaCast("null",""), cfsqltype="cf_sql_integer", null=(arguments.widthPx LTE 0) },
                heightPx        = { value=arguments.heightPx GT 0 ? arguments.heightPx : javaCast("null",""), cfsqltype="cf_sql_integer", null=(arguments.heightPx LTE 0) },
                mode            = { value=arguments.mode,            cfsqltype="cf_sql_nvarchar" },
                isActive        = { value=arguments.isActive,        cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Soft-delete a variant type (set IsActive = 0).
     */
    public void function deactivateVariantType( required numeric imageVariantTypeID ) {
        executeQueryWithRetry(
            "UPDATE ImageVariantTypes SET IsActive = 0 WHERE ImageVariantTypeID = :id",
            { id = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Hard-delete a variant type.
     * Caller must remove dependent UserImageVariants and published images first.
     */
    public void function deleteVariantType( required numeric imageVariantTypeID ) {
        executeQueryWithRetry(
            "DELETE FROM ImageVariantTypes WHERE ImageVariantTypeID = :id",
            { id = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Return all UserImageVariant records for a given variant type (across all users).
     * Used by cascade-delete to clean up temp files before removing the type.
     */
    public array function getVariantsByTypeID( required numeric imageVariantTypeID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT uiv.UserImageVariantID, uiv.LocalPath,
                   uis.UserID
            FROM   UserImageVariants uiv
            JOIN   UserImageSources  uis ON uis.UserImageSourceID = uiv.UserImageSourceID
            WHERE  uiv.ImageVariantTypeID = :typeID
            ",
            { typeID = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
        return queryToArray(qry);
    }

    /**
     * Delete all UserImageVariants rows for a given ImageVariantTypeID.
     */
    public void function deleteVariantsByTypeID( required numeric imageVariantTypeID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImageVariants WHERE ImageVariantTypeID = :typeID",
            { typeID = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }


    // ── UserImageVariants ──────────────────────────────────────────────────

    /**
     * Return all variant records for a user, enriched with type and source data.
     * Joins through UserImageSources to filter by UserID.
     * When sourceID is provided, further filters to variants for that source only.
     * Note: UserImageVariants has no UserID column — user is identified via the source.
     */
    public array function getVariantsForUser(
        required numeric userID,
        numeric sourceID = 0
    ) {
        var sql = "
            SELECT uiv.UserImageVariantID,
                   uiv.UserImageSourceID,
                   uiv.ImageVariantTypeID,
                   uiv.LocalPath,
                   uiv.FileSizeBytes,
                   uiv.GeneratedAt,
                   uiv.Status,
                   uiv.ErrorMessage,
                   ivt.Code,
                   ivt.Description,
                   ivt.Audience,
                   ivt.Mode,
                   ivt.OutputFormat,
                   ivt.WidthPx,
                   ivt.HeightPx,
                   uis.SourceKey,
                   uis.DropboxPath,
                   uiv.FrameOffsetX,
                   uiv.FrameOffsetY
            FROM   UserImageVariants  uiv
            JOIN   ImageVariantTypes  ivt ON ivt.ImageVariantTypeID = uiv.ImageVariantTypeID
            JOIN   UserImageSources   uis ON uis.UserImageSourceID  = uiv.UserImageSourceID
            WHERE  uis.UserID = :userID
        ";

        var params = { userID = { value=arguments.userID, cfsqltype="cf_sql_integer" } };

        if ( arguments.sourceID GT 0 ) {
            sql &= " AND uiv.UserImageSourceID = :sourceID";
            params.sourceID = { value=arguments.sourceID, cfsqltype="cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            sql, params,
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    /**
     * Return counts of generated variants that are not yet published, grouped by user.
     * A variant is considered generated when LocalPath is non-empty.
     * It is considered unpublished when there is no matching UserImages row for
     * the same source + variant code.
     */
    public array function getGeneratedUnpublishedVariantCountsByUser() {
        var qry = executeQueryWithRetry(
            "
            SELECT uis.UserID,
                   COUNT(*) AS GeneratedUnpublishedCount
            FROM   UserImageVariants uiv
            JOIN   UserImageSources uis
                   ON uis.UserImageSourceID = uiv.UserImageSourceID
            JOIN   ImageVariantTypes ivt
                   ON ivt.ImageVariantTypeID = uiv.ImageVariantTypeID
            LEFT JOIN UserImages ui
                   ON ui.UserImageSourceID = uiv.UserImageSourceID
                  AND UPPER(ui.ImageVariant) = UPPER(ivt.Code)
            WHERE  uis.IsActive = 1
              AND  LTRIM(RTRIM(ISNULL(uiv.LocalPath, ''))) <> ''
              AND  ui.ImageID IS NULL
            GROUP BY uis.UserID
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    /**
     * Return a single variant record for a source + ImageVariantTypeID.
     * Returns an empty struct when not found.
     */
    public struct function getVariantBySourceAndType(
        required numeric userImageSourceID,
        required numeric imageVariantTypeID
    ) {
        var qry = executeQueryWithRetry(
            "
            SELECT uiv.*
            FROM   UserImageVariants uiv
            WHERE  uiv.UserImageSourceID  = :sourceID
            AND    uiv.ImageVariantTypeID = :typeID
            ",
            {
                sourceID = { value=arguments.userImageSourceID,  cfsqltype="cf_sql_integer" },
                typeID   = { value=arguments.imageVariantTypeID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );
        return (qry.recordCount GT 0) ? qry.getRow(1) : {};
    }

    /**
     * Ensure a variant record exists for a source + type combination.
     *
     * Keyed on (UserImageSourceID, ImageVariantTypeID) — each source can
     * have its own independent set of variant records.
     * INSERT on first assignment; UPDATE (reset to stale) on reassignment.
     *
     * LocalPath defaults to '' on INSERT — the column is NOT NULL; it is
     * populated by updateVariantGenerated() after successful generation.
     */
    public void function upsertVariantAssignment(
        required numeric userImageSourceID,
        required numeric imageVariantTypeID
    ) {
        executeQueryWithRetry(
            "
            IF EXISTS (
                SELECT 1
                FROM   UserImageVariants
                WHERE  UserImageSourceID  = :sourceID
                AND    ImageVariantTypeID = :typeID
            )
                UPDATE UserImageVariants
                SET    Status       = 'stale',
                       ErrorMessage = NULL
                WHERE  UserImageSourceID  = :sourceID
                AND    ImageVariantTypeID = :typeID
            ELSE
                INSERT INTO UserImageVariants
                    (UserImageSourceID, ImageVariantTypeID, LocalPath, Status)
                VALUES
                    (:sourceID, :typeID, '', 'stale')
            ",
            {
                typeID   = { value=arguments.imageVariantTypeID,  cfsqltype="cf_sql_integer" },
                sourceID = { value=arguments.userImageSourceID,   cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Return all variant records for a given UserImageSourceID that have a LocalPath set.
     * Used before deletion so the caller can remove temp variant files from disk first.
     */
    public array function getVariantsBySourceID( required numeric sourceID ) {
        var qry = executeQueryWithRetry(
            "SELECT UserImageVariantID, LocalPath FROM UserImageVariants WHERE UserImageSourceID = :srcID AND LTRIM(RTRIM(ISNULL(LocalPath, ''))) <> ''",
            { srcID = { value=arguments.sourceID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    /**
     * Delete all UserImageVariants rows that reference a given UserImageSourceID.
     *
     * Called by UserImageSourceService BEFORE the source record is deleted, so
     * the FK constraint (FK_UserImageVariants_Sources) is satisfied.  Variant
     * records derived from the deleted source cannot be reproduced without a
     * new source, so deletion is the correct disposition.
     */
    public void function deleteVariantsBySourceID( required numeric sourceID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImageVariants WHERE UserImageSourceID = :sourceID",
            { sourceID = { value = arguments.sourceID, cfsqltype = "cf_sql_integer" } },
            { datasource = variables.datasource, timeout = 30 }
        );
    }

    /**
     * Delete one variant assignment by source + type.
     */
    public void function deleteVariantBySourceAndType(
        required numeric userImageSourceID,
        required numeric imageVariantTypeID
    ) {
        executeQueryWithRetry(
            "
            DELETE FROM UserImageVariants
            WHERE UserImageSourceID = :sourceID
              AND ImageVariantTypeID = :typeID
            ",
            {
                sourceID = { value = arguments.userImageSourceID, cfsqltype = "cf_sql_integer" },
                typeID   = { value = arguments.imageVariantTypeID, cfsqltype = "cf_sql_integer" }
            },
            { datasource = variables.datasource, timeout = 30 }
        );
    }

    /**
     * Mark a variant as successfully generated.
     * Sets Status = 'current', records the output path and timestamp.
     */
    public void function updateVariantGenerated(
        required numeric userImageVariantID,
        required string  localPath
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserImageVariants
            SET    Status       = 'current',
                   LocalPath    = :localPath,
                   ErrorMessage = NULL,
                   GeneratedAt  = GETDATE()
            WHERE  UserImageVariantID = :id
            ",
            {
                id        = { value=arguments.userImageVariantID, cfsqltype="cf_sql_integer" },
                localPath = { value=arguments.localPath,          cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Mark a variant as failed.
     * Sets Status = 'error' and records the error message for display.
     */
    public void function updateVariantError(
        required numeric userImageVariantID,
        required string  errorMessage
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserImageVariants
            SET    Status       = 'error',
                   ErrorMessage = :errorMessage
            WHERE  UserImageVariantID = :id
            ",
            {
                id           = { value=arguments.userImageVariantID,      cfsqltype="cf_sql_integer" },
                errorMessage = { value=left(arguments.errorMessage, 500),  cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Persist framing metadata for a variant record.
     *
     * Framing stores only the admin's positional bias, not an arbitrary crop
     * rectangle.  Offsets are normalized server-side to the range -100..100.
     */
    public void function saveFrameMetadata(
        required numeric userImageVariantID,
        required numeric frameOffsetX,
        required numeric frameOffsetY
    ) {
        executeQueryWithRetry(
            "
            UPDATE UserImageVariants
            SET    FrameOffsetX = :frameOffsetX,
                   FrameOffsetY = :frameOffsetY
            WHERE  UserImageVariantID = :id
            ",
            {
                id           = { value=arguments.userImageVariantID, cfsqltype="cf_sql_integer" },
                frameOffsetX = { value=arguments.frameOffsetX,       cfsqltype="cf_sql_decimal" },
                frameOffsetY = { value=arguments.frameOffsetY,       cfsqltype="cf_sql_decimal" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Clear LocalPath after a variant has been published and the temp file removed.
     * Status stays 'current' — the image was successfully generated.
     */
    public void function clearLocalPath( required numeric userImageVariantID ) {
        executeQueryWithRetry(
            "
            UPDATE UserImageVariants
            SET    LocalPath = ''
            WHERE  UserImageVariantID = :id
            ",
            { id = { value=arguments.userImageVariantID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
