<!---
    Settings Hub
    Central dashboard with links to all settings sub-sections.
--->

<!--- ── Auth guard ── --->
<cfif NOT (
    request.hasPermission("settings.view")
    OR request.hasAnyPermission([
        "settings.app_config.manage",
        "settings.media_config.manage",
        "settings.api.manage",
        "settings.admin_users.manage",
        "settings.admin_roles.manage",
        "settings.admin_permissions.manage",
        "settings.user_review.manage",
        "users.approve_user_review",
        "settings.import.manage",
        "settings.bulk_exclusions.manage",
        "settings.migrations.manage",
        "settings.uh_sync.view",
        "settings.query_builder.use",
        "settings.scheduled_tasks.manage",
        "settings.workflows.manage"
    ])
)>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<h1 class="mb-1"><i class="bi bi-gear-fill me-2"></i>Settings</h1>
<p class="text-muted">System configuration and administration tools.</p>

<div class="row g-4 mt-3">

    <!--- Admin Users & Roles --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/admin-users/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-shield-lock display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Admin Users &amp; Roles</h5>
                    <p class="card-text text-muted small">Manage admin accounts and role assignments</p>
                </div>
            </div>
        </a>
    </div>

    <cfif request.hasPermission("settings.admin_permissions.manage")>
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/admin-permissions/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-sliders display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Admin Permissions</h5>
                    <p class="card-text text-muted small">Create, edit, and retire permission definitions</p>
                </div>
            </div>
        </a>
    </div>
    </cfif>

    <cfif request.hasAnyPermission(["settings.user_review.manage", "users.approve_user_review"] )>
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/user-review/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-person-lines-fill display-4 mb-3"></i>
                    <h5 class="card-title text-dark">User Review</h5>
                    <p class="card-text text-muted small">Configure self-service profile review and process submissions</p>
                </div>
            </div>
        </a>
    </div>
    </cfif>

    <!--- User Media Config --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/media-config/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-image display-4 mb-3"></i>
                    <h5 class="card-title text-dark">User Media Config</h5>
                    <p class="card-text text-muted small">Filename patterns and image variant types</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Scheduled Tasks --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/scheduled-tasks/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-clock-history display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Scheduled Tasks <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Enable, disable, and configure automated tasks</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Migrations --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/migrations/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-mortarboard display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Migrations <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Graduation migration and future migration tools</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Bulk Exclusions --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/bulk-exclusions/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-funnel display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Bulk Exclusions <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Data quality exclusion rules by user type</p>
                </div>
            </div>
        </a>
    </div>

    <!--- UH Sync --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/uh-sync/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-arrow-left-right display-4 mb-3"></i>
                    <h5 class="card-title text-dark">UH Sync <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Field-level diffs and membership changes vs UH API</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Query Builder --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/query-builder/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-database display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Query Builder <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Visual query builder with export (CSV)</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Import Data --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/import/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-upload display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Import Data <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Import users, flags, organizations via CSV or Excel</p>
                </div>
            </div>
        </a>
    </div>

    <!--- UHCO API --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/uhco-api/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-braces display-4 mb-3"></i>
                    <h5 class="card-title text-dark">UHCO API</h5>
                    <p class="card-text text-muted small">Manage API tokens and secrets for external integrations</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Application Settings --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/app-config/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-sliders display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Application Settings</h5>
                    <p class="card-text text-muted small">Shared key-value configuration such as published media URLs</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Workflows --->
    <div class="col-md-6 col-lg-4">
        <a href="/admin/settings/workflows/" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm">
                <div class="card-body text-center py-4">
                    <i class="bi bi-diagram-3 display-4 mb-3"></i>
                    <h5 class="card-title text-dark">Workflows <span class="badge bg-warning text-dark">Alpha</span></h5>
                    <p class="card-text text-muted small">Automated workflows and processing pipelines</p>
                </div>
            </div>
        </a>
    </div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
