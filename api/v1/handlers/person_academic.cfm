<!--- GET /dir/api/v1/people/{id}/academic --->
<cfset auth.requireAuth("read")>
<cfset acadService = createObject("component", "dir.cfc.academic_service").init()>
<cfset result = acadService.getAcademicInfo(val(resourceID))>
<cfset auth.sendResponse({ userID: val(resourceID), data: result.data })>
<cfabort>
