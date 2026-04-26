<!---
    Admin Users — list, add, toggle active, manage role assignments.
    Permission: settings.admin_users.manage.
--->

<!--- ── Auth guard ── --->
<cfif NOT request.hasPermission("settings.admin_users.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Load service & data ── --->
<cfset authSvc   = createObject("component", "cfc.adminAuth_service").init()>
<cfset users     = authSvc.getAllUsers()>
<cfset allRoles  = authSvc.getAllRoles()>
<cfset allPermissions = authSvc.getAllPermissions()>
<cfset msgParam  = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam  = structKeyExists(url, "err") ? url.err : "">
<cfset currentImpersonation = application.authService.getImpersonationState()>
<cfset permissionCategoryOrder = []>
<cfset permissionsByCategory = {}>
<cfset userDirectPermissionsByID = {}>
<cfset userDirectPermissionLookupByID = {}>
<cfset userEffectivePermissionsByID = {}>
<cfset roleDefaultPermissionIDsByRoleID = {}>

<cfloop array="#allPermissions#" index="permissionItem">
    <cfset permissionCategory = lCase(trim(permissionItem.CATEGORY ?: "other"))>
    <cfif NOT structKeyExists(permissionsByCategory, permissionCategory)>
        <cfset permissionsByCategory[permissionCategory] = []>
        <cfset arrayAppend(permissionCategoryOrder, permissionCategory)>
    </cfif>
    <cfset arrayAppend(permissionsByCategory[permissionCategory], permissionItem)>
</cfloop>

<cfloop array="#allRoles#" index="roleRow">
    <cfset rolePermissionRows = authSvc.getPermissionsForRole(roleRow.ROLE_ID)>
    <cfset defaultPermissionIDs = []>
    <cfloop array="#rolePermissionRows#" index="rolePermissionRow">
        <cfif structKeyExists(rolePermissionRow, "PERMISSION_ID") AND isNumeric(rolePermissionRow.PERMISSION_ID)>
            <cfset arrayAppend(defaultPermissionIDs, val(rolePermissionRow.PERMISSION_ID))>
        </cfif>
    </cfloop>
    <cfset roleDefaultPermissionIDsByRoleID[toString(roleRow.ROLE_ID)] = defaultPermissionIDs>
</cfloop>

<cfloop array="#users#" index="adminUserRow">
    <cfset directPermissions = authSvc.getDirectPermissionsForUser(adminUserRow.USER_ID)>
    <cfset effectivePermissions = authSvc.getEffectivePermissionsForUser(adminUserRow.USER_ID)>
    <cfset directPermissionLookup = {}>
    <cfloop array="#directPermissions#" index="permissionItem">
        <cfset directPermissionLookup[toString(permissionItem.PERMISSION_ID)] = true>
    </cfloop>
    <cfset userDirectPermissionsByID[toString(adminUserRow.USER_ID)] = directPermissions>
    <cfset userDirectPermissionLookupByID[toString(adminUserRow.USER_ID)] = directPermissionLookup>
    <cfset userEffectivePermissionsByID[toString(adminUserRow.USER_ID)] = effectivePermissions>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-admin-users-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Admin Users</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-shield-lock me-2"></i>Admin Users, Roles &amp; Permissions</h1>
<p class="text-muted">Manage who can access the admin panel, their role assignments, and any direct permission overrides.</p>

<!--- Status messages --->
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

<cfif request.isActualSuperAdmin()>
<div class="card border-0 shadow-sm mt-3 mb-4 border-start border-4 border-warning settings-shell">
    <div class="card-body">
        <div class="d-flex justify-content-between align-items-start gap-3 flex-wrap">
            <div>
                <h5 class="mb-1"><i class="bi bi-person-badge me-2"></i>Permission Impersonation</h5>
                <p class="text-muted mb-0">Temporarily impersonate a lower role or a custom permission set without switching LDAP accounts.</p>
            </div>
            <div class="d-flex gap-2 align-items-center">
                <button class="btn btn-sm btn-outline-warning" type="button" data-bs-toggle="collapse" data-bs-target="##impersonationPanel" aria-expanded="<cfif structCount(currentImpersonation)>true<cfelse>false</cfif>">
                    <i class="bi bi-chevron-down me-1"></i>Toggle Panel
                </button>
                <cfif structCount(currentImpersonation)>
                    <form method="post" action="/admin/settings/admin-users/save.cfm" class="d-inline">
                        <input type="hidden" name="action" value="clearImpersonation">
                        <input type="hidden" name="returnURL" value="/admin/settings/admin-users/?msg=#urlEncodedFormat('Impersonation cleared.')#">
                        <button type="submit" class="btn btn-sm btn-outline-danger">
                            <i class="bi bi-x-octagon me-1"></i>Stop Impersonating
                        </button>
                    </form>
                </cfif>
            </div>
        </div>

        <div class="collapse<cfif structCount(currentImpersonation)> show</cfif>" id="impersonationPanel">
        <cfif structCount(currentImpersonation)>
            <div class="alert alert-warning mt-3 mb-0">
                Currently impersonating <strong>#encodeForHTML(currentImpersonation.label ?: '')#</strong>.
            </div>
        </cfif>

        <div class="mt-3">
            <form method="post" action="/admin/settings/admin-users/save.cfm" id="impersonationForm">
                <input type="hidden" name="action" value="startImpersonation">
                <input type="hidden" name="returnURL" value="/admin/dashboard.cfm">

                <div class="row g-3 align-items-end mb-3">
                    <div class="col-md-6 col-lg-4">
                        <label class="form-label fw-semibold" for="impersonationRoleID">Role <span class="text-danger">*</span></label>
                        <select name="impersonationRoleID" id="impersonationRoleID" class="form-select" required>
                            <option value="">Select a role&hellip;</option>
                            <cfloop array="#allRoles#" index="role">
                                <cfif role.ROLE_NAME NEQ "SUPER_ADMIN">
                                    <cfset roleDefaultPermissionIDs = structKeyExists(roleDefaultPermissionIDsByRoleID, toString(role.ROLE_ID)) ? roleDefaultPermissionIDsByRoleID[toString(role.ROLE_ID)] : []>
                                    <option value="#role.ROLE_ID#" data-default-permissions="#encodeForHTMLAttribute(arrayToList(roleDefaultPermissionIDs, ','))#">#encodeForHTML(role.ROLE_NAME)#</option>
                                </cfif>
                            </cfloop>
                        </select>
                    </div>
                    <div class="col-md-auto">
                        <button type="submit" class="btn btn-warning text-dark">
                            <i class="bi bi-person-down me-1"></i>Impersonate
                        </button>
                    </div>
                </div>

                <div class="settings-category-card">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <div>
                            <span class="fw-semibold">Additional Permissions</span>
                            <span class="text-muted small ms-2">Role defaults are checked automatically. Check extras to augment.</span>
                        </div>
                        <div class="d-flex gap-2">
                            <span class="badge bg-secondary text-dark d-flex align-items-center gap-1">
                                <i class="bi bi-circle-fill text-warning" style="font-size:.55rem;"></i>Role default
                            </span>
                            <span class="badge bg-secondary text-dark d-flex align-items-center gap-1">
                                <i class="bi bi-circle-fill text-info" style="font-size:.55rem;"></i>Additional
                            </span>
                        </div>
                    </div>
                    <div class="row g-3">
                        <cfloop array="#permissionCategoryOrder#" index="permissionCategory">
                            <div class="col-md-6 col-lg-4">
                                <div class="settings-category-card h-100 p-2">
                                    <div class="fw-semibold text-capitalize mb-2">#encodeForHTML(permissionCategory)#</div>
                                    <cfloop array="#permissionsByCategory[permissionCategory]#" index="permissionItem">
                                        <div class="form-check mb-1 impersonation-permission-check">
                                            <input class="form-check-input" type="checkbox"
                                                   name="impersonationPermissionIDs"
                                                   value="#permissionItem.PERMISSION_ID#"
                                                   id="imperPerm#permissionItem.PERMISSION_ID#">
                                            <label class="form-check-label small d-flex align-items-center gap-1" for="imperPerm#permissionItem.PERMISSION_ID#">
                                                <i class="bi bi-circle-fill permission-dot" style="font-size:.55rem; opacity:0;"></i>
                                                #encodeForHTML(permissionItem.DISPLAY_NAME)#
                                            </label>
                                        </div>
                                    </cfloop>
                                </div>
                            </div>
                        </cfloop>
                    </div>
                </div>
            </form>
        </div>
        </div>
    </div>
</div>
</cfif>

<!--- ── Add User form ── --->
<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-person-plus me-2"></i>Add Admin User</h5>
        <form method="post" action="/admin/settings/admin-users/save.cfm" class="row g-3 align-items-end">
            <input type="hidden" name="action" value="addUser">
            <div class="col-auto">
                <label class="form-label">CougarNet Username</label>
                <input type="text" name="cougarnet" class="form-control" placeholder="e.g. jdoe123" required
                       pattern="[a-zA-Z0-9_]+" title="Alphanumeric / underscores only">
            </div>
            <div class="col-auto">
                <button type="submit" class="btn btn-ui-add"><i class="bi bi-plus-lg me-1"></i>Add User</button>
            </div>
        </form>
    </div>
</div>

<!--- ── Users table ── --->
<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-people me-2"></i>Current Admin Users</h5>
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>CougarNet</th>
                        <th>Status</th>
                        <th>Roles</th>
                        <th>Permissions</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#users#" index="u">
                    <cfset currentDirectPermissions = structKeyExists(userDirectPermissionsByID, toString(u.USER_ID)) ? userDirectPermissionsByID[toString(u.USER_ID)] : []>
                    <cfset currentDirectPermissionLookup = structKeyExists(userDirectPermissionLookupByID, toString(u.USER_ID)) ? userDirectPermissionLookupByID[toString(u.USER_ID)] : {}>
                    <cfset currentEffectivePermissions = structKeyExists(userEffectivePermissionsByID, toString(u.USER_ID)) ? userEffectivePermissionsByID[toString(u.USER_ID)] : []>
                    <tr>
                        <td>#u.USER_ID#</td>
                        <td><strong>#encodeForHTML(u.COUGARNET)#</strong></td>
                        <td>
                            <cfif u.IS_ACTIVE>
                                <span class="badge settings-badge-active">Active</span>
                            <cfelse>
                                <span class="badge bg-secondary text-dark">Inactive</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif len(trim(u.ROLE_NAMES ?: ""))>
                                <cfloop list="#u.ROLE_NAMES#" index="rn" delimiters=",">
                                    <span class="badge bg-primary me-1">#encodeForHTML(trim(rn))#</span>
                                </cfloop>
                            <cfelse>
                                <span class="text-muted fst-italic">No roles</span>
                            </cfif>
                        </td>
                        <td>
                            <span class="badge settings-badge-count me-1">Direct #arrayLen(currentDirectPermissions)#</span>
                            <span class="badge settings-badge-custom">Effective #arrayLen(currentEffectivePermissions)#</span>
                        </td>
                        <td class="text-end">
                            <div class="settings-action-group">
                            <!--- Toggle active --->
                            <form method="post" action="/admin/settings/admin-users/save.cfm" class="d-inline">
                                <input type="hidden" name="action" value="toggleActive">
                                <input type="hidden" name="userID" value="#u.USER_ID#">
                                <cfif u.IS_ACTIVE>
                                    <button type="submit" class="btn btn-sm btn-outline-warning"
                                            title="Deactivate"
                                            onclick="return confirm('Deactivate #encodeForJavaScript(u.COUGARNET)#?')">
                                        <i class="bi bi-pause-circle"></i>
                                    </button>
                                <cfelse>
                                    <button type="submit" class="btn btn-sm btn-outline-success" title="Activate">
                                        <i class="bi bi-play-circle"></i>
                                    </button>
                                </cfif>
                            </form>
                            <!--- Manage Roles --->
                            <button type="button" class="btn btn-sm btn-outline-primary"
                                    title="Manage Roles"
                                    data-bs-toggle="modal"
                                    data-bs-target="##rolesModal#u.USER_ID#">
                                <i class="bi bi-key"></i>
                            </button>
                            <button type="button" class="btn btn-sm btn-outline-dark"
                                    title="Manage Permissions"
                                    data-bs-toggle="modal"
                                    data-bs-target="##permissionsModal#u.USER_ID#">
                                <i class="bi bi-sliders"></i>
                            </button>
                            <!--- Impersonate User --->
                            <cfif request.isActualSuperAdmin() AND u.USER_ID NEQ session.user.adminUserID AND NOT listFindNoCase(u.ROLE_NAMES ?: "", "SUPER_ADMIN")>
                                <button type="button" class="btn btn-sm btn-outline-warning"
                                        title="Impersonate #encodeForHTMLAttribute(u.COUGARNET)#"
                                        data-bs-toggle="modal"
                                        data-bs-target="##impersonateUserConfirmModal"
                                        data-user-id="#u.USER_ID#"
                                        data-cougarnet="#encodeForHTMLAttribute(u.COUGARNET)#"
                                        data-roles="#encodeForHTMLAttribute(u.ROLE_NAMES ?: 'No roles')#">
                                    <i class="bi bi-person-down"></i>
                                </button>
                            </cfif>
                            </div>
                        </td>
                    </tr>

                    <!--- Roles modal --->
                    <div class="modal fade settings-modal" id="rolesModal#u.USER_ID#" tabindex="-1">
                        <div class="modal-dialog">
                            <div class="modal-content">
                                <div class="modal-header">
                                    <h5 class="modal-title">Roles for #encodeForHTML(u.COUGARNET)#</h5>
                                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body">
                                    <cfset currentRoleIDs = listToArray(u.ROLE_IDS ?: "")>
                                    <cfloop array="#allRoles#" index="role">
                                        <cfset hasRole = arrayFindNoCase(currentRoleIDs, role.ROLE_ID)>
                                        <div class="d-flex justify-content-between align-items-center mb-2">
                                            <span>
                                                <cfif hasRole>
                                                    <i class="bi bi-check-circle-fill text-success me-1"></i>
                                                <cfelse>
                                                    <i class="bi bi-circle text-muted me-1"></i>
                                                </cfif>
                                                #encodeForHTML(role.ROLE_NAME)#
                                            </span>
                                            <form method="post" action="/admin/settings/admin-users/save.cfm" class="d-inline">
                                                <input type="hidden" name="userID" value="#u.USER_ID#">
                                                <input type="hidden" name="roleID" value="#role.ROLE_ID#">
                                                <cfif hasRole>
                                                    <input type="hidden" name="action" value="revokeRole">
                                                    <button type="submit" class="btn btn-sm btn-outline-danger">Revoke</button>
                                                <cfelse>
                                                    <input type="hidden" name="action" value="assignRole">
                                                    <button type="submit" class="btn btn-sm btn-outline-success">Assign</button>
                                                </cfif>
                                            </form>
                                        </div>
                                    </cfloop>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="modal fade settings-modal" id="permissionsModal#u.USER_ID#" tabindex="-1">
                        <div class="modal-dialog modal-lg modal-dialog-scrollable">
                            <div class="modal-content">
                                <form method="post" action="/admin/settings/admin-users/save.cfm">
                                    <div class="modal-header">
                                        <div>
                                            <h5 class="modal-title mb-1">Permissions for #encodeForHTML(u.COUGARNET)#</h5>
                                            <div class="text-muted small">Direct permissions are additive on top of the role defaults shown below.</div>
                                        </div>
                                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                    </div>
                                    <div class="modal-body">
                                        <input type="hidden" name="action" value="saveUserPermissions">
                                        <input type="hidden" name="userID" value="#u.USER_ID#">

                                        <div class="mb-4">
                                            <div class="fw-semibold mb-2">Effective Permissions</div>
                                            <cfif arrayLen(currentEffectivePermissions)>
                                                <div class="d-flex flex-wrap gap-2">
                                                    <cfloop array="#currentEffectivePermissions#" index="effectivePermission">
                                                        <span class="badge bg-info text-dark">#encodeForHTML(effectivePermission.PERMISSION_KEY)#</span>
                                                    </cfloop>
                                                </div>
                                            <cfelse>
                                                <div class="text-muted fst-italic">No effective permissions.</div>
                                            </cfif>
                                        </div>

                                        <div class="alert alert-light border small">
                                            Role defaults are managed on the Manage Roles page. Use the checkboxes below only for user-specific permission additions or exceptions.
                                        </div>

                                        <div class="fw-semibold mb-2">Direct User Permissions</div>
                                        <cfif arrayLen(allPermissions)>
                                            <div class="row g-3">
                                                <cfloop array="#permissionCategoryOrder#" index="permissionCategory">
                                                    <div class="col-md-6">
                                                        <div class="settings-category-card h-100">
                                                            <div class="fw-semibold text-capitalize mb-2">#encodeForHTML(permissionCategory)#</div>
                                                            <cfloop array="#permissionsByCategory[permissionCategory]#" index="permissionItem">
                                                                <div class="form-check mb-2">
                                                                    <input class="form-check-input" type="checkbox" name="permissionIDs" value="#permissionItem.PERMISSION_ID#" id="user#u.USER_ID#permission#permissionItem.PERMISSION_ID#" <cfif structKeyExists(currentDirectPermissionLookup, toString(permissionItem.PERMISSION_ID))>checked</cfif>>
                                                                    <label class="form-check-label" for="user#u.USER_ID#permission#permissionItem.PERMISSION_ID#">
                                                                        <span class="fw-semibold small d-block">#encodeForHTML(permissionItem.DISPLAY_NAME)#</span>
                                                                        <span class="text-muted small">#encodeForHTML(permissionItem.PERMISSION_KEY)#</span>
                                                                    </label>
                                                                </div>
                                                            </cfloop>
                                                        </div>
                                                    </div>
                                                </cfloop>
                                            </div>
                                        <cfelse>
                                            <div class="text-muted fst-italic">No permissions are defined yet.</div>
                                        </cfif>
                                    </div>
                                    <div class="modal-footer">
                                        <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Close</button>
                                        <button type="submit" class="btn btn-primary">Save Direct Permissions</button>
                                    </div>
                                </form>
                            </div>
                        </div>
                    </div>
                </cfloop>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!--- Shared impersonate-user confirmation modal --->
<cfif request.isActualSuperAdmin()>
<div class="modal fade settings-modal" id="impersonateUserConfirmModal" tabindex="-1" aria-labelledby="impersonateUserConfirmTitle" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="impersonateUserConfirmTitle">
                    <i class="bi bi-person-down me-2"></i>Impersonate User
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <p class="mb-1">You are about to impersonate:</p>
                <p class="mb-3">
                    <strong id="impersonateUserConfirmName" class="fs-5"></strong><br>
                    <span class="text-muted small" id="impersonateUserConfirmRoles"></span>
                </p>
                <p class="text-muted small mb-0">Your session will reflect this user&rsquo;s exact permission set. You can stop impersonating at any time from the banner at the top of every page.</p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
                <form method="post" action="/admin/settings/admin-users/save.cfm" class="mb-0">
                    <input type="hidden" name="action" value="startImpersonationUser">
                    <input type="hidden" name="impersonationUserID" id="impersonateUserConfirmUserID" value="">
                    <input type="hidden" name="returnURL" value="/admin/dashboard.cfm">
                    <button type="submit" class="btn btn-warning text-dark">
                        <i class="bi bi-person-down me-1"></i>Confirm Impersonate
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>
</cfif>

<div class="mt-3 d-flex flex-wrap gap-2">
    <a href="/admin/settings/admin-roles/" class="btn btn-outline-secondary">
        <i class="bi bi-gear me-1"></i>Manage Roles
    </a>
    <cfif request.hasPermission("settings.admin_permissions.manage")>
        <a href="/admin/settings/admin-permissions/" class="btn btn-outline-secondary">
            <i class="bi bi-sliders me-1"></i>Manage Permissions
        </a>
    </cfif>
</div>

</div>

<script>
(function () {
    document.addEventListener('DOMContentLoaded', function () {

        // ── Impersonate-user confirm modal ──────────────────────────────────
        var impersonateModal = document.getElementById('impersonateUserConfirmModal');
        if (impersonateModal) {
            impersonateModal.addEventListener('show.bs.modal', function (event) {
                var trigger  = event.relatedTarget;
                var userID   = trigger ? trigger.getAttribute('data-user-id')   : '';
                var cougarnet = trigger ? trigger.getAttribute('data-cougarnet') : '';
                var roles    = trigger ? trigger.getAttribute('data-roles')     : '';
                document.getElementById('impersonateUserConfirmName').textContent  = cougarnet;
                document.getElementById('impersonateUserConfirmRoles').textContent = roles;
                document.getElementById('impersonateUserConfirmUserID').value      = userID;
            });
        }

        // ── Role-based impersonation panel ──────────────────────────────────
        var roleSelect = document.getElementById('impersonationRoleID');        if (!roleSelect) { return; }

        var permissionCheckboxes = Array.prototype.slice.call(
            document.querySelectorAll("input[name='impersonationPermissionIDs']")
        );

        function applyRoleDefaults() {
            var selectedOption = roleSelect.options[roleSelect.selectedIndex];
            var raw = selectedOption ? (selectedOption.getAttribute('data-default-permissions') || '') : '';
            var defaultSet = {};
            raw.split(',').forEach(function (token) {
                var id = (token || '').trim();
                if (id.length) { defaultSet[id] = true; }
            });

            permissionCheckboxes.forEach(function (checkbox) {
                var isDefault = !!defaultSet[checkbox.value];
                checkbox.checked = isDefault;

                // Colour the dot: gold for role default, teal for additional (checked but not default)
                var dot = checkbox.closest('.impersonation-permission-check')
                              ? checkbox.closest('.impersonation-permission-check').querySelector('.permission-dot')
                              : null;
                if (dot) {
                    dot.style.opacity  = isDefault ? '1' : '0';
                    dot.style.color    = 'var(--bs-warning)';
                }
            });
        }

        // Refresh dots as user manually checks/unchecks extras
        function refreshDots() {
            var selectedOption = roleSelect.options[roleSelect.selectedIndex];
            var raw = selectedOption ? (selectedOption.getAttribute('data-default-permissions') || '') : '';
            var defaultSet = {};
            raw.split(',').forEach(function (token) {
                var id = (token || '').trim();
                if (id.length) { defaultSet[id] = true; }
            });

            permissionCheckboxes.forEach(function (checkbox) {
                var isDefault    = !!defaultSet[checkbox.value];
                var isChecked    = checkbox.checked;
                var isAdditional = isChecked && !isDefault;
                var dot = checkbox.closest('.impersonation-permission-check')
                              ? checkbox.closest('.impersonation-permission-check').querySelector('.permission-dot')
                              : null;
                if (dot) {
                    dot.style.opacity = (isDefault || isAdditional) ? '1' : '0';
                    dot.style.color   = isDefault ? 'var(--bs-warning)' : 'var(--bs-info)';
                }
            });
        }

        roleSelect.addEventListener('change', applyRoleDefaults);

        permissionCheckboxes.forEach(function (checkbox) {
            checkbox.addEventListener('change', refreshDots);
        });
    });
}());
</script>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
