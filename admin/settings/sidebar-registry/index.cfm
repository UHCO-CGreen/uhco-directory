<!---
    Sidebar Registry — read-only view of all sidebar nav items and their current status.
    Access: Super Admin only.
    To add or change nav items, edit admin/settings/sidebar-registry.cfm.
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/feature-gates.cfm">
<cfinclude template="/admin/settings/section-status-config.cfm">
<cfinclude template="/admin/settings/sidebar-registry.cfm">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-sidebar-registry-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Sidebar Registry</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-layout-sidebar me-2"></i>Sidebar Registry</h1>
<p class="text-muted">All permissioned sidebar nav items and their current placement rules. Edit <code>admin/settings/sidebar-registry.cfm</code> to add or modify items.</p>

<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>Label</th>
                        <th>Icon</th>
                        <th>Path</th>
                        <th>Required Permission</th>
                        <th>Section Key</th>
                        <th>Status</th>
                        <th>Placement</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#request._sidebarNavRegistry#" index="item">
                    <cfset itemStatus = len(item.sectionKey) ? getSettingsSectionStatus(item.sectionKey) : "">
                    <tr>
                        <td class="fw-semibold">#encodeForHTML(item.label)#</td>
                        <td><i class="bi #encodeForHTML(item.icon)#" title="#encodeForHTML(item.icon)#"></i></td>
                        <td><code class="small">#encodeForHTML(item.href)#</code></td>
                        <td>
                            <cfif len(item.permission)>
                                <code class="small">#encodeForHTML(replace(item.permission, "|", " | ", "all"))#</code>
                            <cfelse>
                                <span class="text-muted small">Always visible</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif len(item.sectionKey)>
                                <code class="small">#encodeForHTML(item.sectionKey)#</code>
                            <cfelse>
                                <span class="text-muted">—</span>
                            </cfif>
                        </td>
                        <td>
                            <cfif itemStatus EQ "Alpha">
                                <span class="badge bg-danger">Alpha</span>
                            <cfelseif itemStatus EQ "Beta">
                                <span class="badge bg-warning text-dark">Beta</span>
                            <cfelseif itemStatus EQ "Disabled">
                                <span class="badge bg-secondary">Disabled</span>
                            <cfelse>
                                <span class="badge bg-success">GA</span>
                            </cfif>
                        </td>
                        <td class="text-muted small">
                            <cfif itemStatus EQ "Alpha">
                                Alpha block (super admin)
                            <cfelseif itemStatus EQ "Disabled">
                                Hidden
                            <cfelse>
                                Main nav
                            </cfif>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
    </div>
</div>

<div class="card settings-shell settings-reference-card mb-3">
    <div class="card-body">
        <p class="text-muted small mb-0"><i class="bi bi-info-circle me-1"></i>Sidebar items are defined in <code>admin/settings/sidebar-registry.cfm</code>. Placement (main nav vs. Alpha block) is determined automatically by the section's status in section-status-config.cfm.</p>
    </div>
</div>

<div class="mt-3">
    <a href="/admin/settings/" class="btn btn-ui-cancel">
        <i class="bi bi-arrow-left me-1"></i>Back to Settings
    </a>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
