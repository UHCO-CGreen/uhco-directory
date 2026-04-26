<!---
    Admin Roles — list, create, edit, delete roles.
    Permission: settings.admin_roles.manage.
--->

<cfif NOT request.hasPermission("settings.admin_roles.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset authSvc  = createObject("component", "cfc.adminAuth_service").init()>
<cfset roles    = authSvc.getAllRoles()>
<cfset allPermissions = authSvc.getAllPermissions()>
<cfset msgParam = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam = structKeyExists(url, "err") ? url.err : "">
<cfset editID   = (structKeyExists(url, "edit") AND isNumeric(url.edit)) ? val(url.edit) : 0>
<cfset editRole = editID GT 0 ? authSvc.getRoleByID(editID) : {}>
<cfset permissionCategoryOrder = []>
<cfset permissionsByCategory = {}>
<cfset rolePermissionsByID = {}>
<cfset rolePermissionLookupByID = {}>

<cfloop array="#allPermissions#" index="permissionItem">
    <cfset permissionCategory = lCase(trim(permissionItem.CATEGORY ?: "other"))>
    <cfif NOT structKeyExists(permissionsByCategory, permissionCategory)>
        <cfset permissionsByCategory[permissionCategory] = []>
        <cfset arrayAppend(permissionCategoryOrder, permissionCategory)>
    </cfif>
    <cfset arrayAppend(permissionsByCategory[permissionCategory], permissionItem)>
</cfloop>

<cfloop array="#roles#" index="roleRow">
    <cfset currentRolePermissions = authSvc.getPermissionsForRole(roleRow.ROLE_ID)>
    <cfset currentRolePermissionLookup = {}>
    <cfloop array="#currentRolePermissions#" index="permissionItem">
        <cfset currentRolePermissionLookup[toString(permissionItem.PERMISSION_ID)] = true>
    </cfloop>
    <cfset rolePermissionsByID[toString(roleRow.ROLE_ID)] = currentRolePermissions>
    <cfset rolePermissionLookupByID[toString(roleRow.ROLE_ID)] = currentRolePermissionLookup>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-admin-roles-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-users/">Admin Users</a></li>
        <li class="breadcrumb-item active">Roles</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-key me-2"></i>Admin Roles</h1>
<p class="text-muted">Create and manage roles plus the default permission bundles assigned to each role.</p>

<cfif len(msgParam)>
    <div class="alert alert-success alert-dismissible fade show mt-3">
        #encodeForHTML(msgParam)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>
<cfif len(errParam)>
    <div class="alert alert-danger alert-dismissible fade show mt-3">
        #encodeForHTML(errParam)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>

<!--- ── Create / Edit form ── --->
<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title">
            <cfif structCount(editRole)>
                <i class="bi bi-pencil me-2"></i>Edit Role
            <cfelse>
                <i class="bi bi-plus-circle me-2"></i>Create Role
            </cfif>
        </h5>
        <form method="post" action="/admin/settings/admin-roles/save.cfm" class="row g-3 align-items-end">
            <cfif structCount(editRole)>
                <input type="hidden" name="action" value="updateRole">
                <input type="hidden" name="roleID" value="#editRole.ROLE_ID#">
            <cfelse>
                <input type="hidden" name="action" value="createRole">
            </cfif>
            <div class="col-auto">
                <label class="form-label">Role Name</label>
                <input type="text" name="roleName" class="form-control text-uppercase"
                       value="#encodeForHTMLAttribute(structCount(editRole) ? editRole.ROLE_NAME : '')#"
                       placeholder="e.g. REPORT_ADMIN" required>
            </div>
            <div class="col-auto">
                <button type="submit" class="btn btn-primary">
                    <cfif structCount(editRole)>Update<cfelse>Create</cfif>
                </button>
                <cfif structCount(editRole)>
                    <a href="/admin/settings/admin-roles/" class="btn btn-outline-secondary">Cancel</a>
                </cfif>
            </div>
        </form>
    </div>
</div>

<cfif structCount(editRole)>
<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-sliders me-2"></i>Default Permissions for #encodeForHTML(editRole.ROLE_NAME)#</h5>
        <cfif editRole.ROLE_NAME EQ "SUPER_ADMIN">
            <div class="alert alert-light border mb-0">
                SUPER_ADMIN is still a code-level override. Default permission bundles are not used for this role.
            </div>
        <cfelseif arrayLen(allPermissions)>
            <cfset editRolePermissionLookup = structKeyExists(rolePermissionLookupByID, toString(editRole.ROLE_ID)) ? rolePermissionLookupByID[toString(editRole.ROLE_ID)] : {}>
            <form method="post" action="/admin/settings/admin-roles/save.cfm">
                <input type="hidden" name="action" value="saveRolePermissions">
                <input type="hidden" name="roleID" value="#editRole.ROLE_ID#">
                <div class="alert alert-light border small">
                    These permissions become the default set for users assigned to this role. User-specific direct permissions are managed separately on the Admin Users page.
                </div>
                <div class="row g-3">
                    <cfloop array="#permissionCategoryOrder#" index="permissionCategory">
                        <div class="col-md-6">
                            <div class="settings-category-card h-100">
                                <div class="fw-semibold text-capitalize mb-2">#encodeForHTML(permissionCategory)#</div>
                                <cfloop array="#permissionsByCategory[permissionCategory]#" index="permissionItem">
                                    <div class="form-check mb-2">
                                        <input class="form-check-input" type="checkbox" name="permissionIDs" value="#permissionItem.PERMISSION_ID#" id="role#editRole.ROLE_ID#permission#permissionItem.PERMISSION_ID#" <cfif structKeyExists(editRolePermissionLookup, toString(permissionItem.PERMISSION_ID))>checked</cfif>>
                                        <label class="form-check-label" for="role#editRole.ROLE_ID#permission#permissionItem.PERMISSION_ID#">
                                            <span class="fw-semibold small d-block">#encodeForHTML(permissionItem.DISPLAY_NAME)#</span>
                                            <span class="text-muted small">#encodeForHTML(permissionItem.PERMISSION_KEY)#</span>
                                        </label>
                                    </div>
                                </cfloop>
                            </div>
                        </div>
                    </cfloop>
                </div>
                <div class="mt-3">
                    <button type="submit" class="btn btn-primary">Save Default Permissions</button>
                </div>
            </form>
        <cfelse>
            <div class="text-muted fst-italic">No permissions are defined yet.</div>
        </cfif>
    </div>
</div>
</cfif>

<!--- ── Roles table ── --->
<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>All Roles</h5>
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Role Name</th>
                        <th>Default Permissions</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#roles#" index="r">
                    <cfset currentRolePermissions = structKeyExists(rolePermissionsByID, toString(r.ROLE_ID)) ? rolePermissionsByID[toString(r.ROLE_ID)] : []>
                    <tr>
                        <td>#r.ROLE_ID#</td>
                        <td><span class="badge bg-primary">#encodeForHTML(r.ROLE_NAME)#</span></td>
                        <td>
                            <span class="badge settings-badge-count me-1">#arrayLen(currentRolePermissions)# total</span>
                            <cfif arrayLen(currentRolePermissions)>
                                <cfloop from="1" to="#min(arrayLen(currentRolePermissions), 3)#" index="permissionIndex">
                                    <span class="badge border settings-badge-neutral me-1">#encodeForHTML(currentRolePermissions[permissionIndex].PERMISSION_KEY)#</span>
                                </cfloop>
                                <cfif arrayLen(currentRolePermissions) GT 3>
                                    <span class="text-muted small">+ #arrayLen(currentRolePermissions) - 3# more</span>
                                </cfif>
                            <cfelse>
                                <span class="text-muted fst-italic">None</span>
                            </cfif>
                        </td>
                        <td class="text-end">
                            <div class="settings-action-group">
                            <a href="/admin/settings/admin-roles/?edit=#r.ROLE_ID#" class="btn btn-sm btn-edit users-list-action-button users-list-action-button-edit" title="Edit Role" data-bs-toggle="tooltip" data-bs-title="Edit Role" aria-label="Edit Role">
                                <i class="bi bi-pencil-square"></i>
                            </a>
                            <cfif r.ROLE_NAME NEQ "SUPER_ADMIN">
                                <form method="post" action="/admin/settings/admin-roles/save.cfm" class="d-inline">
                                    <input type="hidden" name="action" value="deleteRole">
                                    <input type="hidden" name="roleID" value="#r.ROLE_ID#">
                                    <button type="submit" class="btn btn-sm btn-remove users-list-action-button users-list-action-button-delete" title="Delete Role" data-bs-toggle="tooltip" data-bs-title="Delete Role" aria-label="Delete Role"
                                            onclick="return confirm('Delete role #encodeForJavaScript(r.ROLE_NAME)#? This will remove it from all users.')">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                            <cfelse>
                                <button class="btn btn-sm btn-outline-secondary" disabled title="SUPER_ADMIN cannot be deleted">
                                    <i class="bi bi-lock"></i>
                                </button>
                            </cfif>
                            </div>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
    </div>
</div>

<div class="mt-3 d-flex flex-wrap gap-2">
    <a href="/admin/settings/admin-users/" class="btn btn-outline-secondary">
        <i class="bi bi-people me-1"></i>Back to Admin Users
    </a>
    <cfif request.hasPermission("settings.admin_permissions.manage")>
        <a href="/admin/settings/admin-permissions/" class="btn btn-outline-secondary">
            <i class="bi bi-sliders me-1"></i>Manage Permission Definitions
        </a>
    </cfif>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
