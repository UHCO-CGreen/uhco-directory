<!---
    data_quality_report.cfm
    Displays the most recent data quality audit results.
    Use the "Run Now" button to trigger a fresh audit, or schedule
    run_data_quality_report.cfm via the ColdFusion Administrator scheduler.
--->

<!--- ── Issue code → human label map ── --->
<cfset issueLabels = {
    "missing_uh_api_id"      : "Missing UH API ID",
    "missing_firstname"      : "Missing First Name",
    "missing_lastname"       : "Missing Last Name",
    "missing_email_primary"  : "Missing Primary Email (@uh.edu)",
    "missing_email_secondary": "Missing Secondary Email (@cougarnet or @central)",
    "missing_title1"         : "Missing Title",
    "missing_room"           : "Missing Room",
    "missing_building"       : "Missing Building",
    "no_flags"               : "Zero Flags",
    "no_orgs"                : "Zero Organizations",
    "missing_cougarnet"      : "Missing CougarNet ID",
    "missing_peoplesoft"     : "Missing PeopleSoft ID",
    "missing_legacy_id"      : "Missing Legacy ID (Students Only)",
    "missing_grad_year"      : "Missing Grad Year (Students Only)",
    "missing_phone"          : "Missing Phone Number",
    "missing_degrees"        : "Missing Degrees",
    "no_images"              : "No Profile Images"
}>

<!--- ── Severity map: high = red, mid = warning/orange, (default = secondary) ── --->
<cfset issueSeverity = {
    "missing_uh_api_id"      : "high",
    "missing_firstname"      : "high",
    "missing_lastname"       : "high",
    "missing_email_primary"  : "high",
    "missing_email_secondary": "mid",
    "missing_title1"         : "high",
    "no_flags"               : "high",
    "no_orgs"                : "high",
    "no_images"              : "high",
    "missing_cougarnet"      : "high",
    "missing_peoplesoft"     : "high",
    "missing_degrees"        : "high",
    "missing_grad_year"      : "high",
    "missing_room"           : "mid",
    "missing_building"       : "mid",
    "missing_legacy_id"      : "mid",
    "missing_phone"          : "mid"
}>

<!--- ── URL params ── --->
<cfset msgParam       = structKeyExists(url, "msg")       ? url.msg           : "">
<cfset errParam       = structKeyExists(url, "err")       ? url.err           : "">
<cfset syncFieldParam = structKeyExists(url, "syncField") ? url.syncField     : "">
<cfset filterCode     = structKeyExists(url, "filter")    ? trim(url.filter)  : "">
<cfset viewRunID   = structKeyExists(url, "runID")  AND isNumeric(url.runID) ? val(url.runID) : 0>

<!--- ── Load data ── --->
<cfset dqDAO      = createObject("component", "dao.dataQuality_DAO").init()>
<cfset recentRuns = []>
<cfset summary    = []>
<cfset userDetail = []>
<cfset currentRun = {}>
<cfset dbOk       = true>
<cfset dbError    = "">

<cftry>
    <cfset recentRuns = dqDAO.getRecentRuns(10)>
    <!--- Use the requested runID, else the latest run --->
    <cfif viewRunID GT 0>
        <cfloop from="1" to="#arrayLen(recentRuns)#" index="i">
            <cfif recentRuns[i].RUNID EQ viewRunID>
                <cfset currentRun = recentRuns[i]>
                <cfbreak>
            </cfif>
        </cfloop>
    <cfelseif arrayLen(recentRuns)>
        <cfset currentRun = recentRuns[1]>
    </cfif>

    <cfif NOT structIsEmpty(currentRun)>
        <cfset summary    = dqDAO.getSummaryByRun(currentRun.RUNID)>
        <cfset userDetail = dqDAO.getUserDetailByRun(currentRun.RUNID, filterCode)>
    </cfif>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Build summary lookup ── --->
