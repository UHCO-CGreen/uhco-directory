<!---
    resolve_uh_sync_diff.cfm
    Handles sync / discard actions for UH Sync Report items.

    Accepts POST with one of these operation sets:

    Field diff:
        diffID     — UHSyncDiffs.DiffID
        resolution — 'synced' | 'discarded'
        returnTo   — redirect target (validated)

    Gone user:
        goneID     — UHSyncGone.GoneID
        resolution — 'deleted' | 'kept'
        userID     — required for 'deleted' (local UserID to remove)
        returnTo   — redirect target (validated)

    New API user:
        newID      — UHSyncNew.NewID
        resolution — 'imported' | 'ignored'
        returnTo   — redirect target (validated)

    Sync all user fields + flags:
        syncAll           — '1'
        applySourceUserID — local UserID
        returnTo          — redirect target (validated)

    Sync single flag from live UH API data:
        applyFlagName     — local flag name
        applyFlagApiValue — API boolean-like value
        applySourceUserID — local UserID
        returnTo          — redirect target (validated)
--->

<cfparam name="form.diffID"     default="0">
<cfparam name="form.goneID"     default="0">
<cfparam name="form.newID"      default="0">
<cfparam name="form.resolution" default="">
<cfparam name="form.returnTo"   default="">
<cfparam name="form.userID"     default="0">
<cfparam name="form.applyFlagName" default="">
<cfparam name="form.applyFlagApiValue" default="">
<cfparam name="form.applySourceUserID" default="0">
<cfparam name="form.syncAll" default="0">

<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset usersService = createObject("component", "cfc.users_service").init()>

<!--- Only allow POST --->
<cfif cgi.REQUEST_METHOD NEQ "POST">
    <cflocation url="#request.webRoot#/admin/reporting/uh_sync_report.cfm" addtoken="false">
    <cfabort>
</cfif>

<!--- Validate returnTo: root-relative only, no open-redirect --->
<cfset returnTo = "/admin/reporting/uh_sync_report.cfm">
<cfif len(trim(form.returnTo))>
    <cfset candidate = trim(form.returnTo)>
    <cfif left(candidate, 1) EQ "/" AND NOT find("//", candidate) AND NOT findNoCase("javascript:", candidate)>
        <cfset returnTo = candidate>
    </cfif>
</cfif>
<cfset sep = find("?", returnTo) ? "&" : "?">

<cfset resolution = lCase(trim(form.resolution))>
<cfset uhSyncDAO  = createObject("component", "dao.uhSync_DAO").init()>

