<!---
    quick_import_person.cfm
    One-click import for a staging record whose Reason is
    "User in API but not in local Users table".

    Steps performed:
        1. Validate the uhApiId and ensure no local user already has it.
        2. Fetch the full person record from the UH API.
        3. Create the local Users row.
        4. Sync all available fields from the API response.
        5. Assign flags (Current-Student / Staff / Faculty-Fulltime) from API booleans.
        6. Remove the record from UHApiPeopleStaging.
        7. Redirect back to the caller (url.returnTo) with a success/error message.
--->
<cfparam name="url.uhApiId"  default="">
<cfparam name="url.returnTo" default="">

<cfset quarantineMode = "redirect">
<cfset quarantineReturnTo = "/admin/users/index.cfm">
<cfinclude template="/admin/users/_uh_workflow_quarantine_guard.cfm">

<cfif NOT request.hasPermission("users.edit") OR NOT request.canCreateUsers()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset datasource = request.datasource>

<!--- Validate returnTo: root-relative only, no open-redirect --->
<cfset returnTo = "/admin/users/uh_people_import.cfm">
<cfif len(trim(url.returnTo))>
    <cfset candidate = trim(url.returnTo)>
    <cfif left(candidate, 1) EQ "/" AND NOT find("//", candidate) AND NOT findNoCase("javascript:", candidate)>
        <cfset returnTo = candidate>
    </cfif>
</cfif>

<cfset sep = find("?", returnTo) ? "&" : "?">

<!--- Require a non-empty uhApiId --->
<cfset uhApiId = trim(url.uhApiId)>
<cfif NOT len(uhApiId)>
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('No UH API ID provided')#" addtoken="false">
    <cfabort>
</cfif>

<!--- Guard: do not create a duplicate --->
<cfset existingCheck = queryExecute(
    "SELECT TOP 1 UserID, FirstName, LastName FROM Users WHERE UH_API_ID = :id",
    { id = { value=uhApiId, cfsqltype="cf_sql_nvarchar" } },
    { datasource=datasource, timeout=30 }
)>
<cfif existingCheck.recordCount GT 0>
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('A local user already has UH API ID ' & uhApiId & ' (UserID ' & existingCheck.UserID & ')')#" addtoken="false">
    <cfabort>
</cfif>

<!--- API credentials --->
<cfset uhApiCredentials = request.runtimeSecretPolicy.getUHApiCredentials()>
<cfset uhApiToken = trim(uhApiCredentials.token ?: "")>
<cfset uhApiSecret = trim(uhApiCredentials.secret ?: "")>

<cfif uhApiToken EQ "" OR uhApiSecret EQ "">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API credentials are not configured. Set UH_API_TOKEN and UH_API_SECRET environment variables.')#" addtoken="false">
    <cfabort>
</cfif>

<!--- Fetch person from UH API --->
<cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
<cfsilent>
    <cfset personResponse = uhApi.getPerson(uhApiId)>
</cfsilent>
<cfset statusCode   = personResponse.statusCode ?: "Unknown">
<cfset responseData = personResponse.data ?: {}>
<cfif left(statusCode, 3) NEQ "200">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API returned status ' & statusCode & ' for ID ' & uhApiId)#" addtoken="false">
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

<!--- Deep key-search helpers --->
<cfscript>
    function qipFindDeep(any node="", required string keyName) {
        var keys  = [];
        var k     = "";
        var found = "";
        var i     = 1;
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
                found = qipFindDeep(node=arguments.node[keys[i]], keyName=arguments.keyName);
                if (len(trim(toString(found)))) { return found; }
            }
        } else if (isArray(arguments.node)) {
            for (i = 1; i <= arrayLen(arguments.node); i++) {
                found = qipFindDeep(node=arguments.node[i], keyName=arguments.keyName);
                if (len(trim(toString(found)))) { return found; }
            }
        }
        return "";
    }

    function qipGet(required any src, required string keysCsv) {
        var names = listToArray(arguments.keysCsv);
        var i     = 1;
        var v     = "";
        for (i = 1; i <= arrayLen(names); i++) {
            v = qipFindDeep(node=arguments.src, keyName=trim(names[i]));
            if (len(trim(toString(v)))) { return toString(v); }
        }
        return "";
    }
</cfscript>

