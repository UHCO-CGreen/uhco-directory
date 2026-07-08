<!---
    Admin Permissions — create, edit, delete permission definitions.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("admin-permissions")>

<cfset authSvc = createObject("component", "cfc.adminAuth_service").init()>
<cfset permissions = authSvc.getAllPermissions()>
<cfset roles = authSvc.getAllRoles()>
<cfset msgParam = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam = structKeyExists(url, "err") ? url.err : "">
<cfset editID = (structKeyExists(url, "edit") AND isNumeric(url.edit)) ? val(url.edit) : 0>
<cfset editPermission = editID GT 0 ? authSvc.getPermissionByID(editID) : {}>
<cfset selectedRoleID = (structKeyExists(url, "role") AND isNumeric(url.role)) ? val(url.role) : 0>
<cfset rolePermissions = arrayNew(1)>
<cfif selectedRoleID GT 0>
    <cfset selectedRole = authSvc.getRoleByID(selectedRoleID)>
    <cfif structCount(selectedRole)>
        <cfset rolePermissions = authSvc.getPermissionsForRole(selectedRoleID)>
        <cfset permissionsToDisplay = arrayNew(1)>
        <cfloop array="#permissions#" index="p">
            <cfset inRole = false>
            <cfloop array="#rolePermissions#" index="rp">
                <cfif rp.PERMISSION_ID EQ p.PERMISSION_ID>
                    <cfset inRole = true>
                    <cfbreak>
                </cfif>
            </cfloop>
            <cfif inRole>
                <cfset arrayAppend(permissionsToDisplay, p)>
            </cfif>
        </cfloop>
        <cfset permissions = permissionsToDisplay>
    </cfif>
</cfif>