<!--- ══════════════════════════════════════════════════════════════════ --->
<!--- ── SYNC ALL USER DATA ─────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════════ --->
<cfif form.syncAll EQ "1" AND isNumeric(form.applySourceUserID) AND val(form.applySourceUserID) GT 0>

    <cfset applyUserID = val(form.applySourceUserID)>

    <cfif NOT request.canAccessUserByID(applyUserID)>
        <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
        <cfabort>
    </cfif>

    <cfset profileService = createObject("component", "cfc.directory_service").init()>
    <cfset syncProfile = profileService.getFullProfile(applyUserID)>

    <cfif NOT (structKeyExists(syncProfile, "user") AND structCount(syncProfile.user))>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed: user profile could not be loaded.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset syncUser = syncProfile.user>
    <cfset syncApiId = trim(syncUser.UH_API_ID ?: "")>

    <cfif NOT len(syncApiId)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed: this user does not have a UH API ID.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset uhApiCredentials = request.runtimeSecretPolicy.getUHApiCredentials()>
    <cfset uhApiToken = trim(uhApiCredentials.token ?: "")>
    <cfset uhApiSecret = trim(uhApiCredentials.secret ?: "")>

    <cfif uhApiToken EQ "" OR uhApiSecret EQ "">
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed: UH API credentials are not configured. Set UH_API_TOKEN and UH_API_SECRET environment variables.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfsilent>
        <cfset syncUhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfset syncPersonResponse = syncUhApi.getPerson(
            syncApiId,
            trim(syncUser.DEPARTMENT ?: ""),
            trim(syncUser.DIVISION ?: ""),
            trim(syncUser.CAMPUS ?: "")
        )>
    </cfsilent>

    <cfset syncStatusCode = syncPersonResponse.statusCode ?: "Unknown">
    <cfset syncResponseData = syncPersonResponse.data ?: {}>
    <cfset syncApiPerson = {}>

    <cfif left(syncStatusCode, 3) EQ "200">
        <cfif isStruct(syncResponseData)>
            <cfif structKeyExists(syncResponseData, "data") AND isStruct(syncResponseData.data)>
                <cfif structKeyExists(syncResponseData.data, "person") AND isStruct(syncResponseData.data.person)>
                    <cfset syncApiPerson = syncResponseData.data.person>
                <cfelse>
                    <cfset syncApiPerson = syncResponseData.data>
                </cfif>
            <cfelseif structKeyExists(syncResponseData, "person") AND isStruct(syncResponseData.person)>
                <cfset syncApiPerson = syncResponseData.person>
            <cfelse>
                <cfset syncApiPerson = syncResponseData>
            </cfif>
        </cfif>
    <cfelse>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed: UH API request returned status ' & syncStatusCode & '.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset currentUserResult = usersService.getUser(applyUserID)>
    <cfif NOT (structKeyExists(currentUserResult, "success") AND currentUserResult.success)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed: unable to load local user for update.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset currentUser = currentUserResult.data>
    <cfset userData = {
        FirstName              = currentUser.FIRSTNAME ?: "",
        MiddleName             = currentUser.MIDDLENAME ?: "",
        LastName               = currentUser.LASTNAME ?: "",
        Pronouns               = currentUser.PRONOUNS ?: "",
        EmailPrimary           = currentUser.EMAILPRIMARY ?: "",
        Phone                  = currentUser.PHONE ?: "",
        Room                   = currentUser.ROOM ?: "",
        Building               = currentUser.BUILDING ?: "",
        CougarNetID            = currentUser.COUGARNETID ?: "",
        Title1                 = currentUser.TITLE1 ?: "",
        Title2                 = currentUser.TITLE2 ?: "",
        Title3                 = currentUser.TITLE3 ?: "",
        Division               = currentUser.DIVISION ?: "",
        DivisionName           = currentUser.DIVISIONNAME ?: "",
        Campus                 = currentUser.CAMPUS ?: "",
        Department             = currentUser.DEPARTMENT ?: "",
        DepartmentName         = currentUser.DEPARTMENTNAME ?: "",
        Office_Mailing_Address = currentUser.OFFICE_MAILING_ADDRESS ?: "",
        Mailcode               = currentUser.MAILCODE ?: "",
        UH_API_ID              = currentUser.UH_API_ID ?: "",
        Degrees                = currentUser.DEGREES ?: "",
        Prefix                 = currentUser.PREFIX ?: "",
        Suffix                 = currentUser.SUFFIX ?: ""
    }>

    <cfscript>
        function resolveSyncAllFindValueByKeyDeep(any node="", required string keyName) {
            var keys = [];
            var currentKey = "";
            var found = "";
            var index = 1;

            if (isNull(arguments.node)) { return ""; }

            if (isStruct(arguments.node)) {
                keys = structKeyArray(arguments.node);
                for (index = 1; index <= arrayLen(keys); index++) {
                    currentKey = keys[index];
                    if (compareNoCase(currentKey, arguments.keyName) EQ 0) {
                        if (isSimpleValue(arguments.node[currentKey])) { return toString(arguments.node[currentKey] ?: ""); }
                        if (isBoolean(arguments.node[currentKey])) { return arguments.node[currentKey] ? "true" : "false"; }
                    }
                }
                for (index = 1; index <= arrayLen(keys); index++) {
                    found = resolveSyncAllFindValueByKeyDeep(node=arguments.node[keys[index]], keyName=arguments.keyName);
                    if (len(trim(toString(found)))) { return found; }
                }
            } else if (isArray(arguments.node)) {
                for (index = 1; index <= arrayLen(arguments.node); index++) {
                    found = resolveSyncAllFindValueByKeyDeep(node=arguments.node[index], keyName=arguments.keyName);
                    if (len(trim(toString(found)))) { return found; }
                }
            }

            return "";
        }

        function resolveSyncAllGetApiValue(required any source, required string keyListCsv) {
            var names = listToArray(arguments.keyListCsv);
            var index = 1;
            var foundValue = "";

            for (index = 1; index <= arrayLen(names); index++) {
                foundValue = resolveSyncAllFindValueByKeyDeep(node=arguments.source, keyName=trim(names[index]));
                if (len(trim(toString(foundValue)))) { return toString(foundValue); }
            }

            return "";
        }
    </cfscript>

    <cfset apiFirstName      = trim(resolveSyncAllGetApiValue(syncApiPerson, "first_name,firstName"))>
    <cfset apiMiddleName     = trim(resolveSyncAllGetApiValue(syncApiPerson, "middle_name,middleName"))>
    <cfset apiLastName       = trim(resolveSyncAllGetApiValue(syncApiPerson, "last_name,lastName"))>
    <cfset apiEmail          = trim(resolveSyncAllGetApiValue(syncApiPerson, "email,emailAddress"))>
    <cfset apiPhone          = trim(resolveSyncAllGetApiValue(syncApiPerson, "phone,phoneNumber"))>
    <cfset apiRoom           = trim(resolveSyncAllGetApiValue(syncApiPerson, "room"))>
    <cfset apiBuilding       = trim(resolveSyncAllGetApiValue(syncApiPerson, "building"))>
    <cfset apiTitle          = trim(resolveSyncAllGetApiValue(syncApiPerson, "title"))>
    <cfset apiDivision       = trim(resolveSyncAllGetApiValue(syncApiPerson, "division"))>
    <cfset apiDivisionName   = trim(resolveSyncAllGetApiValue(syncApiPerson, "division_name,divisionName"))>
    <cfset apiCampus         = trim(resolveSyncAllGetApiValue(syncApiPerson, "campus"))>
    <cfset apiDepartment     = trim(resolveSyncAllGetApiValue(syncApiPerson, "department"))>
    <cfset apiDepartmentName = trim(resolveSyncAllGetApiValue(syncApiPerson, "department_name,departmentName"))>
    <cfset apiOfficeAddr     = trim(resolveSyncAllGetApiValue(syncApiPerson, "office_mailing_address,officeMailingAddress,mailing_address"))>
    <cfset apiMailcode       = trim(resolveSyncAllGetApiValue(syncApiPerson, "mailcode,mail_code"))>

    <cfif len(apiFirstName)><cfset userData.FirstName = apiFirstName></cfif>
    <cfif len(apiMiddleName)><cfset userData.MiddleName = apiMiddleName></cfif>
    <cfif len(apiLastName)><cfset userData.LastName = apiLastName></cfif>
    <cfif len(apiEmail)><cfset userData.EmailPrimary = lCase(apiEmail)></cfif>
    <cfif len(apiPhone)><cfset userData.Phone = apiPhone></cfif>
    <cfif len(apiRoom)><cfset userData.Room = apiRoom></cfif>
    <cfif len(apiBuilding)><cfset userData.Building = apiBuilding></cfif>
    <cfif len(apiTitle)><cfset userData.Title1 = apiTitle></cfif>
    <cfif len(apiDivision)><cfset userData.Division = apiDivision></cfif>
    <cfif len(apiDivisionName)><cfset userData.DivisionName = apiDivisionName></cfif>
    <cfif len(apiCampus)><cfset userData.Campus = apiCampus></cfif>
    <cfif len(apiDepartment)><cfset userData.Department = apiDepartment></cfif>
    <cfif len(apiDepartmentName)><cfset userData.DepartmentName = apiDepartmentName></cfif>
    <cfif len(apiOfficeAddr)><cfset userData.Office_Mailing_Address = apiOfficeAddr></cfif>
    <cfif len(apiMailcode)><cfset userData.Mailcode = apiMailcode></cfif>

    <cfset updateResult = usersService.updateUser(applyUserID, userData)>
    <cfif NOT (structKeyExists(updateResult, "success") AND updateResult.success)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Sync All failed while updating user fields: ' & (updateResult.message ?: 'Unknown error'))#" addtoken="false">
        <cfabort>
    </cfif>

    <cfif len(apiFirstName) OR len(apiLastName)>
        <cfset aliasService = createObject("component", "cfc.aliases_service").init()>
        <cfset existingAliases = aliasService.getAliases(applyUserID).data ?: []>
        <cfset primaryAliasIndex = 0>
        <cfset firstActiveAliasIndex = 0>

        <cfloop from="1" to="#arrayLen(existingAliases)#" index="aliasIndex">
            <cfif val(existingAliases[aliasIndex].ISPRIMARY ?: 0) EQ 1>
                <cfset primaryAliasIndex = aliasIndex>
                <cfbreak>
            </cfif>
            <cfif firstActiveAliasIndex EQ 0 AND val(existingAliases[aliasIndex].ISACTIVE ?: 0) EQ 1>
                <cfset firstActiveAliasIndex = aliasIndex>
            </cfif>
        </cfloop>

        <cfif primaryAliasIndex EQ 0><cfset primaryAliasIndex = firstActiveAliasIndex></cfif>

        <cfset aliasesToSave = []>
        <cfif primaryAliasIndex GT 0>
            <cfloop from="1" to="#arrayLen(existingAliases)#" index="aliasIndex">
                <cfset currentAlias = existingAliases[aliasIndex]>
                <cfset aliasRow = {
                    firstName    = trim(currentAlias.FIRSTNAME ?: ""),
                    middleName   = trim(currentAlias.MIDDLENAME ?: ""),
                    lastName     = trim(currentAlias.LASTNAME ?: ""),
                    aliasType    = trim(currentAlias.ALIASTYPE ?: ""),
                    sourceSystem = trim(currentAlias.SOURCESYSTEM ?: ""),
                    isActive     = val(currentAlias.ISACTIVE ?: 0),
                    isPrimary    = val(currentAlias.ISPRIMARY ?: 0)
                }>
                <cfif aliasIndex EQ primaryAliasIndex>
                    <cfif len(apiFirstName)><cfset aliasRow.firstName = apiFirstName></cfif>
                    <cfif len(apiMiddleName)><cfset aliasRow.middleName = apiMiddleName></cfif>
                    <cfif len(apiLastName)><cfset aliasRow.lastName = apiLastName></cfif>
                    <cfif NOT len(aliasRow.aliasType)><cfset aliasRow.aliasType = "SOURCE_VARIANT"></cfif>
                    <cfif NOT len(aliasRow.sourceSystem)><cfset aliasRow.sourceSystem = "UH API"></cfif>
                    <cfset aliasRow.isPrimary = 1>
                </cfif>
                <cfset arrayAppend(aliasesToSave, aliasRow)>
            </cfloop>
        <cfelse>
            <cfset arrayAppend(aliasesToSave, {
                firstName    = apiFirstName,
                middleName   = apiMiddleName,
                lastName     = apiLastName,
                aliasType    = "SOURCE_VARIANT",
                sourceSystem = "UH API",
                isActive     = 1,
                isPrimary    = 1
            })>
        </cfif>

        <cfset aliasService.replaceAliases(applyUserID, aliasesToSave)>
    </cfif>

    <cfset flagsService = createObject("component", "cfc.flags_service").init()>
    <cfset allFlagsResult = flagsService.getAllFlags()>
    <cfset syncFlagsUpdated = 0>

    <cfif structKeyExists(allFlagsResult, "success") AND allFlagsResult.success>
        <cfset currentFlagsResult = flagsService.getUserFlags(applyUserID)>
        <cfset userHasCurrentStudent = false>
        <cfset userHasStaff = false>
        <cfset userHasFaculty = false>
        <cfset currentStudentFlagID = 0>
        <cfset staffFlagID = 0>
        <cfset facultyFlagID = 0>

        <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="flagIndex">
            <cfif compareNoCase(trim(allFlagsResult.data[flagIndex].FLAGNAME ?: ""), "Current-Student") EQ 0>
                <cfset currentStudentFlagID = val(allFlagsResult.data[flagIndex].FLAGID ?: 0)>
            <cfelseif compareNoCase(trim(allFlagsResult.data[flagIndex].FLAGNAME ?: ""), "Staff") EQ 0>
                <cfset staffFlagID = val(allFlagsResult.data[flagIndex].FLAGID ?: 0)>
            <cfelseif compareNoCase(trim(allFlagsResult.data[flagIndex].FLAGNAME ?: ""), "Faculty-Fulltime") EQ 0>
                <cfset facultyFlagID = val(allFlagsResult.data[flagIndex].FLAGID ?: 0)>
            </cfif>
        </cfloop>

        <cfif structKeyExists(currentFlagsResult, "success") AND currentFlagsResult.success>
            <cfloop from="1" to="#arrayLen(currentFlagsResult.data)#" index="userFlagIndex">
                <cfset thisFlagID = val(currentFlagsResult.data[userFlagIndex].FLAGID ?: 0)>
                <cfif thisFlagID EQ currentStudentFlagID><cfset userHasCurrentStudent = true></cfif>
                <cfif thisFlagID EQ staffFlagID><cfset userHasStaff = true></cfif>
                <cfif thisFlagID EQ facultyFlagID><cfset userHasFaculty = true></cfif>
            </cfloop>
        </cfif>

        <cfset apiStudent = lCase(trim(resolveSyncAllGetApiValue(syncApiPerson, "student,is_student,isStudent")))>
        <cfset apiStaff = lCase(trim(resolveSyncAllGetApiValue(syncApiPerson, "staff,is_staff,isStaff")))>
        <cfset apiFaculty = lCase(trim(resolveSyncAllGetApiValue(syncApiPerson, "faculty,is_faculty,isFaculty")))>

        <cfif currentStudentFlagID GT 0>
            <cfif listFindNoCase("yes,true,1,y", apiStudent) AND NOT userHasCurrentStudent>
                <cfset flagsService.addFlag(applyUserID, currentStudentFlagID)>
                <cfset syncFlagsUpdated++>
            <cfelseif listFindNoCase("no,false,0,n", apiStudent) AND userHasCurrentStudent>
                <cfset flagsService.removeFlag(applyUserID, currentStudentFlagID)>
                <cfset syncFlagsUpdated++>
            </cfif>
        </cfif>

        <cfif staffFlagID GT 0>
            <cfif listFindNoCase("yes,true,1,y", apiStaff) AND NOT userHasStaff>
                <cfset flagsService.addFlag(applyUserID, staffFlagID)>
                <cfset syncFlagsUpdated++>
            <cfelseif listFindNoCase("no,false,0,n", apiStaff) AND userHasStaff>
                <cfset flagsService.removeFlag(applyUserID, staffFlagID)>
                <cfset syncFlagsUpdated++>
            </cfif>
        </cfif>

        <cfif facultyFlagID GT 0>
            <cfif listFindNoCase("yes,true,1,y", apiFaculty) AND NOT userHasFaculty>
                <cfset flagsService.addFlag(applyUserID, facultyFlagID)>
                <cfset syncFlagsUpdated++>
            <cfelseif listFindNoCase("no,false,0,n", apiFaculty) AND userHasFaculty>
                <cfset flagsService.removeFlag(applyUserID, facultyFlagID)>
                <cfset syncFlagsUpdated++>
            </cfif>
        </cfif>
    </cfif>

    <cfset pendingDiffsForUser = uhSyncDAO.getUnresolvedDiffsForUser(applyUserID)>
    <cfif arrayLen(pendingDiffsForUser) GT 0>
        <cfset uhSyncDAO.resolveAllDiffsForUser(applyUserID, val(pendingDiffsForUser[1].RUNID ?: 0), "synced")>
    </cfif>

    <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat('Sync All complete. Updated profile fields and ' & syncFlagsUpdated & ' flag change(s).')#" addtoken="false">
    <cfabort>

