<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>

<cfif !structKeyExists(form, "FlagID") || !isNumeric(form.FlagID)>
    <cflocation url="/dir/admin/flags/index.cfm">
</cfif>

<cfset result = flagsService.deleteFlag(form.FlagID)>

<cfif result.success>
    <cflocation url="/dir/admin/flags/index.cfm">
<cfelse>
    <cflocation url="/dir/admin/flags/index.cfm?error=#urlEncodedFormat(result.message)#">
</cfif>
