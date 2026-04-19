<!---
    Admin Roles — POST handler for create, update, delete.
    Permission: settings.admin_roles.manage.
--->

<cfif NOT request.hasPermission("settings.admin_roles.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset authSvc     = createObject("component", "cfc.adminAuth_service").init()>
<cfset action      = structKeyExists(form, "action") ? trim(form.action) : "">
<cfset redirectURL = "/admin/settings/admin-roles/">

<cftry>
    <cfswitch expression="#action#">

        <cfcase value="createRole">
            <cfset rn     = structKeyExists(form, "roleName") ? trim(form.roleName) : "">
            <cfset result = authSvc.createRole(rn)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="updateRole">
            <cfset rid    = structKeyExists(form, "roleID") AND isNumeric(form.roleID) ? val(form.roleID) : 0>
            <cfset rn     = structKeyExists(form, "roleName") ? trim(form.roleName) : "">
            <cfset result = authSvc.updateRole(rid, rn)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="saveRolePermissions">
            <cfset rid = structKeyExists(form, "roleID") AND isNumeric(form.roleID) ? val(form.roleID) : 0>
            <cfset permissionIDList = structKeyExists(form, "permissionIDs") ? form.permissionIDs : "">
            <cfset permissionIDs = []>
            <cfif isArray(permissionIDList)>
                <cfloop array="#permissionIDList#" index="permissionIDValue">
                    <cfif isNumeric(permissionIDValue) AND val(permissionIDValue) GT 0>
                        <cfset arrayAppend(permissionIDs, val(permissionIDValue))>
                    </cfif>
                </cfloop>
            <cfelseif len(trim(permissionIDList & ""))>
                <cfloop list="#permissionIDList#" delimiters="," index="permissionIDValue">
                    <cfif isNumeric(permissionIDValue) AND val(permissionIDValue) GT 0>
                        <cfset arrayAppend(permissionIDs, val(permissionIDValue))>
                    </cfif>
                </cfloop>
            </cfif>
            <cfset result = authSvc.saveRolePermissions(rid, permissionIDs)>
            <cfif result.success>
                <cfset application.authService.reloadAuthorization()>
                <cfset redirectURL &= "?edit=" & rid & "&msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?edit=" & rid & "&err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="deleteRole">
            <cfset rid    = structKeyExists(form, "roleID") AND isNumeric(form.roleID) ? val(form.roleID) : 0>
            <cfset result = authSvc.deleteRole(rid)>
            <cfif result.success>
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
