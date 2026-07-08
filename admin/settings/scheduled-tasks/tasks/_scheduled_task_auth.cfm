<!---
    Shared scheduled-task auth guard.
    Enforces token validation only for scheduler-triggered execution.
--->

<cfif lCase(trim(triggeredBy ?: "manual")) EQ "scheduled">
    <cfset _taskAppConfig = createObject("component", "cfc.appConfig_service").init()>
    <cfset _expectedToken = trim(_taskAppConfig.getValue("scheduled_tasks.shared_secret", ""))>
    <cfset _providedToken = trim(form.token ?: "")>
    <cfset _providedUsername = "">
    <cfset _authHeader = trim(CGI.HTTP_AUTHORIZATION ?: "")>
    <cfset _wantsJson = structKeyExists(url, "format") AND lCase(trim(url.format ?: "")) EQ "json">

    <cfif reFindNoCase("^Basic\s+\S+", _authHeader)>
        <cftry>
            <cfset _decodedAuth = charsetEncode(binaryDecode(listLast(_authHeader, " "), "base64"), "utf-8")>
            <cfif find(":", _decodedAuth)>
                <cfset _providedUsername = listFirst(_decodedAuth, ":")>
                <cfset _providedToken = listRest(_decodedAuth, ":")>
            </cfif>
        <cfcatch>
            <cfset _providedUsername = "">
            <cfset _providedToken = "">
        </cfcatch>
        </cftry>
    </cfif>

    <cfif NOT len(_expectedToken)
        OR NOT len(_providedToken)
        OR (len(_providedUsername) AND _providedUsername NEQ "scheduler")
        OR _providedToken NEQ _expectedToken>
        <cfheader statuscode="403">
        <cfif _wantsJson>
            <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=false, error="Invalid scheduled task credentials." })#</cfoutput>
        <cfelse>
            <cfcontent type="text/plain; charset=utf-8" reset="true">Forbidden
        </cfif>
        <cfabort>
    </cfif>
</cfif>