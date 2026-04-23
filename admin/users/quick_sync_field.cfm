<!---
    quick_sync_field.cfm
    Fetches a single field from the UH API for a user and writes it to the database,
    then redirects back to url.returnTo (falling back to the user view page).
    Called via link (GET) from the Data Quality Report.
--->
<cfparam name="url.userID"    default="">
<cfparam name="url.issueCode" default="">
<cfparam name="url.returnTo"  default="">

<!--- Validate userID --->
<cfif NOT (isNumeric(url.userID) AND val(url.userID) GT 0)>
    <cfset content = "<h1>Quick Sync</h1><div class='alert alert-danger'>Invalid user ID.</div><a href='/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>
<cfset targetUserID = val(url.userID)>

<!--- Validate returnTo: only allow root-relative paths to prevent open redirect --->
<cfset returnTo = "/admin/users/view.cfm?userID=#targetUserID#">
<cfif len(trim(url.returnTo))>
    <cfset candidateReturn = trim(url.returnTo)>
    <cfif left(candidateReturn, 1) EQ "/" AND NOT find("//", candidateReturn) AND NOT findNoCase("javascript:", candidateReturn)>
        <cfset returnTo = candidateReturn>
    </cfif>
</cfif>

<!--- Issue code → { apiKeys, userField, label } map --->
<cfset syncableIssues = {
    "missing_firstname"     : { apiKeys="first_name,firstName",   userField="FirstName",    label="First Name"    },
    "missing_lastname"      : { apiKeys="last_name,lastName",     userField="LastName",     label="Last Name"     },
    "missing_primary_alias" : { apiKeys="first_name,firstName",   userField="PrimaryAlias", label="Primary Alias" },
    "missing_email_primary" : { apiKeys="email,emailAddress",     userField="EmailPrimary", label="Primary Email" },
    "missing_title1"        : { apiKeys="title",                  userField="Title1",       label="Title"         },
    "missing_room"          : { apiKeys="room",                   userField="Room",         label="Room"          },
    "missing_building"      : { apiKeys="building",               userField="Building",     label="Building"      },
    "missing_phone"         : { apiKeys="phone,phoneNumber",      userField="Phone",        label="Phone"         }
}>

<cfset issueCode = trim(url.issueCode)>
<cfif NOT structKeyExists(syncableIssues, issueCode)>
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Issue code not supported for quick sync: ' & issueCode)#" addtoken="false">
    <cfabort>
</cfif>
<cfset issueMap = syncableIssues[issueCode]>

<!--- Load user profile --->
<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset profile = directoryService.getFullProfile(targetUserID)>
<cfif NOT (structKeyExists(profile, "user") AND structCount(profile.user) GT 0)>
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('User ' & targetUserID & ' not found')#" addtoken="false">
    <cfabort>
</cfif>
<cfset dbUser  = profile.user>
<cfset uhApiId = trim(dbUser.UH_API_ID ?: "")>
<cfif uhApiId EQ "">
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('User has no UH API ID assigned')#" addtoken="false">
    <cfabort>
</cfif>

<!--- API credentials --->
<cfset uhApiToken  = structKeyExists(application, "uhApiToken")  ? trim(application.uhApiToken  ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">
<cfif (uhApiToken EQ "" OR uhApiSecret EQ "") AND structKeyExists(server, "system") AND structKeyExists(server.system, "environment")>
    <cfif structKeyExists(server.system.environment, "UH_API_TOKEN")>
        <cfset uhApiToken  = trim(server.system.environment["UH_API_TOKEN"])>
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

<!--- Fetch person from UH API --->
<cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
<cfset personResponse = uhApi.getPerson(
    uhApiId,
    trim(dbUser.DEPARTMENT ?: ""),
    trim(dbUser.DIVISION ?: ""),
    trim(dbUser.CAMPUS ?: "")
)>
<cfset statusCode = personResponse.statusCode ?: "Unknown">
<cfif left(statusCode, 3) NEQ "200">
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API returned status ' & statusCode)#" addtoken="false">
    <cfabort>
</cfif>

<!--- Unwrap nested API response --->
<cfset responseData = personResponse.data ?: {}>
<cfset apiPerson    = {}>
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

<!--- Deep key-search helpers (scoped with qsf_ prefix to avoid conflicts) --->
<cfscript>
    function qsfFindValueByKeyDeep(any node="", required string keyName) {
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
                found = qsfFindValueByKeyDeep(node=arguments.node[keys[i]], keyName=arguments.keyName);
                if (len(trim(toString(found)))) { return found; }
            }
        } else if (isArray(arguments.node)) {
            for (i = 1; i <= arrayLen(arguments.node); i++) {
                found = qsfFindValueByKeyDeep(node=arguments.node[i], keyName=arguments.keyName);
                if (len(trim(toString(found)))) { return found; }
            }
        }
        return "";
    }

    function qsfGetApiValue(required any source, required string keyListCsv) {
        var names = listToArray(arguments.keyListCsv);
        var i     = 1;
        var v     = "";
        for (i = 1; i <= arrayLen(names); i++) {
            v = qsfFindValueByKeyDeep(node=arguments.source, keyName=trim(names[i]));
            if (len(trim(toString(v)))) { return toString(v); }
        }
        return "";
    }
</cfscript>

