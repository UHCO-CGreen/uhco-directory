<!--- ── Data Quality last run ── --->
<cfset dqLastRun  = {}>
<cfset dqDbOk     = true>
<cftry>
    <cfset dqDAO    = createObject("component", "dao.dataQuality_DAO").init()>
    <cfset dqRuns   = dqDAO.getRecentRuns(1)>
    <cfset dqLastRun = arrayLen(dqRuns) ? dqRuns[1] : {}>
<cfcatch>
    <cfset dqDbOk = false>
</cfcatch>
</cftry>

<!--- ── UH Sync last run ── --->
<cfset uhSyncLastRun = {}>
<cfset uhSyncDbOk    = true>
<cftry>
    <cfset uhSyncDAO_dash  = createObject("component", "dao.uhSync_DAO").init()>
    <cfset uhSyncLastRun   = uhSyncDAO_dash.getLatestRun()>
<cfcatch>
    <cfset uhSyncDbOk = false>
</cfcatch>
</cftry>

<cfset dqIssues    = structIsEmpty(dqLastRun) ? -1 : dqLastRun.TOTALISSUES>
<cfset dqBadgeCls  = dqIssues GT 0 ? "bg-danger" : (dqIssues EQ 0 ? "bg-success" : "bg-secondary")>
<cfset dqBadgeTxt  = dqIssues EQ -1 ? "Never run" : dqIssues & " issue(s)">
<cfset dqSubtitle  = structIsEmpty(dqLastRun) ? "No report has been run yet." : "Last run: " & dateTimeFormat(dqLastRun.RUNAT, "mmm d, yyyy HH:nn") & " UTC">

<!--- ── UH Sync badge values ── --->
<cfset uhSyncHasPending = false>
<cfset uhSyncBadgeCls   = "bg-secondary">
<cfset uhSyncBadgeTxt   = "Never run">
<cfset uhSyncSubtitle   = "No sync has been run yet.">
<cfset uhSyncBorderCls  = "">
<cfif NOT structIsEmpty(uhSyncLastRun)>
    <cfset uhSyncTotalPending = (uhSyncLastRun.TOTALDIFFS ?: 0) + (uhSyncLastRun.TOTALGONE ?: 0) + (uhSyncLastRun.TOTALNEW ?: 0)>
    <cfset uhSyncHasPending   = (uhSyncTotalPending GT 0)>
    <cfset uhSyncBadgeCls     = uhSyncHasPending ? "bg-warning text-dark" : "bg-success">
    <cfset uhSyncBadgeTxt     = uhSyncHasPending ? uhSyncTotalPending & " pending" : "Up to date">
    <cfset uhSyncSubtitle     = "Last run: " & dateTimeFormat(uhSyncLastRun.RUNAT, "mmm d, yyyy HH:nn") & " UTC — "
        & (uhSyncLastRun.TOTALDIFFS ?: 0) & " diff(s), "
        & (uhSyncLastRun.TOTALGONE  ?: 0) & " gone, "
        & (uhSyncLastRun.TOTALNEW   ?: 0) & " new">
    <cfset uhSyncBorderCls    = uhSyncHasPending ? "border-warning" : "border-success">
</cfif>

<cfset content = "
<div class='dashboard-shell'>
    <div>
        <h1 class='dashboard-title'>UHCO_<em>Identity</em> Admin Dashboard</h1>
        <p class='dashboard-subtitle mb-0 mt-2'>Manage directory records, review sync health, and access the core operational tools for UHCO Identity.</p>
    </div>