<cfset summaryMap = {}>
<cfloop from="1" to="#arrayLen(summary)#" index="i">
    <cfset summaryMap[summary[i].ISSUECODE] = summary[i].ISSUECOUNT>
</cfloop>

<!--- ── Schedule helper — build the runner URL ── --->
<cfset schedulerUrl = request.siteBaseUrl & "/admin/reporting/run_data_quality_report.cfm?triggeredBy=scheduled&format=json">

<!--- ── Handle schedule form submission ── --->
<cfset scheduleMsg = "">
<cfset scheduleMsgClass = "">
<cfif structKeyExists(form, "scheduleAction") AND form.scheduleAction EQ "enable">
    <cftry>
        <cfschedule
            action      = "update"
            task        = "UHCO_DataQualityReport"
            operation   = "HTTPRequest"
            url         = "#schedulerUrl#"
            startDate   = "#dateFormat(now(), 'MM/DD/YYYY')#"
            startTime   = "02:00 AM"
            interval    = "daily"
            requesttimeout = "300"
            resolveurl  = "false"
            publish     = "false">
        <cfset scheduleMsg      = "Daily schedule enabled — report will run at 2:00 AM each day.">
        <cfset scheduleMsgClass = "alert-success">
    <cfcatch>
        <cfset scheduleMsg      = "Could not register schedule: " & cfcatch.message>
        <cfset scheduleMsgClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<!--- ═══════════════════════════════════════════════════════════════════════ --->
<!--- ── Page content ─────────────────────────────────────────────────────── --->
<!--- ═══════════════════════════════════════════════════════════════════════ --->

<cfset content = "<h1 class='mb-1'>Data Quality Report</h1>">

<!--- Status messages --->
<cfif msgParam EQ "ran">
    <cfset content &= "<div class='alert alert-success mt-3'>Report run complete. Results shown below.</div>">
<cfelseif msgParam EQ "error">
    <cfset content &= "<div class='alert alert-danger mt-3'><strong>Run failed:</strong> #EncodeForHTML(errParam)#</div>">
<cfelseif msgParam EQ "synced">
    <cfset content &= "<div class='alert alert-success mt-3'><i class='bi bi-check-circle-fill'></i> Synced <strong>#EncodeForHTML(syncFieldParam)#</strong> successfully.</div>">
</cfif>
<cfif len(errParam) AND msgParam NEQ "error">
    <cfset content &= "<div class='alert alert-danger mt-3'><strong>Sync failed:</strong> #EncodeForHTML(errParam)#</div>">
</cfif>
<cfif len(scheduleMsg)>
    <cfset content &= "<div class='alert #scheduleMsgClass# mt-2'>#EncodeForHTML(scheduleMsg)#</div>">
</cfif>
<cfif NOT dbOk>
    <cfset content &= "<div class='alert alert-danger'>Database error: #EncodeForHTML(dbError)# — have you run <code>create_data_quality_report.sql</code>?</div>">
</cfif>

<!--- ── Action bar ── --->
<cfset content &= "
<div class='d-flex flex-wrap align-items-center gap-2 mb-4 mt-2'>
    <a href='/admin/reporting/run_data_quality_report.cfm' class='btn btn-primary'>
        <i class='bi bi-play-fill'></i> Run Now
    </a>
    <button class='btn btn-outline-secondary btn-sm' type='button'
            data-bs-toggle='collapse' data-bs-target='##schedulePanel'>
        <i class='bi bi-clock'></i> Schedule
    </button>
    <button class='btn btn-outline-secondary btn-sm' type='button'
            data-bs-toggle='collapse' data-bs-target='##historyPanel'>
        <i class='bi bi-clock-history'></i> Run History
    </button>
</div>
">

