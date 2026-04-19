<!---
    Admin Users — POST handler for add, toggle active, assign/revoke role.
    Permission: settings.admin_users.manage.
--->

<cfset action  = structKeyExists(form, "action") ? trim(form.action) : "">
<cfset isImpersonationAction = listFindNoCase("startImpersonationRole,startImpersonationPermissions,clearImpersonation", action) GT 0>
<cfset currentAdminUserID = (structKeyExists(session, "user") AND structKeyExists(session.user, "adminUserID") AND isNumeric(session.user.adminUserID)) ? val(session.user.adminUserID) : 0>

<cfif NOT request.hasPermission("settings.admin_users.manage") AND NOT (isImpersonationAction AND application.authService.isActualSuperAdmin())>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset authSvc = createObject("component", "cfc.adminAuth_service").init()>
<cfset redirectURL = "/admin/settings/admin-users/">

<cftry>
    <cfswitch expression="#action#">

        <cfcase value="addUser">
            <cfset cn     = structKeyExists(form, "cougarnet") ? trim(form.cougarnet) : "">
            <cfset result = authSvc.addUser(cn)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="toggleActive">
            <cfset uid    = structKeyExists(form, "userID") AND isNumeric(form.userID) ? val(form.userID) : 0>
            <cfset result = authSvc.toggleUserActive(uid)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="assignRole">
            <cfset uid = structKeyExists(form, "userID") AND isNumeric(form.userID) ? val(form.userID) : 0>
            <cfset rid = structKeyExists(form, "roleID") AND isNumeric(form.roleID) ? val(form.roleID) : 0>
            <cfset result = authSvc.assignRole(uid, rid)>
            <cfif result.success>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="revokeRole">
            <cfset uid = structKeyExists(form, "userID") AND isNumeric(form.userID) ? val(form.userID) : 0>
            <cfset rid = structKeyExists(form, "roleID") AND isNumeric(form.roleID) ? val(form.roleID) : 0>
            <cfset result = authSvc.revokeRole(uid, rid)>
            <cfif result.success>
                <cfif currentAdminUserID EQ uid>
                    <cfset application.authService.reloadAuthorization(uid)>
                </cfif>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="saveUserPermissions">
            <cfset uid = structKeyExists(form, "userID") AND isNumeric(form.userID) ? val(form.userID) : 0>
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
            <cfset result = authSvc.saveUserDirectPermissions(uid, permissionIDs, currentAdminUserID)>
            <cfif result.success>
                <cfif currentAdminUserID EQ uid>
                    <cfset application.authService.reloadAuthorization(uid)>
                </cfif>
                <cfset redirectURL &= "?msg=" & urlEncodedFormat(result.message)>
            <cfelse>
                <cfset redirectURL &= "?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="startImpersonationRole">
            <cfset rid = structKeyExists(form, "impersonationRoleID") AND isNumeric(form.impersonationRoleID) ? val(form.impersonationRoleID) : 0>
            <cfset result = application.authService.startRoleImpersonation(rid)>
            <cfset redirectURL = structKeyExists(form, "returnURL") AND len(trim(form.returnURL)) ? trim(form.returnURL) : "/admin/dashboard.cfm">
            <cfif NOT result.success>
                <cfset redirectURL = "/admin/settings/admin-users/?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="startImpersonationPermissions">
            <cfset permissionIDList = structKeyExists(form, "impersonationPermissionIDs") ? trim(form.impersonationPermissionIDs) : "">
            <cfset permissionIDs = []>
            <cfif len(permissionIDList)>
                <cfloop list="#permissionIDList#" delimiters="," index="permissionIDValue">
                    <cfif isNumeric(permissionIDValue) AND val(permissionIDValue) GT 0>
                        <cfset arrayAppend(permissionIDs, val(permissionIDValue))>
                    </cfif>
                </cfloop>
            </cfif>
            <cfset result = application.authService.startPermissionImpersonation(permissionIDs)>
            <cfset redirectURL = structKeyExists(form, "returnURL") AND len(trim(form.returnURL)) ? trim(form.returnURL) : "/admin/dashboard.cfm">
            <cfif NOT result.success>
                <cfset redirectURL = "/admin/settings/admin-users/?err=" & urlEncodedFormat(result.message)>
            </cfif>
        </cfcase>

        <cfcase value="clearImpersonation">
            <cfset application.authService.clearImpersonation()>
            <cfset redirectURL = structKeyExists(form, "returnURL") AND len(trim(form.returnURL)) ? trim(form.returnURL) : "/admin/settings/admin-users/?msg=" & urlEncodedFormat("Impersonation cleared.")>
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
