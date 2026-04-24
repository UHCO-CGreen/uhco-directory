<!---
    grad_migration.cfm
    Graduation Migration Dashboard — Student to Alumni yearly migration.
    Provides preview, execute (with force), schedule management,
    auto-execute toggle, and run history.
--->

<!--- ── URL params ── --->
<cfif NOT request.hasPermission("settings.migrations.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset msgParam  = structKeyExists(url, "msg")  ? trim(url.msg)  : "">
<cfset errParam  = structKeyExists(url, "err")  ? trim(url.err)  : "">
<cfset runIDParam = ( structKeyExists(url, "runID") AND isNumeric(url.runID) ) ? val(url.runID) : 0>
<cfset rolledParam = ( structKeyExists(url, "rolled") AND isNumeric(url.rolled) ) ? val(url.rolled) : 0>
<cfset rollbackErrParam = ( structKeyExists(url, "errors") AND isNumeric(url.errors) ) ? val(url.errors) : 0>
<cfset migrationErrCountParam = ( structKeyExists(url, "errors") AND isNumeric(url.errors) ) ? val(url.errors) : 0>

<!--- Status modal config --->
<cfset showStatusModal = false>
<cfset statusModalTitle = "">
<cfset statusModalBody = "">
<cfset statusModalClass = "primary">

<cfif msgParam EQ "ran" AND runIDParam GT 0>
    <cfset showStatusModal = true>
    <cfset statusModalClass = "success">
    <cfset statusModalTitle = "Migration Completed">
    <cfset statusModalBody = "Migration completed successfully. <a href='/admin/settings/migrations/grad_migration_detail.cfm?runID=#runIDParam#'>View details</a>.">
<cfelseif msgParam EQ "ran_with_errors" AND runIDParam GT 0>
    <cfset showStatusModal = true>
    <cfset statusModalClass = "warning">
    <cfset statusModalTitle = "Migration Completed With Errors">
    <cfset statusModalBody = "Migration completed with errors.#(migrationErrCountParam GT 0 ? ' <strong>#migrationErrCountParam#</strong> record(s) reported errors.' : '')# <a href='/admin/settings/migrations/grad_migration_detail.cfm?runID=#runIDParam#'>View details</a>.">
<cfelseif msgParam EQ "error">
    <cfset showStatusModal = true>
    <cfset statusModalClass = "danger">
    <cfset statusModalTitle = "Operation Failed">
    <cfset statusModalBody = encodeForHTML(errParam)>
<cfelseif msgParam EQ "skipped">
    <cfset showStatusModal = true>
    <cfset statusModalClass = "warning">
    <cfset statusModalTitle = "Operation Skipped">
    <cfset statusModalBody = encodeForHTML(errParam)>
<cfelseif msgParam EQ "rollback">
    <cfset showStatusModal = true>
    <cfset statusModalClass = "success">
    <cfset statusModalTitle = "Rollback Completed">
    <cfset statusModalBody = "Rollback completed successfully.#(runIDParam GT 0 ? ' Run ###runIDParam#' : '')##(rolledParam GT 0 ? ' reverted <strong>#rolledParam#</strong> user(s)' : '')##(rollbackErrParam GT 0 ? ' with <strong>#rollbackErrParam#</strong> error(s)' : '')##(runIDParam GT 0 ? ". <a href='/admin/settings/migrations/grad_migration_detail.cfm?runID=#runIDParam#'>View details</a>." : "")#">
<cfelseif msgParam EQ "settings">
    <cfset showStatusModal = true>
    <cfset statusModalClass = "success">
    <cfset statusModalTitle = "Settings Saved">
    <cfset statusModalBody = "Settings saved.">
</cfif>

<!--- ── Load service & data ── --->
<cfset migrationService = createObject("component", "cfc.gradMigration_service").init()>
<cfset gradWindow       = migrationService.getGradYearWindow()>
<cfset autoExecute      = migrationService.isAutoExecuteEnabled()>
<cfset notifyEmail      = migrationService.getNotifyEmail()>
<cfset recentRuns       = []>
<cfset latestRun        = {}>
<cfset previewData      = {}>
<cfset dbOk             = true>
<cfset dbError          = "">
<cfset showPreview      = false>

<cftry>
    <cfset recentRuns = migrationService.getRecentRuns(10)>
    <cfset latestRun  = migrationService.getLatestRun()>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Handle preview request ── --->
<cfif structKeyExists(url, "preview") AND url.preview EQ "true">
    <cftry>
        <cfset previewYear = ( structKeyExists(url, "gradYear") AND isNumeric(url.gradYear) )
            ? val(url.gradYear) : gradWindow.graduatingYear>
        <cfset previewData = migrationService.preview( previewYear )>
        <cfset showPreview = true>
    <cfcatch type="any">
        <cfset showPreview = true>
        <cfset previewData = { success=false, message=(cfcatch.message & (len(trim(cfcatch.detail)) ? ' — ' & cfcatch.detail : '')) }>
    </cfcatch>
    </cftry>
</cfif>

<!--- ── Schedule helper — build the runner URL ── --->
<cfset schedulerUrl = request.siteBaseUrl & "/admin/settings/migrations/run_grad_migration.cfm?triggeredBy=scheduled&format=json">

<!--- ── Handle schedule form submission ── --->
<cfset scheduleMsg = "">
<cfset scheduleMsgClass = "">
<cfif structKeyExists(form, "scheduleAction") AND form.scheduleAction EQ "enable">
    <cftry>
        <cfschedule
            action      = "update"
            task        = "UHCO_GradMigration"
            operation   = "HTTPRequest"
            url         = "#schedulerUrl#"
            startDate   = "#dateFormat(now(), 'MM/DD/YYYY')#"
            startTime   = "12:01 AM"
            interval    = "daily"
            requesttimeout = "600"
            resolveurl  = "false"
            publish     = "false">
        <cfset scheduleMsg      = "Daily schedule enabled — migration will run at 12:01 AM each day (date guard restricts execution to Memorial Day weekend window).">
        <cfset scheduleMsgClass = "alert-success">
    <cfcatch>
        <cfset scheduleMsg      = "Could not register schedule: " & cfcatch.message>
        <cfset scheduleMsgClass = "alert-danger">
    </cfcatch>
    </cftry>
<cfelseif structKeyExists(form, "scheduleAction") AND form.scheduleAction EQ "disable">
    <cftry>
        <cfschedule action="delete" task="UHCO_GradMigration">
        <cfset scheduleMsg      = "Scheduled task removed.">
        <cfset scheduleMsgClass = "alert-success">
    <cfcatch>
        <cfset scheduleMsg      = "Could not remove schedule: " & cfcatch.message>
        <cfset scheduleMsgClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════ --->
<!--- ── Page content ─────────────────────────────────────────────────────── --->
<!--- ═══════════════════════════════════════════════════════════════════════ --->

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-grad-migration-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Graduation Migration</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-mortarboard-fill me-2"></i>Graduation Migration</h1>
<p class="text-muted">Migrate graduating students to alumni status around Memorial Day.</p>

<cfif NOT dbOk>
    <div class="alert alert-danger mt-3">
        <strong>Database Error:</strong> #encodeForHTML(dbError)#
        <br><small>The migration tables may not exist yet. Run <code>sql/create_grad_migration.sql</code> first.</small>
    </div>
</cfif>

<cfif dbOk>
<!--- ── Status Dashboard ── --->
<div class="row mt-4 g-3">
    <div class="col-md-3">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Graduating Class</h6>
                <h2 class="card-title text-primary">#gradWindow.graduatingYear#</h2>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Memorial Day #year(now())#</h6>
                <h4 class="card-title">#dateFormat(gradWindow.memorialDay, 'mmmm d, yyyy')#</h4>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Auto-Execute</h6>
                <h4 class="card-title">
                    <cfif autoExecute>
                        <span class="badge bg-success"><i class="bi bi-check-circle me-1"></i>ON</span>
                    <cfelse>
                        <span class="badge bg-danger"><i class="bi bi-x-circle me-1"></i>OFF</span>
                    </cfif>
                </h4>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-center h-100 settings-shell">
            <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">Latest Run</h6>
                <cfif structIsEmpty(latestRun)>
                    <h4 class="card-title text-muted">None</h4>
                <cfelse>
                    <h4 class="card-title">
                        <cfswitch expression="#latestRun.STATUS#">
                            <cfcase value="completed"><span class="badge bg-success">#latestRun.STATUS#</span></cfcase>
                            <cfcase value="failed"><span class="badge bg-danger">#latestRun.STATUS#</span></cfcase>
                            <cfcase value="rolled_back"><span class="badge bg-warning text-dark">#latestRun.STATUS#</span></cfcase>
                            <cfcase value="executing"><span class="badge bg-info">#latestRun.STATUS#</span></cfcase>
                            <cfdefaultcase><span class="badge bg-secondary">#latestRun.STATUS#</span></cfdefaultcase>
                        </cfswitch>
                    </h4>
                    <small class="text-muted">Class of #latestRun.GRADYEAR#</small>
                </cfif>
            </div>
        </div>
    </div>
</div>

<!--- ── Preview Panel ── --->
<div class="card mt-4 settings-shell settings-summary-card">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5 class="mb-0"><i class="bi bi-eye me-2"></i>Preview Migration</h5>
        <a href="/admin/settings/migrations/grad_migration.cfm?preview=true&gradYear=#gradWindow.graduatingYear#"
           class="btn btn-outline-primary btn-sm">
            <i class="bi bi-search me-1"></i>Preview Class of #gradWindow.graduatingYear#
        </a>
    </div>
    <cfif showPreview AND structKeyExists(previewData, "success") AND previewData.success>
        <div class="card-body">
            <div class="alert alert-info mb-3">
                <strong>#previewData.totalStudents#</strong> student(s) found with
                <strong>current-student</strong> flag and grad year <strong>#previewData.gradYear#</strong>.
            </div>
            <cfif previewData.totalStudents GT 0>
                <div class="table-responsive">
                    <table class="table table-sm table-striped settings-table">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Grad Year</th>
                                <th>Flag</th>
                                <th>Title1</th>
                                <th>Data Quality Exclusions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <cfloop array="#previewData.students#" index="s">
                                <tr>
                                    <td>
                                        <a href="/admin/users/edit.cfm?userID=#s.USERID#">
                                            #encodeForHTML(s.LASTNAME)#, #encodeForHTML(s.FIRSTNAME)#
                                        </a>
                                    </td>
                                    <td>#s.CURRENTGRADYEAR#</td>
                                    <td>Current-Student &gt;&gt; Alumni</td>
                                    <td>#encodeForHTML( (len(trim(s.TITLE1 ?: "")) ? s.TITLE1 : "(blank)") )# &gt;&gt; Alumni</td>
                                    <td>Student-specific set &gt;&gt; Alumni-specific set</td>
                                </tr>
                            </cfloop>
                        </tbody>
                    </table>
                </div>

                <!--- Execute button --->
                <form method="post" action="/admin/settings/migrations/run_grad_migration.cfm?force=true"
                      class="js-confirm-submit"
                      data-confirm-title="Execute Migration"
                      data-confirm-class="danger"
                      data-confirm-message="This will migrate #previewData.totalStudents# student(s) from current-student to alumni. This action can be rolled back. Continue?"
                      data-confirm-ok="Execute">
                    <input type="hidden" name="triggeredBy" value="#encodeForHTMLAttribute(session.user.displayName ?: 'admin')#">
                    <button type="submit" class="btn btn-danger">
                        <i class="bi bi-play-fill me-1"></i>Execute Migration — Class of #previewData.gradYear#
                    </button>
                </form>
            </cfif>
        </div>
    <cfelseif showPreview AND structKeyExists(previewData, "success") AND NOT previewData.success>
        <div class="card-body">
            <div class="alert alert-warning">#encodeForHTML(previewData.message ?: 'No results')#</div>
        </div>
    </cfif>
</div>

<!--- ── Settings Panel ── --->
<div class="card mt-4 settings-shell settings-summary-card">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-gear me-2"></i>Settings</h5>
    </div>
    <div class="card-body">
        <form method="post" action="/admin/settings/migrations/save_grad_migration_settings.cfm">
            <div class="row g-3 align-items-end">
                <div class="col-md-3">
                    <label class="form-label fw-bold">Auto-Execute on Schedule</label>
                    <div class="form-check form-switch">
                        <input class="form-check-input" type="checkbox" name="autoExecute" value="true"
                            id="autoExecToggle" <cfif autoExecute>checked</cfif>>
                        <label class="form-check-label" for="autoExecToggle">
                            <cfif autoExecute>Enabled<cfelse>Disabled</cfif>
                        </label>
                    </div>
                </div>
                <div class="col-md-5">
                    <label for="notifyEmail" class="form-label fw-bold">Notification Email</label>
                    <input type="email" class="form-control" id="notifyEmail" name="notifyEmail"
                        value="#encodeForHTMLAttribute(notifyEmail)#"
                        placeholder="admin@uh.edu">
                </div>
                <div class="col-md-4">
                    <button type="submit" class="btn btn-primary">
                        <i class="bi bi-save me-1"></i>Save Settings
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

<!--- ── Schedule Panel ── --->
<div class="card mt-4 settings-shell settings-summary-card">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-clock me-2"></i>Scheduled Task</h5>
    </div>
    <div class="card-body">
        <cfif len(scheduleMsg)>
            <div class="alert #scheduleMsgClass#">#encodeForHTML(scheduleMsg)#</div>
        </cfif>
        <p class="mb-2">
            The scheduled task runs daily at <strong>12:01 AM</strong> but only executes during the
            Memorial Day weekend window (Saturday through Tuesday). A date guard prevents execution
            outside this window. Auto-execute must be ON for the scheduled task to proceed.
        </p>
        <div class="d-flex gap-2">
            <form method="post">
                <input type="hidden" name="scheduleAction" value="enable">
                <button type="submit" class="btn btn-outline-success btn-sm">
                    <i class="bi bi-play-circle me-1"></i>Enable Schedule
                </button>
            </form>
            <form method="post">
                <input type="hidden" name="scheduleAction" value="disable">
                <button type="submit" class="btn btn-outline-danger btn-sm">
                    <i class="bi bi-stop-circle me-1"></i>Remove Schedule
                </button>
            </form>
        </div>
        <p class="text-muted mt-2 mb-0">
            <small>Scheduler URL: <code>#encodeForHTML(schedulerUrl)#</code></small>
        </p>
    </div>
</div>

<!--- ── Run History ── --->
<div class="card mt-4 settings-shell settings-summary-card">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-clock-history me-2"></i>Run History</h5>
    </div>
    <div class="card-body">
        <cfif arrayLen(recentRuns) EQ 0>
            <p class="text-muted">No migration runs yet.</p>
        <cfelse>
            <div class="table-responsive">
                <table class="table table-sm table-striped settings-table">
                    <thead>
                        <tr>
                            <th>Run</th>
                            <th>Grad Year</th>
                            <th>Status</th>
                            <th>Mode</th>
                            <th>Targeted</th>
                            <th>Migrated</th>
                            <th>Errors</th>
                            <th>Triggered By</th>
                            <th>Executed</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#recentRuns#" index="r">
                            <tr>
                                <td><strong>###r.RUNID#</strong></td>
                                <td>#r.GRADYEAR#</td>
                                <td>
                                    <cfswitch expression="#r.STATUS#">
                                        <cfcase value="completed"><span class="badge bg-success">#r.STATUS#</span></cfcase>
                                        <cfcase value="completed_w_errors"><span class="badge bg-warning text-dark">#r.STATUS#</span></cfcase>
                                        <cfcase value="failed"><span class="badge bg-danger">#r.STATUS#</span></cfcase>
                                        <cfcase value="rolled_back"><span class="badge bg-warning text-dark">#r.STATUS#</span></cfcase>
                                        <cfcase value="executing"><span class="badge bg-info">#r.STATUS#</span></cfcase>
                                        <cfdefaultcase><span class="badge bg-secondary">#r.STATUS#</span></cfdefaultcase>
                                    </cfswitch>
                                </td>
                                <td>#r.MODE#</td>
                                <td>#r.TOTALTARGETED#</td>
                                <td>#r.TOTALMIGRATED#</td>
                                <td><cfif r.TOTALERRORS GT 0><span class="text-danger fw-bold">#r.TOTALERRORS#</span><cfelse>0</cfif></td>
                                <td>#encodeForHTML(r.TRIGGEREDBY)#</td>
                                <td>#dateTimeFormat(r.EXECUTEDAT, 'MM/dd/yyyy hh:nn tt')#</td>
                                <td>
                                    <a href="/admin/settings/migrations/grad_migration_detail.cfm?runID=#r.RUNID#"
                                       class="btn btn-outline-primary btn-sm" title="View Details">
                                        <i class="bi bi-eye"></i>
                                    </a>
                                    <cfif listFindNoCase("completed,completed_w_errors,failed", r.STATUS)>
                                        <form method="post" action="/admin/settings/migrations/save_grad_migration_settings.cfm"
                                              class="d-inline js-confirm-submit"
                                              data-confirm-title="Confirm Rollback"
                                              data-confirm-class="warning"
                                              data-confirm-message="Roll back migration run ###r.RUNID# (Class of #r.GRADYEAR#)? This will revert all migrated users back to current-student status."
                                              data-confirm-ok="Rollback">
                                            <input type="hidden" name="action" value="rollback">
                                            <input type="hidden" name="runID" value="#r.RUNID#">
                                            <button type="submit" class="btn btn-outline-warning btn-sm" title="Rollback">
                                                <i class="bi bi-arrow-counterclockwise"></i>
                                            </button>
                                        </form>
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

<div class="modal fade" id="confirmActionModal" tabindex="-1" aria-labelledby="confirmActionModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="confirmActionModalLabel">Confirm Action</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body" id="confirmActionModalBody">Are you sure?</div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="confirmActionModalOk">Continue</button>
            </div>
        </div>
    </div>
</div>

<cfif showStatusModal>
    <div class="modal fade" id="migrationStatusModal" tabindex="-1" aria-labelledby="migrationStatusModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-#statusModalClass#">
                <div class="modal-header bg-#statusModalClass# text-white">
                    <h5 class="modal-title" id="migrationStatusModalLabel">#statusModalTitle#</h5>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">#statusModalBody#</div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" data-bs-dismiss="modal">OK</button>
                </div>
            </div>
        </div>
    </div>

    <script>
    document.addEventListener('DOMContentLoaded', function () {
        var el = document.getElementById('migrationStatusModal');
        if (el && window.bootstrap && bootstrap.Modal) {
            var modal = new bootstrap.Modal(el, { backdrop: 'static' });
            modal.show();
        }
    });
    </script>
</cfif>

<script>
document.addEventListener('DOMContentLoaded', function () {
    var confirmModalEl = document.getElementById('confirmActionModal');
    if (!confirmModalEl || !(window.bootstrap && bootstrap.Modal)) {
        return;
    }

    var confirmModal = new bootstrap.Modal(confirmModalEl);
    var titleEl = document.getElementById('confirmActionModalLabel');
    var bodyEl = document.getElementById('confirmActionModalBody');
    var okBtn = document.getElementById('confirmActionModalOk');
    var pendingForm = null;

    document.querySelectorAll('form.js-confirm-submit').forEach(function (form) {
        form.addEventListener('submit', function (evt) {
            evt.preventDefault();
            pendingForm = form;

            var title = form.getAttribute('data-confirm-title') || 'Confirm Action';
            var msg = form.getAttribute('data-confirm-message') || 'Are you sure you want to continue?';
            var okText = form.getAttribute('data-confirm-ok') || 'Continue';
            var style = form.getAttribute('data-confirm-class') || 'primary';

            titleEl.textContent = title;
            bodyEl.textContent = msg;
            okBtn.textContent = okText;
            okBtn.className = 'btn btn-' + style;

            confirmModal.show();
        });
    });

    okBtn.addEventListener('click', function () {
        if (pendingForm) {
            var formToSubmit = pendingForm;
            pendingForm = null;
            confirmModal.hide();
            formToSubmit.submit();
        }
    });
});
</script>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
