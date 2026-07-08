<!---
    POST-only JSON endpoint: force-logout a target admin user.
    SUPER_ADMIN only. Cannot be used to log out yourself.

    Request (form or JSON body):
        targetUserID  — numeric, required

    Response JSON:
        { "success": true }
        { "error": "..." }
--->
<cfset _forceLogoutResponse = structNew("ordered")>

<cftry>

    <!--- Method guard --->
    <cfif cgi.request_method NEQ "POST">
        <cfheader statusCode="405" statusText="Method Not Allowed">
        <cfcontent type="application/json; charset=utf-8" reset="true">
        <cfset _forceLogoutResponse["error"] = "Method not allowed.">
        <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Auth guard --->
    <cfif NOT application.authService.isActualSuperAdmin()>
        <cfheader statusCode="403" statusText="Forbidden">
        <cfcontent type="application/json; charset=utf-8" reset="true">
        <cfset _forceLogoutResponse["error"] = "Forbidden.">
        <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Resolve targetUserID from form or JSON body --->
    <cfset _targetUserID = 0>
    <cfif structKeyExists(form, "targetUserID") AND isNumeric(form.targetUserID)>
        <cfset _targetUserID = int(val(form.targetUserID))>
    <cfelseif len(trim(getHttpRequestData().content ?: ""))>
        <cftry>
            <cfset _jsonBody = deserializeJSON(getHttpRequestData().content)>
            <cfif isStruct(_jsonBody) AND structKeyExists(_jsonBody, "targetUserID") AND isNumeric(_jsonBody.targetUserID)>
                <cfset _targetUserID = int(val(_jsonBody.targetUserID))>
            </cfif>
        <cfcatch type="any"></cfcatch>
        </cftry>
    </cfif>

    <cfif _targetUserID LTE 0>
        <cfheader statusCode="400" statusText="Bad Request">
        <cfcontent type="application/json; charset=utf-8" reset="true">
        <cfset _forceLogoutResponse["error"] = "targetUserID must be a positive integer.">
        <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Prevent self-logout via this endpoint --->
    <cfset _currentUserID = val(session.user.adminUserID ?: 0)>
    <cfif _targetUserID EQ _currentUserID>
        <cfheader statusCode="400" statusText="Bad Request">
        <cfcontent type="application/json; charset=utf-8" reset="true">
        <cfset _forceLogoutResponse["error"] = "Cannot force-logout yourself via this endpoint.">
        <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>
        <cfabort>
    </cfif>

    <!--- Set ForceLogout flag + close active DB session rows --->
    <cfset application.adminSessionsDAO.setForceLogout(_targetUserID)>
    <cfset application.adminSessionsDAO.closeSessionsForUser(_targetUserID)>

    <!--- Audit the action --->
    <cfif isObject(application.authAuditService)>
        <cfset application.authAuditService.log(
            source      = "admin",
            eventType   = "FORCE_LOGOUT",
            adminUserID = _currentUserID,
            username    = session.user.username ?: "",
            ipAddress   = left(trim(cgi.remote_addr & ""), 50),
            details     = "targetUserID=#_targetUserID#"
        )>
    </cfif>

    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfset _forceLogoutResponse["success"] = true>
    <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>

<cfcatch type="any">
    <cfheader statusCode="500" statusText="Internal Server Error">
    <cfcontent type="application/json; charset=utf-8" reset="true">
    <cfset _forceLogoutResponse["error"] = "An unexpected error occurred.">
    <cfoutput>#serializeJSON(_forceLogoutResponse)#</cfoutput>
</cfcatch>
</cftry>
