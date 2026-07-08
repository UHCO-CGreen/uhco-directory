component output="false" singleton {

    variables.maxTestUserCount = 10;

    private string function normalizeOfficeMailingAddress( any value = "" ) {
        var normalized = toString(arguments.value ?: "");

        normalized = reReplace(normalized, "[\r\n\t]+", " ", "all");
        normalized = reReplace(normalized, "\s{2,}", " ", "all");

        return trim(normalized);
    }

    
    public any function init() {
        variables.UsersDAO = createObject("component", "dao.users_DAO").init();
        return this;
    }

    /**
     * Get a user record with validation and consistent return structure
     */
    public struct function getUser( required numeric userID ) {
        var user = variables.UsersDAO.getUserByID( userID );

        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found.", data={} };
        }

        _getDependency("nameResolutionService", "cfc.nameResolution_service").attachPrimaryNameEnvelopeToRow(user);

        return { success=true, data=user };
    }

    public struct function getUserByCougarnet( required string cougarnetID ) {
        var user = variables.UsersDAO.getUserByCougarnet( trim(arguments.cougarnetID) );

        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found.", data={} };
        }

        _getDependency("nameResolutionService", "cfc.nameResolution_service").attachPrimaryNameEnvelopeToRow(user);

        return { success=true, data=user };
    }

    /**
     * Create a user with validation and normalization
     */
    public struct function createUser( required struct data ) {

        // Normalize
        data.EmailPrimary = len( data.EmailPrimary ?: "" ) ? trim( lCase( data.EmailPrimary ) ) : "";
        data.FirstName = trim( data.FirstName );
        data.LastName = trim( data.LastName );
        data.Title1 = trim( data.Title1 ?: "" );
        data.Title2 = trim( data.Title2 ?: "" );
        data.Title3 = trim( data.Title3 ?: "" );
        data.Room = trim( data.Room ?: "" );
        data.Building = trim( data.Building ?: "" );
        data.Prefix = trim( data.Prefix ?: "" );
        data.Suffix = trim( data.Suffix ?: "" );
        data.Degrees = trim( data.Degrees ?: "" );
        data.Campus = trim( data.Campus ?: "" );
        data.Division = trim( data.Division ?: "" );
        data.DivisionName = trim( data.DivisionName ?: "" );
        data.Department = trim( data.Department ?: "" );
        data.DepartmentName = trim( data.DepartmentName ?: "" );
        data.Office_Mailing_Address = normalizeOfficeMailingAddress( data.Office_Mailing_Address ?: "" );
        data.Mailcode = trim( data.Mailcode ?: "" );

        // Validate
        if ( !len( data.FirstName ) OR !len( data.LastName ) ) {
            return { success=false, message="First and last name are required." };
        }

        if ( len( data.EmailPrimary ) && !isValid( "email", data.EmailPrimary ) ) {
            return { success=false, message="Primary email is invalid." };
        }

        // Create
        var newID = variables.UsersDAO.createUser( data );

        return {
            success=true,
            message="User created.",
            userID=newID
        };
    }

    /**
     * Update a user with validation
     */
    public struct function updateUser( required numeric userID, required struct data ) {
        data.Title1 = trim( data.Title1 ?: "" );
        data.Title2 = trim( data.Title2 ?: "" );
        data.Title3 = trim( data.Title3 ?: "" );
        data.Room = trim( data.Room ?: "" );
        data.Building = trim( data.Building ?: "" );
        data.Prefix = trim( data.Prefix ?: "" );
        data.Suffix = trim( data.Suffix ?: "" );
        data.Degrees = trim( data.Degrees ?: "" );
        data.Campus = trim( data.Campus ?: "" );
        data.Division = trim( data.Division ?: "" );
        data.DivisionName = trim( data.DivisionName ?: "" );
        data.Department = trim( data.Department ?: "" );
        data.DepartmentName = trim( data.DepartmentName ?: "" );
        data.Office_Mailing_Address = normalizeOfficeMailingAddress( data.Office_Mailing_Address ?: "" );
        data.Mailcode = trim( data.Mailcode ?: "" );

        if ( len( data.EmailPrimary ?: "" ) && !isValid( "email", data.EmailPrimary ) ) {
            return { success=false, message="Invalid primary email." };
        }

        variables.UsersDAO.updateUser( userID, data );

        return { success=true, message="User updated." };
    }

    public void function updateDegreesField( required numeric userID, required string degrees ) {
        variables.UsersDAO.updateDegreesField( userID, degrees );
    }

    public void function updateTitle1Field( required numeric userID, required string title1 ) {
        variables.UsersDAO.updateTitle1Field( userID, trim(arguments.title1 ?: "") );
    }

    public void function updateDropboxFolderPath( required numeric userID, required string folderPath ) {
        variables.UsersDAO.updateDropboxFolderPath( userID, trim(arguments.folderPath ?: "") );
    }

    public void function setUserActive( required numeric userID, required boolean active ) {
        variables.UsersDAO.setUserActive(
            userID = arguments.userID,
            active = arguments.active
        );
    }

    public void function updateDemographics(
        required numeric userID,
        string dob = "",
        string gender = ""
    ) {
        variables.UsersDAO.updateDemographics(
            userID = arguments.userID,
            dob = arguments.dob,
            gender = arguments.gender
        );
    }

    /**
     * Delete a user and all related records
     */
    public struct function deleteUser(
        required numeric userID,
        boolean forceDeleteRelatedDuplicatePairs = false
    ) {
        var user = variables.UsersDAO.getUserByID( userID );
        
        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found." };
        }

        _getDependency("userDeletionService", "cfc.userDeletion_service").deleteUser(
            userID = userID,
            purgeDuplicatePairs = arguments.forceDeleteRelatedDuplicatePairs
        );

        return { 
            success=true, 
            message="User #user.FIRSTNAME# #user.LASTNAME# has been permanently deleted along with all associated records." 
        };
    }

    public boolean function isTestModeEnabled() {
        return _configValueToBoolean( _getDependency("AppConfigService", "cfc.appConfig_service").getValue( "test_mode.enabled", "0" ) );
    }

    public void function setTestModeEnabled( required boolean enabled ) {
        _getDependency("AppConfigService", "cfc.appConfig_service").setValue( "test_mode.enabled", arguments.enabled ? "1" : "0" );
    }

    public struct function generateTestUsers( numeric count = 0 ) {
        var generationCount = variables.maxTestUserCount;
        var staleMonths = val( _getDependency("AppConfigService", "cfc.appConfig_service").getValue( "dashboard.stale_months", "6" ) );
        var createdUsers = [];
        var totalTestUsers = 0;
        var existingTestUsers = variables.UsersDAO.getTestUserCount();

        if ( existingTestUsers GT 0 ) {
            return {
                success = false,
                message = "Delete the existing TEST_USER records before generating a new batch. Current total: #existingTestUsers#.",
                totalTestUsers = existingTestUsers
            };
        }

        if ( staleMonths LT 1 ) {
            staleMonths = 6;
        }

        createdUsers = variables.UsersDAO.generateSyntheticTestUsers(
            count = generationCount,
            staleMonths = staleMonths
        );
        totalTestUsers = variables.UsersDAO.getTestUserCount();

        return {
            success = true,
            message = "Generated #arrayLen(createdUsers)# test users. Total TEST_USER records: #totalTestUsers#.",
            data = createdUsers,
            totalTestUsers = totalTestUsers
        };
    }

    public numeric function getTestUserCount() {
        return variables.UsersDAO.getTestUserCount();
    }

    public numeric function getTestUserLimit() {
        return variables.maxTestUserCount;
    }

    public struct function deleteAllTestUsers() {
        return deleteUsersByFlagName( "TEST_USER" );
    }

    public struct function resetTestUsers() {
        var staleMonths = val( _getDependency("AppConfigService", "cfc.appConfig_service").getValue( "dashboard.stale_months", "6" ) );
        var existingTestUsers = variables.UsersDAO.getTestUserCount();

        if ( staleMonths LT 1 ) {
            staleMonths = 6;
        }

        if ( existingTestUsers NEQ variables.maxTestUserCount ) {
            return {
                success = false,
                message = "Exactly #variables.maxTestUserCount# TEST_USER records are required before reset. Current total: #existingTestUsers#.",
                totalTestUsers = existingTestUsers
            };
        }

        return variables.UsersDAO.resetTestUsers(
            staleMonths = staleMonths,
            maxUsers = variables.maxTestUserCount
        );
    }

    public struct function deleteUsersByFlagName( required string flagName ) {
        var normalizedFlagName = trim( arguments.flagName ?: "" );
        var targetUserIDs = [];
        var deletedCount = 0;

        if ( !len( normalizedFlagName ) ) {
            return { success=false, message="Flag name is required.", deletedCount=0, matchedCount=0 };
        }

        targetUserIDs = variables.UsersDAO.getUserIDsByFlagName( normalizedFlagName );

        for ( var targetUserID in targetUserIDs ) {
            if ( val( targetUserID ) GT 0 ) {
                _getDependency("userDeletionService", "cfc.userDeletion_service").deleteUser( val( targetUserID ) );
                deletedCount++;
            }
        }

        return {
            success = true,
            message = "Deleted #deletedCount# users with flag #normalizedFlagName#.",
            deletedCount = deletedCount,
            matchedCount = arrayLen( targetUserIDs )
        };
    }

    
    public array function listUsers() {
        var rows = variables.UsersDAO.getAllUsers();
        _attachCurrentNameEnvelopeToRows(rows);
        return rows;
    }

    public array function listUsersForAdminIndex() {
        var rows = variables.UsersDAO.getAdminListUsers();
        return rows;
    }

    public struct function searchUsers(
        string searchTerm   = "",
        string filterFlag   = "",
        string filterOrg    = "",
        string filterClass  = "",
        string excludeFlags = "",
        string excludeOrgs  = "",
        numeric maxRows     = 50,
        numeric startRow    = 1
    ) {
        var result = variables.UsersDAO.searchUsers(
            searchTerm   = arguments.searchTerm,
            filterFlag   = arguments.filterFlag,
            filterOrg    = arguments.filterOrg,
            filterClass  = arguments.filterClass,
            excludeFlags = arguments.excludeFlags,
            excludeOrgs  = arguments.excludeOrgs,
            maxRows      = arguments.maxRows,
            startRow     = arguments.startRow
        );

        if ( structKeyExists(result, "data") AND isArray(result.data) ) {
            _getDependency("nameResolutionService", "cfc.nameResolution_service").attachPrimaryNameEnvelopeToRows(result.data);

            var userIDs = [];
            for ( var row in result.data ) {
                if ( structKeyExists(row, "USERID") AND isNumeric(row.USERID) ) {
                    arrayAppend(userIDs, val(row.USERID));
                }
            }
            var emailsMap    = _getDependency("EmailsDAO", "dao.emails_DAO").getPrimaryEmailsMap(userIDs);
            var phonesMap    = _getDependency("PhoneDAO", "dao.phone_DAO").getPrimaryPhonesMap(userIDs);
            var addressesMap = _getDependency("AddressesDAO", "dao.addresses_DAO").getPrimaryAddressesMap(userIDs);
            var degreesMap   = _getDependency("DegreesDAO", "dao.degrees_DAO").getDegreesMap(userIDs);
            var flagsMap     = _getDependency("flagsService", "cfc.flags_service").getAllUserFlagMap();
            var orgsMap      = _getDependency("organizationsService", "cfc.organizations_service").getAllUserOrgMap();

            for ( var row in result.data ) {
                var uKey = toString(val(row.USERID ?: 0));
                row["FLAGS"]        = structKeyExists(flagsMap, uKey)     ? flagsMap[uKey]       : [];
                row["ORGANIZATIONS"] = structKeyExists(orgsMap, uKey)      ? orgsMap[uKey]        : [];
                row["PRIMARYEMAIL"] = structKeyExists(emailsMap, uKey)    ? emailsMap[uKey]      : {};
                row["PRIMARYPHONE"] = structKeyExists(phonesMap, uKey)    ? phonesMap[uKey]      : {};
                row["ADDRESSES"]    = structKeyExists(addressesMap, uKey) ? [addressesMap[uKey]] : [];
                row["DEGREES"]      = structKeyExists(degreesMap, uKey)   ? degreesMap[uKey]     : [];

                var degParts = [];
                for ( var deg in row["DEGREES"] ) {
                    var dn = trim(deg.DEGREENAME ?: "");
                    if ( len(dn) ) arrayAppend(degParts, dn);
                }
                row["COMBINEDDEGREES"] = arrayToList(degParts, ", ");
            }
        }

        return result;
    }

    private void function _attachCurrentNameEnvelopeToRows( required array rows ) {
        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            _attachCurrentNameEnvelopeToRow(arguments.rows[i]);
        }
    }

    private void function _attachCurrentNameEnvelopeToRow( required struct row ) {
        var first = trim(arguments.row.FIRSTNAME ?: "");
        var middle = trim(arguments.row.MIDDLENAME ?: "");
        var last = trim(arguments.row.LASTNAME ?: "");
        var parts = [];

        if ( len(first) ) {
            arrayAppend(parts, first);
        }
        if ( len(middle) ) {
            arrayAppend(parts, middle);
        }
        if ( len(last) ) {
            arrayAppend(parts, last);
        }

        arguments.row["FULLNAME"] = arrayToList(parts, " ");
        arguments.row["NAMES"] = [
            {
                ALIASID = 0,
                FIRST = first,
                MIDDLE = middle,
                LAST = last,
                FULL = arguments.row["FULLNAME"],
                PRIMARY = true
            }
        ];
    }

    private boolean function _configValueToBoolean( required string value ) {
        var normalizedValue = lCase( trim( arguments.value ?: "" ) );
        return listFindNoCase( "1,true,yes,on", normalizedValue ) GT 0;
    }

    private any function _getDependency( required string key, required string componentPath ) {
        if ( !structKeyExists(variables, arguments.key) OR !isObject(variables[arguments.key]) ) {
            variables[arguments.key] = createObject("component", arguments.componentPath).init();
        }

        return variables[arguments.key];
    }

}