<!---
    Settings Hub
    Central dashboard with links to all settings sub-sections.
--->

<!--- ── Auth guard ── --->
<cfif NOT (
    request.hasPermission("settings.view")
    OR request.hasAnyPermission([
        "settings.view",
        "settings.media_config.manage",
        "settings.api.manage",
        "settings.bulk_exclusions.manage",
        "settings.scheduled_tasks.manage",
        "settings.workflows.manage",
        "settings.user_permissions.manage",
        "flags.manage",
        "orgs.manage",
        "external_ids.manage"
    ])
    OR request.isSuperAdmin()
)>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/feature-gates.cfm">
<cfinclude template="/admin/settings/section-status-config.cfm">

<cfset disabledFeature = lCase(trim(url.disabledFeature ?: ""))>
<cfset disabledFeatureState = request.getSettingsFeatureAvailability(disabledFeature)>
<cfset disabledFeatureMessage = disabledFeatureState.isDisabled ? (disabledFeatureState.label & " is temporarily disabled while it is reimagined.") : "">

<cfsavecontent variable="pageStyles">
<style>
.settings-group-toggle {
    background: none;
    border: none;
    color: inherit;
    font-size: 1.1rem;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: 0;
    text-decoration: none;
}
.settings-group-toggle:hover { color: var(--bs-primary); }
.settings-group-chevron {
    font-size: .85rem;
    transition: transform .2s ease;
    margin-left: .25rem;
}
.settings-group-toggle[aria-expanded="false"] .settings-group-chevron {
    transform: rotate(-90deg);
}
.settings-hub-card-compact .card-body {
    display: flex;
    align-items: center;
    gap: .85rem;
    padding: .65rem 1rem;
    text-align: left;
}
.settings-hub-card-compact .settings-hub-icon-sm {
    font-size: 1.5rem;
    flex-shrink: 0;
}
.settings-hub-card-compact .card-title {
    font-size: .9rem;
    margin-bottom: .1rem;
}
.settings-hub-card-compact .card-text {
    font-size: .75rem;
    line-height: 1.3;
    margin-bottom: 0;
}
.settings-hub-card-compact:hover .settings-hub-icon-sm { color: var(--bs-primary); }
</style>
</cfsavecontent>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-hub">
<h1 class="mb-1"><i class="bi bi-gear-fill me-2"></i>Settings</h1>
<p class="text-muted">System configuration and administration tools.</p>

<cfif len(disabledFeatureMessage)>
    <div class="alert alert-warning mt-3 mb-0">
        <i class="bi bi-cone-striped me-2"></i>#encodeForHTML(disabledFeatureMessage)#
    </div>
</cfif>