<!--- ── Schedule panel ── --->
<cfset content &= "
<div class='collapse mb-3' id='schedulePanel'>
    <div class='card card-body'>
        <h6 class='mb-2'>Daily Scheduled Run</h6>
        <p class='text-muted small mb-2'>
            Schedule the report to run automatically at 2:00 AM each day via the ColdFusion Scheduler.
            Alternatively, add the URL below to the CF Administrator manually.
        </p>
        <div class='input-group mb-3 report-scheduler-input'>
            <input type='text' class='form-control form-control-sm font-monospace'
                   value='#EncodeForHTMLAttribute(schedulerUrl)#' readonly id='schedUrlInput'>
            <button class='btn btn-sm btn-outline-secondary'
                    onclick=""navigator.clipboard.writeText(document.getElementById('schedUrlInput').value)"">
                <i class='bi bi-clipboard'></i>
            </button>
        </div>
        <form method='post'>
            <input type='hidden' name='scheduleAction' value='enable'>
            <button type='submit' class='btn btn-sm btn-success'>
                <i class='bi bi-check-circle'></i> Enable Daily Schedule via ColdFusion
            </button>
        </form>
    </div>
</div>
">

<!--- ── Run history panel ── --->
<cfset content &= "<div class='collapse mb-3' id='historyPanel'><div class='card card-body'>">
<cfset content &= "<h6 class='mb-2'>Recent Runs</h6>">
<cfif arrayLen(recentRuns) EQ 0>
    <cfset content &= "<p class='text-muted'>No runs yet.</p>">
<cfelse>
    <cfset content &= "<table class='table table-sm table-bordered mb-0'><thead class='table-dark'><tr><th>Run ID</th><th>Date/Time (UTC)</th><th>Triggered By</th><th>Users</th><th>Issues</th><th></th></tr></thead><tbody>">
    <cfloop from="1" to="#arrayLen(recentRuns)#" index="i">
        <cfset r = recentRuns[i]>
        <cfset activeCls = (NOT structIsEmpty(currentRun) AND r.RUNID EQ currentRun.RUNID) ? " class='table-primary'" : "">
        <cfset badgeCls = r.TOTALISSUES GT 0 ? "bg-danger" : "bg-success">
        <cfset content &= "<tr#activeCls#>
            <td>#r.RUNID#</td>
            <td>#dateTimeFormat(r.RUNAT, 'mmm d, yyyy HH:nn')#</td>
            <td>#EncodeForHTML(r.TRIGGEREDBY)#</td>
            <td>#r.TOTALUSERS#</td>
            <td><span class='badge #badgeCls#'>#r.TOTALISSUES#</span></td>
            <td><a href='?runID=#r.RUNID#' class='btn btn-xs btn-sm btn-outline-secondary py-0 px-1'>View</a></td>
        </tr>">
    </cfloop>
    <cfset content &= "</tbody></table>">
</cfif>
<cfset content &= "</div></div>">

<!--- ── No run yet ── --->
<cfif structIsEmpty(currentRun)>
    <cfset content &= "
    <div class='card border-0 text-center py-5'>
        <div class='card-body'>
            <i class='bi bi-clipboard-data display-4 text-muted'></i>
            <h4 class='mt-3 text-muted'>No report data yet</h4>
            <p class='text-muted'>Click <strong>Run Now</strong> to generate the first report.</p>
        </div>
    </div>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<!--- ── Run header ── --->
<cfset runBadgeCls = currentRun.TOTALISSUES GT 0 ? "bg-danger" : "bg-success">
<cfset content &= "
<div class='d-flex flex-wrap align-items-center gap-3 mb-3'>
    <span class='text-muted small'>
        Run ##<strong>#currentRun.RUNID#</strong>
        &mdash; #dateTimeFormat(currentRun.RUNAT, 'mmmm d, yyyy HH:nn')# UTC
        &mdash; triggered by <em>#EncodeForHTML(currentRun.TRIGGEREDBY)#</em>
        &mdash; #currentRun.TOTALUSERS# total users
    </span>
    <span class='badge #runBadgeCls# fs-6'>#currentRun.TOTALISSUES# issue(s)</span>
    <button class='btn btn-outline-secondary btn-sm ms-auto' type='button'
            data-bs-toggle='collapse' data-bs-target='##filterCards'
            aria-expanded='true' aria-controls='filterCards'>
        <i class='bi bi-funnel'></i> Filter by Issue
    </button>
