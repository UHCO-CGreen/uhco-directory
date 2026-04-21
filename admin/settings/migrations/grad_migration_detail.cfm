<!---
    grad_migration_detail.cfm
    Detail view for a specific graduation migration run.
    Shows run metadata and per-user migration results.
--->

<!--- ── URL params ── --->
<cfif NOT request.hasPermission("settings.migrations.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset runID = ( structKeyExists(url, "runID") AND isNumeric(url.runID) ) ? val(url.runID) : 0>

<cfif runID EQ 0>
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm" addtoken="false">
</cfif>

<!--- ── Load service & data ── --->
<cfset migrationService = createObject("component", "cfc.gradMigration_service").init()>
<cfset run     = {}>
<cfset details = []>
<cfset dbOk    = true>
<cfset dbError = "">

<cftry>
    <cfset run     = migrationService.getRunByID( runID )>
    <cfset details = migrationService.getDetailsByRun( runID )>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<cfif structIsEmpty(run) AND dbOk>
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=error&err=#urlEncodedFormat('Run not found.')#" addtoken="false">
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════ --->
<!--- ── Page content ─────────────────────────────────────────────────────── --->
<!--- ═══════════════════════════════════════════════════════════════════════ --->

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-grad-migration-detail-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/migrations/grad_migration.cfm">Graduation Migration</a></li>
        <li class="breadcrumb-item active">Run ###runID#</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-mortarboard-fill me-2"></i>Migration Run ###runID#</h1>

<cfif NOT dbOk>
    <div class="alert alert-danger mt-3">
        <strong>Database Error:</strong> #encodeForHTML(dbError)#
    </div>
</cfif>

<cfif dbOk AND NOT structIsEmpty(run)>

<!--- ── Run Metadata ── --->
<div class="row mt-4 g-3">
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Grad Year</h6>
                <h3 class="card-title text-primary">#run.GRADYEAR#</h3>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Status</h6>
                <h4>
                    <cfswitch expression="#run.STATUS#">
                        <cfcase value="completed"><span class="badge bg-success">#run.STATUS#</span></cfcase>
                        <cfcase value="failed"><span class="badge bg-danger">#run.STATUS#</span></cfcase>
                        <cfcase value="rolled_back"><span class="badge bg-warning text-dark">#run.STATUS#</span></cfcase>
                        <cfcase value="executing"><span class="badge bg-info">#run.STATUS#</span></cfcase>
                        <cfdefaultcase><span class="badge bg-secondary">#run.STATUS#</span></cfdefaultcase>
                    </cfswitch>
                </h4>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Targeted</h6>
                <h3 class="card-title">#run.TOTALTARGETED#</h3>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Migrated</h6>
                <h3 class="card-title text-success">#run.TOTALMIGRATED#</h3>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Errors</h6>
                <h3 class="card-title <cfif run.TOTALERRORS GT 0>text-danger<cfelse>text-muted</cfif>">#run.TOTALERRORS#</h3>
            </div>
        </div>
    </div>
    <div class="col-md-2">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Mode</h6>
                <h4 class="card-title">#run.MODE#</h4>
            </div>
        </div>
    </div>
</div>

<!--- ── Additional metadata ── --->
<div class="card mt-3 settings-shell settings-reference-card">
    <div class="card-body">
        <div class="row">
            <div class="col-md-4">
                <strong>Triggered By:</strong> #encodeForHTML(run.TRIGGEREDBY)#
            </div>
            <div class="col-md-4">
                <strong>Executed:</strong> #dateTimeFormat(run.EXECUTEDAT, 'MM/dd/yyyy hh:nn tt')#
            </div>
            <div class="col-md-4">
                <strong>Completed:</strong>
                <cfif isDate(run.COMPLETEDAT)>
                    #dateTimeFormat(run.COMPLETEDAT, 'MM/dd/yyyy hh:nn tt')#
                <cfelse>
                    <span class="text-muted">—</span>
                </cfif>
            </div>
        </div>
        <cfif run.STATUS EQ "rolled_back">
            <div class="row mt-2">
                <div class="col-md-4">
                    <strong>Rolled Back By:</strong> #encodeForHTML(run.ROLLEDBACKBY ?: "—")#
                </div>
                <div class="col-md-4">
                    <strong>Rolled Back At:</strong>
                    <cfif isDate(run.ROLLEDBACKAT)>
                        #dateTimeFormat(run.ROLLEDBACKAT, 'MM/dd/yyyy hh:nn tt')#
                    <cfelse>
                        <span class="text-muted">—</span>
                    </cfif>
                </div>
                <div class="col-md-4"></div>
            </div>
        </cfif>
    </div>
</div>

<!--- ── Rollback button ── --->
<cfif run.STATUS EQ "completed">
    <div class="mt-3">
        <form method="post" action="/admin/settings/migrations/save_grad_migration_settings.cfm"
              onsubmit="return confirm('Roll back this migration? All #run.TOTALMIGRATED# migrated users will be reverted to current-student status.');">
            <input type="hidden" name="action" value="rollback">
            <input type="hidden" name="runID" value="#run.RUNID#">
            <button type="submit" class="btn btn-warning">
                <i class="bi bi-arrow-counterclockwise me-1"></i>Rollback This Run
            </button>
        </form>
    </div>
</cfif>

<!--- ── Per-User Details ── --->
<div class="card mt-4 settings-shell settings-summary-card">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-people me-2"></i>User Details (#arrayLen(details)#)</h5>
    </div>
    <div class="card-body">
        <cfif arrayLen(details) EQ 0>
            <p class="text-muted">No detail records found.</p>
        <cfelse>
            <div class="table-responsive">
                <table class="table table-sm table-striped settings-table">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Previous Title</th>
                            <th>New Title</th>
                            <th>Exclusions +/-</th>
                            <th>Status</th>
                            <th>Error</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#details#" index="d">
                            <tr>
                                <td>
                                    <a href="/admin/users/edit.cfm?userID=#d.USERID#">
                                        #encodeForHTML(d.LASTNAME)#, #encodeForHTML(d.FIRSTNAME)#
                                    </a>
                                </td>
                                <td>#encodeForHTML(d.EMAILPRIMARY)#</td>
                                <td>#encodeForHTML(d.PREVIOUSTITLE1 ?: "")#</td>
                                <td>#encodeForHTML(d.NEWTITLE1 ?: "")#</td>
                                <td>
                                    <cfif d.EXCLUSIONSADDED GT 0>
                                        <span class="text-success">+#d.EXCLUSIONSADDED#</span>
                                    </cfif>
                                    <cfif d.EXCLUSIONSREMOVED GT 0>
                                        <span class="text-danger">-#d.EXCLUSIONSREMOVED#</span>
                                    </cfif>
                                    <cfif d.EXCLUSIONSADDED EQ 0 AND d.EXCLUSIONSREMOVED EQ 0>
                                        <span class="text-muted">—</span>
                                    </cfif>
                                </td>
                                <td>
                                    <cfswitch expression="#d.STATUS#">
                                        <cfcase value="migrated"><span class="badge bg-success">#d.STATUS#</span></cfcase>
                                        <cfcase value="error"><span class="badge bg-danger">#d.STATUS#</span></cfcase>
                                        <cfcase value="rolled_back"><span class="badge bg-warning text-dark">#d.STATUS#</span></cfcase>
                                        <cfcase value="pending"><span class="badge bg-secondary">#d.STATUS#</span></cfcase>
                                        <cfdefaultcase><span class="badge bg-secondary">#d.STATUS#</span></cfdefaultcase>
                                    </cfswitch>
                                </td>
                                <td>
                                    <cfif len(d.ERRORMESSAGE ?: "")>
                                        <small class="text-danger">#encodeForHTML(d.ERRORMESSAGE)#</small>
                                    <cfelse>
                                        <span class="text-muted">—</span>
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

</cfif>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