<!--- ── Group 1: Application Settings ───────────────────────────────── --->
<cfif request.isSuperAdmin() OR request.hasAnyPermission(["settings.media_config.manage","flags.manage","orgs.manage","external_ids.manage"])>
<div class="settings-group mt-4 mb-4">
    <button class="settings-group-toggle" type="button"
            data-bs-toggle="collapse" data-bs-target="##sg-app"
            aria-expanded="true" aria-controls="sg-app">
        <i class="bi bi-sliders2"></i>Application Settings
        <i class="bi bi-chevron-down settings-group-chevron"></i>
    </button>
    <div class="collapse show mt-3" id="sg-app">
        <div class="row g-2">

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/app-config/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-sliders settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">App Config<cfif len(getSettingsSectionStatus("app-config"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("app-config"))#">#getSettingsSectionStatus("app-config")#</span></cfif></div>
                                <p class="card-text text-muted">Key-value config, dashboard settings, and image URL</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/ldap/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-diagram-3 settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">LDAP Settings<cfif len(getSettingsSectionStatus("ldap"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("ldap"))#">#getSettingsSectionStatus("ldap")#</span></cfif></div>
                                <p class="card-text text-muted">CougarNet LDAP connectivity and group filters</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("settings.media_config.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/media-config/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-image settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">User Media Config<cfif len(getSettingsSectionStatus("media-config"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("media-config"))#">#getSettingsSectionStatus("media-config")#</span></cfif></div>
                                <p class="card-text text-muted">Filename patterns and image variant types</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("flags.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/flags/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-flag-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Manage Flags</div>
                                <p class="card-text text-muted">Create, edit, and delete user flags</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("orgs.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/orgs/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-building-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Manage Organizations</div>
                                <p class="card-text text-muted">Create, edit, and delete organizations</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("external_ids.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/external/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-person-bounding-box settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Manage External IDs</div>
                                <p class="card-text text-muted">Manage external identifier types and assignments</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/section-status/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-toggles settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Section Status</div>
                                <p class="card-text text-muted">View Alpha/Beta/GA state for each admin section</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/sidebar-registry/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-layout-sidebar settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Sidebar Registry</div>
                                <p class="card-text text-muted">View sidebar nav items, permissions, and placement</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

        </div>
    </div>
</div>
</cfif>

<!--- ── Group 2: User Permissions ───────────────────────────────────── --->
<cfif request.isSuperAdmin() OR request.hasPermission("settings.user_permissions.manage")>
<div class="settings-group mb-4">
    <button class="settings-group-toggle" type="button"
            data-bs-toggle="collapse" data-bs-target="##sg-perms"
            aria-expanded="true" aria-controls="sg-perms">
        <i class="bi bi-people"></i>User Permissions
        <i class="bi bi-chevron-down settings-group-chevron"></i>
    </button>
    <div class="collapse show mt-3" id="sg-perms">
        <div class="row g-2">

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/admin-users/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-people-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Admin Users &amp; Roles<cfif len(getSettingsSectionStatus("admin-users"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("admin-users"))#">#getSettingsSectionStatus("admin-users")#</span></cfif></div>
                                <p class="card-text text-muted">Manage admin accounts and role assignments</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/admin-permissions/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-key-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Admin Permissions<cfif len(getSettingsSectionStatus("admin-permissions"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("admin-permissions"))#">#getSettingsSectionStatus("admin-permissions")#</span></cfif></div>
                                <p class="card-text text-muted">Create, edit, and retire permission definitions</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/section-permissions/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-shield-lock settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Section Permissions</div>
                                <p class="card-text text-muted">Assign which permission guards each admin section</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("settings.user_permissions.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/user-permissions/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-person-check-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">External Access Permissions<cfif len(getSettingsSectionStatus("user-permissions"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("user-permissions"))#">#getSettingsSectionStatus("user-permissions")#</span></cfif></div>
                                <p class="card-text text-muted">Grant or revoke module access for identity users</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

        </div>
    </div>
</div>
</cfif>

<!--- ── Group 3: Data Management ────────────────────────────────────── --->
<cfif request.isSuperAdmin() OR request.hasAnyPermission(["settings.api.manage","settings.bulk_exclusions.manage"])>
<div class="settings-group mb-4">
    <button class="settings-group-toggle" type="button"
            data-bs-toggle="collapse" data-bs-target="##sg-data"
            aria-expanded="true" aria-controls="sg-data">
        <i class="bi bi-database"></i>Data Management
        <i class="bi bi-chevron-down settings-group-chevron"></i>
    </button>
    <div class="collapse show mt-3" id="sg-data">
        <div class="row g-2">

            <cfif request.hasPermission("settings.api.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/uhco-api/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-braces settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">UHCO API<cfif len(getSettingsSectionStatus("uhco-api"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("uhco-api"))#">#getSettingsSectionStatus("uhco-api")#</span></cfif></div>
                                <p class="card-text text-muted">Manage API tokens and secrets for external integrations</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/test-mode/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-bezier2 settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Test Mode<cfif len(getSettingsSectionStatus("test-mode"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("test-mode"))#">#getSettingsSectionStatus("test-mode")#</span></cfif></div>
                                <p class="card-text text-muted">Synthetic user batch management and test mode toggle</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("settings.bulk_exclusions.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/bulk-exclusions/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-funnel settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Bulk Exclusions<cfif len(getSettingsSectionStatus("bulk-exclusions"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("bulk-exclusions"))#">#getSettingsSectionStatus("bulk-exclusions")#</span></cfif></div>
                                <p class="card-text text-muted">Data quality exclusion rules by user type</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

        </div>
    </div>
</div>
</cfif>

<!--- ── Group 4: Scheduled Tasks & Logging ──────────────────────────── --->
<cfif request.isSuperAdmin() OR request.hasPermission("settings.scheduled_tasks.manage")>
<div class="settings-group mb-4">
    <button class="settings-group-toggle" type="button"
            data-bs-toggle="collapse" data-bs-target="##sg-tasks"
            aria-expanded="true" aria-controls="sg-tasks">
        <i class="bi bi-clock-history"></i>Scheduled Tasks &amp; Logging
        <i class="bi bi-chevron-down settings-group-chevron"></i>
    </button>
    <div class="collapse show mt-3" id="sg-tasks">
        <div class="row g-2">

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/observability/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-shield-lock-fill settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Auth Observability<cfif len(getSettingsSectionStatus("observability"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("observability"))#">#getSettingsSectionStatus("observability")#</span></cfif></div>
                                <p class="card-text text-muted">Real-time authentication event log</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.isSuperAdmin()>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/change-log/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-journal-text settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Change Log</div>
                                <p class="card-text text-muted">Audit trail of admin changes; super admins can revert</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

            <cfif request.hasPermission("settings.scheduled_tasks.manage")>
            <div class="col-md-6 col-lg-3">
                <a href="/admin/settings/scheduled-tasks/" class="text-decoration-none">
                    <div class="card border-0 shadow-sm settings-hub-card settings-hub-card-compact">
                        <div class="card-body">
                            <i class="bi bi-clock-history settings-hub-icon-sm"></i>
                            <div>
                                <div class="card-title fw-semibold">Scheduled Tasks<cfif len(getSettingsSectionStatus("scheduled-tasks"))> <span class="badge settings-status-badge settings-status-badge--#lCase(getSettingsSectionStatus("scheduled-tasks"))#">#getSettingsSectionStatus("scheduled-tasks")#</span></cfif></div>
                                <p class="card-text text-muted">Enable, disable, and configure automated tasks</p>
                            </div>
                        </div>
                    </div>
                </a>
            </div>
            </cfif>

        </div>
    </div>
</div>
</cfif>

</div>

<script>
(function () {
    document.querySelectorAll('.collapse[id^="sg-"]').forEach(function (el) {
        var key = 'settings-hub-' + el.id;
        if (localStorage.getItem(key) === 'collapsed') {
            el.classList.remove('show');
            var btn = document.querySelector('[data-bs-target="##' + el.id + '"]');
            if (btn) btn.setAttribute('aria-expanded', 'false');
        }
        el.addEventListener('hidden.bs.collapse', function () { localStorage.setItem(key, 'collapsed'); });
        el.addEventListener('shown.bs.collapse',  function () { localStorage.setItem(key, 'expanded'); });
    });
})();
</script>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
