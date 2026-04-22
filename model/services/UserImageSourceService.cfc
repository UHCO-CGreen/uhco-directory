/**
 * UserImageSourceService.cfc
 *
 * Responsible for: business rules, source validation, and the file-provider abstraction.
 *
 * ╔══════════════════════════════════════════════════════════════════
 *   DROPBOX SWAP POINT — overview                                   
 *                                                                   
 *   All filesystem logic is confined to three private methods:      
 *     _listProviderFiles()   — enumerate available source images    
 *     _resolveProviderPath() — turn a logical path into a real one  
 *     _isValidProviderPath() — validate a submitted SourcePath      
 *                                                                   
 *   To replace the local folder with Dropbox:                       
 *     1. Swap these three methods for Dropbox API equivalents.      
 *     2. Change variables.localSourceDir to a Dropbox folder ID.    
 *     3. No other files (DAO, page, UI) need to change.             
 * ══════════════════════════════════════════════════════════════════
 */
component output="false" singleton {

    // ── POC: local source directory ──────────────────────────────────────────
    // DROPBOX SWAP POINT: replace this path with a Dropbox folder reference.
    variables.localSourceDir    = "/_temp_source/";
    variables.allowedExtensions = ["jpg", "jpeg", "png"];

    // Default SourceKey values. Can be overridden by AppConfig key media.source_keys.
    variables.defaultSourceKeys = ["profile", "alumni", "dean", "marketing"];

    // Dropbox subfolders to search per flag group (populated in init).
    variables.foldersByFlag = [];

    // Dropbox subfolders always excluded regardless of flags.
    variables.excludedFolders = ["Archived", "Employees To Be Named"];


    public any function init() {
        variables.SourceDAO        = createObject("component", "dao.UserImageSourceDAO").init();
        variables.VariantDAO       = createObject("component", "dao.UserImageVariantDAO").init();
        variables.PatternDAO       = createObject("component", "dao.FileNamePatternDAO").init();
        variables.ImagesDAO        = createObject("component", "dao.images_DAO").init();
        variables.AppConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.DropboxProvider  = createObject("component", "cfc.DropboxProvider").init();

        // Build the flag-to-folder mapping.
        // Uses structNew() + dot-notation to avoid CF parser issues with {} inside init().
        var _m = structNew();

        _m = structNew();
        _m.flags   = ["Faculty-Fulltime", "Faculty-Adjunct", "Professor-Emeritus", "Active-Retiree"];
        _m.folders = ["Faculty"];
        arrayAppend( variables.foldersByFlag, _m );

        _m = structNew();
        _m.flags   = ["Staff"];
        _m.folders = ["Staff"];
        arrayAppend( variables.foldersByFlag, _m );

        _m = structNew();
        _m.flags   = ["Resident"];
        _m.folders = ["Residents"];
        arrayAppend( variables.foldersByFlag, _m );

        _m = structNew();
        _m.flags   = ["Current-Student"];
        _m.folders = ["Students", "Grad Students"];
        arrayAppend( variables.foldersByFlag, _m );

        _m = structNew();
        _m.flags   = ["Alumni"];
        _m.folders = ["Students"];
        arrayAppend( variables.foldersByFlag, _m );

        _m = structNew();
        _m.flags   = ["FERV Board"];
        _m.folders = ["FERV Board"];
        arrayAppend( variables.foldersByFlag, _m );

        // Compute the absolute disk path to the local source folder from the CFC's
        // own location.  expandPath("/...") resolves against the IIS site root, not
        // the application root, so it cannot be used here reliably.
        // getCurrentTemplatePath() always returns this CFC's absolute path on disk.
        // getCanonicalPath() resolves ".." so directoryExists/directoryList never
        // receive a dotted path, which some CF engines reject.
        var cfc_dir   = getDirectoryFromPath( getCurrentTemplatePath() );
        var rawPath   = cfc_dir & "..\..\_temp_source";
        var canonical = createObject("java", "java.io.File").init( rawPath ).getCanonicalPath();
        variables.localSourceDirAbsolute = canonical & "\";

        return this;
    }


    // ── Public: configuration helpers ────────────────────────────────────────

    /**
     * Returns a single source record by its primary key.
     * Returns an empty struct if not found.
     */
    public struct function getSourceByID( required numeric sourceID ) {
        return variables.SourceDAO.getSourceByID( arguments.sourceID );
    }

    /**
     * Returns a struct keyed by UserID with active source counts.
     */
    public struct function getActiveSourceCountMapByUser() {
        var rows = variables.SourceDAO.getActiveSourceCountsByUser();
        var result = {};

        for (var row in rows) {
            result[ toString(row.USERID) ] = val(row.ACTIVESOURCECOUNT ?: 0);
        }

        return result;
    }

    /**
     * Returns the list of valid SourceKey values for UI dropdowns.
     */
    public array function getSourceKeys() {
        var configured = trim( variables.AppConfigService.getValue("media.source_keys", "") );
        var parsed = [];

        if ( len(configured) ) {
            for ( var token in listToArray(configured, ",") ) {
                token = lCase( trim(token) );
                if ( len(token) AND !arrayFindNoCase(parsed, token) ) {
                    arrayAppend(parsed, token);
                }
            }
        }

        return arrayLen(parsed) ? parsed : variables.defaultSourceKeys;
    }

    /**
     * Returns an array of structs representing available source images.
     *   { filename: string, path: string }
     *
     * Page receives this structured data — no filesystem access in the page.
     *
     * DROPBOX SWAP POINT: replace _listProviderFiles() to call Dropbox list API.
     */
    public array function getAvailableFiles() {
        return _listProviderFiles();
    }

    /**
     * Returns the active source provider name ("dropbox" or "local").
     * Exposed so page-level code can conditionally render the right UI.
     */
    public string function getSourceProvider() {
        return _getSourceProvider();
    }

    /**
     * Returns the active Dropbox browse mode: "files" (default) or "folders".
     *   files   — recursive file listing filtered by flag folders + name tokens
     *   folders — looks for a per-user subfolder (by CougarNet ID) within each
     *             flag folder; lists only files inside that subfolder
     */
    public string function getDropboxBrowseMode() {
        return _getDropboxBrowseMode();
    }

    /**
     * Returns the top-level Dropbox folders that should use folder lookup when
     * browse mode is set to "mixed".
     */
    public array function getDropboxFolderBrowseFolders() {
        return _getDropboxFolderBrowseFolders();
    }

    /**
     * Returns the ordered list of subfolder names that "folders" browse mode
     * will try inside each flag folder, given the user's identity data.
     * Useful for displaying a diagnostic hint on the sources page.
     *
     * Order: external ID values first (all types), then name tokens.
     */
    public array function getCandidateFolderNames(
        required string firstName,
        required string lastName,
        string          middleName = "",
        required array  externalIDs
    ) {
        return _buildFolderCandidates(
            firstName   = arguments.firstName,
            lastName    = arguments.lastName,
            middleName  = arguments.middleName,
            externalIDs = arguments.externalIDs
        );
    }

    /**
     * Public wrapper so the page can display which folders will be searched.
     * Returns an empty array when no flags match (means all-minus-excluded).
     */
    public array function getAllowedFoldersByFlags( required array userFlags ) {
        return _getAllowedFoldersByFlags( arguments.userFlags );
    }

    /**
     * Returns available source images filtered by:
     *   1. Dropbox subfolders that match the user's assigned flags.
     *   2. Name/token matching within those folders.
     *
     * Folder mapping is driven by variables.foldersByFlag.
     * Always excludes variables.excludedFolders (e.g. "Archived").
     *
     * Falls back progressively:
     *   matched files → folder-filtered files → all-minus-excluded files
     */
    public array function getAvailableFilesForUserByFlags(
        required string firstName,
        required string lastName,
        string  middleName  = "",
        required array  externalIDs,
        required array  userFlags
    ) {
        var isDropbox      = ( _getSourceProvider() EQ "dropbox" );
        var browseMode     = _getDropboxBrowseMode();
        var rootFolder     = isDropbox ? _normalizeSlashPath( variables.AppConfigService.getValue("dropbox.root_folder", "") ) : "";
        var allowedFolders = _getAllowedFoldersByFlags( arguments.userFlags );

        // ── FOLDER mode: targeted per-user subfolder lookup ──────────────────
        if ( isDropbox AND browseMode EQ "folders" ) {
            return _listFilesForUserFolder(
                rootFolder     = rootFolder,
                allowedFolders = allowedFolders,
                externalIDs    = arguments.externalIDs,
                firstName      = arguments.firstName,
                lastName       = arguments.lastName,
                middleName     = arguments.middleName
            );
        }

        if ( isDropbox AND browseMode EQ "mixed" ) {
            var allDropboxFiles     = _listProviderFiles();
            var folderBrowseFolders = [];
            var fileBrowseFolders   = [];
            var mixedResults        = [];

            if ( arrayLen(allowedFolders) ) {
                for ( var allowedFolder in allowedFolders ) {
                    if ( arrayFindNoCase(_getDropboxFolderBrowseFolders(), allowedFolder) ) {
                        arrayAppend( folderBrowseFolders, allowedFolder );
                    } else {
                        arrayAppend( fileBrowseFolders, allowedFolder );
                    }
                }
            }

            if ( arrayLen(folderBrowseFolders) ) {
                mixedResults = _mergeAvailableFiles(
                    mixedResults,
                    _listFilesForUserFolder(
                        rootFolder     = rootFolder,
                        allowedFolders = folderBrowseFolders,
                        externalIDs    = arguments.externalIDs,
                        firstName      = arguments.firstName,
                        lastName       = arguments.lastName,
                        middleName     = arguments.middleName
                    )
                );
            }

            mixedResults = _mergeAvailableFiles(
                mixedResults,
                _filterDropboxFilesByFoldersAndTokens(
                    allFiles       = allDropboxFiles,
                    rootFolder     = rootFolder,
                    allowedFolders = fileBrowseFolders,
                    firstName      = arguments.firstName,
                    lastName       = arguments.lastName,
                    middleName     = arguments.middleName,
                    externalIDs    = arguments.externalIDs,
                    requiredPathSegments = ["publish"],
                    allowGlobalFallback = false
                )
            );

            return mixedResults;
        }

        // ── FILE mode (default): recursive listing + flag + token filter ─────
        var allFiles = _listProviderFiles();

        if ( isDropbox ) {
            return _filterDropboxFilesByFoldersAndTokens(
                allFiles       = allFiles,
                rootFolder     = rootFolder,
                allowedFolders = allowedFolders,
                firstName      = arguments.firstName,
                lastName       = arguments.lastName,
                middleName     = arguments.middleName,
                externalIDs    = arguments.externalIDs
            );
        }

        var tokens = _buildUserTokens( arguments.firstName, arguments.lastName, arguments.middleName, arguments.externalIDs );
        if ( !arrayLen(tokens) ) {
            return allFiles;
        }

        var matched = [];
        for ( var fi in allFiles ) {
            if ( _filenameMatchesTokens( fi.filename, tokens ) ) {
                arrayAppend( matched, fi );
            }
        }

        return arrayLen(matched) ? matched : allFiles;
    }

    /**
     * Returns available source images filtered to files whose names match
     * the user's identity tokens: name combinations and external IDs.
     *
     * Patterns are loaded from the FileNamePatterns table and resolved
     * against user fields.  External ID values are always included as
     * literal tokens.
     *
     * Falls back to all files when no tokens can be built.
     *
     * @firstName   User's first name
     * @lastName    User's last name
     * @middleName  User's middle name (optional)
     * @externalIDs Array of structs from externalID_service.getExternalIDs()
     *              Each struct has at minimum: EXTERNALVALUE
     */
    public array function getAvailableFilesForUser(
        required string firstName,
        required string lastName,
        string  middleName = "",
        required array  externalIDs
    ) {
        var allFiles = _listProviderFiles();
        var tokens   = _buildUserTokens( arguments.firstName, arguments.lastName, arguments.middleName, arguments.externalIDs );

        // No usable tokens — show everything so the admin is never stuck
        if ( !arrayLen(tokens) ) {
            return allFiles;
        }

        var matched = [];
        for ( var f in allFiles ) {
            if ( _filenameMatchesTokens( f.filename, tokens ) ) {
                arrayAppend( matched, f );
            }
        }

        // If nothing matched, fall back to all files so the page is never empty
        return arrayLen(matched) ? matched : allFiles;
    }


    // ── Public: CRUD operations ───────────────────────────────────────────────

    /**
     * Return all source records for a user.
     */
    public struct function getSourcesForUser( required numeric userID ) {
        return {
            success = true,
            data    = variables.SourceDAO.getSourcesForUser( arguments.userID )
        };
    }

    /**
     * Add a new image source for a user.
     * Marks any existing variants for the same user+sourceKey as STALE.
     */
    public struct function addSource(
        required numeric userID,
        required string  sourceKey,
        required string  sourcePath
    ) {
        var cleanKey  = trim( arguments.sourceKey );
        var cleanPath = trim( arguments.sourcePath );

        if ( !len(cleanKey) || !arrayFindNoCase(getSourceKeys(), cleanKey) ) {
            return { success=false, message="Invalid source key." };
        }

        // DROPBOX SWAP POINT: _isValidProviderPath() validates against the local folder.
        // Replace with Dropbox file-metadata validation when switching providers.
        if ( !_isValidProviderPath(cleanPath) ) {
            return { success=false, message="Selected file is not a valid source image." };
        }

        var newID = variables.SourceDAO.insertSource({
            UserID     = arguments.userID,
            SourceKey  = cleanKey,
            SourcePath = cleanPath
        });

        // Side-effect: flag related variants as stale (explicit regeneration required).
        _markVariantsStale( arguments.userID, cleanKey );

        return { success=true, message="Image source added.", sourceID=newID };
    }

    /**
     * Update the SourceKey and SourcePath of an existing source.
     * Enforces ownership.  Marks related variants STALE.
     */
    public struct function updateSource(
        required numeric sourceID,
        required numeric userID,
        required string  sourceKey,
        required string  sourcePath
    ) {
        var existing = variables.SourceDAO.getSourceByID( arguments.sourceID );

        if ( structIsEmpty(existing) ) {
            return { success=false, message="Source record not found." };
        }

        // Ownership check: prevents editing another user's source via form manipulation.
        if ( val(existing.USERID) NEQ arguments.userID ) {
            return { success=false, message="Source does not belong to this user." };
        }

        var cleanKey  = trim( arguments.sourceKey );
        var cleanPath = trim( arguments.sourcePath );

        if ( !len(cleanKey) || !arrayFindNoCase(getSourceKeys(), cleanKey) ) {
            return { success=false, message="Invalid source key." };
        }

        // DROPBOX SWAP POINT: same as addSource above.
        if ( !_isValidProviderPath(cleanPath) ) {
            return { success=false, message="Selected file is not a valid source image." };
        }

        variables.SourceDAO.updateSource( arguments.sourceID, {
            SourceKey  = cleanKey,
            SourcePath = cleanPath
        });

        // Mark variants stale after any source change.
        _markVariantsStale( arguments.userID, cleanKey );

        return { success=true, message="Image source updated." };
    }

    /**
     * Deactivate (soft-delete) a source.
     * Enforces ownership.  Marks related variants STALE.
     * Deletion is intentionally not supported — deactivation only.
     */
    public struct function deactivateSource(
        required numeric sourceID,
        required numeric userID
    ) {
        var existing = variables.SourceDAO.getSourceByID( arguments.sourceID );

        if ( structIsEmpty(existing) ) {
            return { success=false, message="Source record not found." };
        }

        if ( val(existing.USERID) NEQ arguments.userID ) {
            return { success=false, message="Source does not belong to this user." };
        }

        variables.SourceDAO.setActiveStatus( arguments.sourceID, false );

        // Mark variants stale when their source is deactivated.
        _markVariantsStale( arguments.userID, existing.SOURCEKEY );

        return { success=true, message="Image source deactivated." };
    }

    /**
     * Hard-delete a source record from the database.
     * Enforces ownership.  Marks related variants STALE before deletion.
     * NOTE: no file deletion occurs — only the DB record is removed.
     * This may be extended later (e.g. to remove files or Dropbox entries).
     */
    public struct function deleteSource(
        required numeric sourceID,
        required numeric userID
    ) {
        var existing = variables.SourceDAO.getSourceByID( arguments.sourceID );

        if ( structIsEmpty(existing) ) {
            return { success=false, message="Source record not found." };
        }

        if ( val(existing.USERID) NEQ arguments.userID ) {
            return { success=false, message="Source does not belong to this user." };
        }

        // Remove all published images and variant records that reference this source
        // before deleting it.  This satisfies the FK constraints on UserImages and
        // UserImageVariants that reference UserImageSources.
        variables.ImagesDAO.deleteBySourceID( arguments.sourceID );
        variables.VariantDAO.deleteVariantsBySourceID( arguments.sourceID );

        // Mark variants stale before the record is gone so the key is still known.
        _markVariantsStale( arguments.userID, existing.SOURCEKEY );

        variables.SourceDAO.deleteSource( arguments.sourceID );

        return { success=true, message="Image source deleted." };
    }


    // ── Private: file provider (POC = local filesystem) ──────────────────────
    //
    // DROPBOX SWAP POINT:
    //   All three methods below are the only things that change when Dropbox
    //   replaces the local folder.  The public interface above stays identical.

    /**
     * Returns the array of Dropbox subfolder names that should be searched
     * for a user based on their assigned flags.  Empty array = no restriction.
     */
    private array function _getAllowedFoldersByFlags( required array userFlags ) {
        var allowed   = [];
        var flagNames = [];

        for ( var flag in arguments.userFlags ) {
            arrayAppend( flagNames, lCase( trim(flag.FLAGNAME ?: "") ) );
        }

        if ( !arrayLen(flagNames) ) {
            return allowed; // no flags → caller will fall back to all-minus-excluded
        }

        for ( var mapping in variables.foldersByFlag ) {
            var hit = false;
            for ( var mappedFlag in mapping.flags ) {
                if ( arrayFindNoCase(flagNames, lCase(trim(mappedFlag))) ) {
                    hit = true;
                    break;
                }
            }
            if ( hit ) {
                for ( var folder in mapping.folders ) {
                    if ( !arrayFindNoCase(allowed, folder) ) {
                        arrayAppend( allowed, folder );
                    }
                }
            }
        }

        return allowed;
    }

    /**
     * Extracts the first subfolder segment from a Dropbox path relative to
     * the configured root folder.
     * e.g. rootFolder="/Headshots", path="/Headshots/Staff/photo.jpg" → "Staff"
     */
    private string function _getFirstSubfolder( required string filePath, required string rootFolder ) {
        var p    = _normalizeSlashPath( arguments.filePath );
        var root = _normalizeSlashPath( arguments.rootFolder );
        var remainder = "";
        var parts = [];

        if ( !len(root) OR root EQ "/" ) {
            parts = listToArray( reReplace(p, "^/", ""), "/" );
            return ( arrayLen(parts) GTE 2 ) ? parts[1] : "";
        }

        if ( left(p, len(root) + 1) EQ (root & "/") ) {
            remainder = mid( p, len(root) + 2, len(p) );
            parts = listToArray( remainder, "/" );
            return ( arrayLen(parts) GTE 2 ) ? parts[1] : "";
        }

        return "";
    }

    private boolean function _fileIsInAllowedFolders(
        required string filePath,
        required string rootFolder,
        required array  allowedFolders
    ) {
        var sub = _getFirstSubfolder( arguments.filePath, arguments.rootFolder );
        return len(sub) AND arrayFindNoCase( arguments.allowedFolders, sub ) GT 0;
    }

    private boolean function _fileIsInExcludedFolder(
        required string filePath,
        required string rootFolder
    ) {
        var sub = _getFirstSubfolder( arguments.filePath, arguments.rootFolder );
        return len(sub) AND arrayFindNoCase( variables.excludedFolders, sub ) GT 0;
    }

    /**
     * Returns the configured Dropbox browse mode.
     * "files"   = recursive listing filtered by name tokens (default)
     * "folders" = per-user subfolder lookup by CougarNet ID (or name token)
     */
    private string function _getDropboxBrowseMode() {
        var mode = lCase( trim( variables.AppConfigService.getValue("dropbox.browse_mode", "files") ) );
        if ( listFindNoCase("files,folders,mixed", mode) ) {
            return mode;
        }
        return "files";
    }

    private array function _getDropboxFolderBrowseFolders() {
        var configured = trim( variables.AppConfigService.getValue("dropbox.folder_browse_folders", "Faculty,Staff") );
        var result = [];

        for ( var folderName in listToArray(configured, ",") ) {
            folderName = trim(folderName);
            if ( len(folderName) AND !arrayFindNoCase(result, folderName) ) {
                arrayAppend( result, folderName );
            }
        }

        return result;
    }

    private array function _buildFolderCandidates(
        required string firstName,
        required string lastName,
        string          middleName = "",
        required array  externalIDs
    ) {
        var candidates = [];
        var first = lCase( trim(arguments.firstName) );
        var last = lCase( trim(arguments.lastName) );
        var middle = lCase( trim(arguments.middleName) );
        var fi = len(first) ? left(first, 1) : "";
        var mi = len(middle) ? left(middle, 1) : "";
        var nameToken = fi & mi & last;
        var nameTokenShort = fi & last;

        for ( var extID in arguments.externalIDs ) {
            var extVal = lCase( trim(extID.EXTERNALVALUE ?: "") );
            if ( len(extVal) GTE 2 AND left(extVal, 4) NEQ "http" AND !arrayFindNoCase(candidates, extVal) ) {
                arrayAppend( candidates, extVal );
            }
        }

        if ( len(nameToken) GTE 2 AND !arrayFindNoCase(candidates, nameToken) ) {
            arrayAppend( candidates, nameToken );
        }
        if ( len(nameTokenShort) GTE 2 AND nameTokenShort NEQ nameToken AND !arrayFindNoCase(candidates, nameTokenShort) ) {
            arrayAppend( candidates, nameTokenShort );
        }

        return candidates;
    }

    private array function _filterDropboxFilesByFoldersAndTokens(
        required array  allFiles,
        required string rootFolder,
        required array  allowedFolders,
        required string firstName,
        required string lastName,
        string          middleName = "",
        required array  externalIDs,
        array           requiredPathSegments = [],
        boolean         allowGlobalFallback = true
    ) {
        var folderFiltered = [];
        var matched = [];
        var tokens = _buildUserTokens( arguments.firstName, arguments.lastName, arguments.middleName, arguments.externalIDs );

        if ( arrayLen(arguments.allowedFolders) ) {
            for ( var fi in arguments.allFiles ) {
                if (
                    _fileIsInAllowedFolders(fi.path, arguments.rootFolder, arguments.allowedFolders)
                    AND _pathContainsAllSegments(fi.path, arguments.requiredPathSegments)
                ) {
                    arrayAppend( folderFiltered, fi );
                }
            }
        }

        if ( !arrayLen(folderFiltered) AND arguments.allowGlobalFallback ) {
            for ( var fi in arguments.allFiles ) {
                if (
                    !_fileIsInExcludedFolder(fi.path, arguments.rootFolder)
                    AND _pathContainsAllSegments(fi.path, arguments.requiredPathSegments)
                ) {
                    arrayAppend( folderFiltered, fi );
                }
            }
        }

        if ( !arrayLen(tokens) ) {
            return folderFiltered;
        }

        for ( var fi in folderFiltered ) {
            if ( _filenameMatchesTokens( fi.filename, tokens ) ) {
                arrayAppend( matched, fi );
            }
        }

        return arrayLen(matched) ? matched : folderFiltered;
    }

    private boolean function _pathContainsAllSegments(
        required string filePath,
        array segmentNames = []
    ) {
        var normalizedPath = _normalizeSlashPath( arguments.filePath );
        var segments = listToArray( normalizedPath, "/" );

        if ( !arrayLen(arguments.segmentNames) ) {
            return true;
        }

        for ( var segmentName in arguments.segmentNames ) {
            if ( !arrayFindNoCase(segments, segmentName) ) {
                return false;
            }
        }

        return true;
    }

    private array function _mergeAvailableFiles(
        required array baseFiles,
        required array newFiles
    ) {
        var merged = [];
        var seenPaths = {};

        for ( var baseFile in arguments.baseFiles ) {
            if ( !structKeyExists(baseFile, "path") ) {
                continue;
            }
            seenPaths[ lCase(baseFile.path) ] = true;
            arrayAppend( merged, baseFile );
        }

        for ( var newFile in arguments.newFiles ) {
            if ( !structKeyExists(newFile, "path") ) {
                continue;
            }
            if ( !structKeyExists(seenPaths, lCase(newFile.path)) ) {
                seenPaths[ lCase(newFile.path) ] = true;
                arrayAppend( merged, newFile );
            }
        }

        return merged;
    }

    /**
     * FOLDER browse mode: for each allowed flag folder, attempt to find a
     * per-user subfolder named after the user's CougarNet ID (preferred) or
     * a name-derived token.  Returns all image files found in matching
     * subfolders across all flag folders.
     *
     * Expected Dropbox structure:
     *   {root}/{FlagFolder}/{cougarnetID}/photo1.jpg
     *   {root}/{FlagFolder}/{cougarnetID}/photo2.jpg
     *
     * Falls back to empty array (not an error) when no subfolder is found,
     * so the page can display a "no images found" message rather than crashing.
     */
    private array function _listFilesForUserFolder(
        required string rootFolder,
        required array  allowedFolders,
        required array  externalIDs,
        required string firstName,
        required string lastName,
        string          middleName = ""
    ) {
        var result = [];
        var candidates = _buildFolderCandidates(
            firstName   = arguments.firstName,
            lastName    = arguments.lastName,
            middleName  = arguments.middleName,
            externalIDs = arguments.externalIDs
        );

        if ( !arrayLen(candidates) ) {
            return result; // no identifiers — nothing to look up
        }

        // Determine which flag folders to search.
        // If no flag folders mapped, search all-minus-excluded (same fallback as file mode).
        var foldersToSearch = arrayLen(arguments.allowedFolders) ? arguments.allowedFolders : [];
        if ( !arrayLen(foldersToSearch) ) {
            // No flag match — try every non-excluded top-level folder.
            // We don't have a pre-built list here, so fall back gracefully to empty.
            return result;
        }

        for ( var flagFolder in foldersToSearch ) {
            // List the entire flag folder recursively, then find files whose
            // path contains the candidate name as any segment — handles arbitrary
            // nesting depth (e.g. Faculty/Department/mdtwa/photo.jpg).
            var flagFolderPath = _normalizeSlashPath( arguments.rootFolder & "/" & flagFolder );
            var flagFiles = [];

            try {
                flagFiles = variables.DropboxProvider.listFolderRecursive( flagFolderPath );
            } catch (any e) {
                continue; // flag folder doesn't exist — skip
            }

            var matchedInFlag = [];
            for ( var f in flagFiles ) {
                if ( !structKeyExists(f, "filename") OR !structKeyExists(f, "path") ) { continue; }
                var ext = lCase( listLast(f.filename, ".") );
                if ( !arrayFindNoCase(variables.allowedExtensions, ext) ) { continue; }

                // Check every path segment against the candidate list.
                // The file must be a direct child of the matched user folder —
                // files inside any subfolder of the user folder are excluded.
                // e.g. /Headshots/Faculty/SomeDept/mdtwa/photo.jpg      → include (mdtwa is segment N-1, file is N)
                //      /Headshots/Faculty/SomeDept/mdtwa/summer/photo.jpg → exclude (one extra level)
                var segments = listToArray( _normalizeSlashPath(f.path), "/" );
                var segMatch = false;
                var lastIdx  = arrayLen(segments);
                for ( var si = 1; si LT lastIdx; si++ ) {
                    if ( arrayFindNoCase(candidates, segments[si]) AND si EQ lastIdx - 1 ) {
                        segMatch = true;
                        break;
                    }
                }
                if ( segMatch ) {
                    arrayAppend( matchedInFlag, { filename=f.filename, path=_normalizeSlashPath(f.path) } );
                }
            }

            for ( var mf in matchedInFlag ) {
                arrayAppend( result, mf );
            }
        }

        return result;
    }

    /**
     * Enumerate files in the local source directory.
     * Returns array of { filename, path } structs.
     *
     * DROPBOX REPLACEMENT: call cfhttp to the Dropbox list_folder API,
     * parse the JSON entries, and return the same struct shape.
     */
    private array function _listProviderFiles() {
        var result = [];
        var provider = _getSourceProvider();

        if ( provider EQ "dropbox" ) {
            var rootPath = variables.AppConfigService.getValue("dropbox.root_folder", "");
            var files = variables.DropboxProvider.listFolderRecursive(rootPath);

            for ( var f in files ) {
                if ( structKeyExists(f, "filename") AND structKeyExists(f, "path") ) {
                    arrayAppend( result, {
                        filename = f.filename,
                        path = _normalizeSlashPath(f.path)
                    });
                }
            }

            return result;
        }

        var expandedDir = variables.localSourceDirAbsolute;

        if ( !directoryExists(expandedDir) ) {
            return result;
        }

        var localFiles = directoryList( expandedDir, false, "query" );

        for ( var row in localFiles ) {
            // directoryList type values are lowercase ("file" / "dir")
            if ( lCase(row.type) EQ "file" ) {
                var ext = lCase( listLast(row.name, ".") );
                if ( arrayFindNoCase(variables.allowedExtensions, ext) ) {
                    arrayAppend( result, {
                        filename = row.name,
                        path     = variables.localSourceDir & row.name
                    });
                }
            }
        }

        return result;
    }

    /**
     * Validate a SourcePath submitted from the form.
     * Guards against path-traversal and unknown files.
     *
     * DROPBOX REPLACEMENT: look up the path in the Dropbox file-metadata API
     * and confirm it exists and belongs to the expected folder.
     */
    private boolean function _isValidProviderPath( required string path ) {
        var p = trim( arguments.path );
        var ext = "";
        var absolutePath = "";
        var provider = _getSourceProvider();

        if ( provider EQ "dropbox" ) {
            p = _normalizeSlashPath(p);

            if ( !_pathIsUnderDropboxRoot(p) ) {
                return false;
            }

            ext = lCase( listLast(p, ".") );
            if ( !arrayFindNoCase(variables.allowedExtensions, ext) ) {
                return false;
            }

            return variables.DropboxProvider.fileExists( p );
        }

        // Must start with the known local source prefix (prevents path traversal).
        if ( left( p, len(variables.localSourceDir) ) NEQ variables.localSourceDir ) {
            return false;
        }

        ext = lCase( listLast(p, ".") );
        if ( !arrayFindNoCase(variables.allowedExtensions, ext) ) {
            return false;
        }

        absolutePath = _resolveProviderAbsolutePath( p );
        return len(absolutePath) AND fileExists( absolutePath );
    }

    /**
     * Convert a logical provider path like /_temp_source/2025/file.jpg into
     * an absolute local disk path while rejecting traversal.
     */
    private string function _resolveProviderAbsolutePath( required string providerPath ) {
        var provider = _getSourceProvider();

        if ( provider EQ "dropbox" ) {
            return variables.DropboxProvider.downloadToTemp( _normalizeSlashPath(arguments.providerPath) );
        }

        var relativePath = trim( arguments.providerPath );
        var normalizedRelative = "";

        if ( left( relativePath, len(variables.localSourceDir) ) NEQ variables.localSourceDir ) {
            return "";
        }

        relativePath = mid( relativePath, len(variables.localSourceDir) + 1, len(relativePath) );
        relativePath = replace( relativePath, "/", "\\", "all" );
        normalizedRelative = reReplace( relativePath, "^[\\/]+", "", "all" );

        if ( !len(normalizedRelative) ) {
            return "";
        }

        if ( find("..", normalizedRelative) ) {
            return "";
        }

        return variables.localSourceDirAbsolute & normalizedRelative;
    }

    private string function _getSourceProvider() {
        var provider = lCase( trim(variables.AppConfigService.getValue("dropbox.source_provider", "local")) );
        return provider EQ "dropbox" ? "dropbox" : "local";
    }

    private boolean function _pathIsUnderDropboxRoot( required string candidatePath ) {
        var rootPath = _normalizeSlashPath( variables.AppConfigService.getValue("dropbox.root_folder", "") );
        var candidate = _normalizeSlashPath( arguments.candidatePath );

        if ( !len(candidate) ) {
            return false;
        }

        if ( !len(rootPath) OR rootPath EQ "/" ) {
            return true;
        }

        if ( candidate EQ rootPath ) {
            return true;
        }

        return left(candidate, len(rootPath) + 1) EQ (rootPath & "/");
    }

    private string function _normalizeSlashPath( required string rawPath ) {
        var p = trim( arguments.rawPath );

        if ( !len(p) ) {
            return "";
        }

        p = urlDecode(p);
        p = replace( p, "\\", "/", "all" );
        p = reReplace( p, "/+", "/", "all" );

        if ( left(p, 1) NEQ "/" ) {
            p = "/" & p;
        }

        if ( len(p) GT 1 AND right(p, 1) EQ "/" ) {
            p = left(p, len(p) - 1);
        }

        return p;
    }


    // ── Private: variant side-effect ─────────────────────────────────────────

    /**
     * Build the set of lowercase filename tokens to match against for a user.
     * Tokens are derived from name combinations and all external ID values.
     */
    private array function _buildUserTokens(
        required string firstName,
        required string lastName,
        string  middleName = "",
        required array  externalIDs
    ) {
        var tokens  = [];
        var first   = lCase( trim(arguments.firstName) );
        var last    = lCase( trim(arguments.lastName) );
        var middle  = lCase( trim(arguments.middleName) );
        var fi      = len(first)  ? left(first, 1)  : "";
        var mi      = len(middle) ? left(middle, 1) : "";

        // Build a replacement map for pattern tokens
        var tokenMap = {
            "{first}"  = first,
            "{last}"   = last,
            "{middle}" = middle,
            "{fi}"     = fi,
            "{mi}"     = mi
        };

        // Load patterns from DB
        var patterns = variables.PatternDAO.getActivePatterns();

        for ( var p in patterns ) {
            var resolved = lCase( trim(p.PATTERN) );

            // Replace all known tokens
            for ( var key in tokenMap ) {
                resolved = replaceNoCase( resolved, key, tokenMap[key], "all" );
            }

            // Skip if any unresolved token remains or required fields were empty
            if ( find("{", resolved) OR !len(resolved) ) {
                continue;
            }

            // Deduplicate
            if ( !arrayFindNoCase(tokens, resolved) ) {
                arrayAppend( tokens, resolved );
            }
        }

        // External ID values (CougarNet username, PeopleSoft ID, etc.)
        for ( var extID in arguments.externalIDs ) {
            var extVal = lCase( trim(extID.EXTERNALVALUE ?: "") );
            if ( len(extVal) GTE 3 AND !arrayFindNoCase(tokens, extVal) ) {
                arrayAppend( tokens, extVal );
            }
        }

        return tokens;
    }

    /**
     * Return true if the filename stem (no extension) contains any token.
     * Minimum token length of 3 prevents single-letter false positives.
     */
    private boolean function _filenameMatchesTokens(
        required string filename,
        required array  tokens
    ) {
        // Strip extension to get just the stem
        var dotPos = find( ".", reverse(arguments.filename) );
        var stem   = dotPos ? lCase( left(arguments.filename, len(arguments.filename) - dotPos) ) : lCase(arguments.filename);

        for ( var token in arguments.tokens ) {
            if ( len(token) GTE 3 AND findNoCase(token, stem) ) {
                return true;
            }
        }
        return false;
    }

    // ── Private: variant side-effect ─────────────────────────────────────────

    /**
     * Marks all variants for a user+sourceKey as STALE via the DAO.
     * Wrapped in try/catch so a missing UserImageVariants table does not
     * break the POC — remove the catch once that table exists.
     *
     * Variants are NEVER regenerated automatically.
     * Regeneration is always an explicit admin action.
     */
    private void function _markVariantsStale(
        required numeric userID,
        required string  sourceKey
    ) {
        try {
            variables.SourceDAO.markVariantsStale( arguments.userID, arguments.sourceKey );
        } catch (any e) {
            // POC: UserImageVariants table may not yet exist — silently ignore.
            // Remove this catch block once the variants table is in place.
        }
    }

}
