<!---
    Bulk Exclusions Dashboard — run, view status, recent history.
    Permission: settings.bulk_exclusions.manage.
--->

<cfif NOT request.hasPermission("settings.bulk_exclusions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset svc        = createObject("component", "cfc.bulkExclusions_service").init()>
<cfset types      = svc.getTypes()>
<cfset recentRuns = []>
<cfset dbOk       = true>
<cfset dbError    = "">
<cfset msgParam   = structKeyExists(url, "msg") ? url.msg : "">
<cfset errParam   = structKeyExists(url, "err") ? url.err : "">

<cftry>
    <cfset recentRuns = svc.getRecentRuns(20)>
<cfcatch type="any">
    <cfset dbOk    = false>
    <cfset dbError = cfcatch.message>
</cfcatch>
</cftry>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-bulk-exclusions-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Bulk Exclusions</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-funnel-fill me-2"></i>Bulk Exclusions</h1>
<p class="text-muted">Insert data quality exclusions in bulk by user type. Safe to re-run (idempotent).</p>

<!--- Status messages --->
<cfif len(msgParam)>
    <div class="alert alert-success alert-dismissible fade show mt-3">
        #encodeForHTML(msgParam)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>
<cfif len(errParam)>
    <div class="alert alert-danger alert-dismissible fade show mt-3">
        #encodeForHTML(errParam)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>

<cfif NOT dbOk>
    <div class="alert alert-warning mt-3">
        <strong>Database notice:</strong> #encodeForHTML(dbError)#
        <br><small class="text-muted">The BulkExclusionRuns table may not exist yet.
        Run <code>sql/create_bulk_exclusion_runs.sql</code> against the database.</small>
    </div>
</cfif>

<!--- ── Run All button ── --->
<div class="mb-4 mt-3">
    <form method="post" action="/admin/settings/bulk-exclusions/run.cfm" class="d-inline">
        <input type="hidden" name="typeKey" value="ALL">
        <button type="submit" class="btn btn-primary"
                onclick="return confirm('Run ALL 6 exclusion types?')">
            <i class="bi bi-play-fill me-1"></i>Run All Exclusions
        </button>
    </form>
</div>

<!--- ── Type cards ── --->
<div class="row g-4">
    <cfloop array="#types#" index="t">
        <cfset lastRun = dbOk ? svc.getLatestRunByType(t.TYPE_KEY) : {}>
        <div class="col-md-6 col-lg-4">
            <div class="card border-0 shadow-sm h-100 settings-hub-card settings-hub-card--primary">
                <div class="card-body">
                    <div class="d-flex justify-content-between align-items-start">
                        <h5 class="card-title mb-2">
                            <i class="bi #t.ICON# me-2 settings-hub-icon"></i>#encodeForHTML(t.LABEL)#
                        </h5>
                        <a href="/admin/settings/bulk-exclusions/edit.cfm?type=#encodeForURL(t.TYPE_KEY)#"
                           class="users-list-action-button users-list-action-button-edit" title="Edit flags &amp; codes" aria-label="Edit #encodeForHTMLAttribute(t.LABEL)#">
                            <i class="bi bi-pencil-square"></i>
                        </a>
                    </div>
                    <p class="mb-1"><strong>Flags:</strong> <span class="text-muted">#encodeForHTML(t.FLAGS)#</span></p>
                    <p class="mb-2"><strong>Codes:</strong></p>
                    <div class="mb-3">
                        <cfloop list="#t.CODES#" index="code">
                            <span class="badge settings-badge-neutral me-1 mb-1">#trim(code)#</span>
                        </cfloop>
                    </div>
                    <cfif structCount(lastRun)>
                        <p class="text-muted small mb-1">
                            Last run: #dateTimeFormat(lastRun.RUNAT, "MMM d, yyyy h:nn tt")# UTC
                        </p>
                        <p class="small mb-2">
                            Rows inserted: <strong>#lastRun.ROWSAFFECTED#</strong>
                            &middot; Triggered: #encodeForHTML(lastRun.TRIGGEREDBY)#
                        </p>
                    <cfelse>
                        <p class="text-muted small mb-2">Never run</p>
                    </cfif>
                    <form method="post" action="/admin/settings/bulk-exclusions/run.cfm">
                        <input type="hidden" name="typeKey" value="#t.TYPE_KEY#">
                        <button type="submit" class="btn btn-sm btn-outline-primary">
                            <i class="bi bi-play me-1"></i>Run Now
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </cfloop>
</div>

<!--- ── Run History ── --->
<cfif dbOk AND arrayLen(recentRuns)>
<div class="card border-0 shadow-sm mt-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3"><i class="bi bi-clock-history me-2"></i>Recent Runs</h5>
        <div class="table-responsive">
            <table class="table table-hover table-sm align-middle mb-0 settings-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Type</th>
                        <th>Rows</th>
                        <th>Triggered</th>
                        <th>Run At (UTC)</th>
                        <th>Error</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop array="#recentRuns#" index="r">
                    <tr>
                        <td>#r.RUNID#</td>
                        <td><span class="badge settings-badge-primary-soft">#encodeForHTML(r.EXCLUSIONTYPE)#</span></td>
                        <td>#r.ROWSAFFECTED#</td>
                        <td>#encodeForHTML(r.TRIGGEREDBY)#</td>
                        <td>#dateTimeFormat(r.RUNAT, "MMM d, yyyy h:nn tt")#</td>
                        <td>
                            <cfif len(r.ERRORMESSAGE ?: "")>
                                <span class="text-danger" title="#encodeForHTMLAttribute(r.ERRORMESSAGE)#">
                                    <i class="bi bi-exclamation-circle"></i>
                                </span>
                            <cfelse>
                                <span class="text-success"><i class="bi bi-check-circle"></i></span>
                            </cfif>
                        </td>
                    </tr>
                </cfloop>
                </tbody>
            </table>
        </div>
    </div>
</div>
</cfif>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
