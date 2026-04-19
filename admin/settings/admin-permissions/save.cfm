<!---
    Admin Permissions — POST handler for create, update, delete.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.admin_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset authSvc = createObject("component", "cfc.adminAuth_service").init()>
<cfset action = structKeyExists(form, "action") ? trim(form.action) : "">
<cfset redirectURL = "/admin/settings/admin-permissions/">

<cftry>
    <cfswitch expression="#action#">

        <cfcase value="createPermission">
            <cfset result = authSvc.createPermission(
                permissionKey = structKeyExists(form, "permissionKey") ? trim(form.permissionKey) : "",
                displayName = structKeyExists(form, "displayName") ? trim(form.displayName) : "",
                category = structKeyExists(form, "category") ? trim(form.category) : "",
                description = structKeyExists(form, "description") ? trim(form.description) : "",
                sortOrder = structKeyExists(form, "sortOrder") AND isNumeric(form.sortOrder) ? val(form.sortOrder) : 0,
                isActive = structKeyExists(form, "isActive")
            )>
            <cfif result.success>
                <cfset application.authService.reloadAuthorization()>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="updatePermission">
            <cfset permissionID = structKeyExists(form, "permissionID") AND isNumeric(form.permissionID) ? val(form.permissionID) : 0>
            <cfset result = authSvc.updatePermission(
                permissionID = permissionID,
                permissionKey = structKeyExists(form, "permissionKey") ? trim(form.permissionKey) : "",
                displayName = structKeyExists(form, "displayName") ? trim(form.displayName) : "",
                category = structKeyExists(form, "category") ? trim(form.category) : "",
                description = structKeyExists(form, "description") ? trim(form.description) : "",
                sortOrder = structKeyExists(form, "sortOrder") AND isNumeric(form.sortOrder) ? val(form.sortOrder) : 0,
                isActive = structKeyExists(form, "isActive")
            )>
            <cfif result.success>
                <cfset application.authService.reloadAuthorization()>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?edit=" & permissionID & "&err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="deletePermission">
            <cfset permissionID = structKeyExists(form, "permissionID") AND isNumeric(form.permissionID) ? val(form.permissionID) : 0>
            <cfset result = authSvc.deletePermission(permissionID)>
            <cfif result.success>
                <cfset application.authService.reloadAuthorization()>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfdefaultcase>
            <cfset redirectURL &= "?err=" & urlEncodedFormat("Unknown action.")>
        </cfdefaultcase>

    </cfswitch>
<cfcatch type="any">
    <cfset redirectURL &= "?err=" & urlEncodedFormat(cfcatch.message)>
</cfcatch>
</cftry>

<cflocation url="#redirectURL#" addtoken="false">