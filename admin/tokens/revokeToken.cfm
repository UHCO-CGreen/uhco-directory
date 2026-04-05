<cfif CGI.REQUEST_METHOD NEQ "POST" OR NOT structKeyExists(form, "tokenID") OR NOT isNumeric(form.tokenID)>
    <cflocation url="/dir/admin/tokens/index.cfm" addtoken="false">
</cfif>

<cfset tokenService = createObject("component", "dir.cfc.token_service").init()>
<cfset tokenService.revokeToken(val(form.tokenID))>
<cflocation url="/dir/admin/tokens/index.cfm" addtoken="false">
