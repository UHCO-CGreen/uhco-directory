<cfsetting showdebugoutput="false">
<cfcontent type="application/json" reset="true">

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

<cffunction name="emitAsyncResponse" access="private" returntype="void" output="false">
    <cfargument name="statusCode" type="numeric" required="true">
    <cfargument name="success" type="boolean" required="true">
    <cfargument name="message" type="string" required="true">
    <cfargument name="data" required="false" default="#[]#">
    <cfargument name="errors" required="false" default="#[]#">
    <cfargument name="meta" required="false" default="#{}#">

    <cfset var payload = structNew("ordered-casesensitive")>
    <cfset payload.success = arguments.success>
    <cfset payload.message = trim(arguments.message ?: "")>
    <cfset payload.errors = toCaseSafeJsonValue(arguments.errors)>
    <cfset payload.data = toCaseSafeJsonValue(arguments.data)>
    <cfif isStruct(arguments.meta) AND structCount(arguments.meta)>
        <cfset payload.meta = toCaseSafeJsonValue(arguments.meta)>
    </cfif>

    <cfheader statusCode="#arguments.statusCode#">
    <cfoutput>#serializeJSON(payload)#</cfoutput>
    <cfabort>
</cffunction>

<cfif NOT request.hasPermission("users.edit")>
    <cfset emitAsyncResponse(403, false, "Unauthorized: users.edit permission required.", [], ["users.edit permission required"])>
</cfif>

<cfset term = trim((form.searchTerm ?: url.searchTerm ?: "") & "")>
<cfset userType = lCase(trim((form.userType ?: url.userType ?: "") & ""))>
<cfset userID = val((form.userID ?: url.userID ?: 0) & "")>
<cfset maxRows = val((form.maxRows ?: url.maxRows ?: 25) & "")>

<cfif len(term) LT 2>
    <cfset emitAsyncResponse(400, false, "Enter at least 2 characters.", [], ["searchTerm must contain at least 2 characters"])>
</cfif>

<cfif maxRows LTE 0>
    <cfset maxRows = 25>
</cfif>

<cftry>
    <cfset ldapLookupService = createObject("component", "cfc.ldapLookup_simple_service").init()>
    <cfset result = ldapLookupService.searchCandidates(
        searchTerm = term,
        userType = userType,
        userID = userID,
        maxRows = maxRows
    )>

    <cfset emitAsyncResponse(
        200,
        true,
        result.message,
        result.data,
        [],
        (structKeyExists(result, "meta") ? result.meta : {})
    )>

    <cfcatch type="any">
        <cflog
            file="ldap-lookup"
            type="error"
            text="Cougarnet lookup failed. term=#left(term, 80)# userID=#userID# userType=#userType# message=#cfcatch.message# detail=#cfcatch.detail#"
        >
        <cfset emitAsyncResponse(500, false, "Directory lookup failed. Please try again or contact support if the problem continues.", [], [cfcatch.message])>
    </cfcatch>
</cftry>
