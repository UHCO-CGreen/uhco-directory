<!---
    UH Sync: Changed Fields
    Field-level diffs between local database and UH API.
    Split from the combined uh_sync_report.cfm — shows only the "Changed Fields" tab.
--->

<cfif NOT request.hasPermission("settings.uh_sync.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset quarantineMode = "page">
<cfset quarantineReturnTo = "/admin/settings/uh-sync/">
<cfinclude template="/admin/users/_uh_workflow_quarantine_guard.cfm">

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
<cfset msgParam    = structKeyExists(url, "msg")    ? url.msg           : "">
<cfset errParam    = structKeyExists(url, "err")    ? url.err           : "">
<cfset viewRunID   = structKeyExists(url, "runID") AND isNumeric(url.runID) ? val(url.runID) : 0>
<cfset filterField = structKeyExists(url, "filter") ? trim(url.filter)  : "">

<!--- ── Load data ── --->
<cfset uhSyncDAO  = createObject("component", "dao.uhSync_DAO").init()>
<cfset recentRuns = []>
<cfset currentRun = {}>
<cfset diffRows   = []>
<cfset diffSummary = []>
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
    </cfif>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Build diff summary lookup ── --->
<cfset diffSummaryMap = {}>
<cfloop from="1" to="#arrayLen(diffSummary)#" index="i">
    <cfset diffSummaryMap[diffSummary[i].FIELDNAME] = diffSummary[i].DIFFCOUNT>
</cfloop>

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Page content ────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<!--- Sort params for diff table --->
<cfset allowedDiffSortCols = ["LASTNAME","FIELDNAME"]>
<cfset sortCol = (structKeyExists(url, "sortCol") AND arrayFindNoCase(allowedDiffSortCols, url.sortCol) GT 0) ? url.sortCol : "LASTNAME">
<cfset sortDir = ((url.sortDir ?: "") EQ "DESC") ? "DESC" : "ASC">
<cfscript>
    arraySort(diffRows, function(a, b) {
        var aVal = lCase(toString(isNull(a[sortCol]) ? "" : a[sortCol]));
        var bVal = lCase(toString(isNull(b[sortCol]) ? "" : b[sortCol]));
        if (aVal LT bVal) return sortDir EQ "ASC" ? -1 : 1;
        if (aVal GT bVal) return sortDir EQ "ASC" ? 1 : -1;
        return 0;
    });
    function diffSortLink(col) {
        var dir = (sortCol EQ col AND sortDir EQ "ASC") ? "DESC" : "ASC";
        var base = structIsEmpty(currentRun) ? "?" : "?runID=" & currentRun.RUNID & (len(filterField) ? "&filter=" & urlEncodedFormat(filterField) : "") & "&";
        return base & "sortCol=" & col & "&sortDir=" & dir;
    }
    function diffSortArrow(col) {
        if (sortCol EQ col) return sortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
</cfscript>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-uh-sync-changed-fields-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">UH Sync: Changed Fields</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-3">
    <div>
        <h1 class="mb-1"><i class="bi bi-arrow-left-right me-2"></i>UH Sync: Changed Fields</h1>
        <p class="text-muted mb-0">Field-level differences between the local database and the UH API.</p>

        
            <div class="mb-3 mt-2 d-flex gap-2">
                <cfif arrayLen(recentRuns)>
                <button class="btn btn-ui-cancel btn-sm" type="button"
                        data-bs-toggle="collapse" data-bs-target="##historyPanel">
                    <i class="bi bi-clock-history me-1"></i> Run History
                </button>
                </cfif>
                <a href="/admin/reporting/run_uh_sync_report.cfm" class="btn btn-ui-filter btn-sm js-spinner-nav">
                    <i class="bi bi-play-fill me-1"></i> Run Sync
                </a>
                <a href="/admin/settings/uh-sync/membership-changes.cfm<cfif NOT structIsEmpty(currentRun)>?runID=#currentRun.RUNID#</cfif>" class="btn btn-ui-go btn-sm">
                    <i class="bi bi-people me-1"></i> Membership Changes
                </a>
            </div>
        
        
    </div>
    <span class='badge bg-warning text-dark float-end'>Currently in: Alpha</span>
</div>


<cfif NOT dbOk>
    <div class="alert alert-danger">Database error: #encodeForHTML(dbError)# &mdash; have you run <code>create_uh_sync_report.sql</code>?</div>
</cfif>

<!--- ── Run history (collapsible) ── --->
<cfif arrayLen(recentRuns)>

<div class="collapse mb-3" id="historyPanel">
    <div class="card card-body settings-shell">
        <h6 class="mb-2">Recent Runs</h6>
        <table class="table table-sm table-bordered mb-0 settings-table">
            <thead>
                <tr>
                    <th>Run</th><th>Date/Time (UTC)</th><th>Triggered By</th>
                    <th>Compared</th><th>Diffs</th><th>Gone</th><th>New</th><th></th>
                </tr>
            </thead>
            <tbody>
            <cfloop from="1" to="#arrayLen(recentRuns)#" index="i">
                <cfset r = recentRuns[i]>
                <cfset activeCls = (NOT structIsEmpty(currentRun) AND r.RUNID EQ currentRun.RUNID) ? " class='table-primary'" : "">
                <tr#activeCls#>
                    <td>###r.RUNID#</td>
                    <td>#dateTimeFormat(r.RUNAT, "MMM d, yyyy HH:nn")#</td>
                    <td>#encodeForHTML(r.TRIGGEREDBY)#</td>
                    <td>#r.TOTALCOMPARED#</td>
                    <td><span class="badge #(r.TOTALDIFFS GT 0 ? 'bg-warning text-dark' : 'bg-success')#">#r.TOTALDIFFS#</span></td>
                    <td><span class="badge #(r.TOTALGONE GT 0 ? 'bg-danger' : 'bg-success')#">#r.TOTALGONE#</span></td>
                    <td><span class="badge #(r.TOTALNEW GT 0 ? 'bg-info text-dark' : 'bg-success')#">#r.TOTALNEW#</span></td>
                    <td><a href="?runID=#r.RUNID#" class="btn btn-xs btn-sm btn-ui-go py-0 px-1">View</a></td>
                </tr>
            </cfloop>
            </tbody>
        </table>
    </div>
</div>
</cfif>

<!--- ── No run yet ── --->
<cfif structIsEmpty(currentRun)>
    <div class="card border-0 text-center py-5">
        <div class="card-body">
            <i class="bi bi-arrow-left-right display-4 text-muted"></i>
            <h4 class="mt-3 text-muted">No sync data yet</h4>
            <p class="text-muted">Click <strong>Run Sync</strong> to compare local records against the UH API.</p>
        </div>
    </div>
<cfelse>

<!--- ── Run header ── --->
<div class="d-flex flex-wrap align-items-center gap-3 mb-3">
    <span class="text-muted small">
        Run ##<strong>#currentRun.RUNID#</strong>
        &mdash; #dateTimeFormat(currentRun.RUNAT, "MMMM d, yyyy HH:nn")# UTC
        &mdash; triggered by <em>#encodeForHTML(currentRun.TRIGGEREDBY)#</em>
        &mdash; #currentRun.TOTALCOMPARED# users compared
    </span>
    <span class="badge bg-warning text-dark fs-6">#currentRun.TOTALDIFFS# diff(s)</span>
</div>

<!--- ── Field filter badges ── --->
<cfif arrayLen(diffSummary) GT 0>
    <div class="mb-4">
        <h6 class="text-muted mb-2">Filter by changed field</h6>
        <div class="d-flex flex-wrap gap-2">
            <cfloop from="1" to="#arrayLen(diffSummary)#" index="i">
                <cfset ds  = diffSummary[i]>
                <cfset lbl = structKeyExists(fieldLabels, ds.FIELDNAME) ? fieldLabels[ds.FIELDNAME] : ds.FIELDNAME>
                <cfset isActive = (filterField EQ ds.FIELDNAME)>
                <a href="?runID=#currentRun.RUNID#&filter=#urlEncodedFormat(ds.FIELDNAME)#"
                   class="badge #(isActive ? 'bg-primary' : 'bg-warning text-dark')# text-decoration-none fs-6">
                    #encodeForHTML(lbl)# (#ds.DIFFCOUNT#)
                </a>
            </cfloop>
            <cfif len(filterField)>
                <a href="?runID=#currentRun.RUNID#" class="btn btn-sm btn-ui-clear py-0">
                    <i class="bi bi-x"></i> Clear filter
                </a>
            </cfif>
        </div>
    </div>
</cfif>

<!--- ── Diff table ── --->
<cfif arrayLen(diffRows) EQ 0>
    <div class="alert alert-success">
        <i class="bi bi-check-circle-fill me-1"></i>
        No field differences found#(len(filterField) ? " for the selected filter" : "")#.
    </div>
<cfelse>
    <div class="table-responsive settings-shell">
    <table class="table table-sm table-hover align-middle mb-0 settings-table">
        <thead>
            <tr>
                <th><a href="#diffSortLink('LASTNAME')#" class="settings-sort-link">User#diffSortArrow('LASTNAME')#</a></th>
                <th><a href="#diffSortLink('FIELDNAME')#" class="settings-sort-link">Field#diffSortArrow('FIELDNAME')#</a></th>
                <th>Local Value</th>
                <th>API Value</th>
                <th class="text-end">Actions</th>
            </tr>
        </thead>
        <tbody>
        <cfloop from="1" to="#arrayLen(diffRows)#" index="i">
            <cfset dr     = diffRows[i]>
            <cfset fldLbl = structKeyExists(fieldLabels, dr.FIELDNAME) ? fieldLabels[dr.FIELDNAME] : dr.FIELDNAME>
            <cfset returnTo = "/admin/settings/uh-sync/changed-fields.cfm?runID=#currentRun.RUNID##(len(filterField) ? '&filter=' & urlEncodedFormat(filterField) : '')#">
            <tr>
                <td>
                    <a href="/admin/users/edit.cfm?userID=#dr.USERID#" class="text-decoration-none fw-semibold">
                        #encodeForHTML(dr.FIRSTNAME & " " & dr.LASTNAME)#
                    </a>
                    <br><small class="text-muted">#encodeForHTML(dr.EMAILPRIMARY)#</small>
                </td>
                <td><span class="badge bg-secondary">#encodeForHTML(fldLbl)#</span></td>
                <td><span class="text-muted">#(len(dr.LOCALVALUE) ? encodeForHTML(dr.LOCALVALUE) : "<em class='text-muted'>empty</em>")#</span></td>
                <td><strong>#encodeForHTML(dr.APIVALUE)#</strong></td>
                <td class="text-end text-nowrap">
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline">
                        <input type="hidden" name="diffID"     value="#dr.DIFFID#">
                        <input type="hidden" name="resolution" value="synced">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(returnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-save py-0">
                            <i class="bi bi-cloud-download"></i> Sync
                        </button>
                    </form>
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline ms-1">
                        <input type="hidden" name="diffID"     value="#dr.DIFFID#">
                        <input type="hidden" name="resolution" value="discarded">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(returnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-cancel py-0">
                            <i class="bi bi-x"></i> Discard
                        </button>
                    </form>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    </div>
</cfif>

</cfif><!--- end currentRun check --->

</div>

<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('a.js-spinner-nav').forEach(function (link) {
        link.addEventListener('click', function () {
            link.innerHTML = '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>Running&hellip;';
            link.classList.add('disabled');
            link.style.pointerEvents = 'none';
        });
    });
});
</script>

</cfoutput>
</cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif msgParam EQ "ran">
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("Sync report run complete.", { tone: 'success' });
}
<cfelseif msgParam EQ "error">
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("Error: #encodeForJavaScript(errParam)#", { tone: 'danger' });
}
<cfelseif msgParam EQ "resolved">
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'success' });
}
<cfelseif len(errParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'danger' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
