component output="false" singleton {

    variables.sourceWebDir        = "/_temp_source/";
    variables.publishedWebDir     = "/_published_images/";
    variables.allowedExtensions   = ["jpg", "jpeg", "png"];
    variables.defaultSourceKey    = "alumni";
    variables.defaultVariantCode  = "interactive_roster";

    public any function init() {
        variables.UsersDAO     = createObject("component", "dao.users_DAO").init();
        variables.UsersService = createObject("component", "cfc.users_service").init();
        variables.ExternalIDsDAO = createObject("component", "dao.externalIDs_DAO").init();
        variables.PatternDAO   = createObject("component", "dao.FileNamePatternDAO").init();
        variables.SourceDAO    = createObject("component", "dao.UserImageSourceDAO").init();
        variables.VariantDAO   = createObject("component", "dao.UserImageVariantDAO").init();
        variables.ImagesDAO    = createObject("component", "dao.images_DAO").init();
        variables.MediaConfigService = createObject("component", "cfc.mediaConfig_service").init();
        variables.SourceService = createObject("component", "cfc.UserImageSourceService").init();

        var cfcDir = getDirectoryFromPath( getCurrentTemplatePath() );
        var jFile = createObject("java", "java.io.File");

        variables.sourceDirAbsolute = jFile.init( cfcDir & "..\..\_temp_source" ).getCanonicalPath() & "\";
        variables.publishedDirAbsolute = jFile.init( cfcDir & "..\..\_published_images" ).getCanonicalPath() & "\";

        return this;
    }

    public array function getSourceKeys() {
        return variables.SourceService.getSourceKeys();
    }

    public array function getTransferOnlyVariantTypes() {
        var allowed = [];
        var variantTypes = variables.VariantDAO.getVariantTypesAll();

        for ( var variantType in variantTypes ) {
            if ( lCase(trim(variantType.MODE ?: "resize_only")) NEQ "passthrough" ) {
                continue;
            }

            arrayAppend(allowed, variantType);
        }

        return allowed;
    }

    public string function getDefaultSourceKey() {
        return variables.defaultSourceKey;
    }

    public string function getDefaultVariantCode() {
        return variables.defaultVariantCode;
    }

    public struct function searchFolder(
        required string folderName,
        string sourceKey = "",
        string variantCode = "",
        boolean includeTransferred = false,
        boolean includeAmbiguous = false,
        numeric limit = 25
    ) {
        var cleanFolder = trim( arguments.folderName );
        var cleanSourceKey = _normalizeSourceKey( arguments.sourceKey ?: "" );
        var cleanVariantCode = _normalizeVariantCode( arguments.variantCode ?: "" );
        var transferVariant = _resolveTargetVariantType( cleanVariantCode );
        var visibleLimit = max( 1, min( int(val(arguments.limit ?: 25)), 100 ) );
        var tokenProfiles = [];
        var results = [];
        var transferCache = {};
        var totalFolderMatches = 0;
        var transferredHiddenCount = 0;
        var ambiguousHiddenCount = 0;
        var limitedResults = [];

        if ( !len(cleanFolder) ) {
            return { success=false, message="Folder name is required.", data=[] };
        }

        if ( !len(cleanSourceKey) ) {
            return { success=false, message="A valid source key is required.", data=[] };
        }

        if ( structIsEmpty(transferVariant) ) {
            return { success=false, message="A valid transfer-only variant is required.", data=[] };
        }

        if ( find("..", cleanFolder) OR find(":", cleanFolder) ) {
            return { success=false, message="Folder name contains invalid path characters.", data=[] };
        }

        if ( !directoryExists(variables.sourceDirAbsolute) ) {
            return { success=false, message="Source directory does not exist: #variables.sourceDirAbsolute#", data=[] };
        }

        tokenProfiles = _buildUserTokenProfiles();

        var entries = directoryList( variables.sourceDirAbsolute, true, "query" );
        for ( var row in entries ) {
            if ( lCase(row.type) NEQ "file" ) {
                continue;
            }

            var ext = lCase( listLast(row.name, ".") );
            if ( !arrayFindNoCase(variables.allowedExtensions, ext) ) {
                continue;
            }

            var relativeDiskPath = _buildRelativeDiskPath( row.directory, row.name );
            var relativeFolder = getDirectoryFromPath( replace(relativeDiskPath, "\\", "/", "all") );
            if ( right(relativeFolder, 1) EQ "/" ) {
                relativeFolder = left( relativeFolder, len(relativeFolder) - 1 );
            }

            if ( !_folderFilterMatches(relativeFolder, cleanFolder) ) {
                continue;
            }

            totalFolderMatches++;

            var sourcePath = variables.sourceWebDir & replace(relativeDiskPath, "\\", "/", "all");
            var matchInfo = _matchFileToUser( row.name, tokenProfiles, transferVariant );

            if ( matchInfo.matchStatus EQ "ambiguous" AND !arguments.includeAmbiguous ) {
                ambiguousHiddenCount++;
                continue;
            }

            var transferInfo = _getTransferInfo(
                userID        = matchInfo.userID,
                sourcePath    = sourcePath,
                sourceKey     = cleanSourceKey,
                variantCode   = matchInfo.variantCode,
                transferCache = transferCache
            );

            if ( transferInfo.isTransferred AND !arguments.includeTransferred ) {
                transferredHiddenCount++;
                continue;
            }

            arrayAppend(results, {
                filename        = row.name,
                sourcePath      = sourcePath,
                relativeFolder  = relativeFolder,
                matchStatus     = matchInfo.matchStatus,
                userID          = matchInfo.userID,
                userDisplayName = matchInfo.userDisplayName,
                userEmail       = matchInfo.userEmail,
                matchedBy       = matchInfo.matchedBy,
                candidateText   = matchInfo.candidateText,
                canTransfer     = matchInfo.canTransfer AND !transferInfo.isTransferred,
                variantCode     = matchInfo.variantCode,
                isTransferred   = transferInfo.isTransferred,
                sourceID        = transferInfo.sourceID,
                transferLabel   = transferInfo.isTransferred ? "Transfered" : ""
            });
        }

        arraySort(results, function(a, b) {
            if ( a.isTransferred AND !b.isTransferred ) {
                return 1;
            }
            if ( !a.isTransferred AND b.isTransferred ) {
                return -1;
            }

            var statusOrder = { matched = 1, ambiguous = 2, none = 3 };
            var aRank = structKeyExists(statusOrder, a.matchStatus) ? statusOrder[a.matchStatus] : 9;
            var bRank = structKeyExists(statusOrder, b.matchStatus) ? statusOrder[b.matchStatus] : 9;

            if ( aRank LT bRank ) {
                return -1;
            }
            if ( aRank GT bRank ) {
                return 1;
            }

            return compareNoCase( a.filename, b.filename );
        });

        for ( var i = 1; i <= min(arrayLen(results), visibleLimit); i++ ) {
            arrayAppend(limitedResults, results[i]);
        }

        return {
            success = true,
            message = _buildSearchMessage(
                totalFolderMatches      = totalFolderMatches,
                visibleCount            = arrayLen(limitedResults),
                totalVisibleCount       = arrayLen(results),
                transferredHiddenCount  = transferredHiddenCount,
                ambiguousHiddenCount    = ambiguousHiddenCount,
                visibleLimit            = visibleLimit,
                includeTransferred      = arguments.includeTransferred,
                includeAmbiguous        = arguments.includeAmbiguous
            ),
            data = limitedResults
        };
    }

    public struct function transferImage(
        required numeric userID,
        required string sourcePath,
        string sourceKey = "",
        string variantCode = ""
    ) {
        var cleanSourcePath = trim( arguments.sourcePath );
        var cleanSourceKey = _normalizeSourceKey( arguments.sourceKey ?: "" );
        var cleanVariantCode = _normalizeVariantCode( arguments.variantCode ?: "" );
        var sourceAbsolutePath = _resolveSourceAbsolutePath( cleanSourcePath );
        var userResult = variables.UsersService.getUser( arguments.userID );
        var variantType = _resolveTargetVariantType( cleanVariantCode );
        var sourceResult = {};
        var variantRecord = {};
        var publishedFilename = "";
        var publishedAbsolute = "";
        var publishedUrl = "";
        var dimensions = "";
        var outputExtension = "";

        if ( !len(sourceAbsolutePath) OR !fileExists(sourceAbsolutePath) ) {
            return { success=false, message="Source file not found in _temp_source.", sourceID=0, userID=arguments.userID };
        }

        if ( !userResult.success ) {
            return { success=false, message="User not found.", sourceID=0, userID=arguments.userID };
        }

        if ( !len(cleanSourceKey) ) {
            return { success=false, message="A valid source key is required.", sourceID=0, userID=arguments.userID };
        }

        if ( structIsEmpty(variantType) ) {
            return {
                success = false,
                message = "Selected target variant type was not found or is not transfer-only.",
                sourceID = 0,
                userID = arguments.userID
            };
        }

        sourceResult = _ensureSourceRecord(
            userID     = arguments.userID,
            sourceKey  = cleanSourceKey,
            sourcePath = cleanSourcePath
        );
        if ( !sourceResult.success ) {
            return sourceResult;
        }

        variables.VariantDAO.upsertVariantAssignment(
            userImageSourceID  = sourceResult.sourceID,
            imageVariantTypeID = val(variantType.IMAGEVARIANTTYPEID)
        );

        variantRecord = variables.VariantDAO.getVariantBySourceAndType(
            userImageSourceID  = sourceResult.sourceID,
            imageVariantTypeID = val(variantType.IMAGEVARIANTTYPEID)
        );
        if ( structIsEmpty(variantRecord) ) {
            return {
                success = false,
                message = "Could not create or load the variant assignment.",
                sourceID = sourceResult.sourceID,
                userID = arguments.userID
            };
        }

        if ( !directoryExists(variables.publishedDirAbsolute) ) {
            directoryCreate( variables.publishedDirAbsolute );
        }

        outputExtension = _resolveOutputExtension( variantType, cleanSourcePath );
        publishedFilename = _buildPublishedFilename(
            user              = userResult.data,
            variantCode       = variantType.CODE,
            outputExtension   = outputExtension,
            userImageSourceID = sourceResult.sourceID
        );
        publishedAbsolute = variables.publishedDirAbsolute & publishedFilename;
        publishedUrl      = variables.MediaConfigService.buildPublishedUrl( publishedFilename );

        _writePublishedImage(
            sourceAbsolutePath = sourceAbsolutePath,
            publishedAbsolute  = publishedAbsolute,
            outputExtension    = outputExtension
        );

        dimensions = _buildImageDimensions( publishedAbsolute );

        variables.ImagesDAO.upsertPublishedImage(
            userID             = arguments.userID,
            imageVariant       = variantType.CODE,
            imageURL           = publishedUrl,
            imageDescription   = _buildDescription( userResult.data, variantType.DESCRIPTION ?: variantType.CODE ),
            imageDimensions    = dimensions,
            sortOrder          = 0,
            userImageSourceID  = sourceResult.sourceID
        );

        variables.VariantDAO.updateVariantGenerated(
            userImageVariantID = val(variantRecord.USERIMAGEVARIANTID),
            localPath          = ""
        );

        return {
            success      = true,
            message      = "Transferred and published #listLast(cleanSourcePath, '/\\')# for #userResult.data.FIRSTNAME# #userResult.data.LASTNAME#.",
            sourceID     = sourceResult.sourceID,
            userID       = arguments.userID,
            variantCode  = variantType.CODE,
            publishedUrl = publishedUrl
        };
    }

    private array function _buildUserTokenProfiles() {
        var users = variables.UsersDAO.getAllUsers();
        var allExternalIDs = variables.ExternalIDsDAO.getAllExternalIDs();
        var patterns = variables.PatternDAO.getActivePatterns();
        var externalIDsByUser = {};
        var result = [];

        for ( var extRow in allExternalIDs ) {
            var userKey = toString( extRow.USERID );
            if ( !structKeyExists(externalIDsByUser, userKey) ) {
                externalIDsByUser[userKey] = [];
            }

            if ( len(trim(extRow.EXTERNALVALUE ?: "")) ) {
                arrayAppend( externalIDsByUser[userKey], extRow.EXTERNALVALUE );
            }
        }

        for ( var user in users ) {
            var isActive = isBoolean(user.ACTIVE ?: "") ? user.ACTIVE : (val(user.ACTIVE ?: 0) EQ 1);
            if ( !isActive ) {
                continue;
            }

            var key = toString( user.USERID );
            var tokens = _buildUserTokens(
                firstName   = user.FIRSTNAME ?: "",
                lastName    = user.LASTNAME ?: "",
                middleName  = user.MIDDLENAME ?: "",
                externalIDs = structKeyExists(externalIDsByUser, key) ? externalIDsByUser[key] : [],
                patterns    = patterns
            );

            arrayAppend(result, {
                userID        = user.USERID,
                userDisplayName = trim( (user.FIRSTNAME ?: "") & " " & (user.LASTNAME ?: "") ),
                userEmail     = user.EMAILPRIMARY ?: "",
                tokens        = tokens
            });
        }

        return result;
    }

    private struct function _getTransferInfo(
        required numeric userID,
        required string sourcePath,
        required string sourceKey,
        required string variantCode,
        required struct transferCache
    ) {
        var lookupKey = _buildTransferLookupKey(arguments.userID, arguments.sourceKey, arguments.variantCode, arguments.sourcePath);
        var sourceID = 0;
        var context = {};

        if ( !structKeyExists(arguments.transferCache, "items") ) {
            arguments.transferCache.items = {};
        }
        if ( !structKeyExists(arguments.transferCache, "contexts") ) {
            arguments.transferCache.contexts = {};
        }

        if ( structKeyExists(arguments.transferCache.items, lookupKey) ) {
            return arguments.transferCache.items[ lookupKey ];
        }

        if ( arguments.userID GT 0 AND len(arguments.variantCode) AND len(arguments.sourceKey) ) {
            context = _getTransferContext(
                userID        = arguments.userID,
                sourceKey     = arguments.sourceKey,
                variantCode   = arguments.variantCode,
                transferCache = arguments.transferCache
            );
            if ( structKeyExists(context.sourceMap, lCase(trim(arguments.sourcePath))) ) {
                sourceID = context.sourceMap[ lCase(trim(arguments.sourcePath)) ];
            }

            arguments.transferCache.items[ lookupKey ] = {
                isTransferred = (sourceID GT 0 AND structKeyExists(context.transferredSourceIDs, toString(sourceID))),
                sourceID = sourceID
            };
            return arguments.transferCache.items[ lookupKey ];
        }

        return {
            isTransferred = false,
            sourceID = 0
        };
    }

    private string function _buildTransferLookupKey(
        required numeric userID,
        required string sourceKey,
        required string variantCode,
        required string sourcePath
    ) {
        return arguments.userID & "|" & lCase(trim(arguments.sourceKey)) & "|" & lCase(trim(arguments.variantCode)) & "|" & lCase( trim(arguments.sourcePath) );
    }

    private struct function _getTransferContext(
        required numeric userID,
        required string sourceKey,
        required string variantCode,
        required struct transferCache
    ) {
        var contextKey = arguments.userID & "|" & lCase(trim(arguments.sourceKey)) & "|" & lCase(trim(arguments.variantCode));
        var sources = [];
        var images = [];
        var sourceMap = {};
        var transferredSourceIDs = {};

        if ( structKeyExists(arguments.transferCache.contexts, contextKey) ) {
            return arguments.transferCache.contexts[ contextKey ];
        }

        sources = variables.SourceDAO.getSourcesForUser( arguments.userID );
        images = variables.ImagesDAO.getImages( arguments.userID );

        for ( var sourceRow in sources ) {
            if ( compareNoCase(sourceRow.SOURCEKEY ?: "", arguments.sourceKey) NEQ 0 ) {
                continue;
            }

            if ( len(trim(sourceRow.DROPBOXPATH ?: "")) ) {
                sourceMap[ lCase(trim(sourceRow.DROPBOXPATH)) ] = val(sourceRow.USERIMAGESOURCEID ?: 0);
            }
        }

        for ( var imageRow in images ) {
            if ( compareNoCase(imageRow.IMAGEVARIANT ?: "", arguments.variantCode) EQ 0
                AND val(imageRow.USERIMAGESOURCEID ?: 0) GT 0 ) {
                transferredSourceIDs[ toString(val(imageRow.USERIMAGESOURCEID)) ] = true;
            }
        }

        arguments.transferCache.contexts[ contextKey ] = {
            sourceMap = sourceMap,
            transferredSourceIDs = transferredSourceIDs
        };

        return arguments.transferCache.contexts[ contextKey ];
    }

    private struct function _matchFileToUser(
        required string filename,
        required array tokenProfiles,
        required struct variantType
    ) {
        var stem = lCase( reReplace(arguments.filename, "\.[^.]+$", "", "one") );
        var candidates = [];

        for ( var profile in arguments.tokenProfiles ) {
            var matchedTokens = [];
            var score = 0;
            var longestToken = 0;

            for ( var token in profile.tokens ) {
                if ( len(token) GTE 3 AND findNoCase(token, stem) ) {
                    arrayAppend(matchedTokens, token);
                    score += len(token);
                    if ( len(token) GT longestToken ) {
                        longestToken = len(token);
                    }
                }
            }

            if ( arrayLen(matchedTokens) ) {
                arrayAppend(candidates, {
                    userID          = profile.userID,
                    userDisplayName = profile.userDisplayName,
                    userEmail       = profile.userEmail,
                    matchedTokens   = matchedTokens,
                    score           = score,
                    longestToken    = longestToken
                });
            }
        }

        if ( !arrayLen(candidates) ) {
            return {
                status        = "none",
                matchStatus   = "none",
                userID        = 0,
                userDisplayName = "",
                userEmail     = "",
                matchedBy     = "",
                candidateText = "No user token matched this filename.",
                canTransfer   = false,
                variantCode   = structIsEmpty(arguments.variantType) ? "" : arguments.variantType.CODE
            };
        }

        arraySort(candidates, function(a, b) {
            if ( a.score GT b.score ) {
                return -1;
            }
            if ( a.score LT b.score ) {
                return 1;
            }
            if ( a.longestToken GT b.longestToken ) {
                return -1;
            }
            if ( a.longestToken LT b.longestToken ) {
                return 1;
            }
            return compareNoCase( a.userDisplayName, b.userDisplayName );
        });

        var topCandidate = candidates[1];
        var topCount = 0;
        for ( var candidate in candidates ) {
            if ( candidate.score EQ topCandidate.score AND candidate.longestToken EQ topCandidate.longestToken ) {
                topCount++;
            }
        }

        if ( topCount GT 1 ) {
            var ambiguousNames = [];
            for ( var i = 1; i LTE min(arrayLen(candidates), 3); i++ ) {
                arrayAppend(ambiguousNames, candidates[i].userDisplayName);
            }

            return {
                status          = "ambiguous",
                userID          = 0,
                userDisplayName = "",
                userEmail       = "",
                matchedBy       = arrayToList(topCandidate.matchedTokens, ", "),
                candidateText   = "Ambiguous match: #arrayToList(ambiguousNames, ', ')#",
                canTransfer     = false,
                variantCode     = structIsEmpty(arguments.variantType) ? "" : arguments.variantType.CODE,
                matchStatus     = "ambiguous"
            };
        }

        return {
            status          = "matched",
            userID          = topCandidate.userID,
            userDisplayName = topCandidate.userDisplayName,
            userEmail       = topCandidate.userEmail,
            matchedBy       = arrayToList(topCandidate.matchedTokens, ", "),
            candidateText   = "",
            canTransfer     = !structIsEmpty(arguments.variantType),
            variantCode     = structIsEmpty(arguments.variantType) ? "" : arguments.variantType.CODE,
            matchStatus     = "matched"
        };
    }

    private array function _buildUserTokens(
        required string firstName,
        required string lastName,
        string middleName = "",
        required array externalIDs,
        required array patterns
    ) {
        var tokens = [];
        var first = lCase( trim(arguments.firstName) );
        var last = lCase( trim(arguments.lastName) );
        var middle = lCase( trim(arguments.middleName) );
        var fi = len(first) ? left(first, 1) : "";
        var mi = len(middle) ? left(middle, 1) : "";
        var tokenMap = {
            "{first}" = first,
            "{last}"  = last,
                    matchStatus   = "none",
            "{middle}" = middle,
            "{fi}"    = fi,
            "{mi}"    = mi
        };

        for ( var patternRow in arguments.patterns ) {
            var resolved = lCase( trim(patternRow.PATTERN ?: "") );
            for ( var tokenKey in tokenMap ) {
                resolved = replaceNoCase( resolved, tokenKey, tokenMap[tokenKey], "all" );
            }

            if ( find("{", resolved) OR !len(resolved) OR len(resolved) LT 3 ) {
                continue;
            }

            if ( !arrayFindNoCase(tokens, resolved) ) {
                arrayAppend(tokens, resolved);
            }
        }

        for ( var externalValue in arguments.externalIDs ) {
            var cleanedValue = lCase( trim(externalValue ?: "") );
            if ( len(cleanedValue) GTE 3 AND !arrayFindNoCase(tokens, cleanedValue) ) {
                arrayAppend(tokens, cleanedValue);
            }
        }

        return tokens;
    }

    private struct function _resolveTargetVariantType( string variantCode = "" ) {
        var variantTypes = getTransferOnlyVariantTypes();
        var requestedCode = _normalizeVariantCode( arguments.variantCode ?: "" );

        if ( len(requestedCode) ) {
            for ( var variantType in variantTypes ) {
                if ( compareNoCase(variantType.CODE ?: "", requestedCode) EQ 0 ) {
                    return variantType;
                }
            }
            return {};
        }

        for ( var variantType in variantTypes ) {
            if ( compareNoCase(variantType.CODE ?: "", variables.defaultVariantCode) EQ 0 ) {
                return variantType;
            }
        }

        if ( arrayLen(variantTypes) ) {
            return variantTypes[1];
        }

        return {};
    }

    private string function _normalizeSourceKey( required string sourceKey ) {
        var cleanKey = lCase( trim(arguments.sourceKey) );
        var availableKeys = getSourceKeys();

        if ( !len(cleanKey) ) {
            cleanKey = variables.defaultSourceKey;
        }

        if ( arrayFindNoCase(availableKeys, cleanKey) ) {
            return cleanKey;
        }

        return "";
    }

    private string function _normalizeVariantCode( required string variantCode ) {
        var cleanCode = trim(arguments.variantCode);

        if ( !len(cleanCode) ) {
            cleanCode = variables.defaultVariantCode;
        }

        return cleanCode;
    }

    private boolean function _isTruthy( any value ) {
        if ( isBoolean(arguments.value) ) {
            return arguments.value;
        }

        if ( isNumeric(arguments.value ?: "") ) {
            return val(arguments.value) NEQ 0;
        }

        return listFindNoCase("true,yes,on", trim(arguments.value ?: "")) GT 0;
    }

    private string function _buildSearchMessage(
        required numeric totalFolderMatches,
        required numeric visibleCount,
        required numeric totalVisibleCount,
        required numeric transferredHiddenCount,
        required numeric ambiguousHiddenCount,
        required numeric visibleLimit,
        required boolean includeTransferred,
        required boolean includeAmbiguous
    ) {
        var parts = [];

        if ( arguments.totalFolderMatches EQ 0 ) {
            return "No images found for that folder name.";
        }

        arrayAppend(parts, "Found #arguments.totalFolderMatches# image(s) in matching folder path(s).");
        arrayAppend(parts, "Showing #arguments.visibleCount# result(s)");

        if ( arguments.totalVisibleCount GT arguments.visibleLimit ) {
            arrayAppend(parts, "limited to the first #arguments.visibleLimit# after filtering");
        }

        if ( !arguments.includeTransferred AND arguments.transferredHiddenCount GT 0 ) {
            arrayAppend(parts, "#arguments.transferredHiddenCount# already transferred hidden");
        }

        if ( !arguments.includeAmbiguous AND arguments.ambiguousHiddenCount GT 0 ) {
            arrayAppend(parts, "#arguments.ambiguousHiddenCount# ambiguous hidden");
        }

        return arrayToList(parts, " | ");
    }

    private struct function _ensureSourceRecord(
        required numeric userID,
        required string sourceKey,
        required string sourcePath
    ) {
        var sources = variables.SourceDAO.getSourcesForUser( arguments.userID );

        for ( var sourceRow in sources ) {
            if ( compareNoCase(trim(sourceRow.SOURCEKEY ?: ""), trim(arguments.sourceKey)) EQ 0
                AND trim(sourceRow.DROPBOXPATH ?: "") EQ trim(arguments.sourcePath) ) {
                var isActive = isBoolean(sourceRow.ISACTIVE ?: "") ? sourceRow.ISACTIVE : (val(sourceRow.ISACTIVE ?: 0) EQ 1);
                if ( !isActive ) {
                    variables.SourceDAO.setActiveStatus( val(sourceRow.USERIMAGESOURCEID), true );
                }

                return {
                    success = true,
                    message = "Source record ready.",
                    sourceID = val(sourceRow.USERIMAGESOURCEID),
                    userID = arguments.userID
                };
            }
        }

        return {
            success = true,
            message = "Source record created.",
            sourceID = variables.SourceDAO.insertSource({
                UserID     = arguments.userID,
                SourceKey  = arguments.sourceKey,
                SourcePath = arguments.sourcePath
            }),
            userID = arguments.userID
        };
    }

    private string function _resolveSourceAbsolutePath( required string sourcePath ) {
        var relativePath = trim( arguments.sourcePath );
        var normalizedRelative = "";

        if ( left(relativePath, len(variables.sourceWebDir)) NEQ variables.sourceWebDir ) {
            return "";
        }

        relativePath = mid( relativePath, len(variables.sourceWebDir) + 1, len(relativePath) );
        relativePath = replace( relativePath, "/", "\\", "all" );
        normalizedRelative = reReplace( relativePath, "^[\\/]+", "", "all" );

        if ( !len(normalizedRelative) OR find("..", normalizedRelative) ) {
            return "";
        }

        return variables.sourceDirAbsolute & normalizedRelative;
    }

    private string function _buildRelativeDiskPath(
        required string directoryPath,
        required string filename
    ) {
        var fullPath = arguments.directoryPath & "\\" & arguments.filename;
        var relativePath = replaceNoCase( fullPath, variables.sourceDirAbsolute, "", "one" );
        return reReplace( relativePath, "^[\\/]+", "", "all" );
    }

    private boolean function _folderFilterMatches(
        required string relativeDirectory,
        required string folderName
    ) {
        var normalizedPath = lCase( replace(arguments.relativeDirectory, "/", "\\", "all") );
        var searchTerm = lCase( trim(arguments.folderName) );
        var pathSegments = [];

        if ( !len(searchTerm) ) {
            return false;
        }

        if ( !len(normalizedPath) ) {
            return false;
        }

        pathSegments = listToArray( normalizedPath, "\\" );
        for ( var segment in pathSegments ) {
            if ( compareNoCase(trim(segment), searchTerm) EQ 0 ) {
                return true;
            }
        }

        return false;
    }

    private string function _resolveOutputExtension(
        required struct variantType,
        required string sourcePath
    ) {
        var outputExtension = lCase( trim(arguments.variantType.OUTPUTFORMAT ?: "") );

        if ( outputExtension EQ "jpeg" ) {
            outputExtension = "jpg";
        }

        if ( !listFindNoCase("jpg,png", outputExtension) ) {
            outputExtension = lCase( listLast(arguments.sourcePath, ".") );
            if ( outputExtension EQ "jpeg" ) {
                outputExtension = "jpg";
            }
        }

        return outputExtension;
    }

    private void function _writePublishedImage(
        required string sourceAbsolutePath,
        required string publishedAbsolute,
        required string outputExtension
    ) {
        var sourceExtension = lCase( listLast(arguments.sourceAbsolutePath, ".") );

        if ( sourceExtension EQ "jpeg" ) {
            sourceExtension = "jpg";
        }

        if ( fileExists(arguments.publishedAbsolute) ) {
            fileDelete(arguments.publishedAbsolute);
        }

        if ( sourceExtension EQ arguments.outputExtension ) {
            fileCopy(arguments.sourceAbsolutePath, arguments.publishedAbsolute);
            return;
        }

        var sourceImage = imageRead(arguments.sourceAbsolutePath);
        if ( arguments.outputExtension EQ "jpg" ) {
            cfimage(
                action = "write",
                source = sourceImage,
                destination = arguments.publishedAbsolute,
                overwrite = true,
                quality = 0.75
            );
        } else {
            cfimage(
                action = "write",
                source = sourceImage,
                destination = arguments.publishedAbsolute,
                overwrite = true
            );
        }
    }

    private string function _buildImageDimensions( required string imagePath ) {
        var img = imageRead(arguments.imagePath);
        return imageGetWidth(img) & "x" & imageGetHeight(img);
    }

    private string function _buildPublishedFilename(
        required struct user,
        required string variantCode,
        required string outputExtension,
        required numeric userImageSourceID
    ) {
        return variables.MediaConfigService.buildPublishedFilename(
            user              = arguments.user,
            variantCode       = arguments.variantCode,
            extension         = arguments.outputExtension,
            userImageSourceID = arguments.userImageSourceID
        );
    }

    private string function _buildDescription(
        required struct user,
        required string variantDescription
    ) {
        var parts = [];
        var firstName = trim(arguments.user.FIRSTNAME ?: "");
        var middleName = trim(arguments.user.MIDDLENAME ?: "");
        var lastName = trim(arguments.user.LASTNAME ?: "");

        if ( len(firstName) ) {
            arrayAppend(parts, firstName);
        }
        if ( len(middleName) ) {
            arrayAppend(parts, left(middleName, 1) & ".");
        }
        if ( len(lastName) ) {
            arrayAppend(parts, lastName);
        }
        if ( len(trim(arguments.variantDescription)) ) {
            arrayAppend(parts, trim(arguments.variantDescription));
        }
        arrayAppend(parts, "Image");

        return arrayToList(parts, " ");
    }

}