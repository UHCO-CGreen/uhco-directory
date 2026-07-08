<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cffunction name="toCaseSafeJsonValue" access="private" returntype="any" output="false">
    <cfargument name="value" required="true">

    <cfset var resultStruct = "">
    <cfset var resultArray = []>
    <cfset var keyName = "">
    <cfset var itemValue = "">

    <cfif isStruct(arguments.value)>
        <cfset resultStruct = structNew("ordered-casesensitive")>
        <cfloop collection="#arguments.value#" item="keyName">
            <cfset resultStruct[lCase(keyName)] = toCaseSafeJsonValue(arguments.value[keyName])>
        </cfloop>
        <cfreturn resultStruct>
    </cfif>

    <cfif isArray(arguments.value)>
        <cfloop array="#arguments.value#" item="itemValue">
            <cfset arrayAppend(resultArray, toCaseSafeJsonValue(itemValue))>
        </cfloop>
        <cfreturn resultArray>
    </cfif>

    <cfreturn arguments.value>
</cffunction>

<cffunction name="emitAsyncSuccess" access="private" returntype="void" output="false">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" required="false" default="#{}#">

    <cfset var payload = structNew("ordered-casesensitive")>
    <cfset payload.success = true>
    <cfset payload.message = trim(arguments.message ?: "")>
    <cfset payload.errors = []>
    <cfset payload.data = toCaseSafeJsonValue(arguments.data)>

    <cfheader statusCode="200">
    <cfoutput>#serializeJSON(payload)#</cfoutput>
    <cfabort>
</cffunction>

<cffunction name="emitAsyncError" access="private" returntype="void" output="false">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="errors" required="false" default="#[]#">
    <cfargument name="data" required="false" default="#{}#">

    <cfset var payload = structNew("ordered-casesensitive")>
    <cfset payload.success = false>
    <cfset payload.message = trim(arguments.message ?: "")>
    <cfset payload.errors = toCaseSafeJsonValue(arguments.errors)>
    <cfset payload.data = toCaseSafeJsonValue(arguments.data)>

    <cfheader statusCode="#arguments.statusCode#">
    <cfoutput>#serializeJSON(payload)#</cfoutput>
    <cfabort>
</cffunction>

<cffunction name="emitAsyncServiceResult" access="private" returntype="void" output="false">
    <cfargument name="result" type="struct" required="true">

    <cfif structKeyExists(arguments.result, "success") AND arguments.result.success>
        <cfset emitAsyncSuccess(arguments.result.message ?: "Saved.", structKeyExists(arguments.result, "data") ? arguments.result.data : {})>
    <cfelse>
        <cfset emitAsyncError(
            structKeyExists(arguments.result, "statusCode") ? val(arguments.result.statusCode) : 400,
            arguments.result.message ?: "Save failed.",
            structKeyExists(arguments.result, "errors") ? arguments.result.errors : [],
            structKeyExists(arguments.result, "data") ? arguments.result.data : {}
        )>
    </cfif>
</cffunction>

<cfif NOT request.hasPermission("users.edit")>
    <cfset emitAsyncError(403, "Unauthorized: users.edit permission required.", ["users.edit permission required"])>
</cfif>

<cfif NOT structKeyExists(form, "userID") OR NOT isNumeric(form.userID)>
    <cfset emitAsyncError(400, "Missing userID.", ["userID is required and must be numeric"] )>
</cfif>
<cfif NOT structKeyExists(form, "section")>
    <cfset emitAsyncError(400, "Missing section.", ["section is required"] )>
</cfif>

<cfset userID = val(form.userID)>
<cfset section = lCase(trim(form.section))>
<cfset userEditSaveService = createObject("component", "cfc.userEditSave_service").init()>
<cfif NOT request.canAccessUserByID(userID)>
    <cfset emitAsyncError(403, "Unauthorized.", ["test user access is restricted"] )>
</cfif>
<cfset _ssFlagsSvc = createObject("component", "cfc.flags_service").init()>
<cfset _ssFlags = _ssFlagsSvc.getUserFlags(userID).data>
<cfset _ssIsAlumni = false>
<cfset _ssIsFaculty = false>
<cfloop array="#_ssFlags#" index="_ssf">
    <cfif compareNoCase(trim(_ssf.FLAGNAME ?: ""), "Alumni") EQ 0>
        <cfset _ssIsAlumni = true>
    </cfif>
    <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", trim(_ssf.FLAGNAME ?: ""))>
        <cfset _ssIsFaculty = true>
    </cfif>
</cfloop>
<cfif _ssIsAlumni AND NOT (application.authService.hasRole("ALUMNI_ADMIN") OR (_ssIsFaculty AND application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])))>
    <cfset emitAsyncError(403, "Access denied.", ["alumni.view role required"])>
</cfif>

<cftry>
<cfswitch expression="#section#">
    <cfcase value="emails,addldapemailifmissing,addldapaliasifmissing,phones,aliases,awards,residencies,degrees,addresses,addAddress,general,flags,orgs,extids,publications,uh,bioinfo,studentprofile,bio,tabdegrees">
        <cfset emitAsyncServiceResult(userEditSaveService.handle(section, userID, form))>
    </cfcase>

    <cfdefaultcase>
        <cfset emitAsyncError(400, "Unknown section: #section#", ["section is not supported"] )>
    </cfdefaultcase>

</cfswitch>

<cfcatch type="any">
    <cflog
        file="admin-users-save-section"
        type="error"
        text="saveSection failed | section=#section# | userID=#userID# | message=#cfcatch.message# | detail=#cfcatch.detail#"
    >
    <cfset emitAsyncError(500, "Save failed. Please try again or contact support if the problem continues.")>
</cfcatch>
</cftry>
