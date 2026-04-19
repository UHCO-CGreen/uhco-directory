<!---
    uh_sync_report.cfm
    Displays UH API vs local-DB diff results.
    Use "Run Now" to trigger a fresh comparison, or schedule
    run_uh_sync_report.cfm via the ColdFusion Administrator scheduler.
--->

<!--- ── Human-readable field labels ── --->
<cfset fieldLabels = {
    "FirstName"              : "First Name",
    "LastName"               : "Last Name",
    "EmailPrimary"           : "Primary Email",
    "Phone"                  : "Phone",
    "Room"                   : "Room",
    "Building"               : "Building",
    "Title1"                 : "Title",
    "Division"               : "Division",
    "DivisionName"           : "Division Name",
    "Campus"                 : "Campus",
    "Department"             : "Department",
    "DepartmentName"         : "Department Name",
    "Office_Mailing_Address" : "Office Mailing Address",
    "Mailcode"               : "Mailcode"
}>

<!--- ── URL params ── --->
<cfset msgParam     = structKeyExists(url, "msg")    ? url.msg           : "">
<cfset errParam     = structKeyExists(url, "err")    ? url.err           : "">
<cfset viewRunID    = structKeyExists(url, "runID") AND isNumeric(url.runID) ? val(url.runID) : 0>
<cfset filterField  = structKeyExists(url, "filter") ? trim(url.filter)  : "">
<cfset activeTab    = structKeyExists(url, "tab")    ? trim(url.tab)     : "diffs">

<!--- ── Load data ── --->
<cfset uhSyncDAO  = createObject("component", "dao.uhSync_DAO").init()>
<cfset recentRuns = []>
<cfset currentRun = {}>
<cfset diffRows   = []>
<cfset diffSummary = []>
<cfset goneRows   = []>
<cfset newRows    = []>
<cfset dbOk       = true>
<cfset dbError    = "">

<cftry>
    <cfset recentRuns = uhSyncDAO.getRecentRuns(10)>

    <cfif viewRunID GT 0>
        <cfset currentRun = uhSyncDAO.getRunByID(viewRunID)>
    <cfelseif arrayLen(recentRuns)>
        <cfset currentRun = recentRuns[1]>
    </cfif>

    <cfif NOT structIsEmpty(currentRun)>
        <cfset diffRows    = uhSyncDAO.getDiffsByRun(currentRun.RUNID, filterField)>
        <cfset diffSummary = uhSyncDAO.getDiffSummaryByRun(currentRun.RUNID)>
        <cfset goneRows    = uhSyncDAO.getGoneByRun(currentRun.RUNID)>
        <cfset newRows     = uhSyncDAO.getNewByRun(currentRun.RUNID)>
    </cfif>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Build diff summary lookup: FieldName → count ── --->
<cfset diffSummaryMap = {}>
<cfloop from="1" to="#arrayLen(diffSummary)#" index="i">
    <cfset diffSummaryMap[diffSummary[i].FIELDNAME] = diffSummary[i].DIFFCOUNT>
</cfloop>

<!--- ── Scheduler URL ── --->
<cfset schedulerUrl = request.siteBaseUrl & "/admin/reporting/run_uh_sync_report.cfm?triggeredBy=scheduled&format=json">

<!--- ── Schedule form handler ── --->
<cfset scheduleMsg      = "">
<cfset scheduleMsgClass = "">
<cfif structKeyExists(form, "scheduleAction") AND form.scheduleAction EQ "enable">
    <cftry>
        <cfschedule
            action         = "update"
            task           = "UHCO_UHSyncReport"
            operation      = "HTTPRequest"
            url            = "#schedulerUrl#"
            startDate      = "#dateFormat(now(), 'MM/DD/YYYY')#"
            startTime      = "03:00 AM"
            interval       = "daily"
            requesttimeout = "600"
            resolveurl     = "false"
            publish        = "false">
        <cfset scheduleMsg      = "Daily schedule enabled — report will run at 3:00 AM each day.">
        <cfset scheduleMsgClass = "alert-success">
    <cfcatch>
        <cfset scheduleMsg      = "Could not register schedule: " & cfcatch.message>
        <cfset scheduleMsgClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Page content ────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->

<cfset content = "<h1 class='mb-1'>UH API Sync Report</h1>">

