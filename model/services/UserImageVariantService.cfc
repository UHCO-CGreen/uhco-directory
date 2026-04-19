/**
 * UserImageVariantService.cfc
 *
 * Responsible for: business rules, variant-source validation, and the
 * image-generation abstraction.
 *
 * ╔══════════════════════════════════════════════════════════════════════════
 *   GENERATION SWAP POINT — overview
 *
 *   All image-generation logic is confined to one private method:
 *     _generateVariantImage(variantType, source, outputPath)
 *
 *   The POC implementation copies the source file to the output path
 *   unchanged (no resizing).  To swap in real image processing:
 *     1. Replace _generateVariantImage() with actual resize/convert logic.
 *        Use variantType.OUTPUTWIDTH and variantType.OUTPUTHEIGHT.
 *     2. Change variables.localVariantDir to the desired output location.
 *     3. No DAO changes, no page changes.
 *
 *   When Dropbox becomes a source provider:
 *     - The source file will be fetched via Dropbox API instead of from disk.
 *     - Only _generateVariantImage() and _resolveSourcePath() change.
 *     - Variant records, statuses, and the matrix remain unchanged.
 * ══════════════════════════════════════════════════════════════════════════
 *
 * ── Variant lifecycle ──────────────────────────────────────────────────────
 *
 *   missing  → A VariantType exists but no UserImageVariant record yet.
 *              Admin must assign a source before generating.
 *
 *   stale    → A variant record exists but either:
 *                (a) the source was recently changed/deactivated, or
 *                (b) a source was just assigned for the first time.
 *              Generation is available but NOT automatic.
 *
 *   current  → The variant was generated successfully and the source
 *              has not changed since.  No action required.
 *
 *   error    → The last generation attempt failed.
 *              The error message is stored and displayed.
 *              Re-generation is allowed.
 *
 * ── Why generation is explicit ────────────────────────────────────────────
 *
 *   Variants are deterministic derived assets.  Auto-generation would risk
 *   producing unwanted images when sources change mid-workflow.  Requiring an
 *   explicit admin action ensures every generated variant is intentional and
 *   auditable.
 *
 * ───────────────────────────────────────────────────────────────────────────
 */
