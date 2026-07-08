<!---
    Section Permissions — view and edit the permission required to access each admin section.
    Permission: settings.admin_permissions.manage
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("section-permissions")>

<cfset sectionsDAO  = createObject("component", "dao.adminSections_DAO").init()>
<cfset authSvc      = createObject("component", "cfc.adminAuth_service").init()>
<cfset sections     = sectionsDAO.getAllSections()>
<cfset allPerms     = authSvc.getAllPermissions()>
<cfset msgParam     = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam     = structKeyExists(url, "err") ? url.err : "">
<cfset editID       = (structKeyExists(url, "edit") AND isNumeric(url.edit)) ? val(url.edit) : 0>

<!--- Split into main sections (sort_order < 100) and settings sub-sections --->
<cfset mainSections     = []>
<cfset settingsSections = []>
<cfloop array="#sections#" index="sec">
    <cfif val(sec.SORT_ORDER) LT 100>
        <cfset arrayAppend(mainSections, sec)>
    <cfelse>
        <cfset arrayAppend(settingsSections, sec)>
    </cfif>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-section-permissions-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-permissions/">Admin Permissions</a></li>
        <li class="breadcrumb-item active">Section Permissions</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-shield-lock me-2"></i>Section Permissions</h1>
<p class="text-muted">View and edit the permission required to access each admin section. Changes take effect immediately.</p>
<cfif len(sectionStatus)>
    <div class="mb-3">
        <span class="badge bg-warning text-dark">Currently in: #sectionStatus#</span>
    </div>
</cfif>

<!--- Main Sections --->
<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-layout-sidebar me-2"></i>Main Sections</h5>
        <cfif arrayLen(mainSections) EQ 0>
            <p class="text-muted">No main sections found. Run migration 034 to seed the registry.</p>
        <cfelse>
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>Section</th>
                        <th>Path</th>
                        <th>Status</th>
                        <th>Required Permission</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#mainSections#" index="sec">
                    <cfset secStatus = len(trim(sec.SECTION_KEY ?: "")) ? getSettingsSectionStatus(lCase(trim(sec.SECTION_KEY))) : "">
                    <tr>
                        <td>
                            <div class="fw-semibold">#encodeForHTML(sec.SECTION_NAME)#</div>
                            <cfif len(trim(sec.DESCRIPTION ?: ''))>
                                <div class="text-muted small">#encodeForHTML(sec.DESCRIPTION)#</div>
                            </cfif>
                        </td>
                        <td><code class="small">#encodeForHTML(sec.SECTION_PATH)#</code></td>
                        <td>
                            <cfif secStatus EQ "Alpha">
                                <span class="badge bg-danger">Alpha</span>
                            <cfelseif secStatus EQ "Beta">
                                <span class="badge bg-warning text-dark">Beta</span>
                            <cfelseif secStatus EQ "Disabled">
                                <span class="badge bg-secondary">Disabled</span>
                            <cfelse>
                                <span class="badge bg-success">GA</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif editID EQ val(sec.SECTION_ID)>
                                <form method="post" action="/admin/settings/section-permissions/save.cfm" class="d-flex gap-2 align-items-center">
                                    <input type="hidden" name="action" value="updateSectionPermission">
                                    <input type="hidden" name="sectionID" value="#val(sec.SECTION_ID)#">
                                    <select name="permissionID" class="form-select form-select-sm" style="max-width:260px;">
                                        <cfloop array="#allPerms#" index="perm">
                                            <cfif val(perm.IS_ACTIVE) EQ 1>
                                                <option value="#val(perm.PERMISSION_ID)#" <cfif val(perm.PERMISSION_ID) EQ val(sec.PERMISSION_ID)>selected</cfif>>
                                                    #encodeForHTML(perm.PERMISSION_KEY)#
                                                </option>
                                            </cfif>
                                        </cfloop>
                                    </select>
                                    <button type="submit" class="btn btn-sm btn-ui-save">Save</button>
                                    <a href="/admin/settings/section-permissions/" class="btn btn-sm btn-ui-cancel">Cancel</a>
                                </form>
                            <cfelse>
                                <code>#encodeForHTML(sec.PERMISSION_KEY)#</code>
                                <div class="text-muted small">#encodeForHTML(sec.PERMISSION_DISPLAY_NAME)#</div>
                            </cfif>
                        </td>
                        <td class="text-end">
                            <cfif editID NEQ val(sec.SECTION_ID)>
                                <a href="/admin/settings/section-permissions/?edit=#val(sec.SECTION_ID)#"
                                   class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit"
                                   title="Edit Permission" data-bs-toggle="tooltip" data-bs-title="Edit Permission" aria-label="Edit Permission">
                                    <i class="bi bi-pencil-square"></i>
                                </a>
                            </cfif>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
        </cfif>
    </div>
