component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getImages( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserImages WHERE UserID = :id ORDER BY SortOrder",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    /**
     * Return a struct keyed by UserID whose value is the WEB_THUMB ImageURL.
     * Only the first WEB_THUMB per user (by SortOrder) is returned.
     */
    public struct function getWebThumbMap() {
        var qry = executeQueryWithRetry(
            "SELECT UserID, ImageURL
             FROM (
                 SELECT UserID, ImageURL,
                        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY SortOrder) AS rn
                 FROM   UserImages
                 WHERE  ImageVariant = 'WEB_THUMB'
             ) t
             WHERE t.rn = 1",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
        var result = {};
        for (var row in qry) {
            result[ toString(row.USERID) ] = row.IMAGEURL;
        }
        return result;
    }

    public numeric function addImage( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserImages (UserID, ImageVariant, ImageURL, ImageDescription, SortOrder)
            VALUES (:UserID, :ImageVariant, :ImageURL, :ImageDescription, :SortOrder);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    /**
     * Insert a published image record.
     *
     * Multiple images per UserID + ImageVariant are allowed (one per source).
     * If a row already exists for the same user + variant + source, update it;
     * otherwise insert a new row.
     */
    public void function upsertPublishedImage(
        required numeric userID,
        required string  imageVariant,
        required string  imageURL,
        required string  imageDescription,
        string  imageDimensions    = "",
        numeric sortOrder          = 0,
        numeric userImageSourceID  = 0
    ) {
        if ( arguments.userImageSourceID GT 0 ) {
            executeQueryWithRetry(
                "
                IF EXISTS (
                    SELECT 1 FROM UserImages
                    WHERE  UserID = :userID AND ImageVariant = :imageVariant
                    AND    UserImageSourceID = :sourceID
                )
                    UPDATE UserImages
                    SET    ImageURL         = :imageURL,
                           ImageDescription = :imageDescription,
                           ImageDimensions  = :imageDimensions,
                           SortOrder        = :sortOrder,
                           PublishedAt      = GETDATE()
                    WHERE  UserID = :userID AND ImageVariant = :imageVariant
                    AND    UserImageSourceID = :sourceID
                ELSE
                    INSERT INTO UserImages (UserID, ImageVariant, ImageURL, ImageDescription, ImageDimensions, SortOrder, UserImageSourceID, PublishedAt)
                    VALUES (:userID, :imageVariant, :imageURL, :imageDescription, :imageDimensions, :sortOrder, :sourceID, GETDATE())
                ",
                {
                    userID           = { value=arguments.userID,              cfsqltype="cf_sql_integer" },
                    imageVariant     = { value=arguments.imageVariant,        cfsqltype="cf_sql_varchar" },
                    imageURL         = { value=arguments.imageURL,            cfsqltype="cf_sql_varchar" },
                    imageDescription = { value=arguments.imageDescription,    cfsqltype="cf_sql_varchar" },
                    imageDimensions  = { value=arguments.imageDimensions,     cfsqltype="cf_sql_varchar" },
                    sortOrder        = { value=arguments.sortOrder,           cfsqltype="cf_sql_integer" },
                    sourceID         = { value=arguments.userImageSourceID,   cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        } else {
            // Legacy path: no sourceID — upsert by user+variant only
            executeQueryWithRetry(
                "
                IF EXISTS (
                    SELECT 1 FROM UserImages
                    WHERE  UserID = :userID AND ImageVariant = :imageVariant
                )
                    UPDATE UserImages
                    SET    ImageURL         = :imageURL,
                           ImageDescription = :imageDescription,
                           ImageDimensions  = :imageDimensions,
                           SortOrder        = :sortOrder,
                           PublishedAt      = GETDATE()
                    WHERE  UserID = :userID AND ImageVariant = :imageVariant
                ELSE
                    INSERT INTO UserImages (UserID, ImageVariant, ImageURL, ImageDescription, ImageDimensions, SortOrder, PublishedAt)
                    VALUES (:userID, :imageVariant, :imageURL, :imageDescription, :imageDimensions, :sortOrder, GETDATE())
                ",
                {
                    userID           = { value=arguments.userID,           cfsqltype="cf_sql_integer" },
                    imageVariant     = { value=arguments.imageVariant,     cfsqltype="cf_sql_varchar" },
                    imageURL         = { value=arguments.imageURL,         cfsqltype="cf_sql_varchar" },
                    imageDescription = { value=arguments.imageDescription, cfsqltype="cf_sql_varchar" },
                    imageDimensions  = { value=arguments.imageDimensions,  cfsqltype="cf_sql_varchar" },
                    sortOrder        = { value=arguments.sortOrder,        cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    /**
     * Remove published image by UserID + ImageVariant code.
     */
    public void function deleteByUserAndVariant(
        required numeric userID,
        required string  imageVariant
    ) {
        executeQueryWithRetry(
            "DELETE FROM UserImages WHERE UserID = :userID AND ImageVariant = :imageVariant",
            {
                userID       = { value=arguments.userID,       cfsqltype="cf_sql_integer" },
                imageVariant = { value=arguments.imageVariant,  cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Return one published image row for user + variant + source.
     * Returns an empty struct when not found.
     */
    public struct function getPublishedImageByUserVariantAndSource(
        required numeric userID,
        required string imageVariant,
        required numeric userImageSourceID
    ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 ImageID, UserID, ImageVariant, ImageURL, UserImageSourceID
            FROM UserImages
            WHERE UserID = :userID
              AND UPPER(ImageVariant) = UPPER(:imageVariant)
              AND UserImageSourceID = :sourceID
            ORDER BY ImageID DESC
            ",
            {
                userID       = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                imageVariant = { value=arguments.imageVariant, cfsqltype="cf_sql_varchar" },
                sourceID     = { value=arguments.userImageSourceID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return (qry.recordCount GT 0) ? qry.getRow(1) : {};
    }

    /**
     * Delete one published image row by user + variant + source.
     */
    public void function deleteByUserVariantAndSource(
        required numeric userID,
        required string imageVariant,
        required numeric userImageSourceID
    ) {
        executeQueryWithRetry(
            "
            DELETE FROM UserImages
            WHERE UserID = :userID
              AND UPPER(ImageVariant) = UPPER(:imageVariant)
              AND UserImageSourceID = :sourceID
            ",
            {
                userID       = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                imageVariant = { value=arguments.imageVariant, cfsqltype="cf_sql_varchar" },
                sourceID     = { value=arguments.userImageSourceID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function removeImage( required numeric imageID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImages WHERE ImageID = :id",
            { id={ value=imageID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Return all published image records for a given ImageVariant code (across all users).
     * Used by cascade-delete to identify files that need cleanup.
     */
    public array function getImagesByVariantCode( required string imageVariant ) {
        var qry = executeQueryWithRetry(
            "SELECT ImageID, UserID, ImageVariant, ImageURL FROM UserImages WHERE ImageVariant = :code",
            { code = { value=arguments.imageVariant, cfsqltype="cf_sql_varchar" } },
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
        return queryToArray(qry);
    }

    /**
     * Return all published image records (across all users).
     * Used by User Media "View Published" mode.
     */
    public array function getPublishedImages() {
        var qry = executeQueryWithRetry(
            "
            SELECT ImageID,
                   UserID,
                   ImageVariant,
                   ImageURL,
                   ImageDescription,
                   ImageDimensions,
                   SortOrder,
                   UserImageSourceID,
                   PublishedAt
            FROM UserImages
            ORDER BY PublishedAt DESC, UserID ASC, ImageVariant ASC, SortOrder ASC
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    public array function getPublishedVariantList() {
        var qry = executeQueryWithRetry(
            "
            SELECT DISTINCT ImageVariant
            FROM UserImages
            WHERE LTRIM(RTRIM(ISNULL(ImageVariant, ''))) <> ''
            ORDER BY ImageVariant
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );

        return queryToArray(qry);
    }

    public numeric function getPublishedUserSummaryCount( string searchTerm = "", string variantFilter = "" ) {
        var normalizedSearch = trim(arguments.searchTerm ?: "");
        var normalizedVariant = trim(arguments.variantFilter ?: "");
        var params = {};
        var whereParts = [
            "EXISTS (SELECT 1 FROM UserImages uiAny WHERE uiAny.UserID = u.UserID)"
        ];

        if ( len(normalizedVariant) ) {
            arrayAppend(whereParts, "EXISTS (SELECT 1 FROM UserImages uiVariant WHERE uiVariant.UserID = u.UserID AND UPPER(uiVariant.ImageVariant) = UPPER(:variantFilter))");
            params.variantFilter = { value=normalizedVariant, cfsqltype="cf_sql_varchar" };
        }

        if ( len(normalizedSearch) ) {
            params.searchLike = { value="%" & normalizedSearch & "%", cfsqltype="cf_sql_nvarchar" };
            arrayAppend(whereParts,
                "(
                    CAST(u.UserID AS NVARCHAR(20)) LIKE :searchLike
                    OR COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), u.FirstName, '') LIKE :searchLike
                    OR COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), u.LastName, '') LIKE :searchLike
                    OR ISNULL(u.EmailPrimary, '') LIKE :searchLike
                    OR EXISTS (
                        SELECT 1
                        FROM UserImages uiSearch
                        WHERE uiSearch.UserID = u.UserID
                          AND ISNULL(uiSearch.ImageVariant, '') LIKE :searchLike
                    )
                )"
            );
        }

        var qry = executeQueryWithRetry(
            "
            SELECT COUNT(*) AS TotalUserCount
            FROM Users u
            OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                  AND ua.IsActive = 1
                  AND ISNULL(ua.IsPrimary, 0) = 1
                ORDER BY ISNULL(ua.SortOrder, 999999), ua.AliasID
            ) pa
            WHERE #arrayToList(whereParts, ' AND ')#
            ",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return val(qry.TOTALUSERCOUNT ?: 0);
    }

    public array function getPublishedUserSummaryPage(
        numeric pageSize = 25,
        numeric pageNumber = 1,
        string searchTerm = "",
        string variantFilter = ""
    ) {
        var size = max(1, min(200, int(val(arguments.pageSize ?: 25))));
        var page = max(1, int(val(arguments.pageNumber ?: 1)));
        var normalizedSearch = trim(arguments.searchTerm ?: "");
        var normalizedVariant = trim(arguments.variantFilter ?: "");
        var startRow = ((page - 1) * size) + 1;
        var endRow = startRow + size - 1;
        var params = {
            startRow = { value=startRow, cfsqltype="cf_sql_integer" },
            endRow = { value=endRow, cfsqltype="cf_sql_integer" }
        };
        var whereParts = [
            "EXISTS (SELECT 1 FROM UserImages uiAny WHERE uiAny.UserID = u.UserID)"
        ];

        if ( len(normalizedVariant) ) {
            arrayAppend(whereParts, "EXISTS (SELECT 1 FROM UserImages uiVariant WHERE uiVariant.UserID = u.UserID AND UPPER(uiVariant.ImageVariant) = UPPER(:variantFilter))");
            params.variantFilter = { value=normalizedVariant, cfsqltype="cf_sql_varchar" };
        }

        if ( len(normalizedSearch) ) {
            params.searchLike = { value="%" & normalizedSearch & "%", cfsqltype="cf_sql_nvarchar" };
            arrayAppend(whereParts,
                "(
                    CAST(u.UserID AS NVARCHAR(20)) LIKE :searchLike
                    OR COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), u.FirstName, '') LIKE :searchLike
                    OR COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), u.LastName, '') LIKE :searchLike
                    OR ISNULL(u.EmailPrimary, '') LIKE :searchLike
                    OR EXISTS (
                        SELECT 1
                        FROM UserImages uiSearch
                        WHERE uiSearch.UserID = u.UserID
                          AND ISNULL(uiSearch.ImageVariant, '') LIKE :searchLike
                    )
                )"
            );
        }

        var qry = executeQueryWithRetry(
            "
            WITH FilteredUsers AS (
                SELECT
                    u.UserID,
                    COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), u.FirstName, '') AS FirstName,
                    COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), u.LastName, '') AS LastName,
                    ISNULL(u.EmailPrimary, '') AS EmailPrimary
                FROM Users u
                OUTER APPLY (
                    SELECT TOP 1 ua.FirstName, ua.LastName
                    FROM UserAliases ua
                    WHERE ua.UserID = u.UserID
                      AND ua.IsActive = 1
                      AND ISNULL(ua.IsPrimary, 0) = 1
                    ORDER BY ISNULL(ua.SortOrder, 999999), ua.AliasID
                ) pa
                WHERE #arrayToList(whereParts, ' AND ')#
            ),
            UserAggregates AS (
                SELECT
                    fu.UserID,
                    fu.FirstName,
                    fu.LastName,
                    fu.EmailPrimary,
                    COUNT(ui.ImageID) AS TotalPublished,
                    MAX(ui.PublishedAt) AS LatestPublishedAt,
                    ROW_NUMBER() OVER (
                        ORDER BY fu.LastName, fu.FirstName, fu.UserID
                    ) AS RowNum
                FROM FilteredUsers fu
                INNER JOIN UserImages ui
                    ON ui.UserID = fu.UserID
                GROUP BY fu.UserID, fu.FirstName, fu.LastName, fu.EmailPrimary
            )
            SELECT
                ua.UserID,
                ua.FirstName,
                ua.LastName,
                ua.EmailPrimary,
                ua.TotalPublished,
                ua.LatestPublishedAt,
                thumb.ImageURL AS WebThumbURL,
                profile.ImageURL AS WebProfileURL,
                legacy.ImageURL AS LegacyAlumniURL
            FROM UserAggregates ua
            OUTER APPLY (
                SELECT TOP 1 uiThumb.ImageURL
                FROM UserImages uiThumb
                WHERE uiThumb.UserID = ua.UserID
                  AND UPPER(uiThumb.ImageVariant) = 'WEB_THUMB'
                ORDER BY ISNULL(uiThumb.PublishedAt, '1900-01-01') DESC, uiThumb.SortOrder ASC, uiThumb.ImageID DESC
            ) thumb
            OUTER APPLY (
                SELECT TOP 1 uiProfile.ImageURL
                FROM UserImages uiProfile
                WHERE uiProfile.UserID = ua.UserID
                  AND UPPER(uiProfile.ImageVariant) = 'WEB_PROFILE'
                ORDER BY ISNULL(uiProfile.PublishedAt, '1900-01-01') DESC, uiProfile.SortOrder ASC, uiProfile.ImageID DESC
            ) profile
            OUTER APPLY (
                SELECT TOP 1 uiLegacy.ImageURL
                FROM UserImages uiLegacy
                WHERE uiLegacy.UserID = ua.UserID
                  AND UPPER(uiLegacy.ImageVariant) = 'LEGACY_ALUMNI'
                ORDER BY ISNULL(uiLegacy.PublishedAt, '1900-01-01') DESC, uiLegacy.SortOrder ASC, uiLegacy.ImageID DESC
            ) legacy
            WHERE ua.RowNum BETWEEN :startRow AND :endRow
            ORDER BY ua.RowNum
            ",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=size }
        );

        return queryToArray(qry);
    }

    /**
     * Return published image counts grouped by user.
     */
    public array function getPublishedImageCountsByUser() {
        var qry = executeQueryWithRetry(
            "
            SELECT UserID,
                   COUNT(*) AS PublishedCount
            FROM UserImages
            GROUP BY UserID
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    public numeric function getPublishedImageTotalCount() {
        var qry = executeQueryWithRetry(
            "
            SELECT COUNT(*) AS TotalPublishedCount
            FROM UserImages
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return val(qry.TOTALPUBLISHEDCOUNT ?: 0);
    }

    public numeric function getNeedsPublishingUserCount() {
        var qry = executeQueryWithRetry(
            "
            WITH ActiveSourceCounts AS (
                SELECT uis.UserID,
                       COUNT(*) AS ActiveSourceCount
                FROM UserImageSources uis
                WHERE uis.IsActive = 1
                GROUP BY uis.UserID
            ),
            PublishedCounts AS (
                SELECT ui.UserID,
                       COUNT(*) AS PublishedCount
                FROM UserImages ui
                GROUP BY ui.UserID
            ),
            GeneratedUnpublishedCounts AS (
                SELECT uis.UserID,
                       COUNT(*) AS GeneratedUnpublishedCount
                FROM UserImageVariants uiv
                INNER JOIN UserImageSources uis
                    ON uis.UserImageSourceID = uiv.UserImageSourceID
                INNER JOIN ImageVariantTypes ivt
                    ON ivt.ImageVariantTypeID = uiv.ImageVariantTypeID
                LEFT JOIN UserImages ui
                    ON ui.UserImageSourceID = uiv.UserImageSourceID
                   AND UPPER(ui.ImageVariant) = UPPER(ivt.Code)
                WHERE uis.IsActive = 1
                  AND LTRIM(RTRIM(ISNULL(uiv.LocalPath, ''))) <> ''
                  AND ui.ImageID IS NULL
                GROUP BY uis.UserID
            )
            SELECT COUNT(*) AS NeedsPublishingUserCount
            FROM Users u
            LEFT JOIN ActiveSourceCounts ascnt
                ON ascnt.UserID = u.UserID
            LEFT JOIN PublishedCounts pcnt
                ON pcnt.UserID = u.UserID
            LEFT JOIN GeneratedUnpublishedCounts gucnt
                ON gucnt.UserID = u.UserID
            WHERE (
                ISNULL(ascnt.ActiveSourceCount, 0) > 0
                AND ISNULL(pcnt.PublishedCount, 0) = 0
            )
               OR ISNULL(gucnt.GeneratedUnpublishedCount, 0) > 0
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return val(qry.NEEDSPUBLISHINGUSERCOUNT ?: 0);
    }

    public array function getNeedsPublishingQueue() {
        var qry = executeQueryWithRetry(
            "
            WITH ActiveSourceCounts AS (
                SELECT uis.UserID,
                       COUNT(*) AS ActiveSourceCount
                FROM UserImageSources uis
                WHERE uis.IsActive = 1
                GROUP BY uis.UserID
            ),
            PublishedCounts AS (
                SELECT ui.UserID,
                       COUNT(*) AS PublishedCount
                FROM UserImages ui
                GROUP BY ui.UserID
            ),
            GeneratedUnpublishedCounts AS (
                SELECT uis.UserID,
                       COUNT(*) AS GeneratedUnpublishedCount
                FROM UserImageVariants uiv
                INNER JOIN UserImageSources uis
                    ON uis.UserImageSourceID = uiv.UserImageSourceID
                INNER JOIN ImageVariantTypes ivt
                    ON ivt.ImageVariantTypeID = uiv.ImageVariantTypeID
                LEFT JOIN UserImages ui
                    ON ui.UserImageSourceID = uiv.UserImageSourceID
                   AND UPPER(ui.ImageVariant) = UPPER(ivt.Code)
                WHERE uis.IsActive = 1
                  AND LTRIM(RTRIM(ISNULL(uiv.LocalPath, ''))) <> ''
                  AND ui.ImageID IS NULL
                GROUP BY uis.UserID
            )
            SELECT
                u.UserID,
                COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), u.FirstName, '') AS FirstName,
                COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), u.LastName, '') AS LastName,
                ISNULL(u.EmailPrimary, '') AS EmailPrimary,
                ISNULL(ascnt.ActiveSourceCount, 0) AS ActiveSourceCount,
                ISNULL(pcnt.PublishedCount, 0) AS PublishedImageCount,
                ISNULL(gucnt.GeneratedUnpublishedCount, 0) AS GeneratedUnpublishedCount,
                CASE WHEN ISNULL(ascnt.ActiveSourceCount, 0) > 0 AND ISNULL(pcnt.PublishedCount, 0) = 0 THEN 1 ELSE 0 END AS NoPublishedWithSources,
                CASE WHEN ISNULL(gucnt.GeneratedUnpublishedCount, 0) > 0 THEN 1 ELSE 0 END AS HasGeneratedUnpublished
            FROM Users u
            OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                  AND ua.IsActive = 1
                  AND ISNULL(ua.IsPrimary, 0) = 1
                ORDER BY ISNULL(ua.SortOrder, 999999), ua.AliasID
            ) pa
            LEFT JOIN ActiveSourceCounts ascnt
                ON ascnt.UserID = u.UserID
            LEFT JOIN PublishedCounts pcnt
                ON pcnt.UserID = u.UserID
            LEFT JOIN GeneratedUnpublishedCounts gucnt
                ON gucnt.UserID = u.UserID
            WHERE (
                ISNULL(ascnt.ActiveSourceCount, 0) > 0
                AND ISNULL(pcnt.PublishedCount, 0) = 0
            )
               OR ISNULL(gucnt.GeneratedUnpublishedCount, 0) > 0
            ORDER BY
                COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), u.LastName, ''),
                COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), u.FirstName, ''),
                u.UserID
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );

        return queryToArray(qry);
    }

    /**
     * Delete all published image records for a given ImageVariant code (across all users).
     */
    public void function deleteByVariantCode( required string imageVariant ) {
        executeQueryWithRetry(
            "DELETE FROM UserImages WHERE ImageVariant = :code",
            { code = { value=arguments.imageVariant, cfsqltype="cf_sql_varchar" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /**
     * Return all published image records for a given UserImageSourceID.
     * Used before deletion so callers can remove the physical files first.
     */
    public array function getImagesBySourceID( required numeric sourceID ) {
        var qry = executeQueryWithRetry(
            "SELECT ImageID, UserID, ImageVariant, ImageURL FROM UserImages WHERE UserImageSourceID = :srcID",
            { srcID = { value=arguments.sourceID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    /**
     * Delete all published image records that reference a given UserImageSourceID.
     * Called during source deletion to satisfy the FK constraint.
     */
    public void function deleteBySourceID( required numeric sourceID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImages WHERE UserImageSourceID = :srcID",
            { srcID = { value=arguments.sourceID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}