<!--- GET /dir/api/v1/flags --->
<cfset auth.requireAuth("read")>
<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>
<cfset result = flagsService.getAllFlags()>
<cfset auth.sendResponse({ data: result.data ?: result })>
<cfabort>