component output="false" singleton {

    // ── POC: local output directory ─────────────────────────────────────────
    // GENERATION SWAP POINT: change this path when switching to real storage.
    variables.localVariantDir = "/_temp_variants/";


    public any function init() {
        variables.VariantDAO = createObject("component", "dao.UserImageVariantDAO").init();
        variables.SourceDAO  = createObject("component", "dao.UserImageSourceDAO").init();
        variables.ImageProcessor = createObject("component", "cfc.ImageProcessor");
        variables.ImagesService = createObject("component", "cfc.images_service").init();

        // Compute absolute paths from this CFC's location.
        // expandPath("/...") cannot be used — it resolves against the IIS site
        // root, not the application root.  getCanonicalPath() resolves ".."
        // safely so directoryExists/fileExists never receive dotted paths.
        var cfc_dir = getDirectoryFromPath( getCurrentTemplatePath() );

        var rawSource  = cfc_dir & "..\..\_temp_source";
        var rawVariant = cfc_dir & "..\..\_temp_variants";

        var jFile = createObject("java", "java.io.File");

        variables.localSourceDirAbsolute  = jFile.init(rawSource ).getCanonicalPath() & "\";
        variables.localVariantDirAbsolute = jFile.init(rawVariant).getCanonicalPath() & "\";

        return this;
    }


    // ── Public ────────────────────────────────────────────────────────────

    /**
     * Build the variant matrix for a user.
     *
     * Returns an array of structs — one entry per active ImageVariantType —
     * enriched with the user's current variant state:
     *
     *   {
     *     VARIANTTYPECODE    : string
     *     VARIANTNAME        : string
     *     AUDIENCE           : string
     *     SOURCEKEY          : string   (which source key feeds this type)
     *     OUTPUTWIDTH        : numeric|""
     *     OUTPUTHEIGHT       : numeric|""
     *     DESCRIPTION        : string
     *
     *     // Fields below are empty/false when no variant record exists (missing)
     *     USERIMAGEVARI ANTID : numeric|""
     *     SOURCEID            : numeric|""   (assigned source)
     *     ASSIGNEDSOURCEKEY  : string        (resolved from source record)
     *     LOCALPATH           : string
     *     STATUS              : string       "missing"|"stale"|"current"|"error"
     *     ERRORMESSAGE        : string
     *     GENERATEDAT         : date|""
     *   }
     *
     * The page never needs to inspect variant type configuration separately —
     * everything required to render a row is in this struct.
     */
    public array function getVariantMatrix(
        required numeric userID,
        numeric sourceID = 0
    ) {
        var types    = variables.VariantDAO.getVariantTypesAll();
        var variants = variables.VariantDAO.getVariantsForUser(
            userID   = arguments.userID,
            sourceID = arguments.sourceID
        );
        var publishedImagesResult = variables.ImagesService.getImages( arguments.userID );
        var publishedImages = publishedImagesResult.success ? publishedImagesResult.data : [];

        // Index existing variant records by ImageVariantTypeID for O(1) lookup.
        // SourceKey is already resolved by the DAO's JOIN — no extra lookup needed.
        var variantIndex = {};
        for ( var v in variants ) {
            variantIndex[ v.IMAGEVARIANTTYPEID ] = v;
        }

        var publishedIndex = {};
        for ( var publishedImage in publishedImages ) {
            var publishedSourceID = val( publishedImage.USERIMAGESOURCEID ?: 0 );
            var publishedVariantCode = lCase( trim( publishedImage.IMAGEVARIANT ?: "" ) );

            if ( publishedSourceID GT 0 AND len(publishedVariantCode) ) {
                publishedIndex[ _buildPublishedImageKey(publishedSourceID, publishedVariantCode) ] = publishedImage;
            }
        }

        var matrix = [];

        for ( var t in types ) {
            var key    = t.IMAGEVARIANTTYPEID;
            var row    = structCopy(t);
            var exists = structKeyExists(variantIndex, key);

            if ( exists ) {
                var record = variantIndex[key];
                row.USERIMAGEVARIANTID = record.USERIMAGEVARIANTID;
                row.USERIMAGESOURCEID  = record.USERIMAGESOURCEID;
                row.LOCALPATH          = record.LOCALPATH    ?: "";
                row.STATUS             = lCase( record.STATUS ?: "stale" );
                row.ERRORMESSAGE       = record.ERRORMESSAGE  ?: "";
                row.GENERATEDAT        = record.GENERATEDAT   ?: "";
                // SourceKey is already on the record from the DAO's JOIN.
                row.ASSIGNEDSOURCEKEY  = record.SOURCEKEY     ?: "";
                // Framing metadata stores only positional bias for the fixed frame.
                // Empty string means no explicit offsets have been saved yet.
                row.FRAMEOFFSETX       = record.FRAMEOFFSETX   ?: "";
                row.FRAMEOFFSETY       = record.FRAMEOFFSETY   ?: "";
                row.SOURCEDROPBOXPATH  = record.DROPBOXPATH    ?: "";
            } else {
                row.USERIMAGEVARIANTID = "";
                row.USERIMAGESOURCEID  = "";
                row.ASSIGNEDSOURCEKEY  = "";
                row.LOCALPATH          = "";
                row.STATUS             = "missing";
                row.ERRORMESSAGE       = "";
                row.GENERATEDAT        = "";
                row.FRAMEOFFSETX       = "";
                row.FRAMEOFFSETY       = "";
                row.SOURCEDROPBOXPATH  = "";
            }

            var publishedKey = _buildPublishedImageKey( val(row.USERIMAGESOURCEID ?: 0), lCase(trim(row.CODE ?: "")) );
            var publishedRecord = structKeyExists(publishedIndex, publishedKey) ? publishedIndex[publishedKey] : {};
            var displayState = _resolveDisplayState(row, publishedRecord);

            row.HASPUBLISHEDIMAGE = !structIsEmpty(publishedRecord);
            row.PUBLISHEDIMAGEURL = row.HASPUBLISHEDIMAGE ? (publishedRecord.IMAGEURL ?: "") : "";
            row.PUBLISHEDAT       = row.HASPUBLISHEDIMAGE ? (publishedRecord.PUBLISHEDAT ?: "") : "";
            row.DISPLAYSTATUS     = displayState.code;
            row.DISPLAYSTATUSLABEL = displayState.label;
            row.DISPLAYSTATUSCLASS = displayState.cssClass;
            row.PREVIEWURL        = displayState.previewUrl;
            row.PREVIEWSOURCE     = displayState.previewSource;

            arrayAppend(matrix, row);
        }

        return matrix;
    }

    private struct function _resolveDisplayState(
        required struct variantRow,
        struct publishedRecord = {}
    ) {
        var rawStatus = lCase( trim(arguments.variantRow.STATUS ?: "missing") );
        var hasTempVariant = len( trim(arguments.variantRow.LOCALPATH ?: "") ) GT 0;
        var hasPublishedImage = !structIsEmpty(arguments.publishedRecord);
        var tempPreviewUrl = hasTempVariant ? (arguments.variantRow.LOCALPATH & "?v=" & getTickCount()) : "";
        var publishedPreviewUrl = hasPublishedImage ? trim(arguments.publishedRecord.IMAGEURL ?: "") : "";

        if ( rawStatus EQ "missing" ) {
            return {
                code = "not_assigned",
                label = "Not Assigned",
                cssClass = "bg-secondary",
                previewUrl = "",
                previewSource = ""
            };
        }

        if ( rawStatus EQ "error" ) {
            return {
                code = "error",
                label = "Error",
                cssClass = "bg-danger",
                previewUrl = hasTempVariant ? tempPreviewUrl : publishedPreviewUrl,
                previewSource = hasTempVariant ? "staged" : (hasPublishedImage ? "published" : "")
            };
        }

        if ( hasTempVariant ) {
            if ( hasPublishedImage ) {
                return {
                    code = "outdated",
                    label = "Outdated",
                    cssClass = "bg-warning text-dark",
                    previewUrl = tempPreviewUrl,
                    previewSource = "staged"
                };
            }

            return {
                code = "staged",
                label = "Staged",
                cssClass = "bg-info text-dark",
                previewUrl = tempPreviewUrl,
                previewSource = "staged"
            };
        }

        if ( hasPublishedImage ) {
            if ( rawStatus EQ "stale" ) {
                return {
                    code = "outdated",
                    label = "Outdated",
                    cssClass = "bg-warning text-dark",
                    previewUrl = publishedPreviewUrl,
                    previewSource = "published"
                };
            }

            return {
                code = "published",
                label = "Published",
                cssClass = "bg-success",
                previewUrl = publishedPreviewUrl,
                previewSource = "published"
            };
        }

        return {
            code = "assigned",
            label = "Assigned",
            cssClass = "bg-secondary",
            previewUrl = "",
            previewSource = ""
        };
    }

    private string function _buildPublishedImageKey(
        required numeric userImageSourceID,
        required string variantCode
    ) {
        return val(arguments.userImageSourceID) & "|" & lCase(trim(arguments.variantCode));
    }

    /**
     * Assign (or re-assign) a UserImageSource to a variant type for a user.
     *
     * Validates:
     *   - variantTypeCode exists and is active
     *   - sourceID belongs to this user and is active
     *   - sourceID.SourceKey matches the variant type's required SourceKey
     *
     * Saving an assignment always marks the variant STALE so that the admin
     * must explicitly regenerate.  This is intentional — assignment alone does
     * not produce a derived image.
     */
    public struct function assignSource(
        required numeric userID,
        required numeric imageVariantTypeID,
        required numeric userImageSourceID
    ) {
        // Validate the variant type.
        var variantType = variables.VariantDAO.getVariantTypeByID( arguments.imageVariantTypeID );
        if ( structIsEmpty(variantType) ) {
            return { success=false, message="Unknown variant type." };
        }

        // Validate the source record: ownership + active state.
        var source = variables.SourceDAO.getSourceByID( arguments.userImageSourceID );
        if ( structIsEmpty(source) ) {
            return { success=false, message="Source record not found." };
        }
        if ( val(source.USERID) NEQ arguments.userID ) {
            return { success=false, message="Source does not belong to this user." };
        }
        if ( !( isBoolean(source.ISACTIVE) ? source.ISACTIVE : (val(source.ISACTIVE) EQ 1) ) ) {
            return { success=false, message="Source is inactive. Activate or select a different source." };
        }

        variables.VariantDAO.upsertVariantAssignment(
            userImageSourceID  = arguments.userImageSourceID,
            imageVariantTypeID = arguments.imageVariantTypeID
        );

        return { success=true, message="Variant type assigned. Click Generate to produce the image." };
    }

    /**
     * Generate a single variant for a user.
     *
     * Requires:
     *   - Role check is done on the page; this method does NOT re-check roles.
     *   - A source must already be assigned (status != "missing").
     *   - The assigned source must be active.
     *
     * POC behaviour:
     *   - Calls _generateVariantImage() which copies the source file to the
     *     output directory as the derived "variant".
     *   - Real image processing (resize, crop, format conversion) replaces
     *     _generateVariantImage() without any other changes.
     *
     * On success: variant record updated to status = 'current'.
     * On error:   variant record updated to status = 'error' with message.
     */
    public struct function generateVariant(
        required numeric userID,
        required numeric imageVariantTypeID,
        required numeric userImageSourceID,
        struct frameData = {},
        struct cropData = {}
    ) {
        // Validate the variant type.
        var variantType = variables.VariantDAO.getVariantTypeByID( arguments.imageVariantTypeID );
        if ( structIsEmpty(variantType) ) {
            return { success=false, message="Unknown variant type." };
        }

        // Load the current variant record (keyed on source + type).
        var variant = variables.VariantDAO.getVariantBySourceAndType(
            userImageSourceID  = arguments.userImageSourceID,
            imageVariantTypeID = arguments.imageVariantTypeID
        );

        if ( structIsEmpty(variant) || !isNumeric(variant.USERIMAGESOURCEID ?: "") || val(variant.USERIMAGESOURCEID) EQ 0 ) {
            return { success=false, message="No source has been assigned to this variant. Assign a source before generating." };
        }

        // Load and validate the assigned source.
        var source = variables.SourceDAO.getSourceByID( val(variant.USERIMAGESOURCEID) );
        if ( structIsEmpty(source) ) {
            return { success=false, message="Assigned source record no longer exists. Re-assign a source." };
        }
        if ( val(source.USERID) NEQ arguments.userID ) {
            return { success=false, message="Assigned source does not belong to this user." };
        }
        if ( !( isBoolean(source.ISACTIVE) ? source.ISACTIVE : (val(source.ISACTIVE) EQ 1) ) ) {
            return { success=false, message="Assigned source is inactive. Re-assign an active source before generating." };
        }

        // Determine the generation mode:
        //   - cropData present with valid coordinates → crop-first pipeline
        //   - otherwise → legacy offset-framing pipeline
        var hasCropData = structKeyExists(arguments.cropData, "x")
            AND structKeyExists(arguments.cropData, "y")
            AND structKeyExists(arguments.cropData, "width")
            AND structKeyExists(arguments.cropData, "height")
            AND isNumeric(arguments.cropData.x)
            AND isNumeric(arguments.cropData.y)
            AND isNumeric(arguments.cropData.width)
            AND isNumeric(arguments.cropData.height)
            AND val(arguments.cropData.width) GT 0
            AND val(arguments.cropData.height) GT 0;

        var normalizedFrameData = { offsetX=0, offsetY=0 };
        if ( !hasCropData ) {
            try {
                normalizedFrameData = _normalizeFrameData(arguments.frameData);
            } catch (any e) {
                return { success=false, message=e.message };
            }
        }

        var safeCode  = reReplace(variantType.CODE, "[^a-zA-Z0-9_\-]", "_", "ALL");
        var extension = lCase( trim( variantType.OUTPUTFORMAT ?: "" ) );
        if ( extension EQ "jpeg" ) {
            extension = "jpg";
        }
        if ( !listFindNoCase("jpg,png", extension) ) {
            return { success=false, message="Variant type has invalid output format. Expected jpg or png." };
        }
        var outputFilename = "user_#arguments.userID#_src#arguments.userImageSourceID#_#safeCode#.#extension#";
        var outputPath     = variables.localVariantDirAbsolute & outputFilename;
        var outputWebPath  = variables.localVariantDir & outputFilename;

        // Ensure the output directory exists (POC only; real providers manage this).
        if ( !directoryExists(variables.localVariantDirAbsolute) ) {
            try {
                directoryCreate(variables.localVariantDirAbsolute);
            } catch (any e) {
                return { success=false, message="Could not create variant output directory: #e.message#" };
            }
        }

        // Persist framing metadata only when using the legacy offset model.
        if ( !hasCropData ) {
            variables.VariantDAO.saveFrameMetadata(
                userImageVariantID = val(variant.USERIMAGEVARIANTID),
                frameOffsetX       = normalizedFrameData.offsetX,
                frameOffsetY       = normalizedFrameData.offsetY
            );
        }

        // Attempt generation — all filesystem/image logic is inside this call.
        try {
            _generateVariantImage(
                variantType = variantType,
                source      = source,
                outputPath  = outputPath,
                frameData   = normalizedFrameData,
                cropData    = hasCropData ? arguments.cropData : {}
            );
        } catch (any e) {
            // Record the failure so the admin can see what happened.
            variables.VariantDAO.updateVariantError(
                userImageVariantID = val(variant.USERIMAGEVARIANTID),
                errorMessage       = left(e.message, 500)
            );
            return { success=false, message="Generation failed: #e.message#" };
        }

        // Generation succeeded — update the record.
        variables.VariantDAO.updateVariantGenerated(
            userImageVariantID = val(variant.USERIMAGEVARIANTID),
            localPath          = outputWebPath
        );

        return { success=true, message="Variant '#encodeForHTML(variantType.CODE)#' generated successfully." };
    }


    // ── Private ───────────────────────────────────────────────────────────

    /**
     * Delegate deterministic framing output generation to ImageProcessor.
     * Framing chooses what appears inside a fixed output box; it does NOT allow
     * an arbitrary crop rectangle to be saved or replayed.
     *
     * @variantType  Struct from ImageVariantTypes (expects WidthPx/HeightPx/OutputFormat)
     * @source       Struct from UserImageSources (DROPBOXPATH currently points to local source filename)
     * @outputPath   Absolute disk path to write the output file to.
     */
    private void function _generateVariantImage(
        required struct  variantType,
        required struct  source,
        required string  outputPath,
        struct           frameData = {},
        struct           cropData  = {}
    ) {
        // Resolve the absolute disk path of the source file.
        // DROPBOX SWAP POINT: replace this with a Dropbox download call.
        var sourceFilename     = listLast(arguments.source.DROPBOXPATH, "/\\");
        var sourceAbsolutePath = _resolveSourceAbsolutePath( arguments.source.DROPBOXPATH ?: "" );

        if ( !len(sourceAbsolutePath) OR !fileExists(sourceAbsolutePath) ) {
            throw(
                type    = "UserImageVariantService.SourceNotFound",
                message = "Source file not found on disk: #sourceFilename#. Ensure the file exists in the source directory."
            );
        }

        // ── Pass-through mode ─────────────────────────────────────────────
        // When AllowResize = false the source is already at final dimensions.
        // Copy it to the output location (with format conversion via cfimage
        // if the output format differs from the source) and return immediately.
        var allowResize = isBoolean(arguments.variantType.ALLOWRESIZE ?: true)
            ? arguments.variantType.ALLOWRESIZE
            : (val(arguments.variantType.ALLOWRESIZE ?: 1) EQ 1);

        if ( !allowResize ) {
            var ptOutputFormat = lCase( trim( arguments.variantType.OUTPUTFORMAT ?: "" ) );
            if ( ptOutputFormat EQ "jpeg" ) { ptOutputFormat = "jpg"; }
            var ptSourceExt = lCase( listLast(sourceFilename, ".") );
            if ( ptSourceExt EQ "jpeg" ) { ptSourceExt = "jpg"; }

            if ( ptSourceExt EQ ptOutputFormat ) {
                // Same format — straight file copy (fastest).
                fileCopy(sourceAbsolutePath, arguments.outputPath);
            } else {
                // Format conversion required: read → write in target format.
                var ptImage = imageRead(sourceAbsolutePath);
                if ( ptOutputFormat EQ "jpg" ) {
                    cfimage(action="write", source=ptImage, destination=arguments.outputPath, overwrite=true, quality=0.75);
                } else {
                    cfimage(action="write", source=ptImage, destination=arguments.outputPath, overwrite=true);
                }
            }
            return;
        }

        // ── Standard resize / crop pipeline ───────────────────────────────
        var width  = isNumeric(arguments.variantType.WIDTHPX ?: "") ? val(arguments.variantType.WIDTHPX) : 0;
        var height = isNumeric(arguments.variantType.HEIGHTPX ?: "") ? val(arguments.variantType.HEIGHTPX) : 0;
        var outputFormat = lCase( trim( arguments.variantType.OUTPUTFORMAT ?: "" ) );
        var allowTransparency = isBoolean(arguments.variantType.ALLOWTRANSPARENCY ?: "")
            ? arguments.variantType.ALLOWTRANSPARENCY
            : (val(arguments.variantType.ALLOWTRANSPARENCY ?: 0) EQ 1);

        // Variant types may define a fixed box (width+height), width-only, or
        // height-only output.  At least one dimension must be present.
        if ( width LTE 0 AND height LTE 0 ) {
            throw(
                type    = "UserImageVariantService.InvalidVariantType",
                message = "Variant type dimensions are invalid. At least one of WidthPx or HeightPx must be a positive value."
            );
        }

        if ( outputFormat EQ "jpeg" ) {
            outputFormat = "jpg";
        }

        var variantDefinition = {
            outputFormat      = outputFormat,
            allowTransparency = allowTransparency
        };

        if ( width GT 0 ) {
            variantDefinition.width = width;
        }
        if ( height GT 0 ) {
            variantDefinition.height = height;
        }

        variables.ImageProcessor.generateVariant(
            sourcePath        = sourceAbsolutePath,
            destinationPath   = arguments.outputPath,
            variantDefinition = variantDefinition,
            offsets = {
                x = arguments.frameData.offsetX ?: 0,
                y = arguments.frameData.offsetY ?: 0
            },
            cropRect = {
                x      = val(arguments.cropData.x ?: 0),
                y      = val(arguments.cropData.y ?: 0),
                width  = val(arguments.cropData.width ?: 0),
                height = val(arguments.cropData.height ?: 0)
            }
        );
    }

    /**
     * Normalize framing metadata from the UI.
     *
     * Framing stores only a bias for where the fixed output frame is centered
     * within the resized image.  Missing values default to 0,0.  Present but
     * non-numeric values are rejected so the admin gets a clear validation error.
     */
    private struct function _normalizeFrameData( struct frameData = {} ) {
        var offsetX = 0;
        var offsetY = 0;

        if ( structKeyExists(arguments.frameData, "offsetX") ) {
            if ( !isNumeric(arguments.frameData.offsetX) ) {
                throw(type = "UserImageVariantService.InvalidFrameData", message = "Frame offsetX must be numeric.");
            }
            offsetX = val(arguments.frameData.offsetX);
        }

        if ( structKeyExists(arguments.frameData, "offsetY") ) {
            if ( !isNumeric(arguments.frameData.offsetY) ) {
                throw(type = "UserImageVariantService.InvalidFrameData", message = "Frame offsetY must be numeric.");
            }
            offsetY = val(arguments.frameData.offsetY);
        }

        return {
            offsetX = _clamp(offsetX, -100, 100),
            offsetY = _clamp(offsetY, -100, 100)
        };
    }

    private numeric function _clamp(
        required numeric value,
        required numeric minValue,
        required numeric maxValue
    ) {
        if ( arguments.value LT arguments.minValue ) {
            return arguments.minValue;
        }
        if ( arguments.value GT arguments.maxValue ) {
            return arguments.maxValue;
        }
        return arguments.value;
    }

    /**
     * Resolve a logical /_temp_source/... path to a canonical absolute path.
     * Nested source folders are supported; traversal is rejected.
     */
    private string function _resolveSourceAbsolutePath( required string sourcePath ) {
        var relativePath = trim( arguments.sourcePath );
        var normalizedRelative = "";

        if ( left(relativePath, 14) EQ "/_temp_source/" ) {
            relativePath = mid( relativePath, 15, len(relativePath) );
        }

        relativePath = replace( relativePath, "/", "\\", "all" );
        normalizedRelative = reReplace( relativePath, "^[\\/]+", "", "all" );

        if ( !len(normalizedRelative) OR find("..", normalizedRelative) ) {
            return "";
        }

        return variables.localSourceDirAbsolute & normalizedRelative;
    }

}