</div>
">

<!--- ── Summary cards ── --->
<cfset content &= "<div class='collapse show' id='filterCards'><div class='row g-3 mb-4'>">
<cfset orderedCodes = [
    "missing_uh_api_id", "missing_firstname", "missing_lastname",
    "missing_email_primary", "missing_email_secondary", "missing_title1",
    "missing_room", "missing_building", "no_flags", "no_orgs",
    "missing_cougarnet", "missing_peoplesoft", "missing_legacy_id", "missing_grad_year",
    "missing_phone", "missing_degrees", "no_images"
]>
<cfloop from="1" to="#arrayLen(orderedCodes)#" index="i">
    <cfset code     = orderedCodes[i]>
    <cfset cnt      = structKeyExists(summaryMap, code) ? summaryMap[code] : 0>
    <cfset label    = structKeyExists(issueLabels, code) ? issueLabels[code] : code>
    <cfset severity = structKeyExists(issueSeverity, code) ? issueSeverity[code] : "mid">
    <cfif cnt GT 0>
        <cfset cardCls   = severity EQ "high" ? "border-danger"  : "border-warning">
        <cfset badgeCls2 = severity EQ "high" ? "bg-danger"      : "bg-warning text-dark">
    <cfelse>
        <cfset cardCls   = "border-success">
        <cfset badgeCls2 = "bg-success">
    </cfif>
    <cfset filterHref = cnt GT 0 ? "?runID=#currentRun.RUNID#&filter=#urlEncodedFormat(code)#" : "##">
    <cfset content &= "
    <div class='col-6 col-md-4 col-lg-3'>
        <div class='card h-100 #cardCls#'>
            <div class='card-body py-2 px-3 d-flex align-items-center justify-content-between'>
                <span class='small'>#EncodeForHTML(label)#</span>
                <a href='#filterHref#' class='badge #badgeCls2# text-decoration-none ms-2 flex-shrink-0'>#cnt#</a>
            </div>
        </div>
    </div>">
</cfloop>
<cfset content &= "</div></div>">

<!--- ── Filter bar ── --->
<cfset content &= "<div class='d-flex align-items-center gap-2 mb-3'>">
<cfif len(filterCode)>
    <cfset filterLabel = structKeyExists(issueLabels, filterCode) ? issueLabels[filterCode] : filterCode>
    <cfset content &= "
    <span class='badge bg-primary fs-6'>#EncodeForHTML(filterLabel)#</span>
    <a href='?runID=#currentRun.RUNID#' class='btn btn-sm btn-outline-secondary'>
        <i class='bi bi-x'></i> Clear filter
    </a>">
<cfelse>
    <cfset content &= "<span class='text-muted small'>Showing all issues &mdash; click a badge above to filter by type.</span>">
</cfif>
<cfset content &= "<span class='text-muted small ms-auto'>#arrayLen(userDetail)# user(s)</span></div>">

<!--- ── Detail table ── --->
<cfif arrayLen(userDetail) EQ 0>
    <cfset content &= "<div class='alert alert-success'><i class='bi bi-check-circle-fill'></i> No issues found for this selection.</div>">