<!--- Status messages --->
<cfif msgParam EQ "ran">
    <cfset content &= "<div class='alert alert-success mt-3'><i class='bi bi-check-circle-fill'></i> Sync report run complete. Results shown below.</div>">
<cfelseif msgParam EQ "error">
    <cfset content &= "<div class='alert alert-danger mt-3'><strong>Run failed:</strong> #EncodeForHTML(errParam)#</div>">
<cfelseif msgParam EQ "resolved">
    <cfset content &= "<div class='alert alert-success mt-3'><i class='bi bi-check-circle-fill'></i> #EncodeForHTML(errParam)#</div>">
</cfif>
<cfif len(scheduleMsg)>
    <cfset content &= "<div class='alert #scheduleMsgClass# mt-2'>#EncodeForHTML(scheduleMsg)#</div>">
</cfif>
<cfif NOT dbOk>
    <cfset content &= "<div class='alert alert-danger'>Database error: #EncodeForHTML(dbError)# — have you run <code>create_uh_sync_report.sql</code>?</div>">
</cfif>

<!--- ── Action bar ── --->
<cfset content &= "
<div class='d-flex flex-wrap align-items-center gap-2 mb-4 mt-2'>
    <a href='/admin/reporting/run_uh_sync_report.cfm' class='btn btn-primary'>
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
            Schedule the report to run automatically at 3:00 AM each day via the ColdFusion Scheduler.
            Alternatively, add the URL below to the CF Administrator manually.
        </p>
        <div class='input-group mb-3' style='max-width:700px;'>
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
    <cfset content &= "<table class='table table-sm table-bordered mb-0'><thead class='table-dark'><tr>
        <th>Run ID</th><th>Date/Time (UTC)</th><th>Triggered By</th>
        <th>Compared</th><th>Diffs</th><th>Gone</th><th>New</th><th></th>
    </tr></thead><tbody>">
    <cfloop from="1" to="#arrayLen(recentRuns)#" index="i">
        <cfset r = recentRuns[i]>
        <cfset activeCls  = (NOT structIsEmpty(currentRun) AND r.RUNID EQ currentRun.RUNID) ? " class='table-primary'" : "">
        <cfset diffBadge  = r.TOTALDIFFS GT 0 ? "bg-warning text-dark" : "bg-success">
        <cfset goneBadge  = r.TOTALGONE  GT 0 ? "bg-danger"            : "bg-success">
        <cfset newBadge   = r.TOTALNEW   GT 0 ? "bg-info text-dark"    : "bg-success">
        <cfset content &= "<tr#activeCls#>
            <td>#r.RUNID#</td>
            <td>#dateTimeFormat(r.RUNAT, 'mmm d, yyyy HH:nn')#</td>
            <td>#EncodeForHTML(r.TRIGGEREDBY)#</td>
            <td>#r.TOTALCOMPARED#</td>
            <td><span class='badge #diffBadge#'>#r.TOTALDIFFS#</span></td>
            <td><span class='badge #goneBadge#'>#r.TOTALGONE#</span></td>
            <td><span class='badge #newBadge#'>#r.TOTALNEW#</span></td>
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
            <i class='bi bi-arrow-left-right display-4 text-muted'></i>
            <h4 class='mt-3 text-muted'>No sync data yet</h4>
            <p class='text-muted'>Click <strong>Run Now</strong> to compare local records against the UH API.</p>
        </div>
    </div>">
    <cfinclude template="/admin/layout.cfm">
    <cfabort>
</cfif>

<!--- ── Run header ── --->
<cfset totalPending = arrayLen(diffRows) + arrayLen(goneRows) + arrayLen(newRows)>
<cfset runBadgeCls  = (currentRun.TOTALDIFFS GT 0 OR currentRun.TOTALGONE GT 0 OR currentRun.TOTALNEW GT 0) ? "bg-warning text-dark" : "bg-success">
<cfset content &= "
<div class='d-flex flex-wrap align-items-center gap-3 mb-3'>
    <span class='text-muted small'>
        Run ##<strong>#currentRun.RUNID#</strong>
        &mdash; #dateTimeFormat(currentRun.RUNAT, 'mmmm d, yyyy HH:nn')# UTC
        &mdash; triggered by <em>#EncodeForHTML(currentRun.TRIGGEREDBY)#</em>
        &mdash; #currentRun.TOTALCOMPARED# users compared
    </span>
    <span class='badge bg-warning text-dark fs-6'>#currentRun.TOTALDIFFS# diff(s)</span>
    <span class='badge bg-danger fs-6'>#currentRun.TOTALGONE# gone</span>
    <span class='badge bg-info text-dark fs-6'>#currentRun.TOTALNEW# new</span>
