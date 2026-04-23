<cfparam name="url.userID" default="">
<cfparam name="url.sourceUserID" default="">
<cfparam name="url.returnTo" default="">
<cfparam name="form.applyApiField" default="">
<cfparam name="form.applyApiValue" default="">
<cfparam name="form.applyFlagName" default="">
<cfparam name="form.applyFlagApiValue" default="">
<cfparam name="form.applySourceUserID" default="">
<cfparam name="form.syncAll" default="0">

<cfset sourceUserID = "">
<cfif len(trim(url.sourceUserID))>
    <cfset sourceUserID = trim(url.sourceUserID)>
<cfelseif len(trim(url.userID))>
    <cfset sourceUserID = trim(url.userID)>
<cfelseif isNumeric(form.applySourceUserID) AND val(form.applySourceUserID) GT 0>
    <cfset sourceUserID = trim(form.applySourceUserID)>
</cfif>

<!--- returnTo: only allow relative paths under /admin/ to prevent open redirect --->
<cfset returnTo = "">
<cfif len(trim(url.returnTo))>
    <cfset candidateReturn = trim(url.returnTo)>
    <cfif left(candidateReturn, 1) EQ "/" AND NOT find("//", candidateReturn) AND NOT findNoCase("javascript:", candidateReturn)>
        <cfset returnTo = candidateReturn>
    </cfif>
</cfif>

<cfset saveMessage = "">
<cfset saveMessageClass = "">
<cfset dbUser = {}>
<cfset dbFlags = []>

<!--- Require a valid numeric userID --->
<cfif NOT (isNumeric(sourceUserID) AND val(sourceUserID) GT 0)>
    <cfset content = "<h1>UH API Sync</h1><div class='alert alert-danger'>No valid user ID provided. Pass <code>userID</code> in the URL.</div><a href='/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<!--- Load the user record --->
<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset profile = directoryService.getFullProfile(val(sourceUserID))>

<cfif structKeyExists(profile, "user") AND structCount(profile.user) GT 0>
    <cfset dbUser = profile.user>
<cfelse>
    <cfset content = "<h1>UH API Sync</h1><div class='alert alert-danger'>User #EncodeForHTML(sourceUserID)# was not found.</div><a href='/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<cfif structKeyExists(profile, "flags") AND isArray(profile.flags)>
    <cfset dbFlags = profile.flags>
</cfif>

<cfset uhApiId = trim(dbUser.UH_API_ID ?: "")>
<cfif uhApiId EQ "">
    <cfset content = "<h1>UH API Sync</h1><div class='alert alert-warning'>This user does not have a UH API ID assigned. UH API sync is not available.</div><a href='/admin/users/view.cfm?userID=#urlEncodedFormat(sourceUserID)#' class='btn btn-primary me-2'>Back to User</a><a href='/admin/users/index.cfm' class='btn btn-outline-secondary'>Back to Users</a>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<!--- API credentials --->