<cfset apiFirstName    = trim(qipGet(apiPerson, "first_name,firstName"))>
<cfset apiLastName     = trim(qipGet(apiPerson, "last_name,lastName"))>
<cfset apiEmail        = trim(qipGet(apiPerson, "email,emailAddress"))>
<cfset apiPhone        = trim(qipGet(apiPerson, "phone,phoneNumber"))>
<cfset apiRoom         = trim(qipGet(apiPerson, "room"))>
<cfset apiBuilding     = trim(qipGet(apiPerson, "building"))>
<cfset apiTitle        = trim(qipGet(apiPerson, "title"))>
<cfset apiDivision     = trim(qipGet(apiPerson, "division"))>
<cfset apiDivisionName = trim(qipGet(apiPerson, "division_name,divisionName"))>
<cfset apiCampus       = trim(qipGet(apiPerson, "campus"))>
<cfset apiDept         = trim(qipGet(apiPerson, "department"))>
<cfset apiDeptName     = trim(qipGet(apiPerson, "department_name,departmentName"))>
<cfset apiOfficeAddr   = trim(qipGet(apiPerson, "office_mailing_address,officeMailingAddress,mailing_address"))>
<cfset apiMailcode     = trim(qipGet(apiPerson, "mailcode,mail_code"))>
<cfset apiStudent      = lCase(trim(qipGet(apiPerson, "student,is_student,isStudent")))>
<cfset apiStaff        = lCase(trim(qipGet(apiPerson, "staff,is_staff,isStaff")))>
<cfset apiFaculty      = lCase(trim(qipGet(apiPerson, "faculty,is_faculty,isFaculty")))>

<cfif NOT len(apiFirstName) OR NOT len(apiLastName)>
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API did not return a first or last name for ID ' & uhApiId)#" addtoken="false">
    <cfabort>
</cfif>

<!--- Step 3: Create the local user row --->
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset createResult = usersService.createUser({
    FirstName              = apiFirstName,
    MiddleName             = "",
    LastName               = apiLastName,
    Pronouns               = "",
    EmailPrimary           = (len(apiEmail)      ? lCase(apiEmail)    : ""),
    Phone                  = (len(apiPhone)       ? apiPhone           : ""),
    Room                   = (len(apiRoom)        ? apiRoom            : ""),
    Building               = (len(apiBuilding)    ? apiBuilding        : ""),
    CougarNetID            = "",
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
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Failed to create user: ' & (createResult.message ?: 'Unknown error'))#" addtoken="false">
    <cfabort>
</cfif>

<cfset newUserID = val(createResult.userID ?: 0)>

<!--- Step 5: Assign flags --->
<cfset flagsService   = createObject("component", "cfc.flags_service").init()>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset flagsAssigned  = 0>

<cfif structKeyExists(allFlagsResult, "success") AND allFlagsResult.success>
    <cfset studentFlagID = 0>
    <cfset staffFlagID   = 0>
    <cfset facultyFlagID = 0>

    <cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="f">
        <cfset fn = trim(allFlagsResult.data[f].FLAGNAME ?: "")>
        <cfif compareNoCase(fn, "Current-Student")   EQ 0><cfset studentFlagID = val(allFlagsResult.data[f].FLAGID)></cfif>
        <cfif compareNoCase(fn, "Staff")             EQ 0><cfset staffFlagID   = val(allFlagsResult.data[f].FLAGID)></cfif>
        <cfif compareNoCase(fn, "Faculty-Fulltime")  EQ 0><cfset facultyFlagID = val(allFlagsResult.data[f].FLAGID)></cfif>
    </cfloop>

    <cfif studentFlagID GT 0 AND listFindNoCase("yes,true,1,y", apiStudent)>
        <cfset flagsService.addFlag(newUserID, studentFlagID)>
        <cfset flagsAssigned++>
    </cfif>
    <cfif staffFlagID GT 0 AND listFindNoCase("yes,true,1,y", apiStaff)>
        <cfset flagsService.addFlag(newUserID, staffFlagID)>
        <cfset flagsAssigned++>
    </cfif>
    <cfif facultyFlagID GT 0 AND listFindNoCase("yes,true,1,y", apiFaculty)>
        <cfset flagsService.addFlag(newUserID, facultyFlagID)>
        <cfset flagsAssigned++>
    </cfif>
</cfif>

<!--- Step 6: Remove from staging --->
<cfsilent>
    <cfset queryExecute(
        "DELETE FROM UHApiPeopleStaging WHERE UHApiID = :id",
        { id = { value=uhApiId, cfsqltype="cf_sql_nvarchar" } },
        { datasource=datasource, timeout=30 }
    )>
</cfsilent>

<!--- Step 7: Redirect with success message --->
<cflocation url="#returnTo##sep#msg=imported&importedName=#urlEncodedFormat(apiFirstName & ' ' & apiLastName)#&newUserID=#newUserID#" addtoken="false">
