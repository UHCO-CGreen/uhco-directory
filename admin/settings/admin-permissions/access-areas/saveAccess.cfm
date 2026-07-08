<!---
    Access Areas — save handler (create / update / delete).
    POST only. Redirects back to index with msg or err param.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.admin_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST">
    <cflocation url="#request.webRoot#/admin/settings/admin-permissions/access-areas/" addtoken="false">
</cfif>

<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset action = lCase(trim(form.action ?: "create"))>
<cfset areaID = isNumeric(form.areaID ?: "") ? val(form.areaID) : 0>
<cfset accessName = trim(form.AccessName ?: "")>
<cfset redirectURL = request.webRoot & "/admin/settings/admin-permissions/access-areas/">

<cftry>
    <cfswitch expression="#action#">
        <cfcase value="create">
            <cfset result = accessService.createAccessArea(accessName)>
            <cfset redirectURL &= result.success ? "?msg=" & urlEncodedFormat(result.message) : "?err=" & urlEncodedFormat(result.message)>
        </cfcase>

        <cfcase value="update">
            <cfset result = accessService.updateAccessArea(areaID, accessName)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL = request.webRoot & "/admin/settings/admin-permissions/access-areas/edit.cfm?areaID=" & areaID & "&err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="delete">
            <cfset result = accessService.deleteAccessArea(areaID)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL = request.webRoot & "/admin/settings/admin-permissions/access-areas/delete.cfm?areaID=" & areaID & "&err=" & urlEncodedFormat(result.message)>
            </cfif>
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