<cfif uCase(issueMap.userField) EQ "PRIMARYALIAS">
    <cfset aliasesSvc = createObject("component", "cfc.aliases_service").init()>
    <cfset existingAliases = aliasesSvc.getAliases(targetUserID).data>
    <cfset aliasesToSave = []>
    <cfset primaryIdx = 0>
    <cfset firstActiveIdx = 0>

    <cfset apiFirst = trim(qsfGetApiValue(apiPerson, "first_name,firstName"))>
    <cfset apiMiddle = trim(qsfGetApiValue(apiPerson, "middle_name,middleName"))>
    <cfset apiLast = trim(qsfGetApiValue(apiPerson, "last_name,lastName"))>

    <cfif NOT len(apiFirst) AND NOT len(apiLast)>
        <cfset sep = find("?", returnTo) ? "&" : "?">
        <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API did not return name values for Primary Alias sync')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfloop from="1" to="#arrayLen(existingAliases)#" index="i">
        <cfif val(existingAliases[i].ISPRIMARY ?: 0) EQ 1>
            <cfset primaryIdx = i>
            <cfbreak>
        </cfif>
        <cfif firstActiveIdx EQ 0 AND val(existingAliases[i].ISACTIVE ?: 0) EQ 1>
            <cfset firstActiveIdx = i>
        </cfif>
    </cfloop>

    <cfif primaryIdx EQ 0>
        <cfset primaryIdx = firstActiveIdx>
    </cfif>

    <cfloop from="1" to="#arrayLen(existingAliases)#" index="i">
        <cfset a = existingAliases[i]>
        <cfset row = {
            firstName = trim(a.FIRSTNAME ?: ""),
            middleName = trim(a.MIDDLENAME ?: ""),
            lastName = trim(a.LASTNAME ?: ""),
            aliasType = trim(a.ALIASTYPE ?: ""),
            sourceSystem = trim(a.SOURCESYSTEM ?: ""),
            isActive = val(a.ISACTIVE ?: 0),
            isPrimary = val(a.ISPRIMARY ?: 0)
        }>

        <cfif i EQ primaryIdx>
            <cfset row.firstName = apiFirst>
            <cfset row.middleName = apiMiddle>
            <cfset row.lastName = apiLast>
            <cfif NOT len(row.aliasType)><cfset row.aliasType = "SOURCE_VARIANT"></cfif>
            <cfif NOT len(row.sourceSystem)><cfset row.sourceSystem = "UH API"></cfif>
            <cfset row.isActive = 1>
            <cfset row.isPrimary = 1>
        </cfif>

        <cfset arrayAppend(aliasesToSave, row)>
    </cfloop>

    <cfif arrayLen(aliasesToSave) EQ 0>
        <cfset arrayAppend(aliasesToSave, {
            firstName = apiFirst,
            middleName = apiMiddle,
            lastName = apiLast,
            aliasType = "SOURCE_VARIANT",
            sourceSystem = "UH API",
            isActive = 1,
            isPrimary = 1
        })>
    </cfif>

    <cfset aliasesSvc.replaceAliases(targetUserID, aliasesToSave)>
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#msg=synced&syncField=#urlEncodedFormat(issueMap.label)#" addtoken="false">
    <cfabort>
</cfif>

<cfset apiValue = trim(qsfGetApiValue(apiPerson, issueMap.apiKeys))>
<cfif NOT len(apiValue)>
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('UH API did not return a value for ' & issueMap.label)#" addtoken="false">
    <cfabort>
</cfif>

<!--- Load full user record and build userData struct for update --->
<cfset usersService       = createObject("component", "cfc.users_service").init()>
<cfset currentUserResult  = usersService.getUser(targetUserID)>
<cfif NOT (structKeyExists(currentUserResult, "success") AND currentUserResult.success)>
    <cfset sep = find("?", returnTo) ? "&" : "?">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Could not load user record for update')#" addtoken="false">
    <cfabort>
</cfif>
<cfset cu = currentUserResult.data>
<cfset userData = {
    FirstName              = cu.FIRSTNAME              ?: "",
    MiddleName             = cu.MIDDLENAME             ?: "",
    LastName               = cu.LASTNAME               ?: "",
    Pronouns               = cu.PRONOUNS               ?: "",
    EmailPrimary           = cu.EMAILPRIMARY           ?: "",
    Phone                  = cu.PHONE                  ?: "",
    Room                   = cu.ROOM                   ?: "",
    Building               = cu.BUILDING               ?: "",
    CougarNetID            = cu.COUGARNETID            ?: "",
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

<!--- Write just the target field --->
<cfset writeField = uCase(issueMap.userField)>
<cfif writeField EQ "FIRSTNAME">
    <cfset userData.FirstName    = apiValue>
<cfelseif writeField EQ "LASTNAME">
    <cfset userData.LastName     = apiValue>
<cfelseif writeField EQ "EMAILPRIMARY">
    <cfset userData.EmailPrimary = lCase(apiValue)>
<cfelseif writeField EQ "TITLE1">
    <cfset userData.Title1       = apiValue>
<cfelseif writeField EQ "ROOM">
    <cfset userData.Room         = apiValue>
<cfelseif writeField EQ "BUILDING">
    <cfset userData.Building     = apiValue>
<cfelseif writeField EQ "PHONE">
    <cfset userData.Phone        = apiValue>
</cfif>

<cfset updateResult = usersService.updateUser(targetUserID, userData)>
<cfset sep = find("?", returnTo) ? "&" : "?">
<cfif structKeyExists(updateResult, "success") AND updateResult.success>
    <cflocation url="#returnTo##sep#msg=synced&syncField=#urlEncodedFormat(issueMap.label)#" addtoken="false">
<cfelse>
    <cfset errMsg = updateResult.message ?: "Unknown error">
    <cflocation url="#returnTo##sep#err=#urlEncodedFormat('Update failed: ' & errMsg)#" addtoken="false">
</cfif>
