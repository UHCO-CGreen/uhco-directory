<!---
    Admin Permissions — create, edit, delete permission definitions.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.admin_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset authSvc = createObject("component", "cfc.adminAuth_service").init()>
<cfset permissions = authSvc.getAllPermissions()>
<cfset msgParam = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam = structKeyExists(url, "err") ? url.err : "">
<cfset editID = (structKeyExists(url, "edit") AND isNumeric(url.edit)) ? val(url.edit) : 0>
<cfset editPermission = editID GT 0 ? authSvc.getPermissionByID(editID) : {}>

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
                <button type="submit" class="btn btn-primary">
                    <cfif structCount(editPermission)>Update<cfelse>Create</cfif>
                </button>
                <cfif structCount(editPermission)>
                    <a href="/admin/settings/admin-permissions/" class="btn btn-outline-secondary">Cancel</a>
                </cfif>
            </div>
        </form>
    </div>
</div>

<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>All Permissions</h5>
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>Key</th>
                        <th>Display Name</th>
                        <th>Category</th>
                        <th>Status</th>
                        <th>Type</th>
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
                                <span class="badge bg-secondary">Inactive</span>
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
                            <a href="/admin/settings/admin-permissions/?edit=#permissionRow.PERMISSION_ID#" class="btn btn-sm btn-info users-list-action-button users-list-action-button-edit" title="Edit Permission" data-bs-toggle="tooltip" data-bs-title="Edit Permission" aria-label="Edit Permission">
                                <i class="bi bi-pencil-square"></i>
                            </a>
                            <cfif val(permissionRow.IS_SYSTEM) EQ 0>
                                <form method="post" action="/admin/settings/admin-permissions/save.cfm" class="d-inline">
                                    <input type="hidden" name="action" value="deletePermission">
                                    <input type="hidden" name="permissionID" value="#permissionRow.PERMISSION_ID#">
                                    <button type="submit" class="btn btn-sm btn-danger users-list-action-button users-list-action-button-delete" title="Delete Permission" data-bs-toggle="tooltip" data-bs-title="Delete Permission" aria-label="Delete Permission" onclick="return confirm('Delete permission #encodeForJavaScript(permissionRow.PERMISSION_KEY)#?')">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                            <cfelse>
                                <button class="btn btn-sm btn-outline-secondary" disabled title="System permissions cannot be deleted">
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
    <a href="/admin/settings/admin-roles/" class="btn btn-outline-secondary">
        <i class="bi bi-key me-1"></i>Manage Roles
    </a>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">