<cfelse>
    <cfset content &= "
    <div class='table-responsive'>
    <table class='table table-sm table-striped table-hover'>
        <thead class='table-dark'>
            <tr>
                <th>User ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Issues (#arrayLen(userDetail)# users)</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
    ">
    <!--- Quick-sync label map: issue codes that map directly to a UH API field --->    <cfset quickSyncLabels = {
        "missing_firstname"     : "Sync First Name",
        "missing_lastname"      : "Sync Last Name",
        "missing_email_primary" : "Sync Primary Email",
        "missing_title1"        : "Sync Title",
        "missing_room"          : "Sync Room",
        "missing_building"      : "Sync Building",
        "missing_phone"         : "Sync Phone"
    }>
    <!--- Strip prior sync feedback params from returnTo so they don't stack on repeat syncs --->
    <cfset cleanQS = "">
    <cfloop list="#cgi.QUERY_STRING#" index="qsParam" delimiters="&">
        <cfset qsParamName = listFirst(qsParam, "=")>
        <cfif NOT listFindNoCase("msg,err,syncField", qsParamName)>
            <cfset cleanQS &= (len(cleanQS) ? "&" : "") & qsParam>
        </cfif>
    </cfloop>
    <cfset returnToUrl = cgi.SCRIPT_NAME & (len(cleanQS) ? "?" & cleanQS : "")>
    <cfloop from="1" to="#arrayLen(userDetail)#" index="i">
        <cfset row = userDetail[i]>
        <cfset badgesHtml = "">
        <cfloop list="#row.ISSUECODES#" index="code">
            <cfset lbl = structKeyExists(issueLabels, trim(code)) ? issueLabels[trim(code)] : trim(code)>
            <cfset badgesHtml &= "<span class='badge bg-danger me-1 mb-1'>#EncodeForHTML(lbl)#</span>">
        </cfloop>
        <cfset uhApiIdVal = trim(row.UH_API_ID ?: "")>
        <cfset syncBtnHtml = "">
        <cfif len(uhApiIdVal)>
            <cfset syncBtnHtml = "<a href='/admin/users/uh_sync.cfm?userID=#row.USERID#&returnTo=#urlEncodedFormat(returnToUrl)#' class='btn btn-sm btn-secondary py-0 ms-1'>UH Sync</a>">
            <cfloop list="#row.ISSUECODES#" index="qsc">
                <cfset qsc = trim(qsc)>
                <cfif structKeyExists(quickSyncLabels, qsc)>
                    <cfset syncBtnHtml &= "<a href='/admin/users/quick_sync_field.cfm?userID=#row.USERID#&issueCode=#urlEncodedFormat(qsc)#&returnTo=#urlEncodedFormat(returnToUrl)#' class='btn btn-sm btn-outline-success py-0 ms-1'>#EncodeForHTML(quickSyncLabels[qsc])#</a>">
                </cfif>
            </cfloop>
        </cfif>
        <cfset content &= "
        <tr>
            <td><code>#row.USERID#</code></td>
            <td>#EncodeForHTML(row.FIRSTNAME & ' ' & row.LASTNAME)#</td>
            <td>#EncodeForHTML(row.EMAILPRIMARY)#</td>
            <td>#badgesHtml#</td>
            <td class='text-nowrap'>
                <a href='/admin/users/edit.cfm?userID=#row.USERID#' class='btn btn-sm btn-info py-0 users-list-action-button users-list-action-button-edit' title='Edit User' data-bs-toggle='tooltip' data-bs-title='Edit User' aria-label='Edit User'><i class='bi bi-pencil-square'></i></a>#syncBtnHtml#
            </td>
        </tr>
        ">
    </cfloop>
    <cfset content &= "</tbody></table></div>">
</cfif>

<cfset content &= "
<script>
(function () {
    var el  = document.getElementById('filterCards');
    var KEY = 'dqr_filterCards_open';
    if (!el) return;

    // Restore saved state before Bootstrap initialises (avoids flicker)
    if (localStorage.getItem(KEY) === 'false') {
        el.classList.remove('show');
    }

    // Persist state on toggle
    el.addEventListener('shown.bs.collapse',  function () { localStorage.setItem(KEY, 'true');  });
    el.addEventListener('hidden.bs.collapse', function () { localStorage.setItem(KEY, 'false'); });
}());
</script>
">

<cfinclude template="/admin/layout.cfm">
