<!---
    User Permissions — save action (grant / revoke).
    POST only. Redirects back to index with msg or err param.
    Permission: settings.user_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.user_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST">
    <cflocation url="#request.webRoot#/admin/settings/user-permissions/" addtoken="false">
</cfif>

<cfset action = lCase(trim(form.action ?: ""))>
<cfset userID = isNumeric(form.userID ?: "") AND val(form.userID) GT 0 ? int(val(form.userID)) : 0>
<cfset returnTo = trim(form.returnTo ?: "")>
<cfset returnToParam = len(returnTo) ? "&returnTo=" & encodeForURL(returnTo) : "">

<cfif NOT userID>
    <cflocation url="#request.webRoot#/admin/settings/user-permissions/?err=#encodeForURL('Invalid user ID.')#" addtoken="false">
</cfif>

<cfset accessService = createObject("component", "cfc.access_service").init()>

<cftry>
    <cfif action EQ "grant">

        <cfset areaID = isNumeric(form.areaID ?: "") AND val(form.areaID) GT 0 ? int(val(form.areaID)) : 0>
        <cfif NOT areaID>
            <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&err=#encodeForURL('Invalid permission selection.')#" addtoken="false">
        </cfif>
        <cfset grantedBy = isNumeric(session.auth.userID ?: "") ? int(val(session.auth.userID)) : 0>
        <cfset accessService.grantAccess(userID, areaID, grantedBy)>
        <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&msg=#encodeForURL('Permission granted.')#" addtoken="false">

    <cfelseif action EQ "revoke">

        <!--- Look up areaID from the permission string for a clean UX (form posts permission name) --->
        <cfset permName = trim(form.permission ?: "")>
        <cfif NOT len(permName)>
            <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&err=#encodeForURL('Invalid permission name.')#" addtoken="false">
        </cfif>
        <cfset allAreas = accessService.getAccessAreas().data>
        <cfset areaID   = 0>
        <cfloop array="#allAreas#" index="area">
            <cfif area.ACCESSNAME EQ permName>
                <cfset areaID = area.ACCESSAREAID>
                <cfbreak>
            </cfif>
        </cfloop>
        <cfif NOT areaID>
            <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&err=#encodeForURL('Permission not found: #permName#')#" addtoken="false">
        </cfif>
        <cfset accessService.revokeAccess(userID, areaID)>
        <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&msg=#encodeForURL('Permission revoked.')#" addtoken="false">

    <cfelse>
        <cflocation url="#request.webRoot#/admin/settings/user-permissions/?err=#encodeForURL('Unknown action.')#" addtoken="false">
    </cfif>

<cfcatch type="any">
    <cflocation url="#request.webRoot#/admin/settings/user-permissions/?userID=#userID##returnToParam#&err=#encodeForURL(cfcatch.message)#" addtoken="false">
</cfcatch>
</cftry>
