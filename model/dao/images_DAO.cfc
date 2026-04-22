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