<!--- GET /dir/api/v1/organizations --->
<cfset auth.requireAuth("read")>
<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset result = orgsService.getAllOrgs()>
<cfset auth.sendResponse({ data: result.data })>
<cfabort>
