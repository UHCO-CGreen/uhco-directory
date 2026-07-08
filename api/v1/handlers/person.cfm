<!--- GET /dir/api/v1/people/{id} — full profile --->
<cfset auth.requireAuth("read")>

<cfset dirService = createObject("component", "cfc.directory_service").init()>
<cfset publicationsService = createObject("component", "cfc.publications_service").init()>
<cfset profile   = dirService.getFullProfile(val(resourceID))>

<cfif structIsEmpty(profile) OR structIsEmpty(profile.user ?: {})>
    <cfset auth.sendError(404, "User not found")>
</cfif>

<cfif NOT val(profile.user.ACTIVE ?: 1)>
    <cfset auth.sendError(404, "User not found")>
</cfif>

<cfset isTestUser = false>
<cfloop array="#profile.flags ?: []#" index="flagRow">
    <cfif compareNoCase(trim(flagRow.FLAGNAME ?: ""), "TEST_USER") EQ 0>
        <cfset isTestUser = true>
        <cfbreak>
    </cfif>
</cfloop>

<cfif isTestUser>
    <cfset auth.sendError(404, "User not found")>
</cfif>

<cfif isStruct(profile.user ?: {}) AND structKeyExists(profile.user, "NAMES")>
    <cfset profile["NAMES"] = profile.user.NAMES>
</cfif>

<cfset profile["SHOWCASED_PUBLICATIONS"] = publicationsService.getShowcasedPublications(val(resourceID)).data>

<!--- Strip flat name/contact fields from user node — all data is in NAMES envelope --->
<cfset stripFields = ["FIRSTNAME", "MIDDLENAME", "LASTNAME", "FULLNAME", "PREFERREDNAME", "MAIDENNAME", "EMAILPRIMARY"]>
<cfif isStruct(profile.user ?: {})>
    <cfloop array="#stripFields#" item="fieldKey">
        <cfset structDelete(profile.user, fieldKey)>
    </cfloop>
</cfif>

<cfset auth.sendResponse(profile)>
<cfabort>