<!--- Sort params --->
<cfset allowedPermSortCols = ["PERMISSION_KEY","DISPLAY_NAME","CATEGORY","IS_ACTIVE","IS_SYSTEM"]>
<cfset sortCol = (structKeyExists(url, "sortCol") AND arrayFindNoCase(allowedPermSortCols, url.sortCol) GT 0) ? url.sortCol : "PERMISSION_KEY">
<cfset sortDir = ((url.sortDir ?: "") EQ "DESC") ? "DESC" : "ASC">
<cfset baseSortParams = selectedRoleID GT 0 ? "&role=" & selectedRoleID : "">
<cfscript>
    arraySort(permissions, function(a, b) {
        var aVal = lCase(toString(isNull(a[sortCol]) ? "" : a[sortCol]));
        var bVal = lCase(toString(isNull(b[sortCol]) ? "" : b[sortCol]));
        if (aVal LT bVal) return sortDir EQ "ASC" ? -1 : 1;
        if (aVal GT bVal) return sortDir EQ "ASC" ? 1 : -1;
        return 0;
    });
    function permSortLink(col) {
        var dir = (sortCol EQ col AND sortDir EQ "ASC") ? "DESC" : "ASC";
        return "?sortCol=" & col & "&sortDir=" & dir & baseSortParams;
    }
    function permSortArrow(col) {
        if (sortCol EQ col) return sortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
</cfscript>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-admin-permissions-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-users/">Admin Users</a></li>
        <li class="breadcrumb-item active">Permissions</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-sliders me-2"></i>Admin Permissions</h1>
<p class="text-muted">Create custom permissions, edit display metadata, and retire old permissions. System permission keys are used by page guards and cannot be deleted.</p>
<cfif len(sectionStatus)>
    <div class="mb-3">
        <span class="badge bg-warning text-dark">Currently in: #sectionStatus#</span>
    </div>
</cfif>


<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title">
            <cfif structCount(editPermission)>
                <i class="bi bi-pencil me-2"></i>Edit Permission
            <cfelse>
                <i class="bi bi-plus-circle me-2"></i>Create Permission
            </cfif>
        </h5>
        <form method="post" action="/admin/settings/admin-permissions/save.cfm" class="row g-3">
            <cfif structCount(editPermission)>
                <input type="hidden" name="action" value="updatePermission">
                <input type="hidden" name="permissionID" value="#editPermission.PERMISSION_ID#">
            <cfelse>
                <input type="hidden" name="action" value="createPermission">
            </cfif>

            <div class="col-md-4">
                <label class="form-label">Permission Key</label>
                <input type="text" name="permissionKey" class="form-control" value="#encodeForHTMLAttribute(structCount(editPermission) ? editPermission.PERMISSION_KEY : '')#" placeholder="e.g. reports.view" required <cfif structCount(editPermission) AND val(editPermission.IS_SYSTEM) EQ 1>readonly</cfif>>
                <div class="form-text">Use lowercase with periods, for example <span class="font-monospace">reports.view</span>.</div>
            </div>
            <div class="col-md-4">
                <label class="form-label">Display Name</label>
                <input type="text" name="displayName" class="form-control" value="#encodeForHTMLAttribute(structCount(editPermission) ? editPermission.DISPLAY_NAME : '')#" placeholder="e.g. View Reports" required>
            </div>
            <div class="col-md-4">
                <label class="form-label">Category</label>
                <input type="text" name="category" class="form-control" value="#encodeForHTMLAttribute(structCount(editPermission) ? editPermission.CATEGORY : '')#" placeholder="e.g. reports" required>
            </div>
            <div class="col-md-8">
                <label class="form-label">Description</label>
                <input type="text" name="description" class="form-control" value="#encodeForHTMLAttribute(structCount(editPermission) ? (editPermission.DESCRIPTION ?: '') : '')#" placeholder="What does this permission allow?">
            </div>
            <div class="col-md-2">
                <label class="form-label">Sort Order</label>
                <input type="number" name="sortOrder" class="form-control" value="#structCount(editPermission) ? val(editPermission.SORT_ORDER) : 0#">
            </div>
            <div class="col-md-2 d-flex align-items-end">
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" name="isActive" id="isActive" value="1" <cfif NOT structCount(editPermission) OR val(editPermission.IS_ACTIVE) EQ 1>checked</cfif>>
                    <label class="form-check-label" for="isActive">Active</label>
                </div>
            </div>
            <div class="col-12">
                <button type="submit" class="btn <cfif structCount(editPermission)>btn-ui-save<cfelse>btn-ui-add</cfif>">
                    <cfif structCount(editPermission)>Update<cfelse>Create</cfif>
                </button>
                <cfif structCount(editPermission)>
                    <a href="/admin/settings/admin-permissions/" class="btn btn-ui-cancel">Cancel</a>
                </cfif>
            </div>
        </form>
    </div>
</div>

<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>All Permissions</h5>
        
        <div class="mb-3 d-flex gap-2 align-items-end">
            <div style="flex: 1;">
                <label for="roleFilter" class="form-label">Filter by Role</label>
                <select id="roleFilter" class="form-select" data-navigate-on-change data-navigate-base="/admin/settings/admin-permissions/" data-navigate-param="role">
                    <option value="">All Permissions</option>
                    <cfloop array="#roles#" index="role">
                        <cfif role.ROLE_NAME NEQ "SUPER_ADMIN">
                            <option value="#role.ROLE_ID#" <cfif selectedRoleID EQ role.ROLE_ID>selected</cfif>>#encodeForHTML(role.ROLE_NAME)#</option>
                        </cfif>
                    </cfloop>
                </select>
                <div class="form-text">Select a role to see only its assigned permissions.</div>
            </div>
            <cfif selectedRoleID GT 0>
                <div>
                    <span class="badge bg-info">#arrayLen(permissions)# permission<cfif arrayLen(permissions) NEQ 1>s</cfif></span>
                </div>
            </cfif>
        </div>
        
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th><a href="#permSortLink('PERMISSION_KEY')#" class="settings-sort-link">#encodeForHTML('Key')##permSortArrow('PERMISSION_KEY')#</a></th>
                        <th><a href="#permSortLink('DISPLAY_NAME')#" class="settings-sort-link">Display Name#permSortArrow('DISPLAY_NAME')#</a></th>
                        <th><a href="#permSortLink('CATEGORY')#" class="settings-sort-link">Category#permSortArrow('CATEGORY')#</a></th>
                        <th><a href="#permSortLink('IS_ACTIVE')#" class="settings-sort-link">Status#permSortArrow('IS_ACTIVE')#</a></th>
                        <th><a href="#permSortLink('IS_SYSTEM')#" class="settings-sort-link">Type#permSortArrow('IS_SYSTEM')#</a></th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#permissions#" index="permissionRow">
                    <tr>
                        <td><code>#encodeForHTML(permissionRow.PERMISSION_KEY)#</code></td>
                        <td>
                            <div class="fw-semibold">#encodeForHTML(permissionRow.DISPLAY_NAME)#</div>
                            <cfif len(trim(permissionRow.DESCRIPTION ?: ''))>
                                <div class="text-muted small">#encodeForHTML(permissionRow.DESCRIPTION)#</div>
                            </cfif>
                        </td>
                        <td><span class="badge border settings-badge-neutral">#encodeForHTML(permissionRow.CATEGORY)#</span></td>
                        <td>
                            <cfif val(permissionRow.IS_ACTIVE) EQ 1>
                                <span class="badge settings-badge-active">Active</span>
                            <cfelse>
                                <span class="badge bg-secondary text-dark">Inactive</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif val(permissionRow.IS_SYSTEM) EQ 1>
                                <span class="badge bg-warning text-dark">System</span>
                            <cfelse>
                                <span class="badge settings-badge-custom">Custom</span>
                            </cfif>
                        </td>
                        <td class="text-end">
                            <div class="settings-action-group">
                            <a href="/admin/settings/admin-permissions/?edit=#permissionRow.PERMISSION_ID#" class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit" title="Edit Permission" data-bs-toggle="tooltip" data-bs-title="Edit Permission" aria-label="Edit Permission">
                                <i class="bi bi-pencil-square"></i>
                            </a>
                            <cfif val(permissionRow.IS_SYSTEM) EQ 0>
                                <form method="post" action="/admin/settings/admin-permissions/save.cfm" class="d-inline">
                                    <input type="hidden" name="action" value="deletePermission">
                                    <input type="hidden" name="permissionID" value="#permissionRow.PERMISSION_ID#">
                                    <button type="submit" class="btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete" title="Delete Permission" data-bs-toggle="tooltip" data-bs-title="Delete Permission" aria-label="Delete Permission" data-confirm="Delete permission #encodeForJavaScript(permissionRow.PERMISSION_KEY)#?">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                            <cfelse>
                                <button class="btn btn-sm btn-ui-cancel" disabled title="System permissions cannot be deleted">
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

<div class="card mt-4 settings-shell settings-reference-card">
    <div class="card-body">
        <h5 class="mb-1"><i class="bi bi-key me-2"></i>Access Areas</h5>
        <p class="text-muted small mb-2">Manage the permission strings (e.g. <code>module.action</code>) that can be granted to identity users via User Permissions.</p>
        <a href="/admin/settings/admin-permissions/access-areas/" class="btn btn-sm btn-ui-go">
            <i class="bi bi-arrow-right-circle me-1"></i>Manage Access Areas
        </a>
    </div>
</div>

<div class="mt-3 d-flex flex-wrap gap-2">
    <a href="/admin/settings/admin-users/" class="btn btn-ui-go">
        <i class="bi bi-people me-1"></i>Back to Admin Users
    </a>
    <a href="/admin/settings/admin-roles/" class="btn btn-ui-go">
        <i class="bi bi-key me-1"></i>Manage Roles
    </a>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif len(msgParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(msgParam)#", { tone: 'success' });
}
</cfif>
<cfif len(errParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'danger' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">