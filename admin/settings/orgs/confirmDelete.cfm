<cfif !structKeyExists(form, "OrgID") OR !isNumeric(form.OrgID)>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("orgs.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "cfc.organizations_service").init()>
<cfset result = orgsService.deleteOrg(val(form.OrgID))>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>