<div class='row'>
    <div class='col-md-8'>
        <div class='row g-4'>
            <div class='col-md-6'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-people-fill sidebar-icon'></i><span>Users</span></h5>
                            <p class='card-text dashboard-card-text'>Manage UHCO user records.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <div class='dropdown'>
                                <button class='btn btn-primary btn-sm dropdown-toggle' type='button' data-bs-toggle='dropdown' data-bs-boundary='viewport' aria-expanded='false'>
                                    <i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage Users
                                </button>
                                <ul class='dropdown-menu'>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm'><i class='bi bi-exclamation-triangle sidebar-icon me-2'></i>Problem Records</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=faculty'><i class='bi bi-people-fill sidebar-icon me-2'></i>Faculty</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=staff'><i class='bi bi-people-fill sidebar-icon me-2'></i>Staff</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=current-students'><i class='bi bi-people-fill sidebar-icon me-2'></i>Current Students</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=alumni'><i class='bi bi-mortarboard sidebar-icon me-2'></i>Alumni</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=inactive-users'><i class='bi bi-person-dash sidebar-icon me-2'></i>Inactive Users</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/index.cfm?list=all'><i class='bi bi-list sidebar-icon me-2'></i>All Records</a></li>
                                    <li><a class='dropdown-item' href='/admin/users/search-uh-api.cfm'><i class='bi bi-search sidebar-icon me-2'></i>Search UH API</a></li>
                                </ul>
                                </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-6'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-flag-fill sidebar-icon'></i><span>Flags</span></h5>
                            <p class='card-text dashboard-card-text'>Assign display flags.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/flags/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage Flags</a>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-6'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-building-fill sidebar-icon'></i><span>Organizations</span></h5>
                            <p class='card-text dashboard-card-text'>Manage organizational groups.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/orgs/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage Orgs</a>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-6'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-person-bounding-box sidebar-icon'></i><span>External IDs</span></h5>
                            <p class='card-text dashboard-card-text'>Manage external IDs for users.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/external/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage IDs</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class='col-md-4'>
        <div class='row g-4'>
            <div class='col-md-12'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-braces sidebar-icon'></i><span>UHCO API</span></h5>
                            <p class='card-text dashboard-card-text'>Manage UHCO API settings and integrations.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/tokens/index.cfm' class='btn btn-sm btn-primary'><i class='bi bi-key-fill sidebar-icon me-2'></i>Manage Tokens</a>
                            <a href='/admin/tokens/index.cfm' class='btn btn-sm btn-primary'><i class='bi bi-shield-lock-fill sidebar-icon me-2'></i>Manage Secrets</a>
                            <a href='/api/docs.html' class='btn btn-sm btn-primary'><i class='bi bi-book-fill me-2'></i>Documentation</a>
                        </div>
                    </div>
                </div>
            </div>
            <div class='col-12'>
                <div class='card shadow-sm dashboard-card dashboard-status-card " & (dqIssues GT 0 ? "border-danger" : (dqIssues EQ 0 ? "border-success" : "")) & "'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div class='dashboard-status-copy'>
                            <h5 class='card-title dashboard-card-title mb-0'>
                                <i class='bi bi-clipboard-data me-2'></i>Data Quality Report
                                <span class='badge #dqBadgeCls# fs-6'>#dqBadgeTxt#</span>
                            </h5>
                            <small class='text-muted'>#dqSubtitle#</small>
                        </div>
                        <div class='dashboard-actions'>
                            
                            <a href='/admin/reporting/data_quality_report.cfm' class='btn btn-sm btn-primary'><i class='bi bi-file-earmark-text-fill me-2'></i>View Report</a>
                            <a href='/admin/reporting/run_data_quality_report.cfm' class='btn btn-sm btn-outline-secondary'><i class='bi bi-play-fill me-2'></i>Run Now</a>
                        </div>
                    </div>
                </div>
            </div>
            <div class='col-12'>
                <div class='card shadow-sm dashboard-card dashboard-status-card #uhSyncBorderCls#''>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div class='dashboard-status-copy'>
                            <h5 class='card-title dashboard-card-title mb-0'>
                                <i class='bi bi-arrow-left-right me-2'></i>UH API Sync Report
                                <span class='badge #uhSyncBadgeCls# fs-6'>#uhSyncBadgeTxt#</span>
                            </h5>
                            <small class='text-muted'>#uhSyncSubtitle#</small>
                        </div>
                        <div class='dashboard-actions'>
                            
                            <a href='/admin/reporting/uh_sync_report.cfm' class='btn btn-sm btn-primary'><i class='bi bi-file-earmark-text-fill me-2'></i>View Report</a>
                            <a href='/admin/reporting/run_uh_sync_report.cfm' class='btn btn-sm btn-outline-secondary'><i class='bi bi-play-fill me-2'></i>Run Now</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">