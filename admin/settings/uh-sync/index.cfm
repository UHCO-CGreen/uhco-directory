<!---
    UH Sync Hub — overview of sync reports.
    Permission: settings.uh_sync.view.
--->

<cfif NOT request.hasPermission("settings.uh_sync.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- Load latest run info --->
<cfset uhSyncDAO  = createObject("component", "dao.uhSync_DAO").init()>
<cfset recentRuns = []>
<cfset latestRun  = {}>
<cfset dbOk       = true>
<cfset dbError    = "">

<cftry>
    <cfset recentRuns = uhSyncDAO.getRecentRuns(1)>
    <cfif arrayLen(recentRuns)>
        <cfset latestRun = recentRuns[1]>
    </cfif>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-uh-sync-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">UH Sync</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-arrow-left-right me-2"></i>UH Sync</h1>
<p class="text-muted">Compare local directory data against the UH API. View field-level changes and membership additions/removals.</p>

<cfif NOT dbOk>
    <div class="alert alert-warning mt-3">
        <strong>Database notice:</strong> #encodeForHTML(dbError)#
    </div>
</cfif>

<!--- Latest run summary --->
<cfif NOT structIsEmpty(latestRun)>
    <div class="alert alert-light border mt-3">
        <i class="bi bi-info-circle me-1"></i>
        <strong>Latest sync run:</strong>
        #dateTimeFormat(latestRun.RUNAT, "MMM d, yyyy h:nn tt")# UTC
        <cfif structKeyExists(latestRun, "STATUS")>
            &middot; Status: <span class="badge bg-success">#encodeForHTML(latestRun.STATUS)#</span>
        </cfif>
    </div>
</cfif>

<div class="row g-4 mt-2">

    <!--- Changed Fields --->
    <div class="col-md-6">
        <a href="/admin/settings/uh-sync/changed-fields.cfm" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm settings-hub-card settings-hub-card--primary">
                <div class="card-body text-center py-4">
                    <i class="bi bi-arrow-left-right display-4 mb-3 settings-hub-icon"></i>
                    <h5 class="card-title text-dark">Changed Fields</h5>
                    <p class="card-text text-muted small">Field-level diffs between local DB and UH API</p>
                </div>
            </div>
        </a>
    </div>

    <!--- Membership Changes --->
    <div class="col-md-6">
        <a href="/admin/settings/uh-sync/membership-changes.cfm" class="text-decoration-none">
            <div class="card h-100 border-0 shadow-sm settings-hub-card settings-hub-card--success">
                <div class="card-body text-center py-4">
                    <i class="bi bi-people display-4 mb-3 settings-hub-icon settings-hub-icon--success"></i>
                    <h5 class="card-title text-dark">Membership Changes</h5>
                    <p class="card-text text-muted small">Left UH / New in UH tracking</p>
                </div>
            </div>
        </a>
    </div>

</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
