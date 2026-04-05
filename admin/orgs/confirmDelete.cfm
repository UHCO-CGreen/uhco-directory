<cfif !structKeyExists(form, "OrgID") OR !isNumeric(form.OrgID)>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset result = orgsService.deleteOrg(val(form.OrgID))>

<cfif result.success>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="/dir/admin/orgs/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>
