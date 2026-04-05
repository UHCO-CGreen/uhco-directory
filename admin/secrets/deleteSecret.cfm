<cfif CGI.REQUEST_METHOD NEQ "POST" OR NOT structKeyExists(form, "secretID") OR NOT isNumeric(form.secretID)>
    <cflocation url="/dir/admin/secrets/index.cfm" addtoken="false">
</cfif>
<cfset createObject("component", "dir.cfc.secret_service").init().deleteSecret(val(form.secretID))>
<cflocation url="/dir/admin/secrets/index.cfm" addtoken="false">