<cfset uhApiToken = structKeyExists(application, "uhApiToken") ? trim(application.uhApiToken ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">

<cfif (uhApiToken EQ "" OR uhApiSecret EQ "") AND structKeyExists(server, "system") AND structKeyExists(server.system, "environment")>
    <cfif structKeyExists(server.system.environment, "UH_API_TOKEN")>
        <cfset uhApiToken = trim(server.system.environment["UH_API_TOKEN"])>
    </cfif>
    <cfif structKeyExists(server.system.environment, "UH_API_SECRET")>
        <cfset uhApiSecret = trim(server.system.environment["UH_API_SECRET"])>
    </cfif>
</cfif>
<cfif uhApiToken EQ "">
    <cfset uhApiToken = "my5Tu[{[VH%,dT{wR3SEigeWc%2w,ZyFT6=5!2Rv$f0g,_z!UpDduLxhgjSm$P6">
</cfif>
<cfif uhApiSecret EQ "">
    <cfset uhApiSecret = "degxqhYPX2Vk@LFevunxX}:kTkX3fBXR">
</cfif>

<!--- POST handling --->
<cfif cgi.request_method EQ "POST" AND isNumeric(form.applySourceUserID) AND val(form.applySourceUserID) GT 0>
    <cfset applyUserID = val(form.applySourceUserID)>
    <cfset usersService = createObject("component", "cfc.users_service").init()>

    <!--- SYNC ALL --->
    <cfif form.syncAll EQ "1">
        <cfset syncApiPerson = {}>
        <cfset syncStatusCode = "Unknown">

        <cfsilent>
            <cfset syncUhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
            <cfset syncPersonResponse = syncUhApi.getPerson(
                uhApiId,
                trim(dbUser.DEPARTMENT ?: ""),
                trim(dbUser.DIVISION ?: ""),
                trim(dbUser.CAMPUS ?: "")
            )>
        </cfsilent>

        <cfset syncStatusCode = syncPersonResponse.statusCode ?: "Unknown">
        <cfset syncResponseData = syncPersonResponse.data ?: {}>

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
            <cfset saveMessage = "Sync All failed: UH API request returned status #EncodeForHTML(syncStatusCode)#.">
            <cfset saveMessageClass = "alert-danger">
        </cfif>

        <cfif saveMessageClass NEQ "alert-danger">
            <cfset currentUserResult = usersService.getUser(applyUserID)>
            <cfif NOT (structKeyExists(currentUserResult, "success") AND currentUserResult.success)>
                <cfset saveMessage = "Sync All failed: unable to load local user for update.">
                <cfset saveMessageClass = "alert-danger">
            <cfelse>
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
                    function syncAllFindValueByKeyDeep(any node="", required string keyName) {
                        var keys = [];
                        var k = "";
                        var found = "";
                        var i = 1;

                        if (isNull(arguments.node)) { return ""; }

                        if (isStruct(arguments.node)) {
                            keys = structKeyArray(arguments.node);
                            for (i = 1; i <= arrayLen(keys); i++) {
                                k = keys[i];
                                if (compareNoCase(k, arguments.keyName) EQ 0) {
                                    if (isSimpleValue(arguments.node[k])) { return toString(arguments.node[k] ?: ""); }
                                    if (isBoolean(arguments.node[k])) { return arguments.node[k] ? "true" : "false"; }
                                }
                            }
                            for (i = 1; i <= arrayLen(keys); i++) {
                                found = syncAllFindValueByKeyDeep(node=arguments.node[keys[i]], keyName=arguments.keyName);
                                if (len(trim(toString(found)))) { return found; }
                            }
                        } else if (isArray(arguments.node)) {
                            for (i = 1; i <= arrayLen(arguments.node); i++) {
                                found = syncAllFindValueByKeyDeep(node=arguments.node[i], keyName=arguments.keyName);
                                if (len(trim(toString(found)))) { return found; }
                            }
                        }
                        return "";
                    }

                    function syncAllGetApiValue(required any source, required string keyListCsv) {
                        var names = listToArray(arguments.keyListCsv);
                        var i = 1;
                        var v = "";
                        for (i = 1; i <= arrayLen(names); i++) {
                            v = syncAllFindValueByKeyDeep(node=arguments.source, keyName=trim(names[i]));
                            if (len(trim(toString(v)))) { return toString(v); }
                        }
                        return "";
                    }
                </cfscript>

                <cfif isStruct(syncApiPerson)>
                    <cfset apiFirstName      = trim(syncAllGetApiValue(syncApiPerson, "first_name,firstName"))>
                    <cfset apiMiddleName     = trim(syncAllGetApiValue(syncApiPerson, "middle_name,middleName"))>
                    <cfset apiLastName       = trim(syncAllGetApiValue(syncApiPerson, "last_name,lastName"))>
                    <cfset apiEmail          = trim(syncAllGetApiValue(syncApiPerson, "email,emailAddress"))>
                    <cfset apiPhone          = trim(syncAllGetApiValue(syncApiPerson, "phone,phoneNumber"))>
                    <cfset apiRoom           = trim(syncAllGetApiValue(syncApiPerson, "room"))>
                    <cfset apiBuilding       = trim(syncAllGetApiValue(syncApiPerson, "building"))>
                    <cfset apiTitle          = trim(syncAllGetApiValue(syncApiPerson, "title"))>
                    <cfset apiDivision       = trim(syncAllGetApiValue(syncApiPerson, "division"))>
                    <cfset apiDivisionName   = trim(syncAllGetApiValue(syncApiPerson, "division_name,divisionName"))>
                    <cfset apiCampus         = trim(syncAllGetApiValue(syncApiPerson, "campus"))>
                    <cfset apiDepartment     = trim(syncAllGetApiValue(syncApiPerson, "department"))>
                    <cfset apiDepartmentName = trim(syncAllGetApiValue(syncApiPerson, "department_name,departmentName"))>
                    <cfset apiOfficeAddr     = trim(syncAllGetApiValue(syncApiPerson, "office_mailing_address,officeMailingAddress,mailing_address"))>
                    <cfset apiMailcode       = trim(syncAllGetApiValue(syncApiPerson, "mailcode,mail_code"))>

                    <cfif len(apiFirstName)>      <cfset userData.FirstName = apiFirstName>                         </cfif>
                    <cfif len(apiMiddleName)>     <cfset userData.MiddleName = apiMiddleName>                       </cfif>
                    <cfif len(apiLastName)>        <cfset userData.LastName = apiLastName>                           </cfif>
                    <cfif len(apiEmail)>           <cfset userData.EmailPrimary = lCase(apiEmail)>                   </cfif>
                    <cfif len(apiPhone)>           <cfset userData.Phone = apiPhone>                                 </cfif>
                    <cfif len(apiRoom)>            <cfset userData.Room = apiRoom>                                   </cfif>
                    <cfif len(apiBuilding)>        <cfset userData.Building = apiBuilding>                           </cfif>
                    <cfif len(apiTitle)>           <cfset userData.Title1 = apiTitle>                                </cfif>
                    <cfif len(apiDivision)>        <cfset userData.Division = apiDivision>                           </cfif>
                    <cfif len(apiDivisionName)>    <cfset userData.DivisionName = apiDivisionName>                   </cfif>
                    <cfif len(apiCampus)>          <cfset userData.Campus = apiCampus>                               </cfif>
                    <cfif len(apiDepartment)>      <cfset userData.Department = apiDepartment>                       </cfif>
                    <cfif len(apiDepartmentName)>  <cfset userData.DepartmentName = apiDepartmentName>               </cfif>
                    <cfif len(apiOfficeAddr)>      <cfset userData.Office_Mailing_Address = apiOfficeAddr>           </cfif>
                    <cfif len(apiMailcode)>        <cfset userData.Mailcode = apiMailcode>                           </cfif>
                </cfif>

                <cfset updateResult = usersService.updateUser(applyUserID, userData)>
                <cfif NOT (structKeyExists(updateResult, "success") AND updateResult.success)>
                    <cfset saveMessage = "Sync All failed while updating user fields: " & (updateResult.message ?: "Unknown error")>
                    <cfset saveMessageClass = "alert-danger">
                <cfelse>
                    <!--- Also update primary alias with API name values --->
                    <cfif len(apiFirstName) OR len(apiLastName)>
                        <cfset uhSyncAliasesSvcSA = createObject("component", "cfc.aliases_service").init()>
                        <cfset uhSyncExistingAliasesSA = uhSyncAliasesSvcSA.getAliases(applyUserID).data ?: []>
                        <cfset uhSyncPrimaryIdxSA = 0>
                        <cfset uhSyncFirstActiveIdxSA = 0>
                        <cfloop from="1" to="#arrayLen(uhSyncExistingAliasesSA)#" index="uhSyncAliIdxSA">
                            <cfif val(uhSyncExistingAliasesSA[uhSyncAliIdxSA].ISPRIMARY ?: 0) EQ 1>
                                <cfset uhSyncPrimaryIdxSA = uhSyncAliIdxSA>
                                <cfbreak>
                            </cfif>
                            <cfif uhSyncFirstActiveIdxSA EQ 0 AND val(uhSyncExistingAliasesSA[uhSyncAliIdxSA].ISACTIVE ?: 0) EQ 1>
                                <cfset uhSyncFirstActiveIdxSA = uhSyncAliIdxSA>
                            </cfif>
                        </cfloop>
                        <cfif uhSyncPrimaryIdxSA EQ 0><cfset uhSyncPrimaryIdxSA = uhSyncFirstActiveIdxSA></cfif>
                        <cfset uhSyncAliasesToSaveSA = []>
                        <cfif uhSyncPrimaryIdxSA GT 0>
                            <cfloop from="1" to="#arrayLen(uhSyncExistingAliasesSA)#" index="uhSyncAliIdxSA">
                                <cfset uhSyncA = uhSyncExistingAliasesSA[uhSyncAliIdxSA]>
                                <cfset uhSyncAliRow = {
                                    firstName    = trim(uhSyncA.FIRSTNAME ?: ""),
                                    middleName   = trim(uhSyncA.MIDDLENAME ?: ""),
                                    lastName     = trim(uhSyncA.LASTNAME ?: ""),
                                    aliasType    = trim(uhSyncA.ALIASTYPE ?: ""),
                                    sourceSystem = trim(uhSyncA.SOURCESYSTEM ?: ""),
                                    isActive     = val(uhSyncA.ISACTIVE ?: 0),
                                    isPrimary    = val(uhSyncA.ISPRIMARY ?: 0)
                                }>
                                <cfif uhSyncAliIdxSA EQ uhSyncPrimaryIdxSA>
                                    <cfif len(apiFirstName)><cfset uhSyncAliRow.firstName = apiFirstName></cfif>
                                    <cfif len(apiMiddleName)><cfset uhSyncAliRow.middleName = apiMiddleName></cfif>
                                    <cfif len(apiLastName)><cfset uhSyncAliRow.lastName = apiLastName></cfif>
                                    <cfif NOT len(uhSyncAliRow.aliasType)><cfset uhSyncAliRow.aliasType = "SOURCE_VARIANT"></cfif>
                                    <cfif NOT len(uhSyncAliRow.sourceSystem)><cfset uhSyncAliRow.sourceSystem = "UH API"></cfif>
                                    <cfset uhSyncAliRow.isPrimary = 1>
                                </cfif>
                                <cfset arrayAppend(uhSyncAliasesToSaveSA, uhSyncAliRow)>
                            </cfloop>
                        <cfelse>
                            <cfset arrayAppend(uhSyncAliasesToSaveSA, {
                                firstName    = apiFirstName,
                                middleName   = apiMiddleName,
                                lastName     = apiLastName,
                                aliasType    = "SOURCE_VARIANT",
                                sourceSystem = "UH API",
                                isActive     = 1,
                                isPrimary    = 1
                            })>
                        </cfif>
                        <cfset uhSyncAliasesSvcSA.replaceAliases(applyUserID, uhSyncAliasesToSaveSA)>
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

                        <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="f">
                            <cfif compareNoCase(trim(allFlagsResult.data[f].FLAGNAME ?: ""), "Current-Student") EQ 0>
                                <cfset currentStudentFlagID = val(allFlagsResult.data[f].FLAGID ?: 0)>
                            <cfelseif compareNoCase(trim(allFlagsResult.data[f].FLAGNAME ?: ""), "Staff") EQ 0>
                                <cfset staffFlagID = val(allFlagsResult.data[f].FLAGID ?: 0)>
                            <cfelseif compareNoCase(trim(allFlagsResult.data[f].FLAGNAME ?: ""), "Faculty-Fulltime") EQ 0>
                                <cfset facultyFlagID = val(allFlagsResult.data[f].FLAGID ?: 0)>
                            </cfif>
                        </cfloop>

                        <cfif structKeyExists(currentFlagsResult, "success") AND currentFlagsResult.success>
                            <cfloop from="1" to="#arrayLen(currentFlagsResult.data)#" index="uf">
                                <cfset thisFlagID = val(currentFlagsResult.data[uf].FLAGID ?: 0)>
                                <cfif thisFlagID EQ currentStudentFlagID><cfset userHasCurrentStudent = true></cfif>
                                <cfif thisFlagID EQ staffFlagID><cfset userHasStaff = true></cfif>
                                <cfif thisFlagID EQ facultyFlagID><cfset userHasFaculty = true></cfif>
                            </cfloop>
                        </cfif>

                        <cfset apiStudent = lCase(trim(syncAllGetApiValue(syncApiPerson, "student,is_student,isStudent")))>
                        <cfset apiStaff   = lCase(trim(syncAllGetApiValue(syncApiPerson, "staff,is_staff,isStaff")))>
                        <cfset apiFaculty = lCase(trim(syncAllGetApiValue(syncApiPerson, "faculty,is_faculty,isFaculty")))>

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

                    <cfset saveMessage = "Sync All complete. Updated profile fields and " & syncFlagsUpdated & " flag change(s).">
                    <cfset saveMessageClass = "alert-success">
                </cfif>
            </cfif>
        </cfif>

    <!--- SYNC SINGLE FLAG --->
    <cfelseif len(trim(form.applyFlagName))>
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
            <cfset saveMessage = "Unable to sync flag: API value is not a supported boolean.">
            <cfset saveMessageClass = "alert-warning">
        </cfif>

        <cfif saveMessage EQ "">
            <cfset allFlagsResult = flagsService.getAllFlags()>
            <cfif structKeyExists(allFlagsResult, "success") AND allFlagsResult.success>
                <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="f">
                    <cfif compareNoCase(trim(allFlagsResult.data[f].FLAGNAME ?: ""), requestedFlagName) EQ 0>
                        <cfset flagID = val(allFlagsResult.data[f].FLAGID ?: 0)>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>

            <cfif flagID LTE 0>
                <cfset saveMessage = "Unable to sync flag: '#EncodeForHTML(requestedFlagName)#' was not found.">
                <cfset saveMessageClass = "alert-danger">
            </cfif>
        </cfif>

        <cfif saveMessageClass NEQ "alert-danger" AND saveMessageClass NEQ "alert-warning">
            <cfset currentFlagsResult = flagsService.getUserFlags(applyUserID)>
            <cfset userHasFlag = false>
            <cfif structKeyExists(currentFlagsResult, "success") AND currentFlagsResult.success>
                <cfloop from="1" to="#arrayLen(currentFlagsResult.data)#" index="f">
                    <cfif val(currentFlagsResult.data[f].FLAGID ?: 0) EQ flagID>
                        <cfset userHasFlag = true>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>

            <cfif targetHasFlag AND NOT userHasFlag>
                <cfset actionResult = flagsService.addFlag(applyUserID, flagID)>
                <cfif structKeyExists(actionResult, "success") AND actionResult.success>
                    <cfset saveMessage = "Added flag '#EncodeForHTML(requestedFlagName)#'.">
                    <cfset saveMessageClass = "alert-success">
                <cfelse>
                    <cfset saveMessage = "Failed to add flag: " & (actionResult.message ?: "Unknown error")>
                    <cfset saveMessageClass = "alert-danger">
                </cfif>
            <cfelseif NOT targetHasFlag AND userHasFlag>
                <cfset actionResult = flagsService.removeFlag(applyUserID, flagID)>
                <cfif structKeyExists(actionResult, "success") AND actionResult.success>
                    <cfset saveMessage = "Removed flag '#EncodeForHTML(requestedFlagName)#'.">
                    <cfset saveMessageClass = "alert-success">
                <cfelse>
                    <cfset saveMessage = "Failed to remove flag: " & (actionResult.message ?: "Unknown error")>
                    <cfset saveMessageClass = "alert-danger">
                </cfif>
            <cfelse>
                <cfset saveMessage = "No change needed for flag '#EncodeForHTML(requestedFlagName)#'.">
                <cfset saveMessageClass = "alert-info">
            </cfif>
        </cfif>

    <!--- APPLY SINGLE FIELD --->
    <cfelseif len(trim(form.applyApiField))>
        <cfset applyField = uCase(trim(form.applyApiField))>
        <cfset applyValue = trim(form.applyApiValue ?: "")>
        <cfset currentUserResult = usersService.getUser(applyUserID)>

        <cfif NOT (structKeyExists(currentUserResult, "success") AND currentUserResult.success)>
            <cfset saveMessage = "Unable to load user for update.">
            <cfset saveMessageClass = "alert-danger">
        <cfelse>
            <cfset currentUser = currentUserResult.data>
            <cfset userData = {
                FirstName              = currentUser.FIRSTNAME ?: "",
                MiddleName             = currentUser.MIDDLENAME ?: "",
                LastName               = currentUser.LASTNAME ?: "",
                PreferredName          = currentUser.PREFERREDNAME ?: "",
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
                MaidenName             = currentUser.MAIDENNAME ?: "",
                Prefix                 = currentUser.PREFIX ?: "",
                Suffix                 = currentUser.SUFFIX ?: ""
            }>

            <cfif applyField EQ "FIRSTNAME">
                <cfset userData.FirstName = applyValue>
            <cfelseif applyField EQ "MIDDLENAME">
                <cfset userData.MiddleName = applyValue>
            <cfelseif applyField EQ "LASTNAME">
                <cfset userData.LastName = applyValue>
            <cfelseif applyField EQ "EMAILPRIMARY">
                <cfset userData.EmailPrimary = lCase(applyValue)>
            <cfelseif applyField EQ "PHONE">
                <cfset userData.Phone = applyValue>
            <cfelseif applyField EQ "ROOM">
                <cfset userData.Room = applyValue>
            <cfelseif applyField EQ "BUILDING">
                <cfset userData.Building = applyValue>
            <cfelseif applyField EQ "TITLE1">
                <cfset userData.Title1 = applyValue>
            <cfelseif applyField EQ "DIVISION">
                <cfset userData.Division = applyValue>
            <cfelseif applyField EQ "DIVISIONNAME">
                <cfset userData.DivisionName = applyValue>
            <cfelseif applyField EQ "CAMPUS">
                <cfset userData.Campus = applyValue>
            <cfelseif applyField EQ "DEPARTMENT">
                <cfset userData.Department = applyValue>
            <cfelseif applyField EQ "DEPARTMENTNAME">
                <cfset userData.DepartmentName = applyValue>
            <cfelseif applyField EQ "OFFICE_MAILING_ADDRESS">
                <cfset userData.Office_Mailing_Address = applyValue>
            <cfelseif applyField EQ "MAILCODE">
                <cfset userData.Mailcode = applyValue>
            <cfelse>
                <cfset saveMessage = "This field is not currently updatable from this page.">
                <cfset saveMessageClass = "alert-warning">
            </cfif>

            <cfif saveMessageClass NEQ "alert-danger" AND saveMessageClass NEQ "alert-warning">
                <cfset updateResult = usersService.updateUser(applyUserID, userData)>
                <cfif structKeyExists(updateResult, "success") AND updateResult.success>
                    <cfset saveMessage = "Updated " & applyField & " from API value.">
                    <cfset saveMessageClass = "alert-success">
                    <!--- Also update primary alias for name field syncs --->
                    <cfif listFindNoCase("FIRSTNAME,MIDDLENAME,LASTNAME", applyField)>
                        <cfset uhSyncAliasesSvcSF = createObject("component", "cfc.aliases_service").init()>
                        <cfset uhSyncExistingAliasesSF = uhSyncAliasesSvcSF.getAliases(applyUserID).data ?: []>
                        <cfset uhSyncPrimaryIdxSF = 0>
                        <cfset uhSyncFirstActiveIdxSF = 0>
                        <cfloop from="1" to="#arrayLen(uhSyncExistingAliasesSF)#" index="uhSyncAliIdxSF">
                            <cfif val(uhSyncExistingAliasesSF[uhSyncAliIdxSF].ISPRIMARY ?: 0) EQ 1>
                                <cfset uhSyncPrimaryIdxSF = uhSyncAliIdxSF>
                                <cfbreak>
                            </cfif>
                            <cfif uhSyncFirstActiveIdxSF EQ 0 AND val(uhSyncExistingAliasesSF[uhSyncAliIdxSF].ISACTIVE ?: 0) EQ 1>
                                <cfset uhSyncFirstActiveIdxSF = uhSyncAliIdxSF>
                            </cfif>
                        </cfloop>
                        <cfif uhSyncPrimaryIdxSF EQ 0><cfset uhSyncPrimaryIdxSF = uhSyncFirstActiveIdxSF></cfif>
                        <cfset uhSyncAliasesToSaveSF = []>
                        <cfif uhSyncPrimaryIdxSF GT 0>
                            <cfloop from="1" to="#arrayLen(uhSyncExistingAliasesSF)#" index="uhSyncAliIdxSF">
                                <cfset uhSyncASF = uhSyncExistingAliasesSF[uhSyncAliIdxSF]>
                                <cfset uhSyncAliRowSF = {
                                    firstName    = trim(uhSyncASF.FIRSTNAME ?: ""),
                                    middleName   = trim(uhSyncASF.MIDDLENAME ?: ""),
                                    lastName     = trim(uhSyncASF.LASTNAME ?: ""),
                                    aliasType    = trim(uhSyncASF.ALIASTYPE ?: ""),
                                    sourceSystem = trim(uhSyncASF.SOURCESYSTEM ?: ""),
                                    isActive     = val(uhSyncASF.ISACTIVE ?: 0),
                                    isPrimary    = val(uhSyncASF.ISPRIMARY ?: 0)
                                }>
                                <cfif uhSyncAliIdxSF EQ uhSyncPrimaryIdxSF>
                                    <cfif applyField EQ "FIRSTNAME"><cfset uhSyncAliRowSF.firstName = applyValue></cfif>
                                    <cfif applyField EQ "MIDDLENAME"><cfset uhSyncAliRowSF.middleName = applyValue></cfif>
                                    <cfif applyField EQ "LASTNAME"><cfset uhSyncAliRowSF.lastName = applyValue></cfif>
                                    <cfif NOT len(uhSyncAliRowSF.aliasType)><cfset uhSyncAliRowSF.aliasType = "SOURCE_VARIANT"></cfif>
                                    <cfif NOT len(uhSyncAliRowSF.sourceSystem)><cfset uhSyncAliRowSF.sourceSystem = "UH API"></cfif>
                                    <cfset uhSyncAliRowSF.isPrimary = 1>
                                </cfif>
                                <cfset arrayAppend(uhSyncAliasesToSaveSF, uhSyncAliRowSF)>
                            </cfloop>
                        <cfelse>
                            <cfset arrayAppend(uhSyncAliasesToSaveSF, {
                                firstName    = applyField EQ "FIRSTNAME" ? applyValue : trim(currentUser.FIRSTNAME ?: ""),
                                middleName   = applyField EQ "MIDDLENAME" ? applyValue : trim(currentUser.MIDDLENAME ?: ""),
                                lastName     = applyField EQ "LASTNAME" ? applyValue : trim(currentUser.LASTNAME ?: ""),
                                aliasType    = "SOURCE_VARIANT",
                                sourceSystem = "UH API",
                                isActive     = 1,
                                isPrimary    = 1
                            })>
                        </cfif>
                        <cfset uhSyncAliasesSvcSF.replaceAliases(applyUserID, uhSyncAliasesToSaveSF)>
                    </cfif>
                <cfelse>
                    <cfset saveMessage = "Update failed: " & (updateResult.message ?: "Unknown error")>
                    <cfset saveMessageClass = "alert-danger">
                </cfif>
            </cfif>
        </cfif>
    </cfif>

    <!--- Reload DB user and flags for fresh display after POST --->
    <cfset profile = directoryService.getFullProfile(val(sourceUserID))>
    <cfif structKeyExists(profile, "user") AND structCount(profile.user) GT 0>
        <cfset dbUser = profile.user>
    </cfif>
    <cfif structKeyExists(profile, "flags") AND isArray(profile.flags)>
        <cfset dbFlags = profile.flags>
    </cfif>
</cfif>

<!--- Build page content --->
<cfset content = "<div class='d-flex align-items-center justify-content-between mb-1'><h1 class='mb-0'>UH API Sync</h1><form method='post' class='d-inline'><input type='hidden' name='syncAll' value='1'><input type='hidden' name='applySourceUserID' value='#EncodeForHTMLAttribute(sourceUserID)#'><button type='submit' class='btn btn-success'>Sync All Fields &amp; Flags</button></form></div>">
<cfif len(returnTo)>
    <cfset content &= "<a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-sm btn-outline-primary mb-3 me-2'>&##8592; Back to Report</a>">
</cfif>
<cfset content &= "<a href='/admin/users/view.cfm?userID=#urlEncodedFormat(sourceUserID)#' class='btn btn-sm btn-outline-secondary mb-3 me-2'>Back to User</a>">
<cfset content &= "<a href='/admin/users/index.cfm' class='btn btn-sm btn-outline-secondary mb-3'>Back to All Users</a>">
<cfif saveMessage NEQ "">
    <cfset content &= "<div class='alert #saveMessageClass# mt-3'>#EncodeForHTML(saveMessage)#</div>">
</cfif>

<cfif uhApiToken EQ "" OR uhApiSecret EQ "">
    <cfset content &= "<div class='alert alert-danger'>UH API credentials are not configured. Set UH_API_TOKEN and UH_API_SECRET environment variables.</div>">
<cfelse>
    <cfset personResponse = {}>
    <cfset apiPerson = {}>

    <cfsilent>
        <cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfset personResponse = uhApi.getPerson(
            uhApiId,
            trim(dbUser.DEPARTMENT ?: ""),
            trim(dbUser.DIVISION ?: ""),
            trim(dbUser.CAMPUS ?: "")
        )>
    </cfsilent>

    <cfset statusCode = personResponse.statusCode ?: "Unknown">
    <cfset responseData = personResponse.data ?: {}>

    <cfif isStruct(responseData)>
        <cfif structKeyExists(responseData, "data") AND isStruct(responseData.data)>
            <cfif structKeyExists(responseData.data, "person") AND isStruct(responseData.data.person)>
                <cfset apiPerson = responseData.data.person>
            <cfelse>
                <cfset apiPerson = responseData.data>
            </cfif>
        <cfelseif structKeyExists(responseData, "data") AND isArray(responseData.data) AND arrayLen(responseData.data) GT 0 AND isStruct(responseData.data[1])>
            <cfset apiPerson = responseData.data[1]>
        <cfelseif structKeyExists(responseData, "person") AND isStruct(responseData.person)>
            <cfset apiPerson = responseData.person>
        <cfelse>
            <cfset apiPerson = responseData>
        </cfif>
    <cfelseif isArray(responseData) AND arrayLen(responseData) GT 0 AND isStruct(responseData[1])>
        <cfset apiPerson = responseData[1]>
    </cfif>

    <cfset content &= "<p><strong>UH API ID:</strong> #EncodeForHTML(uhApiId)# &nbsp; <strong>Status:</strong> #EncodeForHTML(statusCode)#</p>">

    <cfif left(statusCode, 3) NEQ "200">
        <cfset content &= "<div class='alert alert-danger'>UH API request failed with status #EncodeForHTML(statusCode)#.</div>">
    </cfif>

    <cfif left(statusCode, 3) EQ "200">
        <cfscript>
            function getStructValueCI(required struct s, required string keyName) {
                var keys = structKeyArray(arguments.s);
                var i = 1;
                for (i = 1; i <= arrayLen(keys); i++) {
                    if (compareNoCase(keys[i], arguments.keyName) EQ 0) {
                        return arguments.s[keys[i]];
                    }
                }
                return "";
            }

            function findValueByKeyDeep(any node="", required string keyName) {
                var keys = [];
                var k = "";
                var found = "";
                var i = 1;

                if (isNull(arguments.node)) { return ""; }

                if (isStruct(arguments.node)) {
                    keys = structKeyArray(arguments.node);
                    for (i = 1; i <= arrayLen(keys); i++) {
                        k = keys[i];
                        if (compareNoCase(k, arguments.keyName) EQ 0) {
                            if (isSimpleValue(arguments.node[k]) AND len(trim(toString(arguments.node[k])))) { return arguments.node[k]; }
                            if (isBoolean(arguments.node[k])) { return arguments.node[k]; }
                        }
                    }
                    for (i = 1; i <= arrayLen(keys); i++) {
                        found = findValueByKeyDeep(node=arguments.node[keys[i]], keyName=arguments.keyName);
                        if (isSimpleValue(found) AND len(trim(toString(found)))) { return found; }
                        if (isBoolean(found)) { return found; }
                    }
                } else if (isArray(arguments.node)) {
                    for (i = 1; i <= arrayLen(arguments.node); i++) {
                        found = findValueByKeyDeep(node=arguments.node[i], keyName=arguments.keyName);
                        if (isSimpleValue(found) AND len(trim(toString(found)))) { return found; }
                        if (isBoolean(found)) { return found; }
                    }
                }
                return "";
            }

            function getApiValue(required any s, required string keyListCsv) {
                var names = listToArray(arguments.keyListCsv);
                var i = 1;
                var val = "";
                for (i = 1; i <= arrayLen(names); i++) {
                    val = findValueByKeyDeep(node=arguments.s, keyName=trim(names[i]));
                    if (isSimpleValue(val) AND len(trim(toString(val)))) { return toString(val); }
                    if (!isSimpleValue(val)) { return serializeJSON(val); }
                }
                return "";
            }

            function getDbValue(required struct s, required string keyName) {
                var val = getStructValueCI(arguments.s, arguments.keyName);
                if (isSimpleValue(val)) { return toString(val ?: ""); }
                if (!isNull(val)) { return serializeJSON(val); }
                return "";
            }

            function getApiDirectValue(required struct s, required string keyListCsv) {
                var names = listToArray(arguments.keyListCsv);
                var keys = structKeyArray(arguments.s);
                var i = 1;
                var j = 1;
                var nameToFind = "";
                for (i = 1; i <= arrayLen(names); i++) {
                    nameToFind = trim(names[i]);
                    for (j = 1; j <= arrayLen(keys); j++) {
                        if (compareNoCase(keys[j], nameToFind) EQ 0) { return arguments.s[keys[j]]; }
                    }
                }
                return "";
            }

            function displayVal(required string v) {
                return len(trim(arguments.v)) ? arguments.v : "N/A";
            }

            function normalizeForCompare(required string fieldName, required string v) {
                var out = lCase(trim(arguments.v));
                out = reReplace(out, "\s+", " ", "all");
                if (findNoCase("email", arguments.fieldName)) { return out; }
                if (findNoCase("phone", arguments.fieldName)) { return reReplace(arguments.v, "[^0-9]", "", "all"); }
                return out;
            }

            function hasFlag(required array flags, required string flagName) {
                var i = 1;
                var fName = "";
                for (i = 1; i <= arrayLen(arguments.flags); i++) {
                    if (isStruct(arguments.flags[i])) {
                        fName = trim(toString(arguments.flags[i].FLAGNAME ?: ""));
                        if (compareNoCase(fName, arguments.flagName) EQ 0) { return true; }
                    }
                }
                return false;
            }

            function toYesNo(required any v) {
                var raw = arguments.v;
                var s = "";
                if (isNull(raw)) { return "N/A"; }
                if (isBoolean(raw)) { return raw ? "Yes" : "No"; }
                s = lCase(trim(toString(raw)));
                if (s EQ "true" OR s EQ "1" OR s EQ "yes" OR s EQ "y") { return "Yes"; }
                if (s EQ "false" OR s EQ "0" OR s EQ "no" OR s EQ "n") { return "No"; }
                return "N/A";
            }
        </cfscript>

        <cfset content &= "
        <h4 class='mt-4'>API vs Database Comparison</h4>
        <div class='table-responsive'>
        <table class='table table-sm table-bordered align-middle'>
            <thead class='table-light'>
                <tr>
                    <th>Field</th>
                    <th>Database</th>
                    <th>UH API</th>
                    <th>Match</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
        ">

        <!--- Load primary alias to resolve name field DB values for comparison --->
        <cfset uhSyncDispAliasesSvc = createObject("component", "cfc.aliases_service").init()>
        <cfset uhSyncDispAliasesResult = uhSyncDispAliasesSvc.getAliases(val(sourceUserID))>
        <cfset uhSyncDispPrimaryAlias = {}>
        <cfif structKeyExists(uhSyncDispAliasesResult, "data") AND isArray(uhSyncDispAliasesResult.data)>
            <cfloop from="1" to="#arrayLen(uhSyncDispAliasesResult.data)#" index="uhSyncDispAliIdx">
                <cfif val(uhSyncDispAliasesResult.data[uhSyncDispAliIdx].ISPRIMARY ?: 0) EQ 1>
                    <cfset uhSyncDispPrimaryAlias = uhSyncDispAliasesResult.data[uhSyncDispAliIdx]>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
        <cfset uhSyncResolvedFirstName  = len(trim(uhSyncDispPrimaryAlias.FIRSTNAME  ?: "")) ? trim(uhSyncDispPrimaryAlias.FIRSTNAME)  : trim(dbUser.FIRSTNAME  ?: "")>
        <cfset uhSyncResolvedMiddleName = len(trim(uhSyncDispPrimaryAlias.MIDDLENAME ?: "")) ? trim(uhSyncDispPrimaryAlias.MIDDLENAME) : trim(dbUser.MIDDLENAME ?: "")>
        <cfset uhSyncResolvedLastName   = len(trim(uhSyncDispPrimaryAlias.LASTNAME   ?: "")) ? trim(uhSyncDispPrimaryAlias.LASTNAME)   : trim(dbUser.LASTNAME   ?: "")>

        <cfset comparisonRows = [
            { label="First Name",             dbKey="FIRSTNAME",              apiKeys="first_name,firstName",                                        canUpdate=true },
            { label="Middle Name",            dbKey="MIDDLENAME",             apiKeys="middle_name,middleName",                                       canUpdate=true },
            { label="Last Name",              dbKey="LASTNAME",               apiKeys="last_name,lastName",                                          canUpdate=true },
            { label="Email",                  dbKey="EMAILPRIMARY",           apiKeys="email,emailAddress",                                          canUpdate=true },
            { label="Phone",                  dbKey="PHONE",                  apiKeys="phone,phoneNumber",                                           canUpdate=true },
            { label="Room",                   dbKey="ROOM",                   apiKeys="room",                                                        canUpdate=true },
            { label="Building",               dbKey="BUILDING",               apiKeys="building",                                                    canUpdate=true },
            { label="Title",                  dbKey="TITLE1",                 apiKeys="title",                                                       canUpdate=true },
            { label="Division",               dbKey="DIVISION",               apiKeys="division",                                                    canUpdate=true },
            { label="Division Name",          dbKey="DIVISIONNAME",           apiKeys="division_name,divisionName",                                  canUpdate=true },
            { label="Campus",                 dbKey="CAMPUS",                 apiKeys="campus",                                                      canUpdate=true },
            { label="Department",             dbKey="DEPARTMENT",             apiKeys="department",                                                  canUpdate=true },
            { label="Department Name",        dbKey="DEPARTMENTNAME",         apiKeys="department_name,departmentName",                              canUpdate=true },
            { label="Office Mailing Address", dbKey="OFFICE_MAILING_ADDRESS", apiKeys="office_mailing_address,officeMailingAddress,mailing_address", canUpdate=true },
            { label="Mailcode",               dbKey="MAILCODE",               apiKeys="mailcode,mail_code",                                          canUpdate=true }
        ]>

        <cfset flagCompareRows = [
            { label="Student", apiKeys="student,is_student,isStudent", flagName="Current-Student" },
            { label="Staff",   apiKeys="staff,is_staff,isStaff",       flagName="Staff" },
            { label="Faculty", apiKeys="faculty,is_faculty,isFaculty", flagName="Faculty-Fulltime" }
        ]>

        <cfloop from="1" to="#arrayLen(comparisonRows)#" index="r">
            <cfset row = comparisonRows[r]>
            <cfset dbVal        = getDbValue(dbUser, row.dbKey)>
            <cfset apiVal       = getApiValue(apiPerson, row.apiKeys)>
            <cfset dbRaw        = trim(toString(dbVal ?: ""))>
            <cfif row.dbKey EQ "FIRSTNAME">
                <cfset dbRaw = uhSyncResolvedFirstName>
            <cfelseif row.dbKey EQ "MIDDLENAME">
                <cfset dbRaw = uhSyncResolvedMiddleName>
            <cfelseif row.dbKey EQ "LASTNAME">
                <cfset dbRaw = uhSyncResolvedLastName>
            </cfif>
            <cfset apiRaw       = trim(toString(apiVal ?: ""))>
            <cfset hasDbValue   = len(dbRaw) GT 0>
            <cfset hasApiValue  = len(apiRaw) GT 0>
            <cfset valuesDiffer = compare(dbRaw, apiRaw) NEQ 0>
            <cfset dbDisplay    = displayVal(dbVal)>
            <cfset apiDisplay   = displayVal(apiVal)>
            <cfset isMatch      = normalizeForCompare(row.label, dbDisplay) EQ normalizeForCompare(row.label, apiDisplay)>
            <cfset matchDisplay = isMatch ? "&##10003;" : "&##10007;">
            <cfset showApplyButton = row.canUpdate AND hasApiValue AND ((NOT hasDbValue) OR valuesDiffer)>
            <cfset content &= "
                <tr>
                    <td><strong>#EncodeForHTML(row.label)#</strong></td>
                    <td>#EncodeForHTML(dbDisplay)#</td>
                    <td>#EncodeForHTML(apiDisplay)#</td>
                    <td class='text-center fs-5'>#matchDisplay#</td>
                    <td>">
            <cfif showApplyButton>
                <cfset content &= "
                        <form method='post' class='d-inline'>
                            <input type='hidden' name='applyApiField' value='#EncodeForHTMLAttribute(row.dbKey)#'>
                            <input type='hidden' name='applyApiValue' value='#EncodeForHTMLAttribute(apiDisplay)#'>
                            <input type='hidden' name='applySourceUserID' value='#EncodeForHTMLAttribute(sourceUserID)#'>
                            <button type='submit' class='btn btn-sm btn-outline-primary'>Sync</button>
                        </form>
                ">
            <cfelse>
                <cfset content &= "<span class='text-muted'>-</span>">
            </cfif>
            <cfset content &= "
                    </td>
                </tr>
            ">
        </cfloop>

        <cfloop from="1" to="#arrayLen(flagCompareRows)#" index="r">
            <cfset row = flagCompareRows[r]>
            <cfset apiRawVal = isStruct(apiPerson) ? getApiDirectValue(apiPerson, row.apiKeys) : "">
            <cfif apiRawVal EQ "">
                <cfset apiRawVal = getApiValue(apiPerson, row.apiKeys)>
            </cfif>
            <cfset apiDisplay = toYesNo(apiRawVal)>
            <cfset dbHasFlag  = hasFlag(dbFlags, row.flagName)>
            <cfset dbDisplay  = dbHasFlag ? "Yes" : "No">
            <cfset showFlagApplyButton = (apiDisplay EQ "Yes" OR apiDisplay EQ "No") AND apiDisplay NEQ dbDisplay>
            <cfif apiDisplay EQ "N/A">
                <cfset matchDisplay = "N/A">
            <cfelse>
                <cfset matchDisplay = (apiDisplay EQ dbDisplay) ? "&##10003;" : "&##10007;">
            </cfif>
            <cfset content &= "
                <tr>
                    <td><strong>#EncodeForHTML(row.label)#</strong></td>
                    <td>#EncodeForHTML(dbDisplay)#</td>
                    <td>#EncodeForHTML(apiDisplay)#</td>
                    <td class='text-center fs-5'>#matchDisplay#</td>
                    <td>">
            <cfif showFlagApplyButton>
                <cfset content &= "
                        <form method='post' class='d-inline'>
                            <input type='hidden' name='applyFlagName' value='#EncodeForHTMLAttribute(row.flagName)#'>
                            <input type='hidden' name='applyFlagApiValue' value='#EncodeForHTMLAttribute(apiDisplay)#'>
                            <input type='hidden' name='applySourceUserID' value='#EncodeForHTMLAttribute(sourceUserID)#'>
                            <button type='submit' class='btn btn-sm btn-outline-primary'>Sync Flag</button>
                        </form>
                ">
            <cfelse>
                <cfset content &= "<span class='text-muted'>-</span>">
            </cfif>
            <cfset content &= "
                    </td>
                </tr>
            ">
        </cfloop>

        <cfset content &= "
            </tbody>
        </table>
        </div>
        ">

    </cfif>
</cfif>

<cfset content &= "
<div class='mt-4'>
    <a href='/admin/users/view.cfm?userID=#urlEncodedFormat(sourceUserID)#' class='btn btn-primary'>Back to Profile</a>
    <a href='/admin/users/index.cfm' class='btn btn-secondary ms-2'>Back to Users</a>
</div>
">

<cfinclude template="/admin/layout.cfm">