</div>
">

<!--- ── Summary cards for fields with diffs ── --->
<cfif arrayLen(diffSummary) GT 0>
    <cfset content &= "
    <div class='mb-4'>
        <h6 class='text-muted mb-2'>Filter by changed field</h6>
        <div class='d-flex flex-wrap gap-2'>
    ">
    <cfloop from="1" to="#arrayLen(diffSummary)#" index="i">
        <cfset ds    = diffSummary[i]>
        <cfset lbl   = structKeyExists(fieldLabels, ds.FIELDNAME) ? fieldLabels[ds.FIELDNAME] : ds.FIELDNAME>
        <cfset isActive = (filterField EQ ds.FIELDNAME)>
        <cfset content &= "<a href='?runID=#currentRun.RUNID#&tab=diffs&filter=#urlEncodedFormat(ds.FIELDNAME)#'
                class='badge #(isActive ? 'bg-primary' : 'bg-warning text-dark')# text-decoration-none fs-6'>
                #EncodeForHTML(lbl)# (#ds.DIFFCOUNT#)</a>">
    </cfloop>
    <cfif len(filterField)>
        <cfset content &= "<a href='?runID=#currentRun.RUNID#&tab=diffs' class='btn btn-sm btn-outline-secondary py-0'>
            <i class='bi bi-x'></i> Clear filter</a>">
    </cfif>
    <cfset content &= "</div></div>">
</cfif>

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Tabbed sections ─────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->

<cfset tabDiffActive  = (activeTab NEQ "gone" AND activeTab NEQ "new") ? " show active" : "">
<cfset tabGoneActive  = (activeTab EQ "gone")  ? " show active" : "">
<cfset tabNewActive   = (activeTab EQ "new")   ? " show active" : "">
<cfset navDiffActive  = (tabDiffActive  NEQ "") ? " active" : "">
<cfset navGoneActive  = (tabGoneActive  NEQ "") ? " active" : "">
<cfset navNewActive   = (tabNewActive   NEQ "") ? " active" : "">

<cfset content &= "
<ul class='nav nav-tabs mb-3' id='syncTabs' role='tablist'>
    <li class='nav-item' role='presentation'>
        <button class='nav-link#navDiffActive#' data-bs-toggle='tab' data-bs-target='##tab-diffs' type='button'>
            <i class='bi bi-pencil-square me-1'></i>
            Changed Fields
            <span class='badge bg-warning text-dark ms-1'>#currentRun.TOTALDIFFS#</span>
        </button>
    </li>
    <li class='nav-item' role='presentation'>
        <button class='nav-link#navGoneActive#' data-bs-toggle='tab' data-bs-target='##tab-gone' type='button'>
            <i class='bi bi-person-dash me-1'></i>
            Left UH
            <span class='badge bg-danger ms-1'>#currentRun.TOTALGONE#</span>
        </button>
    </li>
    <li class='nav-item' role='presentation'>
        <button class='nav-link#navNewActive#' data-bs-toggle='tab' data-bs-target='##tab-new' type='button'>
            <i class='bi bi-person-plus me-1'></i>
            New in UH
            <span class='badge bg-info text-dark ms-1'>#currentRun.TOTALNEW#</span>
        </button>
    </li>
</ul>
<div class='tab-content'>
">

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Tab 1: Changed Fields ───────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<cfset content &= "<div class='tab-pane fade#tabDiffActive#' id='tab-diffs' role='tabpanel'>">

<cfif arrayLen(diffRows) EQ 0>
    <cfset content &= "<div class='alert alert-success'><i class='bi bi-check-circle-fill'></i>
        No field differences found#(len(filterField) ? ' for the selected filter' : '')#.</div>">