<!--- ══════════════════════════════════════════════════════════════════ --->
<!--- ── SYNC SINGLE FLAG ──────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════════ --->
<cfelseif len(trim(form.applyFlagName)) AND isNumeric(form.applySourceUserID) AND val(form.applySourceUserID) GT 0>

    <cfset applyUserID = val(form.applySourceUserID)>

    <cfif NOT request.canAccessUserByID(applyUserID)>
        <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
        <cfabort>
    </cfif>

    <cfset flagsService = createObject("component", "cfc.flags_service").init()>
    <cfset requestedFlagName = trim(form.applyFlagName)>
    <cfset requestedApiValue = lCase(trim(form.applyFlagApiValue ?: ""))>
    <cfset targetHasFlag = "">
    <cfset flagID = 0>

    <cfif listFindNoCase("yes,true,1,y", requestedApiValue)>
        <cfset targetHasFlag = true>
    <cfelseif listFindNoCase("no,false,0,n", requestedApiValue)>
        <cfset targetHasFlag = false>
    <cfelse>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Unable to sync flag: API value is not a supported boolean.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset allFlagsResult = flagsService.getAllFlags()>
    <cfif structKeyExists(allFlagsResult, "success") AND allFlagsResult.success>
        <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="flagIndex">
            <cfif compareNoCase(trim(allFlagsResult.data[flagIndex].FLAGNAME ?: ""), requestedFlagName) EQ 0>
                <cfset flagID = val(allFlagsResult.data[flagIndex].FLAGID ?: 0)>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>

    <cfif flagID LTE 0>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Unable to sync flag: ' & requestedFlagName & ' was not found.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset currentFlagsResult = flagsService.getUserFlags(applyUserID)>
    <cfset userHasFlag = false>
    <cfif structKeyExists(currentFlagsResult, "success") AND currentFlagsResult.success>
        <cfloop from="1" to="#arrayLen(currentFlagsResult.data)#" index="flagIndex">
            <cfif val(currentFlagsResult.data[flagIndex].FLAGID ?: 0) EQ flagID>
                <cfset userHasFlag = true>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>

    <cfif targetHasFlag AND NOT userHasFlag>
        <cfset actionResult = flagsService.addFlag(applyUserID, flagID)>
        <cfif NOT (structKeyExists(actionResult, "success") AND actionResult.success)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Failed to add flag: ' & (actionResult.message ?: 'Unknown error'))#" addtoken="false">
            <cfabort>
        </cfif>
        <cfset flagMessage = "Added flag '" & requestedFlagName & "'.">
    <cfelseif NOT targetHasFlag AND userHasFlag>
        <cfset actionResult = flagsService.removeFlag(applyUserID, flagID)>
        <cfif NOT (structKeyExists(actionResult, "success") AND actionResult.success)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Failed to remove flag: ' & (actionResult.message ?: 'Unknown error'))#" addtoken="false">
            <cfabort>
        </cfif>
        <cfset flagMessage = "Removed flag '" & requestedFlagName & "'.">
    <cfelse>
        <cfset flagMessage = "No change needed for flag '" & requestedFlagName & "'.">
    </cfif>

    <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat(flagMessage)#" addtoken="false">
    <cfabort>

