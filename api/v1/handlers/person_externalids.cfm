<!--- GET /dir/api/v1/people/{id}/externalids --->
<cfset auth.requireAuth("read")>
<cfset extService = createObject("component", "dir.cfc.externalID_service").init()>
<cfset result = extService.getExternalIDs(val(resourceID))>
<cfset auth.sendResponse({ userID: val(resourceID), data: result.data })>
<cfabort>
