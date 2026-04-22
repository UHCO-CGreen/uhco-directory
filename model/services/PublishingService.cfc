/**
 * PublishingService.cfc
 *
 * Publishes generated variant images to the production image location
 * and records them in the UserImages table.
 *
 * ── Publishing swap point ──────────────────────────────────────────────────
 *
 *   All file-copy logic is in _copyToPublished().  To switch from local
 *   filesystem to AWS S3 or another cloud provider:
 *     1. Replace _copyToPublished() with an S3 PUT call.
 *     2. Update _buildPublishedUrl() to return the S3/CDN URL.
 *     3. No DAO or page changes required.
 *
 * ── Temp cleanup ───────────────────────────────────────────────────────────
 *
 *   After a successful publish the temp variant file is deleted and the
 *   variant record's LocalPath is cleared.  The image can be regenerated
 *   at any time via the crop → generate workflow.
 *
 * ───────────────────────────────────────────────────────────────────────────
 */
component output="false" singleton {

    // PUBLISHING SWAP POINT: change these when moving to S3/CDN.
    variables.publishedWebDir  = "/_published_images/";


    public any function init() {
        variables.ImagesDAO    = createObject("component", "dao.images_DAO").init();
        variables.VariantDAO   = createObject("component", "dao.UserImageVariantDAO").init();
        variables.UsersService = createObject("component", "cfc.users_service").init();
        variables.VariantService = createObject("component", "cfc.UserImageVariantService").init();
        variables.MediaConfigService = createObject("component", "cfc.mediaConfig_service").init();

        var cfc_dir = getDirectoryFromPath( getCurrentTemplatePath() );
        var rawPublished = cfc_dir & "..\..\_published_images";
        var rawVariants  = cfc_dir & "..\..\_temp_variants";

        var jFile = createObject("java", "java.io.File");
        variables.publishedDirAbsolute = jFile.init(rawPublished).getCanonicalPath() & "\";
        variables.variantDirAbsolute   = jFile.init(rawVariants).getCanonicalPath() & "\";

        return this;
    }


    /**
     * Publish all current variants for a user.
     *
     * Only variants with status = 'current' and a non-empty LocalPath
     * are eligible.  Returns a struct with overall success and per-variant
     * results so the admin can see exactly what happened.
     */
    public struct function publishAllVariants(
        required numeric userID,
        numeric userImageSourceID = 0
    ) {
        var userResult = variables.UsersService.getUser( arguments.userID );
        if ( !userResult.success ) {
            return { success=false, message="User not found.", results=[] };
        }
        var user = userResult.data;

        var matrix = variables.VariantService.getVariantMatrix(
            arguments.userID,
            arguments.userImageSourceID
        );

        var publishable = [];
        for ( var v in matrix ) {
            if ( lCase(v.STATUS ?: "") EQ "current" AND len(v.LOCALPATH ?: "") ) {
                arrayAppend(publishable, v);
            }
        }

        if ( arrayLen(publishable) EQ 0 ) {
            return {
                success = false,
                message = "No current variants available to publish. Generate all variants first.",
                results = []
            };
        }

        // Ensure the published directory exists.
        var dirCheck = _ensurePublishedDir();
        if ( !dirCheck.success ) { return { success=false, message=dirCheck.message, results=[] }; }

        var results      = [];
        var allSucceeded = true;

        for ( var v in publishable ) {
            var singleResult = _publishSingleVariant( user, v, arguments.userImageSourceID );
            arrayAppend(results, singleResult);
            if ( !singleResult.success ) {
                allSucceeded = false;
            }
        }

        var publishedCount = 0;
        for ( var r in results ) {
            if ( r.success ) { publishedCount++; }
        }

        return {
            success = allSucceeded,
            message = allSucceeded
                ? "All #publishedCount# variant(s) published successfully."
                : "#publishedCount# of #arrayLen(results)# variant(s) published. Some failed — see details.",
            results = results
        };
    }


    // ── Private ───────────────────────────────────────────────────────────

    /**
     * Ensure the published directory exists. Returns a struct with success/message.
     */
    private struct function _ensurePublishedDir() {
        if ( !directoryExists(variables.publishedDirAbsolute) ) {
            try {
                directoryCreate(variables.publishedDirAbsolute);
            } catch (any e) {
                return { success=false, message="Could not create published images directory: #e.message#" };
            }
        }
        return { success=true, message="" };
    }


    /**
     * Publish a single variant by userID and imageVariantTypeID.
     *
     * Looks up the user and variant, validates eligibility, copies the
     * file, upserts the DB record, and cleans up the temp file.
     */
    public struct function publishVariant(
        required numeric userID,
        required numeric imageVariantTypeID,
        numeric userImageSourceID = 0
    ) {
        var userResult = variables.UsersService.getUser( arguments.userID );
        if ( !userResult.success ) {
            return { success=false, message="User not found." };
        }
        var user = userResult.data;

        var matrix = variables.VariantService.getVariantMatrix(
            arguments.userID,
            arguments.userImageSourceID
        );
        var variantRow = {};
        for ( var v in matrix ) {
            if ( val(v.IMAGEVARIANTTYPEID ?: 0) EQ arguments.imageVariantTypeID ) {
                variantRow = v;
                break;
            }
        }

        if ( structIsEmpty(variantRow) ) {
            return { success=false, message="Variant type not found in matrix." };
        }
        if ( lCase(variantRow.STATUS ?: "") NEQ "current" OR !len(variantRow.LOCALPATH ?: "") ) {
            return { success=false, message="Variant is not eligible for publishing. Generate it first." };
        }

        var dirCheck = _ensurePublishedDir();
        if ( !dirCheck.success ) { return dirCheck; }

        return _publishSingleVariant( user, variantRow, arguments.userImageSourceID );
    }

    /**
     * Unpublish one variant for a specific user + source.
     * Removes the UserImages row and attempts to delete the published file.
     */
    public struct function unpublishVariant(
        required numeric userID,
        required numeric imageVariantTypeID,
        required numeric userImageSourceID
    ) {
        var variantType = variables.VariantDAO.getVariantTypeByID(arguments.imageVariantTypeID);
        if ( structIsEmpty(variantType) ) {
            return { success=false, message="Unknown variant type." };
        }

        var variantCode = trim(variantType.CODE ?: "");
        var publishedRow = variables.ImagesDAO.getPublishedImageByUserVariantAndSource(
            userID            = arguments.userID,
            imageVariant      = variantCode,
            userImageSourceID = arguments.userImageSourceID
        );

        if ( structIsEmpty(publishedRow) ) {
            return { success=false, message="No published image exists for this variant/source." };
        }

        // Delete DB row first so app state reflects unpublish even if file cleanup fails.
        variables.ImagesDAO.deleteByUserVariantAndSource(
            userID            = arguments.userID,
            imageVariant      = variantCode,
            userImageSourceID = arguments.userImageSourceID
        );

        var fileDeleteResult = _deletePublishedFileByUrl(trim(publishedRow.IMAGEURL ?: ""));
        var baseMessage = "Published image removed for " & variantCode & ".";

        if ( !fileDeleteResult.success ) {
            return {
                success = true,
                message = baseMessage & " (File cleanup note: " & fileDeleteResult.message & ")"
            };
        }

        return { success=true, message=baseMessage };
    }

    /**
     * Publish a single variant.
     *
     * Steps:
     *   1. Build the published filename from user + variant metadata.
     *   2. Copy the temp file to the published directory.
     *   3. Upsert the UserImages record.
     *   4. Delete the temp file and clear the variant's LocalPath.
     */
    private struct function _publishSingleVariant(
        required struct user,
        required struct variantRow,
        numeric userImageSourceID = 0
    ) {
        var variantCode = arguments.variantRow.CODE ?: "";
        var variantDesc = arguments.variantRow.DESCRIPTION ?: "";
        var localPath   = arguments.variantRow.LOCALPATH ?: "";
        var variantID   = val(arguments.variantRow.USERIMAGEVARIANTID ?: 0);
        var userID      = val(arguments.user.USERID ?: 0);
        var sourceID    = val(arguments.userImageSourceID) GT 0
                            ? val(arguments.userImageSourceID)
                            : val(arguments.variantRow.USERIMAGESOURCEID ?: 0);

        try {
            // Resolve absolute path of temp variant file.
            var tempFilename  = listLast(localPath, "/\");
            var tempAbsolute  = variables.variantDirAbsolute & tempFilename;

            if ( !fileExists(tempAbsolute) ) {
                return {
                    success      = false,
                    variantCode  = variantCode,
                    message      = "Temp variant file not found: #tempFilename#"
                };
            }

            // Build the published filename.
            var publishedFilename = _buildPublishedFilename(arguments.user, variantCode, tempFilename, sourceID);
            var publishedAbsolute = variables.publishedDirAbsolute & publishedFilename;
            var publishedUrl      = _buildPublishedUrl(publishedFilename);

            // Build description: "FirstName M. LastName Variant Description Image"
            var description = _buildDescription(arguments.user, variantDesc);

            // Build dimensions string: "800x600", "800xauto", "autox600", etc.
            var widthPx  = val(arguments.variantRow.WIDTHPX  ?: 0);
            var heightPx = val(arguments.variantRow.HEIGHTPX ?: 0);
            var dimensions = (widthPx GT 0 ? widthPx : "auto") & "x" & (heightPx GT 0 ? heightPx : "auto");

            // Step 1: Copy file to published directory.
            _copyToPublished(tempAbsolute, publishedAbsolute);

            // Step 2: Upsert UserImages record.
            variables.ImagesDAO.upsertPublishedImage(
                userID             = userID,
                imageVariant       = variantCode,
                imageURL           = publishedUrl,
                imageDescription   = description,
                imageDimensions    = dimensions,
                userImageSourceID  = sourceID
            );

            // Step 3: Delete temp file and clear variant LocalPath.
            try {
                fileDelete(tempAbsolute);
            } catch (any cleanupErr) {
                // Non-fatal — the publish succeeded even if cleanup fails.
            }

            if ( variantID GT 0 ) {
                variables.VariantDAO.clearLocalPath( variantID );
            }

            return {
                success      = true,
                variantCode  = variantCode,
                message      = "Published: #publishedFilename#",
                publishedUrl = publishedUrl
            };

        } catch (any e) {
            return {
                success      = false,
                variantCode  = variantCode,
                message      = "Failed to publish #variantCode#: #e.message#"
            };
        }
    }


    /**
     * Build the published filename.
     *
     * Convention: [firstinitial]_[middleinitial]_[lastname]_u[userid]_[variant].[ext]
     * All parts are lowercased and non-alphanumeric chars are stripped.
     */
    private string function _buildPublishedFilename(
        required struct user,
        required string variantCode,
        required string tempFilename,
        numeric userImageSourceID = 0
    ) {
        var ext         = lCase(listLast(arguments.tempFilename, "."));

        return variables.MediaConfigService.buildPublishedFilename(
            user              = arguments.user,
            variantCode       = arguments.variantCode,
            extension         = ext,
            userImageSourceID = arguments.userImageSourceID
        );
    }


    /**
     * Build the full published URL.
     * PUBLISHING SWAP POINT: replace with S3/CDN URL construction.
     */
    private string function _buildPublishedUrl( required string filename ) {
        return variables.MediaConfigService.buildPublishedUrl( arguments.filename );
    }


    /**
     * Build the image description.
     * Format: "FirstName M. LastName Variant Description Image"
     */
    private string function _buildDescription(
        required struct user,
        required string variantDescription
    ) {
        var firstName  = trim(arguments.user.FIRSTNAME ?: "");
        var middleName = trim(arguments.user.MIDDLENAME ?: "");
        var lastName   = trim(arguments.user.LASTNAME ?: "");

        var nameParts = [];
        if ( len(firstName) )  { arrayAppend(nameParts, firstName); }
        if ( len(middleName) ) { arrayAppend(nameParts, uCase(left(middleName, 1)) & "."); }
        if ( len(lastName) )   { arrayAppend(nameParts, lastName); }

        var fullName = arrayToList(nameParts, " ");
        var desc     = trim(arguments.variantDescription);

        return trim(fullName & " " & desc & " Image");
    }


    /**
     * Copy the variant file to the published directory.
     * PUBLISHING SWAP POINT: replace with S3 upload.
     */
    private void function _copyToPublished(
        required string sourcePath,
        required string destinationPath
    ) {
        if ( fileExists(arguments.destinationPath) ) {
            fileDelete(arguments.destinationPath);
        }
        fileCopy(arguments.sourcePath, arguments.destinationPath);

        if ( !fileExists(arguments.destinationPath) ) {
            throw(
                type    = "PublishingService.CopyFailed",
                message = "File copy to published directory failed."
            );
        }
    }

    /**
     * Delete a published file by URL, if it maps to the published directory.
     */
    private struct function _deletePublishedFileByUrl( required string imageUrl ) {
        if ( !len(trim(arguments.imageUrl)) ) {
            return { success=false, message="No published URL found." };
        }

        var normalizedUrl = replace(arguments.imageUrl, "\\", "/", "all");
        var fileName = listLast(normalizedUrl, "/");
        if ( !len(fileName) ) {
            return { success=false, message="Unable to resolve published filename." };
        }

        var publishedAbsolute = variables.publishedDirAbsolute & fileName;
        if ( !fileExists(publishedAbsolute) ) {
            return { success=false, message="Published file was already missing." };
        }

        try {
            fileDelete(publishedAbsolute);
            return { success=true, message="File deleted." };
        } catch (any e) {
            return { success=false, message="Failed to delete published file: " & e.message };
        }
    }

}
