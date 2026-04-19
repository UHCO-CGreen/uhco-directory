<!--- ── Scheduled Tasks Manager ─────────────────────────────────────────── --->
<cfif NOT request.hasRole("SUPER_ADMIN")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Task definitions ─────────────────────────────────────────────────── --->
<cfset baseUrl = request.siteBaseUrl>

<cfset tasks = [
    {
        key            = "UHCO_GradMigration",
        label          = "Graduation Migration",
        icon           = "bi-mortarboard",
        color          = "primary",
        description    = "Migrates graduating students to alumni status. Date guard restricts execution to Memorial Day weekend window.",
        endpoint       = "/admin/settings/migrations/run_grad_migration.cfm?triggeredBy=scheduled&format=json",
        startTime      = "12:01 AM",
        timeout        = 600,
        dashboardLink  = "/admin/settings/migrations/",
        runNowLink     = "/admin/settings/migrations/run_grad_migration.cfm?force=true"
    },
    {
        key            = "UHCO_BulkExclusions",
        label          = "Bulk Exclusions",
        icon           = "bi-funnel",
        color          = "warning",
        description    = "Runs all 6 data quality exclusion rule sets (adjunct faculty, alumni, current students, faculty, retirees, staff).",
        endpoint       = "/admin/settings/bulk-exclusions/run_scheduled.cfm?triggeredBy=scheduled&format=json",
        startTime      = "01:00 AM",
        timeout        = 900,
        dashboardLink  = "/admin/settings/bulk-exclusions/",
        runNowLink     = ""
    },
    {
        key            = "UHCO_DataQualityReport",
        label          = "Data Quality Report",
        icon           = "bi-clipboard-check",
        color          = "success",
        description    = "Scans all users for data quality issues and generates an issue-level report.",
        endpoint       = "/admin/reporting/run_data_quality_report.cfm?triggeredBy=scheduled&format=json",
        startTime      = "02:00 AM",
        timeout        = 300,
        dashboardLink  = "/admin/reporting/data_quality_report.cfm",
        runNowLink     = "/admin/reporting/run_data_quality_report.cfm"
    },
    {
        key            = "UHCO_UHSyncReport",
        label          = "UH API Sync Report",
        icon           = "bi-arrow-left-right",
        color          = "info",
        description    = "Compares local user data against UH API to detect field-level diffs and membership changes.",
        endpoint       = "/admin/reporting/run_uh_sync_report.cfm?triggeredBy=scheduled&format=json",
        startTime      = "03:00 AM",
        timeout        = 600,
        dashboardLink  = "/admin/reporting/uh_sync_report.cfm",
        runNowLink     = "/admin/reporting/run_uh_sync_report.cfm"
    }
]>

<!--- ── Query CF Scheduler for active tasks ──────────────────────────────── --->
<cfset enabledTasks = {}>
<cftry>
    <cfschedule action="list" result="cfTasks">
    <cfloop query="cfTasks">
        <cfset enabledTasks[cfTasks.task] = true>
    </cfloop>
<cfcatch>
    <!--- cfschedule list not supported or permission denied — assume unknown --->
    <cfset enabledTasks = {}>
</cfcatch>
</cftry>

<!--- ── Load latest run info from each DAO ───────────────────────────────── --->
<cfset dqDAO   = createObject("component", "dao.dataQuality_DAO").init()>
<cfset uhDAO   = createObject("component", "dao.uhSync_DAO").init()>
<cfset gmDAO   = createObject("component", "dao.gradMigration_DAO").init()>
<cfset beDAO   = createObject("component", "dao.bulkExclusions_DAO").init()>

<cfset latestRuns = {}>
<cftry>
    <cfset dqRuns = dqDAO.getRecentRuns(1)>
    <cfset latestRuns["UHCO_DataQualityReport"] = arrayLen(dqRuns) ? dqRuns[1] : {}>
<cfcatch><cfset latestRuns["UHCO_DataQualityReport"] = {}></cfcatch>
</cftry>
<cftry>
    <cfset latestRuns["UHCO_UHSyncReport"] = uhDAO.getLatestRun()>
<cfcatch><cfset latestRuns["UHCO_UHSyncReport"] = {}></cfcatch>
</cftry>
<cftry>
    <cfset latestRuns["UHCO_GradMigration"] = gmDAO.getLatestRun()>
<cfcatch><cfset latestRuns["UHCO_GradMigration"] = {}></cfcatch>
</cftry>
<cftry>
    <cfset beRuns = beDAO.getRecentRuns(1)>
    <cfset latestRuns["UHCO_BulkExclusions"] = arrayLen(beRuns) ? beRuns[1] : {}>
<cfcatch><cfset latestRuns["UHCO_BulkExclusions"] = {}></cfcatch>
</cftry>