<cfelse>
    <cfset content &= "
    <div class='table-responsive'>
    <table class='table table-sm table-striped table-hover align-middle'>
        <thead class='table-dark'>
            <tr>
                <th>User</th>
                <th>Field</th>
                <th>Local Value</th>
                <th>API Value</th>
                <th class='text-end'>Actions</th>
            </tr>
        </thead>
        <tbody>
    ">
    <cfloop from="1" to="#arrayLen(diffRows)#" index="i">
        <cfset dr      = diffRows[i]>
        <cfset fldLbl  = structKeyExists(fieldLabels, dr.FIELDNAME) ? fieldLabels[dr.FIELDNAME] : dr.FIELDNAME>
        <cfset returnTo = "/admin/reporting/uh_sync_report.cfm?runID=#currentRun.RUNID#&tab=diffs#(len(filterField) ? '&filter=' & urlEncodedFormat(filterField) : '')#">

        <cfset content &= "
        <tr>
            <td>
                <a href='/admin/users/edit.cfm?userID=#dr.USERID#' class='text-decoration-none fw-semibold'>
                    #EncodeForHTML(dr.FIRSTNAME & ' ' & dr.LASTNAME)#
                </a>
                <br><small class='text-muted'>#EncodeForHTML(dr.EMAILPRIMARY)#</small>
            </td>
            <td><span class='badge bg-secondary'>#EncodeForHTML(fldLbl)#</span></td>
            <td><span class='text-muted'>#(len(dr.LOCALVALUE) ? EncodeForHTML(dr.LOCALVALUE) : '<em class=""text-muted"">empty</em>')#</span></td>
            <td><strong>#EncodeForHTML(dr.APIVALUE)#</strong></td>
            <td class='text-end text-nowrap'>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                    <input type='hidden' name='diffID'     value='#dr.DIFFID#'>
                    <input type='hidden' name='resolution' value='synced'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(returnTo)#'>
                    <button type='submit' class='btn btn-sm btn-success py-0'>
                        <i class='bi bi-cloud-download'></i> Sync
                    </button>
                </form>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'>
                    <input type='hidden' name='diffID'     value='#dr.DIFFID#'>
                    <input type='hidden' name='resolution' value='discarded'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(returnTo)#'>
                    <button type='submit' class='btn btn-sm btn-outline-secondary py-0'>
                        <i class='bi bi-x'></i> Discard
                    </button>
                </form>
            </td>
        </tr>
        ">
    </cfloop>
    <cfset content &= "</tbody></table></div>">
</cfif>

<cfset content &= "</div>"> <!--- end tab-diffs --->

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Tab 2: Left UH (Gone) ───────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<cfset content &= "<div class='tab-pane fade#tabGoneActive#' id='tab-gone' role='tabpanel'>">

<cfif arrayLen(goneRows) EQ 0>
    <cfset content &= "<div class='alert alert-success'><i class='bi bi-check-circle-fill'></i>
        No users found in the local database that are missing from the API.</div>">
<cfelse>
    <cfset content &= "
    <p class='text-muted small mb-3'>
        These users have a UH API ID in the local database but were <strong>not returned</strong> by the UH API.
        They may have left UH. Review each record and delete or keep as appropriate.
    </p>
    <div class='table-responsive'>
    <table class='table table-sm table-striped table-hover align-middle'>
        <thead class='table-dark'>
            <tr>
                <th>User</th>
                <th>Title</th>
                <th>UH API ID</th>
                <th class='text-end'>Actions</th>
            </tr>
        </thead>
        <tbody>
    ">
    <cfset goneReturnTo = "/admin/reporting/uh_sync_report.cfm?runID=#currentRun.RUNID#&tab=gone">
    <cfloop from="1" to="#arrayLen(goneRows)#" index="i">
        <cfset gr = goneRows[i]>
        <cfset content &= "
        <tr>
            <td>
                <a href='/admin/users/edit.cfm?userID=#gr.USERID#' class='text-decoration-none fw-semibold'>
                    #EncodeForHTML(gr.FIRSTNAME & ' ' & gr.LASTNAME)#
                </a>
                <br><small class='text-muted'>#EncodeForHTML(gr.EMAILPRIMARY)#</small>
            </td>
            <td>#EncodeForHTML(gr.TITLE1 ?: '')#</td>
            <td><code class='small'>#EncodeForHTML(gr.UH_API_ID)#</code></td>
            <td class='text-end text-nowrap'>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'
                      onsubmit=""return confirm('Delete #EncodeForJavascript(gr.FIRSTNAME & ' ' & gr.LASTNAME)#? This cannot be undone.')"">
                    <input type='hidden' name='goneID'     value='#gr.GONEID#'>
                    <input type='hidden' name='resolution' value='deleted'>
                    <input type='hidden' name='userID'     value='#gr.USERID#'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(goneReturnTo)#'>
                    <button type='submit' class='btn btn-sm btn-danger py-0'>
                        <i class='bi bi-trash'></i> Delete User
                    </button>
                </form>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'>
                    <input type='hidden' name='goneID'     value='#gr.GONEID#'>
                    <input type='hidden' name='resolution' value='kept'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(goneReturnTo)#'>
                    <button type='submit' class='btn btn-sm btn-outline-secondary py-0'>
                        <i class='bi bi-person-check'></i> Keep
                    </button>
                </form>
                <a href='/admin/users/view.cfm?userID=#gr.USERID#' class='btn btn-sm btn-outline-primary py-0 ms-1'>
                    <i class='bi bi-eye'></i> View
                </a>
            </td>
        </tr>
        ">
    </cfloop>
    <cfset content &= "</tbody></table></div>">
