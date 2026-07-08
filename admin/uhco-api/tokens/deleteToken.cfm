<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST" OR NOT structKeyExists(form, "tokenID") OR NOT isNumeric(form.tokenID)>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/tokens/index.cfm" addtoken="false">
</cfif>

<cfset tokenService = createObject("component", "cfc.token_service").init()>
<cfset tokenService.deleteToken(val(form.tokenID))>
<cflocation url="#request.webRoot#/admin/settings/uhco-api/tokens/index.cfm" addtoken="false">