<!--- ── Handle POST actions ──────────────────────────────────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cfset action  = trim(form.action ?: "")>
    <cfset taskKey = trim(form.taskKey ?: "")>

    <!--- Validate taskKey against known tasks --->
    <cfset validTask = false>
    <cfset taskDef   = {}>
    <cfloop from="1" to="#arrayLen(tasks)#" index="ti">
        <cfif tasks[ti].key EQ taskKey>
            <cfset validTask = true>
            <cfset taskDef   = tasks[ti]>
            <cfbreak>
        </cfif>
    </cfloop>

    <cfif NOT validTask>
        <cfset actionMessage      = "Invalid task key.">
        <cfset actionMessageClass = "alert-danger">
    <cfelseif action EQ "enable">
        <cftry>
            <cfschedule
                action         = "update"
                task           = "#taskKey#"
                operation      = "HTTPRequest"
                url            = "#baseUrl##taskDef.endpoint#"
                startDate      = "#dateFormat(now(), 'MM/DD/YYYY')#"
                startTime      = "#taskDef.startTime#"
                interval       = "daily"
                requesttimeout = "#taskDef.timeout#"
                resolveurl     = "false"
                publish        = "false">
            <cfset actionMessage = "<strong>#encodeForHTML(taskDef.label)#</strong> scheduled daily at #encodeForHTML(taskDef.startTime)#.">
        <cfcatch>
            <cfset actionMessage      = "Could not enable schedule: #encodeForHTML(cfcatch.message)#">
            <cfset actionMessageClass = "alert-danger">
        </cfcatch>
        </cftry>
    <cfelseif action EQ "disable">
        <cftry>
            <cfschedule action="delete" task="#taskKey#">
            <cfset actionMessage = "<strong>#encodeForHTML(taskDef.label)#</strong> schedule removed.">
        <cfcatch>
            <cfset actionMessage      = "Could not disable schedule: #encodeForHTML(cfcatch.message)#">
            <cfset actionMessageClass = "alert-danger">
        </cfcatch>
        </cftry>
    </cfif>
</cfif>

<!--- ── Page content ─────────────────────────────────────────────────────── --->
<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Scheduled Tasks</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-clock-history me-2"></i>Scheduled Tasks</h1>
        <p class="text-muted mb-0">Enable, disable, and monitor all automated ColdFusion scheduled tasks.</p>
    </div>
    <span class='badge #(request.isProduction ? "bg-danger" : "bg-success")# float-end'>Currently in: #encodeForHTML(ucase(left(request.environmentName, 1)) & mid(request.environmentName, 2, len(request.environmentName)))#</span>
</div>

<cfif len(actionMessage)>
    <div class="alert #actionMessageClass# alert-dismissible fade show" role="alert">
        #actionMessage#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>

<!--- ── Nightly Run-Order Timeline ───────────────────────────────────────── --->
<div class="card shadow-sm mb-4">
    <div class="card-header bg-dark text-white">
        <h6 class="mb-0"><i class="bi bi-calendar-event me-2"></i>Nightly Run Order</h6>
    </div>
    <div class="card-body py-3">
        <div class="d-flex flex-wrap align-items-center gap-2">
            <cfloop from="1" to="#arrayLen(tasks)#" index="i">
                <span class="badge bg-#tasks[i].color# bg-opacity-75 fs-6 py-2 px-3">
                    <i class="bi #tasks[i].icon# me-1"></i>
                    #encodeForHTML(tasks[i].startTime)#
                    <span class="ms-1 fw-normal">#encodeForHTML(tasks[i].label)#</span>
                </span>
                <cfif i LT arrayLen(tasks)>
                    <i class="bi bi-arrow-right text-muted"></i>
                </cfif>
            </cfloop>
        </div>
    </div>
</div>

