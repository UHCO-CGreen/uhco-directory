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

<cffunction name="emitFetchResult" access="private" returntype="void" output="false">
    <cfargument name="payload" type="struct" required="true">

    <cfif structKeyExists(arguments.payload, "statusCode")>
        <cfheader statusCode="#val(arguments.payload.statusCode)#">
    <cfelse>
        <cfheader statusCode="#(arguments.payload.success ? 200 : 400)#">
    </cfif>

    <cfoutput>#serializeJSON(toCaseSafeJsonValue(arguments.payload))#</cfoutput>
    <cfabort>
</cffunction>

<cfif cgi.REQUEST_METHOD NEQ "POST">
    <cfset emitFetchResult({ success = false, statusCode = 405, message = "Method not allowed.", errors = ["POST required"] })>
</cfif>

<cfif NOT request.hasPermission("users.edit")>
    <cfset emitFetchResult({ success = false, statusCode = 403, message = "Unauthorized: users.edit permission required.", errors = ["users.edit permission required"] })>
</cfif>

<cfparam name="form.userID" default="0">
<cfparam name="form.serviceCode" default="">
<cfparam name="form.limitRecentYears" default="1">

<cfif NOT (isNumeric(form.userID) AND val(form.userID) GT 0)>
    <cfset emitFetchResult({ success = false, statusCode = 400, message = "Invalid userID.", errors = ["userID must be numeric"] })>
</cfif>

<cfif NOT len(trim(form.serviceCode))>
    <cfset emitFetchResult({ success = false, statusCode = 400, message = "Missing serviceCode.", errors = ["serviceCode is required"] })>
</cfif>

<cfset targetUserID = val(form.userID)>
<cfset targetServiceCode = lCase(trim(form.serviceCode))>

<cfif NOT request.canAccessUserByID(targetUserID)>
    <cfset emitFetchResult({ success = false, statusCode = 403, message = "Unauthorized.", errors = ["user access is restricted"] })>
</cfif>

<cftry>
    <cfset fetchService = createObject("component", "cfc.publicationFetch_service").init()>
    <cfset result = fetchService.fetchForUser(
        userID = targetUserID,
        serviceCode = targetServiceCode,
        limitRecentYears = listFindNoCase("1,true,yes,on", trim(form.limitRecentYears)) GT 0,
        triggeredByAdminUserID = structKeyExists(session, "user") ? val(session.user.adminUserID ?: 0) : 0
    )>

    <cfset emitFetchResult(result)>

<cfcatch type="any">
    <cflog
        file="admin-users-publications-fetch"
        type="error"
        text="fetchPublications failed | serviceCode=#targetServiceCode# | userID=#targetUserID# | message=#cfcatch.message# | detail=#cfcatch.detail#"
    >
    <cfset emitFetchResult({ success = false, statusCode = 500, message = "Publication fetch failed. Please try again or contact support if the problem continues.", errors = [] })>
</cfcatch>
</cftry>