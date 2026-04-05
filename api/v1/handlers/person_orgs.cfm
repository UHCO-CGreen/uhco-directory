<!--- GET /dir/api/v1/people/{id}/organizations --->
<cfset auth.requireAuth("read")>
<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset result = orgsService.getUserOrgs(val(resourceID))>
<cfset auth.sendResponse({ userID: val(resourceID), data: result.data })>
<cfabort>
