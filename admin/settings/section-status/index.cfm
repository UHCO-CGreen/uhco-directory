<!---
    Section Status — read-only view of all section Alpha/Beta/GA states.
    Access: Super Admin only.
    To change a section's status, edit admin/settings/section-status-config.cfm.
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/feature-gates.cfm">
<cfinclude template="/admin/settings/section-status-config.cfm">

<cfset statusMap = request._sectionStatuses>
<cfset statusKeys = listToArray(structKeyList(statusMap))>
<cfset arraySort(statusKeys, "textnocase")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-section-status-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Section Status</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-toggles me-2"></i>Section Status</h1>
<p class="text-muted">Current Alpha/Beta/GA state for each admin section. Status controls sidebar placement and access. Edit <code>admin/settings/section-status-config.cfm</code> to change a section's status.</p>

<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <div class="table-responsive">
            <table class="table table-sm table-hover align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>Section Key</th>
                        <th>Status</th>
                        <th>Sidebar Placement</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#statusKeys#" index="key">
                    <cfset currentStatus = getSettingsSectionStatus(key)>
                    <tr>
                        <td><code>#encodeForHTML(key)#</code></td>
                        <td>
                            <cfif currentStatus EQ "Alpha">
                                <span class="badge bg-danger">Alpha</span>
                            <cfelseif currentStatus EQ "Beta">
                                <span class="badge bg-warning text-dark">Beta</span>
                            <cfelseif currentStatus EQ "Disabled">
                                <span class="badge bg-secondary">Disabled</span>
                            <cfelse>
                                <span class="badge bg-success">GA</span>
                            </cfif>
                        </td>
                        <td class="text-muted small">
                            <cfif currentStatus EQ "Alpha">
                                Alpha block — super admin only
                            <cfelseif currentStatus EQ "Disabled">
                                Hidden from all nav
                            <cfelse>
                                Main nav (if permission granted)
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
        <p class="text-muted small mb-0"><i class="bi bi-info-circle me-1"></i>Section status is managed in <code>admin/settings/section-status-config.cfm</code>. Changes require a developer edit and application restart or reinit.</p>
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