</div>

<!--- Settings Sub-sections --->
<div class="card border-0 shadow-sm mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-gear me-2"></i>Settings Sub-sections</h5>
        <cfif arrayLen(settingsSections) EQ 0>
            <p class="text-muted">No settings sub-sections found.</p>
        <cfelse>
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>Section</th>
                        <th>Path</th>
                        <th>Status</th>
                        <th>Required Permission</th>
                        <th class="text-end">Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#settingsSections#" index="sec">
                    <cfset secStatus = len(trim(sec.SECTION_KEY ?: "")) ? getSettingsSectionStatus(lCase(trim(sec.SECTION_KEY))) : "">
                    <tr>
                        <td>
                            <div class="fw-semibold">#encodeForHTML(sec.SECTION_NAME)#</div>
                            <cfif len(trim(sec.DESCRIPTION ?: ''))>
                                <div class="text-muted small">#encodeForHTML(sec.DESCRIPTION)#</div>
                            </cfif>
                        </td>
                        <td><code class="small">#encodeForHTML(sec.SECTION_PATH)#</code></td>
                        <td>
                            <cfif secStatus EQ "Alpha">
                                <span class="badge bg-danger">Alpha</span>
                            <cfelseif secStatus EQ "Beta">
                                <span class="badge bg-warning text-dark">Beta</span>
                            <cfelseif secStatus EQ "Disabled">
                                <span class="badge bg-secondary">Disabled</span>
                            <cfelse>
                                <span class="badge bg-success">GA</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif editID EQ val(sec.SECTION_ID)>
                                <form method="post" action="/admin/settings/section-permissions/save.cfm" class="d-flex gap-2 align-items-center">
                                    <input type="hidden" name="action" value="updateSectionPermission">
                                    <input type="hidden" name="sectionID" value="#val(sec.SECTION_ID)#">
                                    <select name="permissionID" class="form-select form-select-sm" style="max-width:260px;">
                                        <cfloop array="#allPerms#" index="perm">
                                            <cfif val(perm.IS_ACTIVE) EQ 1>
                                                <option value="#val(perm.PERMISSION_ID)#" <cfif val(perm.PERMISSION_ID) EQ val(sec.PERMISSION_ID)>selected</cfif>>
                                                    #encodeForHTML(perm.PERMISSION_KEY)#
                                                </option>
                                            </cfif>
                                        </cfloop>
                                    </select>
                                    <button type="submit" class="btn btn-sm btn-ui-save">Save</button>
                                    <a href="/admin/settings/section-permissions/" class="btn btn-sm btn-ui-cancel">Cancel</a>
                                </form>
                            <cfelse>
                                <code>#encodeForHTML(sec.PERMISSION_KEY)#</code>
                                <div class="text-muted small">#encodeForHTML(sec.PERMISSION_DISPLAY_NAME)#</div>
                            </cfif>
                        </td>
                        <td class="text-end">
                            <cfif editID NEQ val(sec.SECTION_ID)>
                                <a href="/admin/settings/section-permissions/?edit=#val(sec.SECTION_ID)#"
                                   class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit"
                                   title="Edit Permission" data-bs-toggle="tooltip" data-bs-title="Edit Permission" aria-label="Edit Permission">
                                    <i class="bi bi-pencil-square"></i>
                                </a>
                            </cfif>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
        </cfif>
    </div>
</div>

<div class="card settings-shell settings-reference-card mb-3">
    <div class="card-body">
        <p class="text-muted small mb-0"><i class="bi bi-info-circle me-1"></i>Changing a section's permission updates the registry but does NOT remove the inline page guard in that section's <code>.cfm</code> file. Both gates must allow access. Contact a developer to update inline guards.</p>
    </div>
</div>

<div class="mt-3 d-flex flex-wrap gap-2">
    <a href="/admin/settings/admin-permissions/" class="btn btn-ui-cancel">
        <i class="bi bi-key me-1"></i>Back to Admin Permissions
    </a>
    <a href="/admin/settings/admin-roles/" class="btn btn-ui-go">
        <i class="bi bi-person-badge me-1"></i>Manage Roles
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
