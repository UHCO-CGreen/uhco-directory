<!---
    Migrations Hub — Settings sub-section.
    Permission: settings.migrations.manage.
--->

<cfif NOT request.hasPermission("settings.migrations.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset migrationService = createObject("component", "cfc.gradMigration_service").init()>
<cfset latestRun = {}>
<cfset autoExecute = false>
<cftry>
    <cfset latestRun   = migrationService.getLatestRun()>
    <cfset autoExecute = migrationService.isAutoExecuteEnabled()>
<cfcatch></cfcatch>
</cftry>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-migrations-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Migrations</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-mortarboard me-2"></i>Migrations</h1>
<p class="text-muted mb-4">Data migration tools for transitioning user records between lifecycle stages.</p>

<div class="row g-4">

    <!--- Grad Migration Card --->
    <div class="col-md-6">
        <a href="grad_migration.cfm" class="text-decoration-none">
            <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--primary">
                <div class="card-body">
                    <div class="d-flex align-items-center mb-3">
                        <i class="bi bi-mortarboard-fill fs-2 settings-hub-icon me-3"></i>
                        <div>
                            <h5 class="card-title text-dark mb-0">Graduation Migration</h5>
                            <p class="card-text text-muted small mb-0">Migrate graduating students to alumni status</p>
                        </div>
                    </div>
                    <div class="d-flex gap-2 flex-wrap">
                        <cfif structKeyExists(latestRun, "RUN_ID")>
                            <span class="badge settings-badge-primary-soft">
                                Last run: #dateFormat(latestRun.STARTED_AT, "mm/dd/yyyy")#
                            </span>
                            <cfif latestRun.STATUS EQ "completed">
                                <span class="badge settings-badge-success-soft">#latestRun.MIGRATED_COUNT# migrated</span>
                            <cfelse>
                                <span class="badge settings-badge-warning-soft">#latestRun.STATUS#</span>
                            </cfif>
                        <cfelse>
                            <span class="badge settings-badge-neutral">No runs yet</span>
                        </cfif>
                        <cfif autoExecute>
                            <span class="badge settings-badge-success-soft"><i class="bi bi-clock me-1"></i>Scheduled</span>
                        <cfelse>
                            <span class="badge settings-badge-warning-soft"><i class="bi bi-pause-circle me-1"></i>Manual only</span>
                        </cfif>
                    </div>
                </div>
            </div>
        </a>
    </div>

    <!--- Future Migration Placeholder --->
    <div class="col-md-6">
        <div class="card h-100 shadow-sm settings-hub-card">
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <i class="bi bi-plus-circle-dotted fs-2 text-secondary me-3"></i>
                    <div>
                        <h5 class="card-title text-secondary mb-0">Future Migrations</h5>
                        <p class="card-text text-muted small mb-0">Additional migration tools will appear here as they are built</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
