component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.quickpull_DAO").init();
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
                description = "Graduation class list filtered by year and program.",
                baseFields = ["USERID", "FIRSTNAME", "MIDDLENAME", "LASTNAME", "CURRENTGRADYEAR", "PROGRAM", "FULLNAME", "INTERACTIVEUSERIMAGE", "KIOSKROSTERIMAGE", "KIOSKPROFILEIMAGE"]
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
        if ( structIsEmpty(definition) ) {
            return {};
        }

        return {
            quickpull = definition,
            config = getQuickpullConfig(arguments.quickpullType),
            options = {
                generalFields = _getGeneralFieldOptions(),
                emailTypes = _getEmailTypeOptions(),
                phoneTypes = _getPhoneTypeOptions(),
                addressTypes = _getAddressTypeOptions(),
                biographicalItems = _getBiographicalOptions(),
                imageVariants = _getImageVariantOptions(),
                externalSystems = _getExternalSystemOptions()
            }
        };
    }

    public struct function normalizeQuickpullConfig( required struct submittedConfig ) {
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

        return normalized;
    }

    public void function saveQuickpullConfig( required string quickpullType, required struct submittedConfig ) {
        var definition = getQuickpullDefinition(arguments.quickpullType);
        if ( structIsEmpty(definition) ) {
            throw(type="QuickpullConfig.InvalidType", message="Invalid quickpull type.");
        }

        variables.appConfigService.setValue(
            _getQuickpullConfigKey(arguments.quickpullType),
            serializeJSON( normalizeQuickpullConfig(arguments.submittedConfig) )
        );
    }

    /**
     * Clinical-Attending quick pull.
     * Flat list: UserID, FirstName, MiddleName, LastName, Degrees (display string).
     */
    public array function getAttending() {
        var users = variables.dao.getAttendingUsers();
        for (var i = 1; i <= arrayLen(users); i++) {
            var parts = [];
            if (len(trim(users[i].FIRSTNAME)))  arrayAppend(parts, trim(users[i].FIRSTNAME));
            if (len(trim(users[i].MIDDLENAME))) arrayAppend(parts, trim(users[i].MIDDLENAME));
            if (len(trim(users[i].LASTNAME)))   arrayAppend(parts, trim(users[i].LASTNAME));
            var fullName = arrayToList(parts, " ");
            if (len(trim(users[i].DEGREES ?: ""))) {
                fullName &= ", " & trim(users[i].DEGREES);
            }
            users[i]["FULLNAME"] = fullName;
        }
        return _appendConfiguredFieldsToRows( users, "attending" );
    }

    /**
     * Alumni graduation class quick pull.
     * Flat list filtered by grad year: UserID, FirstName, MiddleName, LastName, CurrentGradYear.
     */
    public array function getGradClass( required numeric gradYear, required string programName ) {
        var users = variables.dao.getGradClassUsers( arguments.gradYear, arguments.programName );
        if ( arrayLen(users) == 0 ) return [];

        var ids = [];
        for ( var user in users ) {
            arrayAppend( ids, user.USERID );
        }

        var interactiveMap = variables.dao.getImageMapByVariant( "interactive_roster", ids );
        var rosterMap      = variables.dao.getImageMapByVariant( "KIOSK_ROSTER", ids );
        var profileMap     = variables.dao.getImageMapByVariant( "KIOSK_PROFILE", ids );

        for ( var i = 1; i <= arrayLen(users); i++ ) {
            var key = toString( users[i].USERID );
            users[i]["FULLNAME"] = buildFullName( users[i] );
            users[i]["INTERACTIVEUSERIMAGE"] = structKeyExists( interactiveMap, key ) ? interactiveMap[ key ] : "";
            users[i]["KIOSKROSTERIMAGE"] = structKeyExists( rosterMap, key ) ? rosterMap[ key ] : "";
            users[i]["KIOSKPROFILEIMAGE"] = structKeyExists( profileMap, key ) ? profileMap[ key ] : "";
        }

        return _appendConfiguredFieldsToRows( users, "gradclass" );
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

        _applyConfiguredFieldsToRow( user, uid, "graduate", {} );
        return user;
    }

    /**
     * Deans quick pull with kiosk non-grid image.
     */
    public array function getDeans() {
        var users = variables.dao.getDeansUsers();
        if ( arrayLen(users) == 0 ) return [];

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

        return _appendConfiguredFieldsToRows( users, "deans" );
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
        var cacheKey = toString(arguments.userID);
        var profile = {};

        if ( arguments.userID LTE 0 OR !_hasConfiguredItems(config) ) {
            return;
        }

        if ( !structKeyExists(arguments.profileCache, cacheKey) ) {
            arguments.profileCache[cacheKey] = variables.directoryService.getFullProfile( arguments.userID );
        }

        profile = arguments.profileCache[cacheKey];

        _appendGeneralFields(arguments.row, profile, config.generalFields);
        _appendContactFields(arguments.row, profile, config);
        _appendBiographicalFields(arguments.row, profile, config.biographicalItems);
        _appendImageFields(arguments.row, profile, config.imageVariants);
        _appendExternalIDFields(arguments.row, profile, config.externalSystems);

        if ( config.appendOrganizations ) {
            arguments.row["ORGANIZATIONS"] = profile.organizations ?: [];
        }

        if ( config.appendFlags ) {
            arguments.row["FLAGS"] = profile.flags ?: [];
        }
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

        return normalizeQuickpullConfig(parsed);
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
            arguments.row[fieldName] = structKeyExists(userData, fieldName) ? userData[fieldName] : "";
        }
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
                    arguments.row["CURRENTGRADYEAR"] = academic.CURRENTGRADYEAR ?: "";
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
                case "BIO":
                    arguments.row["BIO"] = bio;
                    break;
                case "HOMETOWNCITY":
                    arguments.row["HOMETOWNCITY"] = bio.HOMETOWNCITY ?: "";
                    break;
                case "HOMETOWNSTATE":
                    arguments.row["HOMETOWNSTATE"] = bio.HOMETOWNSTATE ?: "";
                    break;
                case "DEGREES":
                    arguments.row["DEGREES"] = arguments.profile.degrees ?: [];
                    break;
                case "AWARDS":
                    arguments.row["AWARDS"] = arguments.profile.awards ?: [];
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
        for ( var record in arguments.records ) {
            if ( compareNoCase(trim(record[arguments.typeField] ?: ""), trim(arguments.expectedValue)) EQ 0 ) {
                return record[arguments.returnField] ?: "";
            }
        }
        return "";
    }

    private struct function _getFirstMatchingStruct(
        required array records,
        required string typeField,
        required string expectedValue
    ) {
        for ( var record in arguments.records ) {
            if ( compareNoCase(trim(record[arguments.typeField] ?: ""), trim(arguments.expectedValue)) EQ 0 ) {
                return record;
            }
        }
        return {};
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
            { value = "BIO", label = "All Bio Data" },
            { value = "HOMETOWNCITY", label = "Hometown City" },
            { value = "HOMETOWNSTATE", label = "Hometown State" },
            { value = "DEGREES", label = "Degrees" },
            { value = "AWARDS", label = "Awards" }
        ];
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
            var cleanValue = trim(rawValue ?: "");
            var normalizedKey = uCase(cleanValue);

            if ( len(cleanValue) AND structKeyExists(arguments.allowedValues, normalizedKey) AND !arrayFindNoCase(result, arguments.allowedValues[normalizedKey]) ) {
                arrayAppend(result, arguments.allowedValues[normalizedKey]);
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