</cfif>

<cfset content &= "</div>"> <!--- end tab-gone --->

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Tab 3: New in UH ────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<cfset content &= "<div class='tab-pane fade#tabNewActive#' id='tab-new' role='tabpanel'>">

<cfif arrayLen(newRows) EQ 0>
    <cfset content &= "<div class='alert alert-success'><i class='bi bi-check-circle-fill'></i>
        No new API users found that are missing from the local database.</div>">
<cfelse>
    <cfset content &= "
    <p class='text-muted small mb-3'>
        These people appear in the UH API but have no matching local record.
        You can import them as new users (UH Sync) or ignore them.
    </p>
    <div class='table-responsive'>
    <table class='table table-sm table-striped table-hover align-middle'>
        <thead class='table-dark'>
            <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Title</th>
                <th>Department</th>
                <th>UH API ID</th>
                <th class='text-end'>Actions</th>
            </tr>
        </thead>
        <tbody>
    ">
    <cfset newReturnTo = "/admin/reporting/uh_sync_report.cfm?runID=#currentRun.RUNID#&tab=new">
    <cfloop from="1" to="#arrayLen(newRows)#" index="i">
        <cfset nr = newRows[i]>
        <cfset content &= "
        <tr>
            <td class='fw-semibold'>#EncodeForHTML(nr.FIRSTNAME & ' ' & nr.LASTNAME)#</td>
            <td>#EncodeForHTML(nr.EMAIL)#</td>
            <td>#EncodeForHTML(nr.TITLE)#</td>
            <td>#EncodeForHTML(nr.DEPARTMENT)#</td>
            <td><code class='small'>#EncodeForHTML(nr.UHApiID ?: '')#</code></td>
            <td class='text-end text-nowrap'>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                    <input type='hidden' name='newID'      value='#nr.NEWID#'>
                    <input type='hidden' name='resolution' value='imported'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(newReturnTo)#'>
                    <button type='submit' class='btn btn-sm btn-success py-0'>
                        <i class='bi bi-person-plus'></i> Import
                    </button>
                </form>
                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'>
                    <input type='hidden' name='newID'      value='#nr.NEWID#'>
                    <input type='hidden' name='resolution' value='ignored'>
                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(newReturnTo)#'>
                    <button type='submit' class='btn btn-sm btn-outline-secondary py-0'>
                        <i class='bi bi-x'></i> Ignore
                    </button>
                </form>
            </td>
        </tr>
        ">
    </cfloop>
    <cfset content &= "</tbody></table></div>">
</cfif>

<cfset content &= "</div>"> <!--- end tab-new --->

<cfset content &= "</div>"> <!--- end tab-content --->

<!--- ── JS to persist active tab in sessionStorage ── --->
<cfset content &= "
<script>
(function () {
    var tabs = document.querySelectorAll('##syncTabs button[data-bs-toggle=""tab""]');
    if (!tabs.length) return;
    tabs.forEach(function (btn) {
        btn.addEventListener('shown.bs.tab', function (e) {
            sessionStorage.setItem('uhSyncTab_#currentRun.RUNID#', e.target.getAttribute('data-bs-target'));
        });
    });
    var saved = sessionStorage.getItem('uhSyncTab_#currentRun.RUNID#');
    if (saved) {
        var el = document.querySelector('##syncTabs button[data-bs-target=""' + saved + '""]');
        if (el) { var t = new bootstrap.Tab(el); t.show(); }
    }
})();
</script>
">

<cfinclude template="/admin/layout.cfm">
