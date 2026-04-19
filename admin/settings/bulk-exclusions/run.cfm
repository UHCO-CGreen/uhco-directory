<!---
    Bulk Exclusions — POST handler for manual runs (single type or ALL).
    Permission: settings.bulk_exclusions.manage.
--->

<cfif NOT request.hasPermission("settings.bulk_exclusions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfsetting requesttimeout="900">

<cfset svc         = createObject("component", "cfc.bulkExclusions_service").init()>
<cfset typeKey     = structKeyExists(form, "typeKey") ? trim(form.typeKey) : "">
<cfset redirectURL = "/admin/settings/bulk-exclusions/">

<cftry>
    <cfif typeKey EQ "ALL">
        <cfset result = svc.runAll("manual")>
        <cfif result.success>
            <cfset redirectURL &= "?msg=" & urlEncodedFormat("All exclusions ran successfully. Total rows inserted: " & result.totalRows)>
        <cfelse>
            <cfset msgs = []>
            <cfloop array="#result.results#" index="r">
                <cfif NOT r.success>
                    <cfset arrayAppend(msgs, r.key & ": " & r.message)>
                </cfif>
            </cfloop>
            <cfset redirectURL &= "?err=" & urlEncodedFormat("Some exclusions failed: " & arrayToList(msgs, "; ") & " | Total rows inserted: " & result.totalRows)>
        </cfif>
    <cfelseif len(typeKey)>
        <cfset result = svc.runByType(typeKey, "manual")>
        <cfif result.success>
            <cfset redirectURL &= "?msg=" & urlEncodedFormat(typeKey & ": " & result.message)>
        <cfelse>
            <cfset redirectURL &= "?err=" & urlEncodedFormat(typeKey & ": " & result.message)>
        </cfif>
    <cfelse>
        <cfset redirectURL &= "?err=" & urlEncodedFormat("No exclusion type specified.")>
    </cfif>

<cfcatch type="any">
    <cfset redirectURL &= "?err=" & urlEncodedFormat(cfcatch.message)>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">