<!--- ── Task Cards ───────────────────────────────────────────────────────── --->
<div class="row g-4">
<cfloop from="1" to="#arrayLen(tasks)#" index="i">
    <cfset t = tasks[i]>
    <cfset lr = structKeyExists(latestRuns, t.key) ? latestRuns[t.key] : {}>
    <cfset hasRun = NOT structIsEmpty(lr)>
    <cfset fullUrl = baseUrl & t.endpoint>

    <div class="col-lg-6">
        <div class="card shadow-sm h-100">
            <div class="card-header bg-#t.color# bg-opacity-10 d-flex justify-content-between align-items-center">
                <h5 class="mb-0 text-#t.color#">
                    <i class="bi #t.icon# me-2"></i>#encodeForHTML(t.label)#
                </h5>
                <cfif structKeyExists(enabledTasks, t.key)>
                    <span class="badge bg-success"><i class="bi bi-check-circle me-1"></i>Enabled</span>
                <cfelse>
                    <span class="badge bg-secondary">Disabled</span>
                </cfif>
            </div>
            <div class="card-body">
                <p class="small text-muted mb-3">#encodeForHTML(t.description)#</p>

                <!--- Schedule details --->
                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <div class="small text-muted">Scheduled Time</div>
                        <strong>#encodeForHTML(t.startTime)#</strong> <span class="text-muted small">daily</span>
                    </div>
                    <div class="col-6">
                        <div class="small text-muted">Timeout</div>
                        <strong>#t.timeout#s</strong> <span class="text-muted small">(#int(t.timeout / 60)# min)</span>
                    </div>
                </div>

                <!--- Last run info --->
                <div class="mb-3">
                    <div class="small text-muted mb-1">Last Run</div>
                    <cfif hasRun>
                        <cfset runDate = "">
                        <cfif structKeyExists(lr, "RUNAT")>
                            <cfset runDate = lr.RUNAT>
                        <cfelseif structKeyExists(lr, "RANON")>
                            <cfset runDate = lr.RANON>
                        <cfelseif structKeyExists(lr, "CREATEDAT")>
                            <cfset runDate = lr.CREATEDAT>
                        </cfif>
                        <cfset triggeredBy = "">
                        <cfif structKeyExists(lr, "TRIGGEREDBY")>
                            <cfset triggeredBy = lr.TRIGGEREDBY>
                        </cfif>
                        <span class="badge bg-light text-dark border">
                            <i class="bi bi-clock me-1"></i>
                            <cfif len(runDate)>
                                #isDate(runDate) ? dateTimeFormat(runDate, "MMM d, yyyy h:nn tt") : encodeForHTML(runDate)#
                            <cfelse>
                                Unknown date
                            </cfif>
                        </span>
                        <cfif len(triggeredBy)>
                            <span class="badge bg-light text-muted border ms-1">
                                #encodeForHTML(triggeredBy)#
                            </span>
                        </cfif>
                    <cfelse>
                        <span class="text-muted small">No runs recorded</span>
                    </cfif>
                </div>

                <!--- Endpoint URL (copyable) --->
                <div class="mb-3">
                    <div class="small text-muted mb-1">Endpoint URL</div>
                    <div class="input-group input-group-sm">
                        <input type="text" class="form-control form-control-sm font-monospace"
                               value="#encodeForHTMLAttribute(fullUrl)#" readonly id="url_#t.key#">
                        <button class="btn btn-outline-secondary" type="button"
                                onclick="navigator.clipboard.writeText(document.getElementById('url_#t.key#').value)"
                                title="Copy URL">
                            <i class="bi bi-clipboard"></i>
                        </button>
                    </div>
                </div>
            </div>

            <!--- Card footer with actions --->
            <cfset isEnabled = structKeyExists(enabledTasks, t.key)>
            <div class="card-footer bg-light d-flex flex-wrap gap-2">
                <cfif isEnabled>
                    <form method="post" class="d-inline">
                        <input type="hidden" name="action" value="disable">
                        <input type="hidden" name="taskKey" value="#encodeForHTMLAttribute(t.key)#">
                        <button type="submit" class="btn btn-sm btn-outline-danger" title="Remove scheduled task">
                                <i class="bi bi-x-circle me-1"></i> Disable
                        </button>
                    </form>
                <cfelse>
                    <form method="post" class="d-inline">
                        <input type="hidden" name="action" value="enable">
                        <input type="hidden" name="taskKey" value="#encodeForHTMLAttribute(t.key)#">
                        <button type="submit" class="btn btn-sm btn-success" title="Enable daily schedule">
                            <i class="bi bi-check-circle me-1"></i> Enable
                        </button>
                    </form>
                </cfif>
                <cfif len(t.runNowLink)>
                    <a href="#encodeForHTMLAttribute(t.runNowLink)#" class="btn btn-sm btn-outline-primary">
                        <i class="bi bi-play-fill me-1"></i> Run Now
                    </a>
                </cfif>
                <cfif len(t.dashboardLink)>
                    <a href="#encodeForHTMLAttribute(t.dashboardLink)#" class="btn btn-sm btn-outline-secondary ms-auto">
                        <i class="bi bi-box-arrow-up-right me-1"></i> Dashboard
                    </a>
                </cfif>
            </div>
        </div>
    </div>
</cfloop>
</div>

<!--- ── Notes Card ───────────────────────────────────────────────────────── --->
<div class="card shadow-sm mt-4">
    <div class="card-header bg-light">
        <h6 class="mb-0"><i class="bi bi-info-circle me-2"></i>Notes</h6>
    </div>
    <div class="card-body small text-muted">
        <ul class="mb-0">
            <li><strong>Enable</strong> registers (or re-registers) the task in the ColdFusion Scheduler to run daily at the configured time.</li>
            <li><strong>Disable</strong> removes the task from the ColdFusion Scheduler entirely.</li>
            <li>Tasks can also be managed directly in the ColdFusion Administrator under <em>Server Settings &rarr; Scheduled Tasks</em>.</li>
            <li>The <strong>Graduation Migration</strong> task has an additional date guard — it only executes during the Memorial Day weekend window even if the schedule fires daily.</li>
            <li>Endpoint URLs are shown for reference. You can paste them into CF Administrator or use them to trigger tasks via external schedulers.</li>
        </ul>
    </div>
</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
