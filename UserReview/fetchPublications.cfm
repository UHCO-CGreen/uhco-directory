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

<cffunction name="emitUserReviewResult" access="private" returntype="void" output="false">
    <cfargument name="payload" type="struct" required="true">

    <cfif structKeyExists(arguments.payload, "statusCode")>
        <cfheader statusCode="#val(arguments.payload.statusCode)#">
    <cfelse>
        <cfheader statusCode="#(arguments.payload.success ? 200 : 400)#">
    </cfif>

    <cfoutput>#serializeJSON(toCaseSafeJsonValue(arguments.payload))#</cfoutput>
    <cfabort>
</cffunction>

<cfif cgi.request_method NEQ "POST">
    <cfset emitUserReviewResult({ success = false, statusCode = 405, message = "Method not allowed.", errors = ["POST required"] })>
</cfif>

<cfset userReviewAuth = structKeyExists(request, "userReviewAuth") ? request.userReviewAuth : createObject("component", "cfc.UserReviewAuthService").init()>

<cfif NOT userReviewAuth.isLoggedIn()>
    <cfset emitUserReviewResult({ success = false, statusCode = 401, message = "Login required.", errors = ["not authenticated"] })>
</cfif>

<cfparam name="form.limitRecentYears" default="1">

<cftry>
    <cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
    <cfset saveResult = userReviewService.saveLivePublications(
        actor = userReviewAuth.getSessionUser(),
        formScope = form
    )>

    <cfif NOT saveResult.success>
        <cfset emitUserReviewResult(saveResult)>
    </cfif>

    <cfset result = userReviewService.fetchLivePublications(
        actor = userReviewAuth.getSessionUser(),
        limitRecentYears = listFindNoCase("1,true,yes,on", trim(form.limitRecentYears)) GT 0
    )>
    <cfset emitUserReviewResult(result)>
<cfcatch type="any">
    <cflog file="userreview-publications" type="error" text="fetchPublications failed | message=#cfcatch.message# | detail=#cfcatch.detail#">
    <cfset emitUserReviewResult({ success = false, statusCode = 500, message = "Live publications fetch failed.", errors = [] })>
</cfcatch>
</cftry>