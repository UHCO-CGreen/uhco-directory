<cfif NOT application.authService.hasRole("SUPER_ADMIN") AND NOT request.hasPermission("reporting.duplicate_users.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset duplicateSvc = createObject("component", "cfc.duplicateUsers_service").init()>
<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>

<cfset msgParam = trim(url.msg ?: "")>
<cfset errParam = trim(url.err ?: "")>
<cfset viewRunID = (isNumeric(url.runID ?: "") AND val(url.runID) GT 0) ? val(url.runID) : 0>
<cfset statusFilter = lCase(trim(url.status ?: "pending"))>
<cfif NOT listFindNoCase("pending,ignored,merged,all", statusFilter)>
    <cfset statusFilter = "pending">
</cfif>

<cfset scheduleMsg = "">
<cfset scheduleMsgClass = "alert-success">
<cfset availableRuleModes = [
    { value = "alumni_vs_alumni", label = "Alumni vs Alumni" },
    { value = "alumni_vs_faculty", label = "Alumni vs Faculty (Fulltime/Adjunct)" },
    { value = "alumni_vs_other", label = "Alumni vs Other (not Faculty/Alumni)" },
    { value = "staff_only", label = "Staff Only (Staff / Temporary-Staff)" },
    { value = "all", label = "ALL" }
]>
<cfset selectedRuleMode = duplicateSvc.normalizeRuleMode(url.mode ?: "")>
<cfif selectedRuleMode EQ "all" AND NOT structKeyExists(url, "mode")>
    <cfset selectedRuleMode = "alumni_vs_faculty">
</cfif>
<cfset scheduledRuleMode = duplicateSvc.normalizeRuleMode(appConfigService.getValue("scheduled_tasks.uhco_duplicateusersreport.scan_mode", "alumni_vs_faculty"))>

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <cfif action EQ "ignorePair" AND isNumeric(form.pairID ?: "")>
        <cfset duplicateSvc.ignorePair(val(form.pairID), trim(form.reason ?: ""))>
        <cflocation url="#request.webRoot#/admin/reporting/duplicate_users_report.cfm?runID=#urlEncodedFormat(viewRunID)#&status=#urlEncodedFormat(statusFilter)#&msg=ignored" addtoken="false">
    <cfelseif action EQ "unignorePair" AND isNumeric(form.pairID ?: "")>
        <cfset duplicateSvc.unignorePair(val(form.pairID))>
        <cflocation url="#request.webRoot#/admin/reporting/duplicate_users_report.cfm?runID=#urlEncodedFormat(viewRunID)#&status=#urlEncodedFormat(statusFilter)#&msg=restored" addtoken="false">
    <cfelseif action EQ "enableSchedule">
        <cfset scheduleTaskToken = trim(appConfigService.getValue("scheduled_tasks.shared_secret", ""))>
        <cfset schedulerUrl = request.siteBaseUrl & "/admin/settings/scheduled-tasks/tasks/run_duplicate_users_report_task.cfm?triggeredBy=scheduled&format=json">

        <cfif NOT len(scheduleTaskToken)>
            <cfset scheduleMsg = "Could not register schedule: scheduled_tasks.shared_secret is not configured.">
            <cfset scheduleMsgClass = "alert-danger">
        <cfelse>
            <cftry>
                <cfschedule
                    action = "update"
                    task = "UHCO_DuplicateUsersReport"
                    operation = "HTTPRequest"
                    url = "#schedulerUrl#"
                    username = "scheduler"
                    password = "#scheduleTaskToken#"
                    startDate = "#dateFormat(now(), 'mm/dd/yyyy')#"
                    startTime = "05:00 AM"
                    interval = "monthly"
                    requesttimeout = "600"
                    resolveurl = "false"
                    publish = "false">
                <cfset scheduleMsg = "Monthly schedule enabled. Duplicate scan will run once per month at 5:00 AM.">
                <cfset scheduleMsgClass = "alert-success">
            <cfcatch>
                <cfset scheduleMsg = "Could not register schedule: " & cfcatch.message>
                <cfset scheduleMsgClass = "alert-danger">
            </cfcatch>
            </cftry>
        </cfif>
    <cfelseif action EQ "saveScheduledMode">
        <cfset scheduledRuleModeCandidate = duplicateSvc.normalizeRuleMode(form.scheduledRuleMode ?: "")>
        <cfset appConfigService.setValue("scheduled_tasks.uhco_duplicateusersreport.scan_mode", scheduledRuleModeCandidate)>
        <cfset scheduledRuleMode = scheduledRuleModeCandidate>
        <cfset scheduleMsg = "Scheduled default rule mode saved.">
        <cfset scheduleMsgClass = "alert-success">
    </cfif>
</cfif>

<cfset recentRuns = duplicateSvc.getRecentRuns(12)>
<cfset currentRun = {}>
<cfif viewRunID GT 0>
    <cfset currentRun = duplicateSvc.getRunByID(viewRunID)>
</cfif>
<cfif structIsEmpty(currentRun) AND arrayLen(recentRuns)>
    <cfset currentRun = recentRuns[1]>
</cfif>

<cfset summary = { PENDINGCOUNT = 0, IGNOREDCOUNT = 0, MERGEDCOUNT = 0, TOTALCOUNT = 0 }>
<cfset pairs = []>

<cfif NOT structIsEmpty(currentRun)>
    <cfset summary = duplicateSvc.getStatusSummaryByRun(currentRun.RUNID)>
    <cfset pairs = duplicateSvc.getPairsByRun(currentRun.RUNID, statusFilter EQ "all" ? "" : statusFilter)>
</cfif>

<cfset scheduleTaskToken = trim(appConfigService.getValue("scheduled_tasks.shared_secret", ""))>
<cfset schedulerUrl = request.siteBaseUrl & "/admin/settings/scheduled-tasks/tasks/run_duplicate_users_report_task.cfm?triggeredBy=scheduled&format=json">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>
<h1 class="mb-1">Duplicate Users Report</h1>
<p class="text-muted">Monthly/manual scan of likely duplicate users across all user data tables.</p>

<cfif msgParam EQ "ran">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Duplicate scan completed.</div>
<cfelseif msgParam EQ "ignored">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Pair marked as ignored.</div>
<cfelseif msgParam EQ "restored">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Pair returned to pending.</div>
<cfelseif msgParam EQ "error">
    <div class="alert alert-danger mt-3"><strong>Run failed:</strong> #encodeForHTML(errParam)#</div>
</cfif>

<cfif len(scheduleMsg)>
    <div class="alert #scheduleMsgClass# mt-2">#encodeForHTML(scheduleMsg)#</div>
</cfif>

<div class="d-flex flex-wrap align-items-center gap-2 mt-3 mb-4">
    <a href="/admin/reporting/run_duplicate_users_report.cfm?scan=quick&mode=#urlEncodedFormat(selectedRuleMode)#" class="btn btn-ui-filter">
        <i class="bi bi-play-fill"></i> Run Now (Quick)
    </a>
    <button class="btn btn-ui-cancel btn-sm" type="button" data-bs-toggle="collapse" data-bs-target="##schedulePanel">
        <i class="bi bi-clock"></i> Schedule
    </button>
    <button class="btn btn-ui-cancel btn-sm" type="button" data-bs-toggle="collapse" data-bs-target="##historyPanel">
        <i class="bi bi-clock-history"></i> Run History
    </button>
</div>

<div class="card card-body mb-3">
    <div class="small text-muted mb-2">Manual run mode</div>
    <div class="btn-group flex-wrap" role="group">
        <cfloop array="#availableRuleModes#" index="rm">
            <a href="?mode=#urlEncodedFormat(rm.value)#&status=#urlEncodedFormat(statusFilter)#&runID=#urlEncodedFormat(viewRunID)#" class="btn btn-sm #selectedRuleMode EQ rm.value ? "btn-ui-filter" : "btn-ui-cancel"#">#encodeForHTML(rm.label)#</a>
        </cfloop>
    </div>
</div>

<div class="collapse mb-3" id="schedulePanel">
    <div class="card card-body">
        <h6 class="mb-2">Monthly Scheduled Run</h6>
        <p class="text-muted small mb-2">Use this endpoint in ColdFusion Scheduler for monthly duplicate scanning. Scheduled default mode currently: <strong>#encodeForHTML(scheduledRuleMode)#</strong></p>
        <div class="input-group mb-3 report-scheduler-input">
            <input type="text" class="form-control form-control-sm font-monospace" value="#encodeForHTMLAttribute(schedulerUrl)#" readonly id="dupSchedUrlInput">
            <button class="btn btn-sm btn-ui-go" data-clipboard-source="dupSchedUrlInput">
                <i class="bi bi-clipboard"></i>
            </button>
        </div>
        <form method="post">
            <input type="hidden" name="action" value="enableSchedule">
            <button type="submit" class="btn btn-sm btn-ui-save"><i class="bi bi-check-circle"></i> Enable Monthly Schedule</button>
        </form>
        <form method="post" class="mt-3 pt-3 border-top">
            <input type="hidden" name="action" value="saveScheduledMode">
            <label class="form-label form-label-sm">Scheduled default rule mode</label>
            <div class="d-flex gap-2 flex-wrap align-items-center">
                <select name="scheduledRuleMode" class="form-select form-select-sm" style="max-width: 420px;">
                    <cfloop array="#availableRuleModes#" index="rm">
                        <option value="#encodeForHTMLAttribute(rm.value)#" #scheduledRuleMode EQ rm.value ? "selected" : ""#>#encodeForHTML(rm.label)#</option>
                    </cfloop>
                </select>
                <button type="submit" class="btn btn-sm btn-ui-save">Save Scheduled Mode</button>
            </div>
        </form>
    </div>
</div>

<div class="collapse mb-3" id="historyPanel">
    <div class="card card-body">
        <h6 class="mb-2">Recent Runs</h6>
        <cfif arrayLen(recentRuns) EQ 0>
            <p class="text-muted">No runs yet.</p>
        <cfelse>
            <table class="table table-sm table-bordered mb-0">
                <thead class="table-dark">
                    <tr>
                        <th>Run ID</th>
                        <th>Date/Time (UTC)</th>
                        <th>Triggered By</th>
                        <th>Users</th>
                        <th>Pairs</th>
                        <th>Status</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                <cfloop from="1" to="#arrayLen(recentRuns)#" index="i">
                    <cfset r = recentRuns[i]>
                    <cfset rowActive = (NOT structIsEmpty(currentRun) AND r.RUNID EQ currentRun.RUNID) ? "table-primary" : "">
                    <tr class="#rowActive#">
                        <td>#r.RUNID#</td>
                        <td>#dateTimeFormat(r.RUNAT, "mmm d, yyyy HH:nn")#</td>
                        <td>#encodeForHTML(r.TRIGGEREDBY ?: "")#</td>
                        <td>#val(r.TOTALUSERS ?: 0)#</td>
                        <td>#val(r.TOTALPAIRS ?: 0)#</td>
                        <td>#encodeForHTML(r.STATUS ?: "")#</td>
                        <td><a href="?runID=#r.RUNID#&status=#urlEncodedFormat(statusFilter)#" class="btn btn-sm btn-ui-go py-0 px-1">View</a></td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </cfif>
    </div>
</div>

<cfif structIsEmpty(currentRun)>
    <div class="card border-0 text-center py-5">
        <div class="card-body">
            <i class="bi bi-people display-4 text-muted"></i>
            <h4 class="mt-3 text-muted">No duplicate scan data yet</h4>
            <p class="text-muted">Click <strong>Run Now</strong> to generate the first report.</p>
        </div>
    </div>
<cfelse>
    <div class="d-flex flex-wrap align-items-center gap-3 mb-3">
        <span class="text-muted small">
            Run ##<strong>#currentRun.RUNID#</strong>
            &mdash; #dateTimeFormat(currentRun.RUNAT, "mmmm d, yyyy HH:nn")# UTC
            &mdash; triggered by <em>#encodeForHTML(currentRun.TRIGGEREDBY ?: "")#</em>
            &mdash; #val(currentRun.TOTALUSERS ?: 0)# users scanned
        </span>
        <span class="badge bg-dark fs-6">#val(currentRun.TOTALPAIRS ?: 0)# pair(s)</span>
    </div>

    <div class="row g-3 mb-3">
        <div class="col-md-3"><div class="card card-body py-2"><strong>#summary.PENDINGCOUNT#</strong><small class="text-muted">Pending</small></div></div>
        <div class="col-md-3"><div class="card card-body py-2"><strong>#summary.IGNOREDCOUNT#</strong><small class="text-muted">Ignored</small></div></div>
        <div class="col-md-3"><div class="card card-body py-2"><strong>#summary.MERGEDCOUNT#</strong><small class="text-muted">Merged</small></div></div>
        <div class="col-md-3"><div class="card card-body py-2"><strong>#summary.TOTALCOUNT#</strong><small class="text-muted">Total</small></div></div>
    </div>

    <ul class="nav nav-pills mb-3">
        <li class="nav-item"><a class="nav-link #statusFilter EQ 'pending' ? 'active' : ''#" href="?runID=#currentRun.RUNID#&status=pending">Pending</a></li>
        <li class="nav-item"><a class="nav-link #statusFilter EQ 'ignored' ? 'active' : ''#" href="?runID=#currentRun.RUNID#&status=ignored">Ignored</a></li>
        <li class="nav-item"><a class="nav-link #statusFilter EQ 'merged' ? 'active' : ''#" href="?runID=#currentRun.RUNID#&status=merged">Merged</a></li>
        <li class="nav-item"><a class="nav-link #statusFilter EQ 'all' ? 'active' : ''#" href="?runID=#currentRun.RUNID#&status=all">All</a></li>
    </ul>

    <cfif arrayLen(pairs) EQ 0>
        <div class="alert alert-secondary">No pairs for this run/filter.</div>
    <cfelse>
        <div class="table-responsive">
            <table class="table table-sm table-bordered align-middle">
                <thead class="table-dark">
                    <tr>
                        <th>Pair</th>
                        <th>User A</th>
                        <th>User B</th>
                        <th>Signals</th>
                        <th>Confidence</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop from="1" to="#arrayLen(pairs)#" index="i">
                    <cfset p = pairs[i]>
                    <cfset signalItems = duplicateSvc.parseSignalsJSON(p.MATCHSIGNALS ?: "[]")>
                    <tr>
                        <td>## #p.PAIRID#</td>
                        <td>
                            <div><strong>#val(p.USERID_A)#</strong> &mdash; #encodeForHTML(trim((p.USERAFIRSTNAME ?: "") & " " & (p.USERALASTNAME ?: "")))#</div>
                            <div class="small text-muted">#encodeForHTML(p.USERAEMAIL ?: "")#</div>
                            <div class="small text-muted">Flags: #encodeForHTML(p.USERAFLAGS ?: "none")#</div>
                            <div class="small text-muted">Grad Year: #val(p.USERAGRADYEAR ?: 0)#</div>
                        </td>
                        <td>
                            <div><strong>#val(p.USERID_B)#</strong> &mdash; #encodeForHTML(trim((p.USERBFIRSTNAME ?: "") & " " & (p.USERBLASTNAME ?: "")))#</div>
                            <div class="small text-muted">#encodeForHTML(p.USERBEMAIL ?: "")#</div>
                            <div class="small text-muted">Flags: #encodeForHTML(p.USERBFLAGS ?: "none")#</div>
                            <div class="small text-muted">Grad Year: #val(p.USERBGRADYEAR ?: 0)#</div>
                        </td>
                        <td>
                            <cfif arrayLen(signalItems) EQ 0>
                                <span class="badge bg-secondary">No signal details</span>
                            <cfelse>
                                <cfloop from="1" to="#arrayLen(signalItems)#" index="sIdx">
                                    <cfset s = signalItems[sIdx]>
                                    <span class="badge bg-light text-dark border me-1 mb-1">#encodeForHTML(duplicateSvc.signalLabel(s.type ?: "", s.value ?: ""))#</span>
                                </cfloop>
                            </cfif>
                        </td>
                        <td><span class="badge #duplicateSvc.scoreBadgeClass(val(p.CONFIDENCESCORE ?: 0))#">#val(p.CONFIDENCESCORE ?: 0)#</span></td>
                        <td><span class="badge #p.STATUS EQ 'pending' ? 'bg-warning text-dark' : (p.STATUS EQ 'ignored' ? 'bg-secondary' : 'bg-success')#">#encodeForHTML(p.STATUS)#</span></td>
                        <td>
                            <a href="/admin/users/merge.cfm?pairID=#p.PAIRID#" class="btn btn-sm btn-ui-go py-0 px-1 mb-1">View</a>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
    </cfif>
</cfif>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
