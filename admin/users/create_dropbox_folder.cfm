<cfsetting showdebugoutput="false">
<cfcontent type="application/json; charset=utf-8">

<cffunction name="emit" access="private" returntype="void" output="false">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="payload"    type="struct"  required="true">
    <cfheader statusCode="#arguments.statusCode#">
    <cfoutput>#serializeJSON(arguments.payload)#</cfoutput>
    <cfabort>
</cffunction>

<cffunction name="makePayload" access="private" returntype="struct" output="false">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="message" type="string"  required="true">
    <cfargument name="data"    type="struct"  required="true">
    <cfset var p = structNew("ordered-casesensitive")>
    <cfset p["success"] = arguments.success>
    <cfset p["message"] = arguments.message>
    <cfset p["data"]    = arguments.data>
    <cfreturn p>
</cffunction>

<cfset emptyData = structNew("ordered-casesensitive")>

<cfif cgi.REQUEST_METHOD NEQ "POST">
    <cfset emit(405, makePayload(false, "Method not allowed.", emptyData))>
</cfif>

<cfif NOT application.authService.hasRole("SUPER_ADMIN") AND NOT request.hasPermission("media.folder.manage")>
    <cfset emit(403, makePayload(false, "Insufficient permissions.", emptyData))>
</cfif>

<cfparam name="form.userID" default="0">
<cfif NOT (isNumeric(form.userID) AND val(form.userID) GT 0)>
    <cfset emit(400, makePayload(false, "Invalid userID.", emptyData))>
</cfif>

<cfset targetUserID = val(form.userID)>

<cftry>
    <cfset directoryService = createObject("component", "cfc.directory_service").init()>
    <cfset profile = directoryService.getFullProfile(targetUserID)>
    <cfset user = profile.user>

    <cfset firstName  = trim(toString(user.PREFERREDFIRSTNAME ?: user.FIRSTNAME  ?: ""))>
    <cfset lastName   = trim(toString(user.PREFERREDLASTNAME  ?: user.LASTNAME   ?: ""))>
    <cfset middleName = trim(toString(user.PREFERREDMIDDLENAME ?: user.MIDDLENAME ?: ""))>
    <cfset externalIDs = (structKeyExists(profile, "externalIDs") AND isArray(profile.externalIDs)) ? profile.externalIDs : []>
    <cfset userFlags   = (structKeyExists(profile, "flags")       AND isArray(profile.flags))       ? profile.flags       : []>

    <cfset sourceService = createObject("component", "cfc.UserImageSourceService").init()>
    <cfset result = sourceService.createUserDropboxFolder(
        firstName   = firstName,
        lastName    = lastName,
        middleName  = middleName,
        externalIDs = externalIDs,
        userFlags   = userFlags
    )>

    <cfset responseData = structNew("ordered-casesensitive")>
    <cfset responseData["primaryFolder"]     = result.primaryFolder>
    <cfset responseData["parentFolder"]      = result.parentFolder>
    <cfset responseData["folderPath"]        = result.folderPath>
    <cfset responseData["publishFolderPath"] = result.publishFolderPath>
    <cfset responseData["mainCreated"]       = result.mainCreated>
    <cfset responseData["publishCreated"]    = result.publishCreated>

    <cfif result.success>
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset usersService.updateDropboxFolderPath(targetUserID, result.folderPath)>
    </cfif>

    <cfif result.success>
        <cfset emit(200, makePayload(true,  result.message, responseData))>
    <cfelse>
        <cfset emit(200, makePayload(false, result.error,   responseData))>
    </cfif>

<cfcatch type="any">
    <cflog
        file="dropbox-folder-create"
        type="error"
        text="create_dropbox_folder failed | userID=#targetUserID# | message=#cfcatch.message# | detail=#cfcatch.detail#"
    >
    <cfset emit(500, makePayload(false, "An unexpected error occurred. Please try again.", structNew("ordered-casesensitive")))>
</cfcatch>
</cftry>
