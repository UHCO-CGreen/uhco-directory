<!---
    CORS Whitelist — origin save handler (create / update / delete).
    POST only. Redirects back to index with msg or err param.
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST">
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/" addtoken="false">
</cfif>

<cfset corsService = createObject("component", "cfc.cors_service").init()>
<cfset action = lCase(trim(form.action ?: "create"))>
<cfset originID = isNumeric(form.OriginID ?: "") ? val(form.OriginID) : 0>
<cfset originPattern = trim(form.OriginPattern ?: "")>
<cfset matchType = trim(form.MatchType ?: "exact")>
<cfset description = trim(form.Description ?: "")>
<cfset isActive = structKeyExists(form, "IsActive")>
<cfset redirectURL = request.webRoot & "/admin/settings/uhco-api/cors/">

<cftry>
    <cfswitch expression="#action#">
        <cfcase value="create">
            <cfset result = corsService.createOrigin(originPattern, matchType, description)>
            <cfset redirectURL &= result.success ? "?msg=" & urlEncodedFormat(result.message) : "?err=" & urlEncodedFormat(result.message)>
        </cfcase>

        <cfcase value="update">
            <cfset result = corsService.updateOrigin(originID, originPattern, matchType, description, isActive)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL = request.webRoot & "/admin/settings/uhco-api/cors/edit-origin.cfm?originID=" & originID & "&err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="delete">
            <cfset result = corsService.deleteOrigin(originID)>
            <cfset redirectURL &= result.success ? "?msg=" & urlEncodedFormat(result.message) : "?err=" & urlEncodedFormat(result.message)>
        </cfcase>

        <cfdefaultcase>
            <cfset redirectURL &= "?err=" & urlEncodedFormat("Unknown action.")>
        </cfdefaultcase>
    </cfswitch>
<cfcatch type="any">
    <cfset redirectURL &= find("?", redirectURL) ? "&err=" & urlEncodedFormat(cfcatch.message) : "?err=" & urlEncodedFormat(cfcatch.message)>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">
