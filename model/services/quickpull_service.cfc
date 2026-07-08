component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.quickpull_DAO").init();
        variables.nameResolutionService = createObject("component", "cfc.nameResolution_service").init();
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.directoryService = createObject("component", "cfc.directory_service").init();
        variables.phoneDAO = createObject("component", "dao.phone_DAO").init();
        variables.emailDAO = createObject("component", "dao.emails_DAO").init();
        variables.addressDAO = createObject("component", "dao.addresses_DAO").init();
        variables.imageVariantDAO = createObject("component", "dao.UserImageVariantDAO").init();
        variables.externalIDService = createObject("component", "cfc.externalID_service").init();
        return this;
    }

    public array function getQuickpullDefinitions() {
        return [
            {
                key = "attending",
                label = "Attending",
                endpoint = "/api/v1/quickpulls/attending",
                description = "Clinical attending list.",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "DEGREES", "FULLNAME"]
            },
            {
                key = "gradclass",
                label = "GradClass",
                endpoint = "/api/v1/quickpulls/gradclass",
                description = "Graduation class list filtered by year and program with combined DEGREES and flattened AWARDNAME fields.",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "FULLNAME", "PROGRAM", "KIOSKROSTERIMAGE", "KIOSKPROFILEIMAGE", "FIRSTEXTERNSHIP", "SECONDEXTERNSHIP", "HOMETOWNFULL", "DEGREES", "AWARDNAME1"]
            },
            {
                key = "graduate",
                label = "Graduate",
                endpoint = "/api/v1/quickpulls/graduate",
                description = "Single graduate profile quickpull.",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "DEGREES", "AWARDS", "INTERACTIVEUSERIMAGE", "KIOSKROSTERIMAGE", "KIOSKPROFILEIMAGE"]
            },
            {
                key = "deans",
                label = "Deans",
                endpoint = "/api/v1/quickpulls/deans",
                description = "Dean roster quickpull.",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "TITLE1", "FULLNAME", "KIOSKNONGRIDIMAGE"]
            },
            {
                key = "myuhco",
                label = "MyUHCO",
                endpoint = "/api/v1/quickpulls/myuhco",
                description = "MyUHCO portal profile lookup by external ID (UH_API_ID, COUGARNET, or PEOPLESOFT).",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "DEGREES", "FULLNAME", "FLAGS", "ORGANIZATIONS", "CURRENTGRADYEAR", "WEBPROFILEIMAGE", "WEBTHUMBIMAGE"]
            }
        ];
    }

    public struct function getQuickpullDefinition( required string quickpullType ) {
        for ( var definition in getQuickpullDefinitions() ) {
            if ( definition.key EQ lCase(arguments.quickpullType) ) {
                return duplicate(definition);
            }
        }
        return {};
    }

    public struct function getQuickpullConfig( required string quickpullType ) {
        return duplicate( _getQuickpullConfig(arguments.quickpullType) );
    }

    public struct function getQuickpullEditModel( required string quickpullType ) {
        var definition = getQuickpullDefinition(arguments.quickpullType);
        var biographicalOptions = _getBiographicalOptions();
        if ( structIsEmpty(definition) ) {
            return {};
        }

        if ( lCase(arguments.quickpullType) EQ "gradclass" ) {
            biographicalOptions = _withoutOptionValue(biographicalOptions, "CURRENTGRADYEAR");
        }

        return {
            quickpull = definition,
            config = getQuickpullConfig(arguments.quickpullType),
            options = {
                generalFields = _getGeneralFieldOptions(),
                emailTypes = _getEmailTypeOptions(),
                phoneTypes = _getPhoneTypeOptions(),
                addressTypes = _getAddressTypeOptions(),
                biographicalItems = biographicalOptions,
                imageVariants = _getImageVariantOptions(),
                externalSystems = _getExternalSystemOptions()
            }
        };
    }

    public struct function normalizeQuickpullConfig( required struct submittedConfig, string quickpullType = "" ) {
        var normalized = _getDefaultQuickpullConfig();
        var allowedGeneral = _getAllowedValueSet( _getGeneralFieldOptions() );
        var allowedEmails = _getAllowedValueSet( _getEmailTypeOptions() );
        var allowedPhones = _getAllowedValueSet( _getPhoneTypeOptions() );
        var allowedAddresses = _getAllowedValueSet( _getAddressTypeOptions() );
        var allowedBio = _getAllowedValueSet( _getBiographicalOptions() );
        var allowedImages = _getAllowedValueSet( _getImageVariantOptions() );
        var allowedExternal = _getAllowedValueSet( _getExternalSystemOptions() );

        normalized.generalFields = _sanitizeSelections(arguments.submittedConfig.generalFields ?: [], allowedGeneral);
        normalized.emailTypes = _sanitizeSelections(arguments.submittedConfig.emailTypes ?: [], allowedEmails);
        normalized.phoneTypes = _sanitizeSelections(arguments.submittedConfig.phoneTypes ?: [], allowedPhones);
        normalized.addressTypes = _sanitizeSelections(arguments.submittedConfig.addressTypes ?: [], allowedAddresses);
        normalized.biographicalItems = _sanitizeSelections(arguments.submittedConfig.biographicalItems ?: [], allowedBio);
        normalized.imageVariants = _sanitizeSelections(arguments.submittedConfig.imageVariants ?: [], allowedImages);
        normalized.externalSystems = _sanitizeSelections(arguments.submittedConfig.externalSystems ?: [], allowedExternal);
        normalized.appendOrganizations = _toBoolean(arguments.submittedConfig.appendOrganizations ?: false);
        normalized.appendFlags = _toBoolean(arguments.submittedConfig.appendFlags ?: false);

        if ( lCase(arguments.quickpullType) EQ "gradclass" ) {
            normalized.biographicalItems = _removeSelection(normalized.biographicalItems, "CURRENTGRADYEAR");
        }

        return normalized;
    }

    public void function saveQuickpullConfig( required string quickpullType, required struct submittedConfig ) {
        var definition = getQuickpullDefinition(arguments.quickpullType);
        if ( structIsEmpty(definition) ) {
            throw(type="QuickpullConfig.InvalidType", message="Invalid quickpull type.");
        }

        variables.appConfigService.setValue(
            _getQuickpullConfigKey(arguments.quickpullType),
            serializeJSON( normalizeQuickpullConfig(arguments.submittedConfig, arguments.quickpullType) )
        );
    }

    /**
     * Clinical-Attending quick pull.
     * Flat list: UserID, FirstName, MiddleName, LastName, Degrees (display string).
     */
    public array function getAttending() {
        var users = variables.dao.getAttendingUsers();
        variables.nameResolutionService.resolveRows(users);
        for (var i = 1; i <= arrayLen(users); i++) {
            var parts = [];
            if (len(trim(users[i].FIRSTNAME)))  arrayAppend(parts, trim(users[i].FIRSTNAME));
            if (len(trim(users[i].MIDDLENAME))) arrayAppend(parts, trim(users[i].MIDDLENAME));
            if (len(trim(users[i].LASTNAME)))   arrayAppend(parts, trim(users[i].LASTNAME));
            var fullName = arrayToList(parts, " ");
            var attendingDegreeSuffix = _getAttendingDegreeSuffix(users[i].DEGREES ?: "");
            if (len(attendingDegreeSuffix)) {
                fullName &= ", " & attendingDegreeSuffix;
            }
            users[i]["FULLNAME"] = fullName;
        }
        users = _appendConfiguredFieldsToRows( users, "attending" );
        variables.nameResolutionService.attachPrimaryNameEnvelopeToRows(users, "USERID", false);
        variables.nameResolutionService.stripFlatNameFields(users);
        return users;
    }

    /**
     * Alumni graduation class quick pull.
     * Flat list filtered by degree graduation year: UserID, FullName, Program and configured output fields.
     */
    public array function getGradClass(
        required numeric gradYear,
        required string programName,
        string lastNameFilter = ""
    ) {
        var gradClassConfig = _getQuickpullConfig( "gradclass" );
        var filterRange = _resolveGradClassLastNameFilterRange(arguments.lastNameFilter);
        var users = variables.dao.getGradClassUsers(
            arguments.gradYear,
            arguments.programName,
            filterRange.start,
            filterRange.finish
        );
        if ( arrayLen(users) == 0 ) return [];

        var ids = [];
        for ( var user in users ) {
            arrayAppend( ids, user.USERID );
        }

        var rosterMap      = variables.dao.getImageMapByVariant( "KIOSK_ROSTER", ids );
        var profileMap     = variables.dao.getImageMapByVariant( "KIOSK_PROFILE", ids );
        var degreesByUser  = _buildUserDegreeMap( variables.dao.getDegreesForUsers( ids ) );
        var awardsByUser   = _buildUserAwardNameMap( variables.dao.getAwardsForUsers( ids ) );
        var rows = [];
        var profileCache = {};

        for ( var i = 1; i <= arrayLen(users); i++ ) {
            var userID = val( users[i].USERID ?: 0 );
            var key = toString( userID );
            var row = {
                "USERID" = userID,
                "FIRSTNAME" = users[i].FIRSTNAME ?: "",
                "MIDDLENAME" = users[i].MIDDLENAME ?: "",
                "LASTNAME" = users[i].LASTNAME ?: "",
                "FULLNAME" = buildFullName( users[i] ),
                "PROGRAM" = users[i].PROGRAM ?: "",
                "KIOSKROSTERIMAGE" = structKeyExists( rosterMap, key ) ? rosterMap[ key ] : "",
                "KIOSKPROFILEIMAGE" = structKeyExists( profileMap, key ) ? profileMap[ key ] : "",
                "FIRSTEXTERNSHIP" = users[i].FIRSTEXTERNSHIP ?: "",
                "SECONDEXTERNSHIP" = users[i].SECONDEXTERNSHIP ?: "",
                "DISSERTATIONTHESIS" = users[i].DISSERTATIONTHESIS ?: "",
                "HOMETOWNFULL" = _buildHometownFull( users[i].HOMETOWNCITY ?: "", users[i].HOMETOWNSTATE ?: "" ),
                "DEGREES" = structKeyExists( degreesByUser, key ) ? degreesByUser[ key ] : ""
            };

            if ( structKeyExists( awardsByUser, key ) ) {
                for ( var awardIndex = 1; awardIndex <= arrayLen(awardsByUser[ key ]); awardIndex++ ) {
                    row["AWARDNAME" & awardIndex] = awardsByUser[ key ][ awardIndex ];
                }
            }

            _applyConfiguredFieldsToRowWithConfig( row, userID, gradClassConfig, profileCache );

            if ( structKeyExists(row, "ALLDEGREES") && isArray(row.ALLDEGREES) ) {
                row["ALLDEGREES"] = _filterExcludedDegrees(row.ALLDEGREES, ["B.S."]);
            }

            arrayAppend( rows, row );
        }

        variables.nameResolutionService.resolveRows(rows);
        _repairMissingGradClassNames(rows, profileCache);
        variables.nameResolutionService.attachPrimaryNameEnvelopeToRows(rows, "USERID", false);
        variables.nameResolutionService.stripFlatNameFields(rows);

        return rows;
    }

    private void function _repairMissingGradClassNames( required array rows, required struct profileCache ) {
        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            var row = arguments.rows[i];
            var userID = val(row.USERID ?: 0);

            if ( userID LTE 0 ) {
                continue;
            }

            var cacheKey = toString(userID);
            if ( !structKeyExists(arguments.profileCache, cacheKey) ) {
                arguments.profileCache[cacheKey] = variables.directoryService.getFullProfile(userID);
            }

            var profile = arguments.profileCache[cacheKey];
            var profileUser = isStruct(profile) ? (profile.user ?: {}) : {};

            // Final authoritative source for GradClass split names.
            var profileFirst = trim(profileUser.FIRSTNAME ?: "");
            var profileMiddle = trim(profileUser.MIDDLENAME ?: "");
            var profileLast = trim(profileUser.LASTNAME ?: "");

            if ( len(profileFirst) ) {
                row["FIRSTNAME"] = profileFirst;
            }
            if ( len(profileMiddle) ) {
                row["MIDDLENAME"] = profileMiddle;
            }
            if ( len(profileLast) ) {
                row["LASTNAME"] = profileLast;
            }

            row["FULLNAME"] = buildFullName(row);
        }
    }

    private struct function _resolveGradClassLastNameFilterRange( string lastNameFilter = "" ) {
        var normalizedFilter = uCase(trim(arguments.lastNameFilter ?: ""));
        var filterMap = {
            "A-C" = { start = "A", finish = "C" },
            "D-G" = { start = "D", finish = "G" },
            "H-K" = { start = "H", finish = "K" },
            "L-M" = { start = "L", finish = "M" },
            "N-P" = { start = "N", finish = "P" },
            "Q-S" = { start = "Q", finish = "S" },
            "T-Z" = { start = "T", finish = "Z" }
        };

        if ( len(normalizedFilter) AND structKeyExists(filterMap, normalizedFilter) ) {
            return filterMap[ normalizedFilter ];
        }

        return { start = "", finish = "" };
    }

    /**
     * Full graduate quick pull for a single user.
     * Returns a struct with nested degrees, awards, and kiosk images.
     * Returns empty struct if user not found or not an Alumni.
     */
    public struct function getGraduate( required numeric userID ) {
        var users = variables.dao.getGraduateUser( arguments.userID );
        if ( arrayLen(users) == 0 ) return {};

        var user = users[1];
        var uid  = arguments.userID;
        var ids  = [ uid ];

        // Fetch related data
        user["DEGREES"]           = variables.dao.getDegreesForUsers( ids );
        user["AWARDS"]            = variables.dao.getAwardsForUsers( ids );

        var interactiveMap = variables.dao.getImageMapByVariant( "interactive_roster", ids );
        var rosterMap      = variables.dao.getImageMapByVariant( "KIOSK_ROSTER",  ids );
        var profileMap     = variables.dao.getImageMapByVariant( "KIOSK_PROFILE", ids );
        var key = toString( uid );
        user["INTERACTIVEUSERIMAGE"] = structKeyExists( interactiveMap, key ) ? interactiveMap[ key ] : "";
        user["KIOSKROSTERIMAGE"]  = structKeyExists( rosterMap,  key ) ? rosterMap[ key ]  : "";
        user["KIOSKPROFILEIMAGE"] = structKeyExists( profileMap, key ) ? profileMap[ key ] : "";

        variables.nameResolutionService.resolveRow(user);
        _applyConfiguredFieldsToRow( user, uid, "graduate", {} );
        variables.nameResolutionService.attachPrimaryNameEnvelopeToRow(user, {}, "USERID", false);
        variables.nameResolutionService.stripFlatNameFields(user);
        return user;
    }

    /**
     * Deans quick pull with kiosk non-grid image.
     */
    public array function getDeans() {
        var users = variables.dao.getDeansUsers();
        if ( arrayLen(users) == 0 ) return [];

        variables.nameResolutionService.resolveRows(users);

        var ids = [];
        for ( var u in users ) {
            arrayAppend( ids, u.USERID );
        }

        var nonGridMap = variables.dao.getImageMapByVariant( "KIOSK_NON_GRID", ids );

        for ( var i = 1; i <= arrayLen(users); i++ ) {
            var uid = toString( users[i].USERID );
            users[i]["FULLNAME"] = buildFullName( users[i] );
            users[i]["KIOSKNONGRIDIMAGE"] = structKeyExists( nonGridMap, uid ) ? nonGridMap[ uid ] : "";
        }

        users = _appendConfiguredFieldsToRows( users, "deans" );
        variables.nameResolutionService.attachPrimaryNameEnvelopeToRows(users, "USERID", false);
        variables.nameResolutionService.stripFlatNameFields(users);
        return users;
    }

    /**
     * MyUHCO portal profile lookup by external ID.
     * Tries to match the externalValue against UH_API_ID, COUGARNET, or PEOPLESOFT.
     * Returns a single user struct with degrees, flags, orgs, images, and configured fields.
     * Returns empty struct if user not found, or if Alumni/Current-Student but not authorized.
     */
    public struct function getMyUHCO(
        required string externalValue,
        required boolean isAuthorized
    ) {
        var userID = 0;
        var systems = ["UH_API_ID", "COUGARNET", "PEOPLESOFT"];
        
        // Try to find user by external ID across all three systems
        for (var system in systems) {
            userID = variables.dao.getUserIDByExternalID(trim(arguments.externalValue), system);
            if (userID > 0) break;
        }

        if (userID <= 0) return {};

        // Get the base user record
        var profile = variables.directoryService.getFullProfile(userID);
        if (structIsEmpty(profile)) return {};

        var user = duplicate(profile.user);
        user.USERID = userID;
        user.FULLNAME = buildFullName(user);
        user.DEGREES = profile.degrees ?: [];
        user.FLAGS = profile.flags ?: [];
        user.ORGANIZATIONS = profile.organizations ?: [];

        // Check if user has Alumni or Current-Student flags
        var hasAlumniOrStudent = false;
        for (var flag in user.FLAGS) {
            if (arrayFindNoCase(["Alumni", "Current-Student"], flag.FLAGNAME ?: "") > 0) {
                hasAlumniOrStudent = true;
                break;
            }
        }

        // If restricted flags present, require authorization
        if (hasAlumniOrStudent AND NOT arguments.isAuthorized) {
            return {};
        }

        // Get CurrentGradYear if user is Alumni or Current-Student
        if (hasAlumniOrStudent) {
            var academic = profile.academic ?: {};
            user.CURRENTGRADYEAR = academic.EFFECTIVEGRADYEAR ?: (academic.CURRENTGRADYEAR ?: "");
        } else {
            user.CURRENTGRADYEAR = "";
        }

        // Get web profile/thumb images
        var ids = [userID];
        var webProfileMap = variables.dao.getImageMapByVariant("WEB_PROFILE", ids);
        var webThumbMap = variables.dao.getImageMapByVariant("WEB_THUMB", ids);
        var key = toString(userID);

        user.WEBPROFILEIMAGE = structKeyExists(webProfileMap, key) ? webProfileMap[key] : "";
        user.WEBTHUMBIMAGE = structKeyExists(webThumbMap, key) ? webThumbMap[key] : "";

        // Apply configured additional fields
        _applyConfiguredFieldsToRow(user, userID, "myuhco", {});
        variables.nameResolutionService.attachPrimaryNameEnvelopeToRow(user, {}, "USERID", false);
        variables.nameResolutionService.stripFlatNameFields(user);

        return user;
    }

    /**
     * MyUHCO roster metadata listing for generated class PDFs.
     * Returns local roster file details plus last Dropbox publish status/path when available.
     */
    public array function getMyUHCORosterCatalog( boolean publishedOnly = false ) {
        var rosterDirectory = expandPath("/_temp_rosters");
        var publishMetaPath = rosterDirectory & "/.publish-status.json";
        var publishMeta = {};
        var fileQuery = queryNew("name,size,dateLastModified,type");
        var pattern = "^class-of-([0-9]{4})-roster\.pdf$";

        if ( fileExists(publishMetaPath) ) {
            try {
                var publishMetaRaw = trim(fileRead(publishMetaPath, "utf-8"));
                if ( len(publishMetaRaw) AND isJSON(publishMetaRaw) ) {
                    publishMeta = deserializeJSON(publishMetaRaw);
                    if ( !isStruct(publishMeta) ) {
                        publishMeta = {};
                    }
                }
            } catch ( any ignored ) {
                publishMeta = {};
            }
        }

        if ( !directoryExists(rosterDirectory) ) {
            return [];
        }

        directoryList(
            rosterDirectory,
            false,
            "query",
            "class-of-*-roster.pdf",
            "dateLastModified DESC",
            "fileQuery"
        );

        var result = [];
        for ( var row in queryToArray(fileQuery) ) {
            var fileName = trim(row.NAME ?: "");
            var fileMatch = reFindNoCase(pattern, fileName, 1, true);
            var gradYear = 0;
            var metaKey = lCase(fileName);
            var fileMeta = structKeyExists(publishMeta, metaKey) AND isStruct(publishMeta[metaKey]) ? publishMeta[metaKey] : {};
            var publishStatus = lCase(trim(fileMeta.lastStatus ?: ""));

            if ( arrayLen(fileMatch.pos) LT 2 OR fileMatch.pos[2] LTE 0 ) {
                continue;
            }

            gradYear = val(mid(fileName, fileMatch.pos[2], fileMatch.len[2]));

            if ( arguments.publishedOnly AND publishStatus NEQ "ok" ) {
                continue;
            }

            arrayAppend(result, {
                FILENAME = fileName,
                GRADYEAR = gradYear,
                SIZEKB = javacast("double", (val(row.SIZE ?: 0) / 1024)),
                DATELASTMODIFIED = isDate(row.DATELASTMODIFIED ?: "")
                    ? dateTimeFormat(row.DATELASTMODIFIED, "yyyy-mm-dd'T'HH:nn:ss")
                    : "",
                LOCALURL = "/_temp_rosters/" & fileName,
                PUBLISHED = (publishStatus EQ "ok"),
                LASTPUBLISHSTATUS = publishStatus,
                LASTPUBLISHATTEMPTAT = trim(fileMeta.lastAttemptAt ?: ""),
                LASTPUBLISHEDAT = trim(fileMeta.lastPublishedAt ?: ""),
                LASTPUBLISHEDPATH = trim(fileMeta.lastPublishedPath ?: ""),
                LASTERROR = trim(fileMeta.lastError ?: "")
            });
        }

        return result;
    }

    private array function _appendConfiguredFieldsToRows( required array rows, required string quickpullType ) {
        var profileCache = {};

        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            _applyConfiguredFieldsToRow(
                arguments.rows[i],
                val(arguments.rows[i].USERID ?: 0),
                arguments.quickpullType,
                profileCache
            );
        }

        return arguments.rows;
    }

    private void function _applyConfiguredFieldsToRow(
        required struct row,
        required numeric userID,
        required string quickpullType,
        required struct profileCache
    ) {
        var config = _getQuickpullConfig( arguments.quickpullType );

        _applyConfiguredFieldsToRowWithConfig(
            arguments.row,
            arguments.userID,
            config,
            arguments.profileCache
        );
    }

    private void function _applyConfiguredFieldsToRowWithConfig(
        required struct row,
        required numeric userID,
        required struct config,
        required struct profileCache
    ) {
        var cacheKey = toString(arguments.userID);
        var profile = {};

        if ( arguments.userID LTE 0 OR !_hasConfiguredItems(arguments.config) ) {
            return;
        }

        if ( !structKeyExists(arguments.profileCache, cacheKey) ) {
            arguments.profileCache[cacheKey] = variables.directoryService.getFullProfile( arguments.userID );
        }

        profile = arguments.profileCache[cacheKey];

        // Guard against empty split-name payloads by using the canonical profile user record.
        _hydrateRowNamePartsFromProfile(arguments.row, profile);

        _appendGeneralFields(arguments.row, profile, arguments.config.generalFields);
        _appendContactFields(arguments.row, profile, arguments.config);
        _appendBiographicalFields(arguments.row, profile, arguments.config.biographicalItems);
        _appendImageFields(arguments.row, profile, arguments.config.imageVariants);
        _appendExternalIDFields(arguments.row, profile, arguments.config.externalSystems);

        if ( arguments.config.appendOrganizations ) {
            arguments.row["ORGANIZATIONS"] = profile.organizations ?: [];
        }

        if ( arguments.config.appendFlags ) {
            arguments.row["FLAGS"] = profile.flags ?: [];
        }

        // Keep FULLNAME consistent with the final name parts after configured-field mutations.
        arguments.row["FULLNAME"] = buildFullName(arguments.row);
    }

    private void function _hydrateRowNamePartsFromProfile( required struct row, required struct profile ) {
        var profileUser = arguments.profile.user ?: {};
        var resolvedFirst = _firstMeaningfulNamePart([
            arguments.row["FIRSTNAME"] ?: "",
            profileUser.FIRSTNAME ?: ""
        ]);
        var resolvedMiddle = _firstMeaningfulNamePart([
            arguments.row["MIDDLENAME"] ?: "",
            profileUser.MIDDLENAME ?: ""
        ]);
        var resolvedLast = _firstMeaningfulNamePart([
            arguments.row["LASTNAME"] ?: "",
            profileUser.LASTNAME ?: ""
        ]);

        arguments.row["FIRSTNAME"] = resolvedFirst;
        arguments.row["MIDDLENAME"] = resolvedMiddle;
        arguments.row["LASTNAME"] = resolvedLast;
    }

    private struct function _getQuickpullConfig( required string quickpullType ) {
        var rawValue = trim(variables.appConfigService.getValue(_getQuickpullConfigKey(arguments.quickpullType), ""));
        var parsed = {};

        if ( structIsEmpty(getQuickpullDefinition(arguments.quickpullType)) ) {
            return _getDefaultQuickpullConfig();
        }

        if ( !len(rawValue) ) {
            return _getDefaultQuickpullConfig();
        }

        try {
            parsed = deserializeJSON(rawValue);
        } catch ( any ignored ) {
            return _getDefaultQuickpullConfig();
        }

        if ( !isStruct(parsed) ) {
            return _getDefaultQuickpullConfig();
        }

        return normalizeQuickpullConfig(parsed, arguments.quickpullType);
    }

    private string function _getQuickpullConfigKey( required string quickpullType ) {
        return "api.quickpull." & lCase(arguments.quickpullType) & ".config";
    }

    private struct function _getDefaultQuickpullConfig() {
        return {
            generalFields = [],
            emailTypes = [],
            phoneTypes = [],
            addressTypes = [],
            biographicalItems = [],
            imageVariants = [],
            externalSystems = [],
            appendOrganizations = false,
            appendFlags = false
        };
    }

    private boolean function _hasConfiguredItems( required struct config ) {
        return arrayLen(arguments.config.generalFields)
            OR arrayLen(arguments.config.emailTypes)
            OR arrayLen(arguments.config.phoneTypes)
            OR arrayLen(arguments.config.addressTypes)
            OR arrayLen(arguments.config.biographicalItems)
            OR arrayLen(arguments.config.imageVariants)
            OR arrayLen(arguments.config.externalSystems)
            OR arguments.config.appendOrganizations
            OR arguments.config.appendFlags;
    }

    private void function _appendGeneralFields( required struct row, required struct profile, required array selectedFields ) {
        var userData = arguments.profile.user ?: {};

        for ( var fieldName in arguments.selectedFields ) {
            if ( compareNoCase(fieldName, "PREFERREDNAME") EQ 0 ) {
                var originalFirstName = _normalizeMeaningfulNamePart(arguments.row["FIRSTNAME"] ?: "");
                var originalMiddleName = _normalizeMeaningfulNamePart(arguments.row["MIDDLENAME"] ?: "");
                var originalLastName = _normalizeMeaningfulNamePart(arguments.row["LASTNAME"] ?: "");
                var preferredFirstName = _normalizeMeaningfulNamePart(userData.PREFERREDNAME ?: "");
                var resolvedFirstName = _firstMeaningfulNamePart([
                    preferredFirstName,
                    userData.FIRSTNAME ?: "",
                    originalFirstName
                ]);
                var resolvedMiddleName = originalMiddleName;
                var resolvedLastName = originalLastName;

                // Never clear an existing name part when preferred-name resolution yields empty.
                if ( !len(resolvedFirstName) AND len(originalFirstName) ) {
                    resolvedFirstName = originalFirstName;
                }

                arguments.row["FIRSTNAME"] = resolvedFirstName;
                arguments.row["MIDDLENAME"] = resolvedMiddleName;
                arguments.row["LASTNAME"] = resolvedLastName;
            } else {
                arguments.row[fieldName] = structKeyExists(userData, fieldName) ? userData[fieldName] : "";
            }
        }
    }

    private string function _firstMeaningfulNamePart( required array candidates ) {
        for ( var candidate in arguments.candidates ) {
            var normalizedCandidate = _normalizeMeaningfulNamePart(candidate);
            if ( len(normalizedCandidate) ) {
                return normalizedCandidate;
            }
        }

        return "";
    }

    private string function _normalizeMeaningfulNamePart( any rawValue = "" ) {
        var normalized = trim(arguments.rawValue ?: "");

        if ( !len(normalized) ) {
            return "";
        }

        // Treat punctuation-only placeholders like "." or "-" as empty.
        if ( reFind("[\\p{L}\\p{N}]", normalized) EQ 0 ) {
            return "";
        }

        return normalized;
    }

    private void function _appendContactFields( required struct row, required struct profile, required struct config ) {
        var emails = arguments.profile.emails ?: [];
        var phones = arguments.profile.phones ?: [];
        var addresses = arguments.profile.addresses ?: [];

        for ( var emailType in arguments.config.emailTypes ) {
            arguments.row["EMAIL_" & _normalizeToken(emailType)] = _getFirstMatchingField(emails, "EMAILTYPE", emailType, "EMAILADDRESS");
        }

        for ( var phoneType in arguments.config.phoneTypes ) {
            arguments.row["PHONE_" & _normalizeToken(phoneType)] = _getFirstMatchingField(phones, "PHONETYPE", phoneType, "PHONENUMBER");
        }

        for ( var addressType in arguments.config.addressTypes ) {
            arguments.row["ADDRESS_" & _normalizeToken(addressType)] = _getFirstMatchingStruct(addresses, "ADDRESSTYPE", addressType);
        }
    }

    private void function _appendBiographicalFields( required struct row, required struct profile, required array selectedItems ) {
        var academic = arguments.profile.academic ?: {};
        var studentProfile = arguments.profile.studentProfile ?: {};
        var residencies = arguments.profile.residencies ?: [];
        var bio = arguments.profile.bio ?: {};

        for ( var itemKey in arguments.selectedItems ) {
            switch ( itemKey ) {
                case "ACADEMIC":
                    arguments.row["ACADEMIC"] = academic;
                    break;
                case "STUDENTPROFILE":
                    arguments.row["STUDENTPROFILE"] = studentProfile;
                    break;
                case "CURRENTGRADYEAR":
                    arguments.row["CURRENTGRADYEAR"] = academic.EFFECTIVEGRADYEAR ?: (academic.CURRENTGRADYEAR ?: "");
                    break;
                case "ORIGINALGRADYEAR":
                    arguments.row["ORIGINALGRADYEAR"] = academic.ORIGINALGRADYEAR ?: "";
                    break;
                case "FIRSTEXTERNSHIP":
                    arguments.row["FIRSTEXTERNSHIP"] = studentProfile.FIRSTEXTERNSHIP ?: "";
                    break;
                case "SECONDEXTERNSHIP":
                    arguments.row["SECONDEXTERNSHIP"] = studentProfile.SECONDEXTERNSHIP ?: "";
                    break;
                case "COMMENCEMENTAGE":
                    arguments.row["COMMENCEMENTAGE"] = studentProfile.COMMENCEMENTAGE ?: "";
                    break;
                case "DISSERTATIONTHESIS":
                    arguments.row["DISSERTATIONTHESIS"] = studentProfile.DISSERTATIONTHESIS ?: (arguments.row["DISSERTATIONTHESIS"] ?: "");
                    break;
                case "BIO":
                    arguments.row["BIO"] = bio;
                    break;
                case "HOMETOWNCITY":
                    arguments.row["HOMETOWNCITY"] = studentProfile.HOMETOWNCITY ?: "";
                    break;
                case "HOMETOWNSTATE":
                    arguments.row["HOMETOWNSTATE"] = studentProfile.HOMETOWNSTATE ?: "";
                    break;
                case "HOMETOWNFULL":
                    arguments.row["HOMETOWNFULL"] = _buildHometownFull(
                        studentProfile.HOMETOWNCITY ?: "",
                        studentProfile.HOMETOWNSTATE ?: ""
                    );
                    break;
                case "DEGREES":
                    arguments.row["DEGREES"] = arguments.profile.degrees ?: [];
                    break;
                case "ALLDEGREES":
                    arguments.row["ALLDEGREES"] = arguments.profile.degrees ?: [];
                    break;
                case "UHCODEGREES":
                    arguments.row["UHCODEGREES"] = _filterUHCODegrees(arguments.profile.degrees ?: []);
                    break;
                case "AWARDS":
                    arguments.row["AWARDS"] = arguments.profile.awards ?: [];
                    break;
                case "RESIDENCIES":
                    arguments.row["RESIDENCIES"] = residencies;
                    break;
            }
        }
    }

    private void function _appendImageFields( required struct row, required struct profile, required array selectedVariants ) {
        var images = arguments.profile.images ?: [];

        for ( var variantCode in arguments.selectedVariants ) {
            arguments.row["IMAGE_" & _normalizeToken(variantCode)] = _getFirstMatchingField(images, "IMAGEVARIANT", variantCode, "IMAGEURL");
        }
    }

    private void function _appendExternalIDFields( required struct row, required struct profile, required array selectedSystems ) {
        var externalIDs = arguments.profile.externalIDs ?: [];

        for ( var systemName in arguments.selectedSystems ) {
            arguments.row["EXTERNALID_" & _normalizeToken(systemName)] = _getFirstMatchingField(externalIDs, "SYSTEMNAME", systemName, "EXTERNALVALUE");
        }
    }

    private string function _getFirstMatchingField(
        required array records,
        required string typeField,
        required string expectedValue,
        required string returnField
    ) {
        var fallbackValue = "";

        for ( var record in arguments.records ) {
            if ( compareNoCase(trim(record[arguments.typeField] ?: ""), trim(arguments.expectedValue)) EQ 0 ) {
                if ( val(record.ISPRIMARY ?: 0) EQ 1 ) {
                    return record[arguments.returnField] ?: "";
                }

                if ( !len(fallbackValue) ) {
                    fallbackValue = record[arguments.returnField] ?: "";
                }
            }
        }

        return fallbackValue;
    }

    private struct function _getFirstMatchingStruct(
        required array records,
        required string typeField,
        required string expectedValue
    ) {
        var fallback = {};

        for ( var record in arguments.records ) {
            if ( compareNoCase(trim(record[arguments.typeField] ?: ""), trim(arguments.expectedValue)) EQ 0 ) {
                if ( val(record.ISPRIMARY ?: 0) EQ 1 ) {
                    return record;
                }

                if ( structIsEmpty(fallback) ) {
                    fallback = record;
                }
            }
        }

        return fallback;
    }

    private array function _getGeneralFieldOptions() {
        return [
            { value = "PREFIX", label = "Prefix" },
            { value = "PREFERREDNAME", label = "Preferred Name" },
            { value = "SUFFIX", label = "Suffix" },
            { value = "PRONOUNS", label = "Pronouns" },
            { value = "EMAILPRIMARY", label = "Primary Email" },
            { value = "TITLE1", label = "Primary Title" },
            { value = "TITLE2", label = "Secondary Title" },
            { value = "TITLE3", label = "Tertiary Title" },
            { value = "DIVISION", label = "Division" },
            { value = "DIVISIONNAME", label = "Division Name" },
            { value = "DEPARTMENT", label = "Department" },
            { value = "DEPARTMENTNAME", label = "Department Name" },
            { value = "BUILDING", label = "Building" },
            { value = "ROOM", label = "Room" },
            { value = "MAILCODE", label = "Mail Code" },
            { value = "CAMPUS", label = "Campus" },
            { value = "OFFICE_MAILING_ADDRESS", label = "Office Mailing Address" },
            { value = "PHONE", label = "Directory Phone" },
            { value = "ACTIVE", label = "Active Flag" }
        ];
    }

    private array function _getBiographicalOptions() {
        return [
            { value = "ACADEMIC", label = "All Academic Data" },
            { value = "CURRENTGRADYEAR", label = "Current Grad Year" },
            { value = "ORIGINALGRADYEAR", label = "Original Grad Year" },
            { value = "STUDENTPROFILE", label = "All Student Profile Data" },
            { value = "FIRSTEXTERNSHIP", label = "First Externship" },
            { value = "SECONDEXTERNSHIP", label = "Second Externship" },
            { value = "COMMENCEMENTAGE", label = "Commencement Age" },
            { value = "DISSERTATIONTHESIS", label = "Dissertation / Thesis" },
            { value = "BIO", label = "All Bio Data" },
            { value = "HOMETOWNCITY", label = "Hometown City" },
            { value = "HOMETOWNSTATE", label = "Hometown State" },
            { value = "HOMETOWNFULL", label = "Hometown Full (City, State)" },
            { value = "DEGREES", label = "Degrees" },
            { value = "ALLDEGREES", label = "All Degrees (Full Data)" },
            { value = "UHCODEGREES", label = "UHCO Degrees (Full Data)" },
            { value = "AWARDS", label = "Awards" },
            { value = "RESIDENCIES", label = "Residencies (Full Data)" }
        ];
    }

    private array function _withoutOptionValue( required array options, required string valueToRemove ) {
        var filtered = [];

        for ( var option in arguments.options ) {
            if ( compareNoCase(trim(option.value ?: ""), trim(arguments.valueToRemove)) NEQ 0 ) {
                arrayAppend(filtered, option);
            }
        }

        return filtered;
    }

    private array function _removeSelection( required array selections, required string valueToRemove ) {
        var filtered = [];

        for ( var selection in arguments.selections ) {
            if ( compareNoCase(trim(selection ?: ""), trim(arguments.valueToRemove)) NEQ 0 ) {
                arrayAppend(filtered, selection);
            }
        }

        return filtered;
    }

    private array function _filterExcludedDegrees( required array degrees, required array excludeNames ) {
        var result = [];

        for ( var degree in arguments.degrees ) {
            var degreeName = trim(degree.DEGREENAME ?: "");
            if ( !arrayFindNoCase(arguments.excludeNames, degreeName) ) {
                arrayAppend(result, degree);
            }
        }

        return result;
    }

    private array function _filterUHCODegrees( required array degrees ) {
        var result = [];

        for ( var degree in arguments.degrees ) {
            if ( _isUHCODegree(degree) ) {
                arrayAppend(result, degree);
            }
        }

        return result;
    }

    private boolean function _isUHCODegree( required struct degree ) {
        var isUhcoRaw = degree.ISUHCO ?: "";
        var university = uCase(trim(degree.UNIVERSITY ?: ""));
        var program = uCase(trim(degree.PROGRAM ?: ""));

        // Primary signal: explicit IsUHCO flag in UserDegrees.
        if ( isBoolean(isUhcoRaw) ) {
            return isUhcoRaw;
        }
        if ( val(isUhcoRaw) EQ 1 ) {
            return true;
        }

        // Legacy fallback: infer UHCO when rows predate IsUHCO population.
        if ( compareNoCase(university, "UHCO") EQ 0 ) {
            return true;
        }
        if ( findNoCase("HOUSTON COLLEGE OF OPTOMETRY", university) ) {
            return true;
        }
        if ( listFindNoCase("OD,OD PROGRAM,PHD,PHD PROGRAM,MS,MS PROGRAM,RESIDENCY", program) ) {
            return true;
        }

        return false;
    }

    private string function _buildHometownFull( string hometownCity = "", string hometownState = "" ) {
        var city = trim(arguments.hometownCity ?: "");
        var state = trim(arguments.hometownState ?: "");

        if ( len(city) AND len(state) ) {
            return city & ", " & state;
        }

        return len(city) ? city : state;
    }

    private array function _getEmailTypeOptions() {
        return _buildTypeOptions(variables.emailDAO.getEmailTypes(), "EMAILTYPE", "Email");
    }

    private array function _getPhoneTypeOptions() {
        return _buildTypeOptions(variables.phoneDAO.getPhoneTypes(), "PHONETYPE", "Phone");
    }

    private array function _getAddressTypeOptions() {
        return _buildTypeOptions(variables.addressDAO.getAddressTypes(), "ADDRESSTYPE", "Address");
    }

    private array function _buildTypeOptions( required array rows, required string valueKey, required string fallbackLabel ) {
        var options = [];

        for ( var row in arguments.rows ) {
            var optionValue = trim(row[arguments.valueKey] ?: "");
            if ( len(optionValue) ) {
                arrayAppend(options, { value = optionValue, label = optionValue });
            }
        }

        if ( !arrayLen(options) ) {
            arrayAppend(options, { value = "PRIMARY", label = "Primary " & arguments.fallbackLabel });
        }

        return options;
    }

    private array function _getImageVariantOptions() {
        var options = [];

        for ( var variant in variables.imageVariantDAO.getVariantTypesAll() ) {
            arrayAppend(options, {
                value = trim(variant.CODE ?: ""),
                label = len(trim(variant.DESCRIPTION ?: "")) ? variant.CODE & " - " & variant.DESCRIPTION : variant.CODE
            });
        }

        return options;
    }

    private array function _getExternalSystemOptions() {
        var options = [];
        var systemsResult = variables.externalIDService.getSystems();

        if ( systemsResult.success ) {
            for ( var systemRow in systemsResult.data ) {
                arrayAppend(options, {
                    value = trim(systemRow.SYSTEMNAME ?: ""),
                    label = trim(systemRow.SYSTEMNAME ?: "")
                });
            }
        }

        return options;
    }

    private struct function _getAllowedValueSet( required array options ) {
        var allowed = {};

        for ( var option in arguments.options ) {
            allowed[ uCase(option.value) ] = option.value;
        }

        return allowed;
    }

    private array function _sanitizeSelections( required any submittedValues, required struct allowedValues ) {
        var values = isArray(arguments.submittedValues) ? arguments.submittedValues : [ arguments.submittedValues ];
        var result = [];

        for ( var rawValue in values ) {
            var candidateValues = [];

            if ( isArray(rawValue) ) {
                candidateValues = rawValue;
            } else {
                var cleanRawValue = trim(rawValue ?: "");
                candidateValues = len(cleanRawValue) ? listToArray(cleanRawValue) : [];
            }

            for ( var candidateValue in candidateValues ) {
                var cleanValue = trim(candidateValue ?: "");
                var normalizedKey = uCase(cleanValue);

                if ( len(cleanValue) AND structKeyExists(arguments.allowedValues, normalizedKey) AND !arrayFindNoCase(result, arguments.allowedValues[normalizedKey]) ) {
                    arrayAppend(result, arguments.allowedValues[normalizedKey]);
                }
            }
        }

        return result;
    }

    private boolean function _toBoolean( any value ) {
        if ( isBoolean(arguments.value) ) {
            return arguments.value;
        }

        return listFindNoCase("1,true,yes,on", trim(arguments.value ?: "")) GT 0;
    }

    private string function _normalizeToken( required string value ) {
        var token = uCase(trim(arguments.value));
        token = reReplace(token, "[^A-Z0-9]+", "_", "all");
        token = reReplace(token, "_{2,}", "_", "all");
        token = reReplace(token, "^_|_$", "", "all");
        return token;
    }

    private string function _getAttendingDegreeSuffix( string degrees = "" ) {
        var allowedDegreeMap = {
            "OD" = "O.D.",
            "MD" = "M.D.",
            "BSCOPTOM" = "BSc(Optom)"
        };
        var selectedDegrees = [];

        for ( var rawDegree in listToArray(arguments.degrees, ",") ) {
            var cleanDegree = trim(rawDegree ?: "");
            var normalizedDegree = reReplace(uCase(cleanDegree), "[^A-Z0-9]", "", "all");

            if (
                len(normalizedDegree)
                AND structKeyExists(allowedDegreeMap, normalizedDegree)
                AND !arrayFindNoCase(selectedDegrees, allowedDegreeMap[normalizedDegree])
            ) {
                arrayAppend(selectedDegrees, allowedDegreeMap[normalizedDegree]);
            }
        }

        return arrayToList(selectedDegrees, ", ");
    }

    private struct function _buildUserDegreeMap( required array degreeRows ) {
        var groupedDegrees = {};

        for ( var degreeRow in arguments.degreeRows ) {
            var userKey = toString( degreeRow.USERID ?: "" );
            var degreeName = trim( degreeRow.DEGREENAME ?: "" );

            if ( !len(userKey) OR !len(degreeName) ) {
                continue;
            }

            if ( compareNoCase(degreeName, "B.S.") EQ 0 ) {
                continue;
            }

            if ( !structKeyExists(groupedDegrees, userKey) ) {
                groupedDegrees[userKey] = [];
            }

            if ( !arrayFindNoCase(groupedDegrees[userKey], degreeName) ) {
                arrayAppend(groupedDegrees[userKey], degreeName);
            }
        }

        var degreeMap = {};
        for ( var mapKey in groupedDegrees ) {
            degreeMap[ mapKey ] = arrayToList(groupedDegrees[ mapKey ], ", ");
        }

        return degreeMap;
    }

    private struct function _buildUserAwardNameMap( required array awardRows ) {
        var awardMap = {};

        for ( var awardRow in arguments.awardRows ) {
            var userKey = toString( awardRow.USERID ?: "" );
            var awardName = trim( awardRow.AWARDNAME ?: "" );

            if ( !len(userKey) OR !len(awardName) ) {
                continue;
            }

            if ( !structKeyExists(awardMap, userKey) ) {
                awardMap[userKey] = [];
            }

            if ( !arrayFindNoCase(awardMap[userKey], awardName) ) {
                arrayAppend(awardMap[userKey], awardName);
            }
        }

        return awardMap;
    }

    private string function buildFullName( required struct user ) {
        var parts = [];
        if ( len(trim(arguments.user.FIRSTNAME ?: "")) ) {
            arrayAppend( parts, trim(arguments.user.FIRSTNAME) );
        }
        if ( len(trim(arguments.user.MIDDLENAME ?: "")) ) {
            arrayAppend( parts, trim(arguments.user.MIDDLENAME) );
        }
        if ( len(trim(arguments.user.LASTNAME ?: "")) ) {
            arrayAppend( parts, trim(arguments.user.LASTNAME) );
        }
        return arrayToList( parts, " " );
    }

}
