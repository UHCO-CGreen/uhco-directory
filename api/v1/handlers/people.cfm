<!--- GET /dir/api/v1/people  — list users with optional filtering --->
<cfset auth.requireAuth("read")>

<cfset dirService = createObject("component", "cfc.directory_service").init()>
<cfset publicationsService = createObject("component", "cfc.publications_service").init()>

<!--- Query params --->
<cfset search      = trim(url.search ?: "")>
<cfset filterFlag  = trim(url.flag   ?: "")>
<cfset filterOrg   = trim(url.org    ?: "")>
<cfset filterClass = isNumeric(url.class ?: "") ? toString(int(val(url.class ?: ""))) : "">
<cfset filterGradYear = isNumeric(url.gradyear ?: "") ? toString(int(val(url.gradyear ?: ""))) : "">
<cfset limit       = isNumeric(url.limit  ?: "") ? min(val(url.limit),  500) : 50>
<cfset offset      = isNumeric(url.offset ?: "") ? max(val(url.offset), 0)   : 0>

<!--- Allow gradyear= only when filtering Alumni or Current-Student --->
<cfif len(filterGradYear) AND listFindNoCase("Alumni,Current-Student", filterFlag)>
    <cfset filterClass = filterGradYear>
</cfif>

<!---
    Secret-gating: check for a valid secret and collect which flags it unlocks.
    Any protected flags NOT unlocked by a valid secret are excluded from results.
    Any protected orgs NOT unlocked by a valid secret are excluded from results.
    Unlocking "Current-Student" also unlocks Academic Programs orgs (student programs).
--->
<cfset DEFAULT_PROTECTED_FLAGS = "Current-Student,Alumni">
<cfset PROTECTED_ORGS          = "OD Program,MS Program,PhD Program,Residency Program">
<cfset unlockedFlags = auth.checkSecret()>

<!--- Build the excludeFlags list: protected flags that are NOT unlocked --->
<cfset excludeFlags = "">
<cfloop list="#DEFAULT_PROTECTED_FLAGS#" item="pf">
    <cfif NOT arrayFindNoCase(unlockedFlags, trim(pf))>
        <cfset excludeFlags = listAppend(excludeFlags, trim(pf))>
    </cfif>
</cfloop>
<cfif NOT listFindNoCase(excludeFlags, "TEST_USER")>
    <cfset excludeFlags = listAppend(excludeFlags, "TEST_USER")>
</cfif>

<!--- Build excludeOrgs: Academic Programs children are protected unless Current-Student is unlocked --->
<cfset excludeOrgs = "">
<cfif NOT arrayFindNoCase(unlockedFlags, "Current-Student")>
    <cfset excludeOrgs = PROTECTED_ORGS>
</cfif>

<!--- If caller filtered by a flag that is itself protected and not unlocked, return empty --->
<cfif len(filterFlag) AND listFindNoCase(excludeFlags, filterFlag)>
    <cfset auth.sendResponse({ total: 0, limit: limit, offset: offset, data: [] })>
    <cfabort>
</cfif>

<!--- If caller filtered by a protected org and orgs are not unlocked, return empty --->
<cfif len(filterOrg) AND listFindNoCase(excludeOrgs, filterOrg)>
    <cfset auth.sendResponse({ total: 0, limit: limit, offset: offset, data: [] })>
    <cfabort>
</cfif>

<!--- class= is implicitly student data; block it when Current-Student is excluded --->
<cfif len(filterClass) AND listFindNoCase(excludeFlags, "Current-Student")>
    <cfset auth.sendResponse({ total: 0, limit: limit, offset: offset, data: [] })>
    <cfabort>
</cfif>

<cfset result = dirService.searchUsers(
    searchTerm   = search,
    filterFlag   = filterFlag,
    filterOrg    = filterOrg,
    filterClass  = filterClass,
    excludeFlags = excludeFlags,
    excludeOrgs  = excludeOrgs,
    maxRows      = limit,
    startRow     = offset + 1
)>

<cfset payload = {
    total   : result.totalCount ?: 0,
    limit   : limit,
    offset  : offset,
    data    : result.data
}>

<!--- Strip flat name/contact fields — structured data is in NAMES/ADDRESSES/DEGREES envelopes --->
<cfset stripFields = ["FIRSTNAME", "MIDDLENAME", "LASTNAME", "FULLNAME", "PREFERREDNAME", "MAIDENNAME", "EMAILPRIMARY", "PHONE", "OFFICE_MAILING_ADDRESS", "CURRENT_MAILING_ADDRESS", "ADDRESS"]>
<cfloop array="#payload.data#" item="personRow">
    <cfloop array="#stripFields#" item="fieldKey">
        <cfset structDelete(personRow, fieldKey)>
    </cfloop>
    <cfset personRow["SHOWCASED_PUBLICATIONS"] = publicationsService.getShowcasedPublications(val(personRow.USERID ?: 0)).data>
</cfloop>

<cfset auth.sendResponse(payload)>
<cfabort>