<!--- ══════════════════════════════════════════════════════════════════ --->
<!--- ── FIELD DIFF ─────────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════════ --->
<cfelseif isNumeric(form.diffID) AND val(form.diffID) GT 0>

    <cfset diffID     = val(form.diffID)>
    <cfset allowedRes = ["synced", "discarded"]>

    <cfif NOT arrayFindNoCase(allowedRes, resolution)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Invalid resolution for diff.')#" addtoken="false">
        <cfabort>
    </cfif>

    <!--- Load the diff record --->
    <cfset diffRow = uhSyncDAO.getDiffByID(diffID)>
    <cfif structIsEmpty(diffRow)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Diff record not found.')#" addtoken="false">
        <cfabort>
    </cfif>
    <cfif len(trim(diffRow.RESOLUTION ?: ""))>
        <!--- Already resolved — just redirect cleanly --->
        <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat('Already resolved.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfif resolution EQ "synced">
        <!--- Apply the API value to the local user field --->
        <cfif NOT request.canAccessUserByID(val(diffRow.USERID))>
            <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
            <cfabort>
        </cfif>

        <cfset currentUserResult = usersService.getUser(val(diffRow.USERID))>

        <cfif NOT (structKeyExists(currentUserResult, "success") AND currentUserResult.success)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Could not load user ' & diffRow.USERID & ' for update.')#" addtoken="false">
            <cfabort>
        </cfif>

        <cfset cu       = currentUserResult.data>
        <cfset userData = {
            FirstName              = cu.FIRSTNAME              ?: "",
            MiddleName             = cu.MIDDLENAME             ?: "",
            LastName               = cu.LASTNAME               ?: "",
            Pronouns               = cu.PRONOUNS               ?: "",
            EmailPrimary           = cu.EMAILPRIMARY           ?: "",
            Phone                  = cu.PHONE                  ?: "",
            Room                   = cu.ROOM                   ?: "",
            Building               = cu.BUILDING               ?: "",
            Title1                 = cu.TITLE1                 ?: "",
            Title2                 = cu.TITLE2                 ?: "",
            Title3                 = cu.TITLE3                 ?: "",
            Division               = cu.DIVISION               ?: "",
            DivisionName           = cu.DIVISIONNAME           ?: "",
            Campus                 = cu.CAMPUS                 ?: "",
            Department             = cu.DEPARTMENT             ?: "",
            DepartmentName         = cu.DEPARTMENTNAME         ?: "",
            Office_Mailing_Address = cu.OFFICE_MAILING_ADDRESS ?: "",
            Mailcode               = cu.MAILCODE               ?: "",
            UH_API_ID              = cu.UH_API_ID              ?: "",
            Degrees                = cu.DEGREES                ?: "",
            Prefix                 = cu.PREFIX                 ?: "",
            Suffix                 = cu.SUFFIX                 ?: ""
        }>

        <!--- Map the stored field name to the userData key --->
        <cfset fieldName = uCase(trim(diffRow.FIELDNAME))>
        <cfset apiVal    = trim(diffRow.APIVALUE)>

        <cfif     fieldName EQ "FIRSTNAME">              <cfset userData.FirstName              = apiVal>
        <cfelseif fieldName EQ "LASTNAME">               <cfset userData.LastName               = apiVal>
        <cfelseif fieldName EQ "EMAILPRIMARY">           <cfset userData.EmailPrimary           = lCase(apiVal)>
        <cfelseif fieldName EQ "PHONE">                  <cfset userData.Phone                  = apiVal>
        <cfelseif fieldName EQ "ROOM">                   <cfset userData.Room                   = apiVal>
        <cfelseif fieldName EQ "BUILDING">               <cfset userData.Building               = apiVal>
        <cfelseif fieldName EQ "TITLE1">                 <cfset userData.Title1                 = apiVal>
        <cfelseif fieldName EQ "DIVISION">               <cfset userData.Division               = apiVal>
        <cfelseif fieldName EQ "DIVISIONNAME">           <cfset userData.DivisionName           = apiVal>
        <cfelseif fieldName EQ "CAMPUS">                 <cfset userData.Campus                 = apiVal>
        <cfelseif fieldName EQ "DEPARTMENT">             <cfset userData.Department             = apiVal>
        <cfelseif fieldName EQ "DEPARTMENTNAME">         <cfset userData.DepartmentName         = apiVal>
        <cfelseif fieldName EQ "OFFICE_MAILING_ADDRESS"> <cfset userData.Office_Mailing_Address = apiVal>
        <cfelseif fieldName EQ "MAILCODE">               <cfset userData.Mailcode               = apiVal>
        <cfelse>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Field ' & diffRow.FIELDNAME & ' cannot be synced from this page.')#" addtoken="false">
            <cfabort>
        </cfif>

        <cfset updateResult = usersService.updateUser(val(diffRow.USERID), userData)>
        <cfif NOT (structKeyExists(updateResult, "success") AND updateResult.success)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Update failed: ' & (updateResult.message ?: 'Unknown error.'))#" addtoken="false">
            <cfabort>
        </cfif>
    </cfif>

    <!--- Mark diff resolved --->
    <cftry>
        <cfset uhSyncDAO.resolveDiff(diffID, resolution)>
    <cfcatch>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Resolution save failed: ' & cfcatch.message)#" addtoken="false">
        <cfabort>
    </cfcatch>
    </cftry>

    <cfset fieldLabel = trim(diffRow.FIELDNAME)>
    <cfset msgLabels  = { "synced"="Synced", "discarded"="Discarded" }>
    <cfset msgTxt     = (msgLabels[resolution] ?: resolution) & " " & fieldLabel & " for user " & diffRow.USERID & ".">
    <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat(msgTxt)#" addtoken="false">
    <cfabort>

<!--- ══════════════════════════════════════════════════════════════════ --->
<!--- ── GONE USER ──────────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════════ --->
<cfelseif isNumeric(form.goneID) AND val(form.goneID) GT 0>

    <cfset goneID     = val(form.goneID)>
    <cfset allowedRes = ["deleted", "kept"]>

    <cfif NOT arrayFindNoCase(allowedRes, resolution)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Invalid resolution for gone user.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset goneRow = uhSyncDAO.getGoneByID(goneID)>
    <cfif structIsEmpty(goneRow)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Gone record not found.')#" addtoken="false">
        <cfabort>
    </cfif>
    <cfif len(trim(goneRow.RESOLUTION ?: ""))>
        <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat('Already resolved.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfif resolution EQ "deleted">
        <cfif NOT request.hasPermission("users.delete")>
            <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
            <cfabort>
        </cfif>

        <!--- Delete user from local DB using userID from form (double-check matches gone record) --->
        <cfset targetUserID = isNumeric(form.userID) ? val(form.userID) : val(goneRow.USERID)>
        <cfif targetUserID GT 0>
            <cfif NOT request.canAccessUserByID(targetUserID)>
                <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
                <cfabort>
            </cfif>

            <cfset deleteResult  = usersService.deleteUser(targetUserID)>
            <cfif NOT (structKeyExists(deleteResult, "success") AND deleteResult.success)>
                <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Could not delete user: ' & (deleteResult.message ?: 'Unknown error.'))#" addtoken="false">
                <cfabort>
            </cfif>
        </cfif>
    </cfif>

    <cftry>
        <cfset uhSyncDAO.resolveGone(goneID, resolution)>
    <cfcatch>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Resolution save failed: ' & cfcatch.message)#" addtoken="false">
        <cfabort>
    </cfcatch>
    </cftry>

    <cfset msgTxt = resolution EQ "deleted" ? "User deleted successfully." : "User marked as kept (no action taken).">
    <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat(msgTxt)#" addtoken="false">
    <cfabort>

<!--- ══════════════════════════════════════════════════════════════════ --->
<!--- ── NEW API USER ───────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════════ --->
<cfelseif isNumeric(form.newID) AND val(form.newID) GT 0>

    <cfset newID      = val(form.newID)>
    <cfset allowedRes = ["imported", "ignored"]>

    <cfif NOT arrayFindNoCase(allowedRes, resolution)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Invalid resolution for new user.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset newRow = uhSyncDAO.getNewByID(newID)>
    <cfif structIsEmpty(newRow)>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('New-user record not found.')#" addtoken="false">
        <cfabort>
    </cfif>
    <cfif len(trim(newRow.RESOLUTION ?: ""))>
        <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat('Already resolved.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfif resolution EQ "imported">
        <cfif NOT request.canCreateUsers()>
            <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
            <cfabort>
        </cfif>

        <cfset uhApiId = trim(newRow.UHApiID ?: "")>
        <!--- Prefer actual UHApiID column name - handles different CF case sensitivity --->
        <cftry>
            <cfset uhApiId = trim(newRow.UHApiID)>
        <cfcatch>
            <cfset uhApiId = "">
        </cfcatch>
        </cftry>

        <cfif NOT len(uhApiId)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('No UH API ID stored for this new-user record.')#" addtoken="false">
            <cfabort>
        </cfif>

        <!--- Guard: do not create a duplicate --->
        <cfset existingCheck = queryExecute(
            "SELECT TOP 1 UserID FROM Users WHERE UH_API_ID = :id",
            { id = { value=uhApiId, cfsqltype="cf_sql_nvarchar" } },
            { datasource="#request.datasource#", timeout=30 }
        )>
        <cfif existingCheck.recordCount GT 0>
            <!--- Already exists — just mark resolved and continue --->
            <cfset uhSyncDAO.resolveNew(newID, "imported")>
            <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat('User already exists locally (UserID ' & existingCheck.UserID & '); marked as imported.')#" addtoken="false">
            <cfabort>
        </cfif>

        <!--- ── Re-fetch fresh person data from UH API ── --->
        <cfset uhApiCredentials = request.runtimeSecretPolicy.getUHApiCredentials()>
        <cfset uhApiToken = trim(uhApiCredentials.token ?: "")>
        <cfset uhApiSecret = trim(uhApiCredentials.secret ?: "")>

        <cfif uhApiToken EQ "" OR uhApiSecret EQ "">
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API credentials are not configured. Set UH_API_TOKEN and UH_API_SECRET environment variables.')#" addtoken="false">
            <cfabort>
        </cfif>

        <cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfsilent>
            <cfset personResponse = uhApi.getPerson(uhApiId)>
        </cfsilent>
        <cfset statusCode   = personResponse.statusCode ?: "Unknown">
        <cfset responseData = personResponse.data ?: {}>

        <cfif left(statusCode, 3) NEQ "200">
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API returned status ' & statusCode & ' while re-fetching person ' & uhApiId)#" addtoken="false">
            <cfabort>
        </cfif>

        <!--- Unwrap nested response --->
        <cfset apiPerson = {}>
        <cfif isStruct(responseData)>
            <cfif structKeyExists(responseData, "data") AND isStruct(responseData.data)>
                <cfif structKeyExists(responseData.data, "person") AND isStruct(responseData.data.person)>
                    <cfset apiPerson = responseData.data.person>
                <cfelse>
                    <cfset apiPerson = responseData.data>
                </cfif>
            <cfelseif structKeyExists(responseData, "data") AND isArray(responseData.data) AND arrayLen(responseData.data) GT 0>
                <cfset apiPerson = responseData.data[1]>
            <cfelseif structKeyExists(responseData, "person") AND isStruct(responseData.person)>
                <cfset apiPerson = responseData.person>
            <cfelse>
                <cfset apiPerson = responseData>
            </cfif>
        <cfelseif isArray(responseData) AND arrayLen(responseData) GT 0>
            <cfset apiPerson = responseData[1]>
        </cfif>

        <!--- Deep-search helper --->
        <cfscript>
            function rsdFindDeep(any node="", required string keyName) {
                var keys  = [];  var k = "";  var found = "";  var i = 1;
                if (isNull(arguments.node)) { return ""; }
                if (isStruct(arguments.node)) {
                    keys = structKeyArray(arguments.node);
                    for (i = 1; i <= arrayLen(keys); i++) {
                        k = keys[i];
                        if (compareNoCase(k, arguments.keyName) EQ 0 AND isSimpleValue(arguments.node[k])) {
                            return toString(arguments.node[k] ?: "");
                        }
                    }
                    for (i = 1; i <= arrayLen(keys); i++) {
                        found = rsdFindDeep(node=arguments.node[keys[i]], keyName=arguments.keyName);
                        if (len(trim(toString(found)))) { return found; }
                    }
                } else if (isArray(arguments.node)) {
                    for (i = 1; i <= arrayLen(arguments.node); i++) {
                        found = rsdFindDeep(node=arguments.node[i], keyName=arguments.keyName);
                        if (len(trim(toString(found)))) { return found; }
                    }
                }
                return "";
            }
            function rsdGet(required any src, required string keysCsv) {
                var names = listToArray(arguments.keysCsv);
                var i = 1; var v = "";
                for (i = 1; i <= arrayLen(names); i++) {
                    v = rsdFindDeep(node=arguments.src, keyName=trim(names[i]));
                    if (len(trim(toString(v)))) { return toString(v); }
                }
                return "";
            }
        </cfscript>

        <cfset apiFirstName    = trim(rsdGet(apiPerson, "first_name,firstName"))>
        <cfset apiLastName     = trim(rsdGet(apiPerson, "last_name,lastName"))>
        <cfset apiEmail        = trim(rsdGet(apiPerson, "email,emailAddress"))>
        <cfset apiPhone        = trim(rsdGet(apiPerson, "phone,phoneNumber"))>
        <cfset apiRoom         = trim(rsdGet(apiPerson, "room"))>
        <cfset apiBuilding     = trim(rsdGet(apiPerson, "building"))>
        <cfset apiTitle        = trim(rsdGet(apiPerson, "title"))>
        <cfset apiDivision     = trim(rsdGet(apiPerson, "division"))>
        <cfset apiDivisionName = trim(rsdGet(apiPerson, "division_name,divisionName"))>
        <cfset apiCampus       = trim(rsdGet(apiPerson, "campus"))>
        <cfset apiDept         = trim(rsdGet(apiPerson, "department"))>
        <cfset apiDeptName     = trim(rsdGet(apiPerson, "department_name,departmentName"))>
        <cfset apiOfficeAddr   = trim(rsdGet(apiPerson, "office_mailing_address,officeMailingAddress,mailing_address"))>
        <cfset apiMailcode     = trim(rsdGet(apiPerson, "mailcode,mail_code"))>
        <cfset apiStudent      = lCase(trim(rsdGet(apiPerson, "student,is_student,isStudent")))>
        <cfset apiStaff        = lCase(trim(rsdGet(apiPerson, "staff,is_staff,isStaff")))>
        <cfset apiFaculty      = lCase(trim(rsdGet(apiPerson, "faculty,is_faculty,isFaculty")))>

        <!--- Fallback to stored values if API re-fetch had sparse data --->
        <cfif NOT len(apiFirstName)><cfset apiFirstName = trim(newRow.FIRSTNAME ?: "")></cfif>
        <cfif NOT len(apiLastName)> <cfset apiLastName  = trim(newRow.LASTNAME  ?: "")></cfif>
        <cfif NOT len(apiEmail)>    <cfset apiEmail     = trim(newRow.EMAIL     ?: "")></cfif>
        <cfif NOT len(apiTitle)>    <cfset apiTitle     = trim(newRow.TITLE     ?: "")></cfif>
        <cfif NOT len(apiDept)>     <cfset apiDept      = trim(newRow.DEPARTMENT ?: "")></cfif>
        <cfif NOT len(apiPhone)>    <cfset apiPhone     = trim(newRow.PHONE     ?: "")></cfif>

        <cfif NOT len(apiFirstName) OR NOT len(apiLastName)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Cannot import: missing first or last name for API ID ' & uhApiId)#" addtoken="false">
            <cfabort>
        </cfif>

        <!--- Create local user --->
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset createResult = usersService.createUser({
            FirstName              = apiFirstName,
            MiddleName             = "",
            LastName               = apiLastName,
            Pronouns               = "",
            EmailPrimary           = (len(apiEmail)       ? lCase(apiEmail)    : ""),
            Phone                  = (len(apiPhone)       ? apiPhone           : ""),
            Room                   = (len(apiRoom)        ? apiRoom            : ""),
            Building               = (len(apiBuilding)    ? apiBuilding        : ""),
            Title1                 = (len(apiTitle)       ? apiTitle           : ""),
            Title2                 = "",
            Title3                 = "",
            Division               = (len(apiDivision)    ? apiDivision        : ""),
            DivisionName           = (len(apiDivisionName)? apiDivisionName    : ""),
            Campus                 = (len(apiCampus)      ? apiCampus          : ""),
            Department             = (len(apiDept)        ? apiDept            : ""),
            DepartmentName         = (len(apiDeptName)    ? apiDeptName        : ""),
            Office_Mailing_Address = (len(apiOfficeAddr)  ? apiOfficeAddr      : ""),
            Mailcode               = (len(apiMailcode)    ? apiMailcode        : ""),
            Degrees                = "",
            Prefix                 = "",
            Suffix                 = "",
            UH_API_ID              = uhApiId
        })>

        <cfif NOT (structKeyExists(createResult, "success") AND createResult.success)>
            <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Failed to create user: ' & (createResult.message ?: 'Unknown error.'))#" addtoken="false">
            <cfabort>
        </cfif>

        <cfset newUserID = val(createResult.userID ?: 0)>

        <!--- Assign flags from API booleans --->
        <cfset flagsService     = createObject("component", "cfc.flags_service").init()>
        <cfset allFlagsResult   = flagsService.getAllFlags()>
        <cfif structKeyExists(allFlagsResult, "success") AND allFlagsResult.success>
            <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="f">
                <cfset fname = trim(allFlagsResult.data[f].FLAGNAME ?: "")>
                <cfset fid   = val(allFlagsResult.data[f].FLAGID ?: 0)>
                <cfif compareNoCase(fname, "Current-Student") EQ 0 AND listFindNoCase("yes,true,1,y", apiStudent)>
                    <cfset flagsService.addFlag(newUserID, fid)>
                <cfelseif compareNoCase(fname, "Staff") EQ 0 AND listFindNoCase("yes,true,1,y", apiStaff)>
                    <cfset flagsService.addFlag(newUserID, fid)>
                <cfelseif compareNoCase(fname, "Faculty-Fulltime") EQ 0 AND listFindNoCase("yes,true,1,y", apiFaculty)>
                    <cfset flagsService.addFlag(newUserID, fid)>
                </cfif>
            </cfloop>
        </cfif>

    </cfif>  <!--- end resolution EQ imported --->

    <!--- Mark new record resolved --->
    <cftry>
        <cfset uhSyncDAO.resolveNew(newID, resolution)>
    <cfcatch>
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Resolution save failed: ' & cfcatch.message)#" addtoken="false">
        <cfabort>
    </cfcatch>
    </cftry>

    <cfset msgTxt = resolution EQ "imported"
        ? "User imported successfully (UserID " & (newUserID ?: "?") & ")."
        : "New API user ignored.">
    <cflocation url="#returnTo##sep#msg=resolved&info=#urlEncodedFormat(msgTxt)#" addtoken="false">
    <cfabort>

<cfelse>
    <!--- No valid operation supplied --->
    <cflocation url="#request.webRoot#/admin/reporting/uh_sync_report.cfm?err=#urlEncodedFormat('No valid action supplied.')#" addtoken="false">
</cfif>
