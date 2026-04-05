<!--- GET /dir/api/v1/organizations/{id} --->
<cfset auth.requireAuth("read")>
<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset result = orgsService.getOrg(val(resourceID))>
<cfif structIsEmpty(result.data ?: {})>
    <cfset auth.sendError(404, "Organization not found")>
</cfif>
<cfset auth.sendResponse(result.data)>
<cfabort>
