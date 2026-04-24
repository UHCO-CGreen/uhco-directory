<cfsetting showdebugoutput="false">
<cfcontent type="application/json" reset="true">

<cfif NOT request.hasPermission("users.edit")>
    <cfoutput>#serializeJSON({ success=false, message="Unauthorized: users.edit permission required.", data=[] })#</cfoutput>
    <cfabort>
</cfif>

<cfset term = trim((form.searchTerm ?: url.searchTerm ?: "") & "")>
<cfset userType = lCase(trim((form.userType ?: url.userType ?: "") & ""))>
<cfset userID = val((form.userID ?: url.userID ?: 0) & "")>
<cfset maxRows = val((form.maxRows ?: url.maxRows ?: 25) & "")>

<cfif len(term) LT 2>
    <cfoutput>#serializeJSON({ success=false, message="Enter at least 2 characters.", data=[] })#</cfoutput>
    <cfabort>
</cfif>

<cfif maxRows LTE 0>
    <cfset maxRows = 25>
</cfif>

<cftry>
    <cfset ldapLookupService = createObject("component", "cfc.ldapLookup_simple_service").init()>
    <cfset result = ldapLookupService.searchCandidates(
        searchTerm = term,
        userType = userType,
        userID = userID,
        maxRows = maxRows
    )>

    <cfoutput>#serializeJSON(result)#</cfoutput>

    <cfcatch type="any">
        <cflog
            file="ldap-lookup"
            type="error"
            text="Cougarnet lookup failed. term=#left(term, 80)# userID=#userID# userType=#userType# message=#cfcatch.message# detail=#cfcatch.detail#"
        >
        <cfoutput>#serializeJSON({
            success = false,
            message = "Directory lookup failed. Please try again or contact support if the problem continues.",
            data = [],
            _debug = {
                message: cfcatch.message,
                detail: cfcatch.detail,
                type: cfcatch.type
            }
        })#</cfoutput>
    </cfcatch>
</cftry>
