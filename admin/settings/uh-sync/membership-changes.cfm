<!---
    UH Sync: Membership Changes
    Left UH and New in UH tracking.
    Split from the combined uh_sync_report.cfm — shows the Gone + New tabs.
--->

<cfif NOT request.hasPermission("settings.uh_sync.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset quarantineMode = "page">
<cfset quarantineReturnTo = "/admin/settings/uh-sync/">
<cfinclude template="/admin/users/_uh_workflow_quarantine_guard.cfm">

<!--- ── URL params ── --->
<cfset msgParam  = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam  = structKeyExists(url, "err") ? url.err : "">
<cfset viewRunID = structKeyExists(url, "runID") AND isNumeric(url.runID) ? val(url.runID) : 0>
<cfset activeTab = structKeyExists(url, "tab") ? trim(url.tab) : "gone">

<!--- ── Load data ── --->
<cfset uhSyncDAO  = createObject("component", "dao.uhSync_DAO").init()>
<cfset recentRuns = []>
<cfset currentRun = {}>
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
        <cfset goneRows = uhSyncDAO.getGoneByRun(currentRun.RUNID)>
        <cfset newRows  = uhSyncDAO.getNewByRun(currentRun.RUNID)>
    </cfif>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Sort params ── --->
<cfset allowedGoneSortCols = ["LASTNAME","TITLE1"]>
<cfset goneSortCol = (structKeyExists(url, "goneSortCol") AND arrayFindNoCase(allowedGoneSortCols, url.goneSortCol) GT 0) ? url.goneSortCol : "LASTNAME">
<cfset goneSortDir = ((url.goneSortDir ?: "") EQ "DESC") ? "DESC" : "ASC">

<cfset allowedNewSortCols = ["LASTNAME","EMAIL","DEPARTMENT"]>
<cfset newSortCol = (structKeyExists(url, "newSortCol") AND arrayFindNoCase(allowedNewSortCols, url.newSortCol) GT 0) ? url.newSortCol : "LASTNAME">
<cfset newSortDir = ((url.newSortDir ?: "") EQ "DESC") ? "DESC" : "ASC">

<cfscript>
    arraySort(goneRows, function(a, b) {
        var aVal = lCase(toString(isNull(a[goneSortCol]) ? "" : a[goneSortCol]));
        var bVal = lCase(toString(isNull(b[goneSortCol]) ? "" : b[goneSortCol]));
        if (aVal LT bVal) return goneSortDir EQ "ASC" ? -1 : 1;
        if (aVal GT bVal) return goneSortDir EQ "ASC" ? 1 : -1;
        return 0;
    });
    arraySort(newRows, function(a, b) {
        var aVal = lCase(toString(isNull(a[newSortCol]) ? "" : a[newSortCol]));
        var bVal = lCase(toString(isNull(b[newSortCol]) ? "" : b[newSortCol]));
        if (aVal LT bVal) return newSortDir EQ "ASC" ? -1 : 1;
        if (aVal GT bVal) return newSortDir EQ "ASC" ? 1 : -1;
        return 0;
    });
    function goneSortLink(col) {
        var dir = (goneSortCol EQ col AND goneSortDir EQ "ASC") ? "DESC" : "ASC";
        var base = structIsEmpty(currentRun) ? "?" : "?runID=" & currentRun.RUNID & "&tab=gone&";
        return base & "goneSortCol=" & col & "&goneSortDir=" & dir;
    }
    function goneSortArrow(col) {
        if (goneSortCol EQ col) return goneSortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
    function newSortLink(col) {
        var dir = (newSortCol EQ col AND newSortDir EQ "ASC") ? "DESC" : "ASC";
        var base = structIsEmpty(currentRun) ? "?" : "?runID=" & currentRun.RUNID & "&tab=new&";
        return base & "newSortCol=" & col & "&newSortDir=" & dir;
    }
    function newSortArrow(col) {
        if (newSortCol EQ col) return newSortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
</cfscript>

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Page content ────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-uh-sync-membership-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">UH Sync: Membership Changes</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-3">
    <div>
        <h1 class="mb-1"><i class="bi bi-people me-2"></i>UH Sync: Membership Changes</h1>
        <p class="text-muted mb-0">Track users who have left UH or are new in the UH API.</p>
    
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
            <a href="/admin/settings/uh-sync/changed-fields.cfm<cfif NOT structIsEmpty(currentRun)>?runID=#currentRun.RUNID#</cfif>" class="btn btn-ui-go btn-sm">
                <i class="bi bi-arrow-left-right me-1"></i> Changed Fields
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
            <i class="bi bi-people display-4 text-muted"></i>
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
    <span class="badge bg-danger fs-6">#currentRun.TOTALGONE# gone</span>
    <span class="badge bg-info text-dark fs-6">#currentRun.TOTALNEW# new</span>
</div>

<!--- ── Tabs: Left UH / New in UH ── --->
<cfset tabGoneActive = (activeTab NEQ "new") ? " show active" : "">
<cfset tabNewActive  = (activeTab EQ "new")  ? " show active" : "">
<cfset navGoneActive = (tabGoneActive NEQ "") ? " active" : "">
<cfset navNewActive  = (tabNewActive  NEQ "") ? " active" : "">

<ul class="nav nav-tabs mb-3" id="memberTabs" role="tablist">
    <li class="nav-item" role="presentation">
        <button class="nav-link#navGoneActive#" data-bs-toggle="tab" data-bs-target="##tab-gone" type="button">
            <i class="bi bi-person-dash me-1"></i>
            Left UH
            <span class="badge bg-danger ms-1">#currentRun.TOTALGONE#</span>
        </button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link#navNewActive#" data-bs-toggle="tab" data-bs-target="##tab-new" type="button">
            <i class="bi bi-person-plus me-1"></i>
            New in UH
            <span class="badge bg-info text-dark ms-1">#currentRun.TOTALNEW#</span>
        </button>
    </li>
</ul>
<div class="tab-content">

<!--- ── Tab: Left UH (Gone) ── --->
<div class="tab-pane fade#tabGoneActive#" id="tab-gone" role="tabpanel">
<cfif arrayLen(goneRows) EQ 0>
    <div class="alert alert-success">
        <i class="bi bi-check-circle-fill me-1"></i>
        No users found in the local database that are missing from the API.
    </div>
<cfelse>
    <p class="text-muted small mb-3">
        These users have a UH API ID in the local database but were <strong>not returned</strong> by the UH API.
        They may have left UH. Review each record and delete or keep as appropriate.
    </p>
    <div class="table-responsive settings-shell">
    <table class="table table-sm table-hover align-middle mb-0 settings-table">
        <thead>
            <tr>
                <th><a href="#goneSortLink('LASTNAME')#" class="settings-sort-link">User#goneSortArrow('LASTNAME')#</a></th>
                <th><a href="#goneSortLink('TITLE1')#" class="settings-sort-link">Title#goneSortArrow('TITLE1')#</a></th>
                <th>UH API ID</th>
                <th class="text-end">Actions</th>
            </tr>
        </thead>
        <tbody>
        <cfset goneReturnTo = "/admin/settings/uh-sync/membership-changes.cfm?runID=#currentRun.RUNID#&tab=gone">
        <cfloop from="1" to="#arrayLen(goneRows)#" index="i">
            <cfset gr = goneRows[i]>
            <tr>
                <td>
                    <a href="/admin/users/edit.cfm?userID=#gr.USERID#" class="text-decoration-none fw-semibold">
                        #encodeForHTML(gr.FIRSTNAME & " " & gr.LASTNAME)#
                    </a>
                    <br><small class="text-muted">#encodeForHTML(gr.EMAILPRIMARY)#</small>
                </td>
                <td>#encodeForHTML(gr.TITLE1 ?: "")#</td>
                <td><code class="small">#encodeForHTML(gr.UH_API_ID)#</code></td>
                <td class="text-end text-nowrap">
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline js-confirm-submit"
                          data-confirm-title="Delete User"
                          data-confirm-message="Delete #encodeForJavaScript(gr.FIRSTNAME & ' ' & gr.LASTNAME)#? This cannot be undone."
                          data-confirm-ok="Delete"
                          data-confirm-class="danger">
                        <input type="hidden" name="goneID"     value="#gr.GONEID#">
                        <input type="hidden" name="resolution" value="deleted">
                        <input type="hidden" name="userID"     value="#gr.USERID#">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(goneReturnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-delete py-0">
                            <i class="bi bi-trash"></i> Delete User
                        </button>
                    </form>
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline ms-1">
                        <input type="hidden" name="goneID"     value="#gr.GONEID#">
                        <input type="hidden" name="resolution" value="kept">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(goneReturnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-cancel py-0">
                            <i class="bi bi-person-check"></i> Keep
                        </button>
                    </form>
                    <a href="/admin/users/view.cfm?userID=#gr.USERID#" class="btn btn-sm btn-ui-go py-0 ms-1">
                        <i class="bi bi-eye"></i> View
                    </a>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    </div>
</cfif>
</div>

<!--- ── Tab: New in UH ── --->
<div class="tab-pane fade#tabNewActive#" id="tab-new" role="tabpanel">
<cfif arrayLen(newRows) EQ 0>
    <div class="alert alert-success">
        <i class="bi bi-check-circle-fill me-1"></i>
        No new API users found that are missing from the local database.
    </div>
<cfelse>
    <p class="text-muted small mb-3">
        These people appear in the UH API but have no matching local record.
        You can import them as new users or ignore them.
    </p>
    <div class="table-responsive settings-shell">
    <table class="table table-sm table-hover align-middle mb-0 settings-table">
        <thead>
            <tr>
                <th><a href="#newSortLink('LASTNAME')#" class="settings-sort-link">Name#newSortArrow('LASTNAME')#</a></th>
                <th><a href="#newSortLink('EMAIL')#" class="settings-sort-link">Email#newSortArrow('EMAIL')#</a></th>
                <th>Title</th>
                <th><a href="#newSortLink('DEPARTMENT')#" class="settings-sort-link">Department#newSortArrow('DEPARTMENT')#</a></th>
                <th>UH API ID</th>
                <th class="text-end">Actions</th>
            </tr>
        </thead>
        <tbody>
        <cfset newReturnTo = "/admin/settings/uh-sync/membership-changes.cfm?runID=#currentRun.RUNID#&tab=new">
        <cfloop from="1" to="#arrayLen(newRows)#" index="i">
            <cfset nr = newRows[i]>
            <tr>
                <td class="fw-semibold">#encodeForHTML(nr.FIRSTNAME & " " & nr.LASTNAME)#</td>
                <td>#encodeForHTML(nr.EMAIL)#</td>
                <td>#encodeForHTML(nr.TITLE)#</td>
                <td>#encodeForHTML(nr.DEPARTMENT)#</td>
                <td><code class="small">#encodeForHTML(nr.UHApiID ?: "")#</code></td>
                <td class="text-end text-nowrap">
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline">
                        <input type="hidden" name="newID"      value="#nr.NEWID#">
                        <input type="hidden" name="resolution" value="imported">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(newReturnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-save py-0">
                            <i class="bi bi-person-plus"></i> Import
                        </button>
                    </form>
                    <form method="post" action="/admin/users/resolve_uh_sync_diff.cfm" class="d-inline ms-1">
                        <input type="hidden" name="newID"      value="#nr.NEWID#">
                        <input type="hidden" name="resolution" value="ignored">
                        <input type="hidden" name="returnTo"   value="#encodeForHTMLAttribute(newReturnTo)#">
                        <button type="submit" class="btn btn-sm btn-ui-cancel py-0">
                            <i class="bi bi-x"></i> Ignore
                        </button>
                    </form>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    </div>
</cfif>
</div>

</div><!--- end tab-content --->

<!--- ── JS to persist active tab ── --->
<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
(function () {
    'use strict';
    var tabs = document.querySelectorAll('##memberTabs button[data-bs-toggle="tab"]');
    if (!tabs.length) return;
    tabs.forEach(function (btn) {
        btn.addEventListener('shown.bs.tab', function (e) {
            sessionStorage.setItem('uhMemberTab_#currentRun.RUNID#', e.target.getAttribute('data-bs-target'));
        });
    });
    var saved = sessionStorage.getItem('uhMemberTab_#currentRun.RUNID#');
    if (saved) {
        var el = document.querySelector('##memberTabs button[data-bs-target="' + saved + '"]');
        if (el) { var t = new bootstrap.Tab(el); t.show(); }
    }
}());
</script>

</cfif><!--- end currentRun check --->

</div>

<cfinclude template="/admin/settings/_confirm_modal.cfm">

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
