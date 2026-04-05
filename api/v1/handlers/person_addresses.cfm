<!--- GET /dir/api/v1/people/{id}/addresses --->
<cfset auth.requireAuth("read")>
<cfset addrService = createObject("component", "dir.cfc.addresses_service").init()>
<cfset result = addrService.getAddresses(val(resourceID))>
<cfset auth.sendResponse({ userID: val(resourceID), data: result.data })>
<cfabort>
