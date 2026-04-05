<!--- GET /dir/api/v1/people/{id} — full profile --->
<cfset auth.requireAuth("read")>

<cfset dirService = createObject("component", "dir.cfc.directory_service").init()>
<cfset profile   = dirService.getFullProfile(val(resourceID))>

<cfif structIsEmpty(profile) OR structIsEmpty(profile.user ?: {})>
    <cfset auth.sendError(404, "User not found")>
</cfif>

<cfset auth.sendResponse(profile)>
<cfabort>
