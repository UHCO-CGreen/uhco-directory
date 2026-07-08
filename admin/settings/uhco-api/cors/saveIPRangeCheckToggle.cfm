<!---
    CORS Whitelist — enable/disable the IP range trust check.
    POST only. Redirects back to index with msg or err param.
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST">
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/" addtoken="false">
</cfif>

<cfset corsService = createObject("component", "cfc.cors_service").init()>
<cfset enabled = structKeyExists(form, "enabled")>
<cfset redirectURL = request.webRoot & "/admin/settings/uhco-api/cors/">

<cftry>
    <cfset result = corsService.setIPRangeCheckEnabled(enabled)>
    <cfset redirectURL &= result.success ? "?msg=" & urlEncodedFormat(result.message) : "?err=" & urlEncodedFormat(result.message)>
<cfcatch type="any">
    <cfset redirectURL &= "?err=" & urlEncodedFormat(cfcatch.message)>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">
