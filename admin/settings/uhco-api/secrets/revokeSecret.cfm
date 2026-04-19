<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST" OR NOT structKeyExists(form, "secretID") OR NOT isNumeric(form.secretID)>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/secrets/index.cfm" addtoken="false">
</cfif>
<cfset createObject("component", "cfc.secret_service").init().revokeSecret(val(form.secretID))>
<cflocation url="#request.webRoot#/admin/settings/uhco-api/secrets/index.cfm" addtoken="false">
