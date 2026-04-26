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
<cfset dqBadgeCls  = dqIssues GT 0 ? "bg-danger" : (dqIssues EQ 0 ? "bg-success" : "bg-secondary text-dark")>
<cfset dqBadgeTxt  = dqIssues EQ -1 ? "Never run" : dqIssues & " issue(s)">
<cfset dqSubtitle  = structIsEmpty(dqLastRun) ? "No report has been run yet." : "Last run: " & dateTimeFormat(dqLastRun.RUNAT, "mmm d, yyyy HH:nn") & " UTC">

<!--- ── UH Sync badge values ── --->
<cfset uhSyncHasPending = false>
<cfset uhSyncBadgeCls   = "bg-secondary text-dark">
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

<!--- ── Dashboard summary lists: stale users, unpublished variants, stale media ── --->
<cfset usersDAO_dash = createObject("component", "dao.users_DAO").init()>
<cfset variantsDAO_dash = createObject("component", "dao.UserImageVariantDAO").init()>
<cfset appConfigService_dash = createObject("component", "cfc.appConfig_service").init()>
<cfset usersService_dash = createObject("component", "cfc.users_service").init()>

<cfset canUsersView = request.hasPermission("users.view")>
<cfset canUsersEdit = request.hasPermission("users.edit")>
<cfset canMediaEdit = request.hasPermission("media.edit")>
<cfset canMediaPublish = request.hasPermission("media.publish")>
<cfset canViewTestUsers_dash = application.authService.hasRole("SUPER_ADMIN")>
<cfset testModeEnabledValue_dash = trim(appConfigService_dash.getValue("test_mode.enabled", "0"))>
<cfset testModeEnabled_dash = usersService_dash.isTestModeEnabled() OR (listFindNoCase("1,true,yes,on", testModeEnabledValue_dash) GT 0)>
<cfset isSuperAdminImpersonation_dash = structKeyExists(request, "isImpersonating") AND request.isImpersonating() AND structKeyExists(request, "isActualSuperAdmin") AND request.isActualSuperAdmin()>
<cfset showTestUsersForAdmin_dash = canViewTestUsers_dash OR testModeEnabled_dash OR isSuperAdminImpersonation_dash>
<cfset hideTestUsersForAdmin_dash = NOT showTestUsersForAdmin_dash>

<cfset dashboardPageSize = val(appConfigService_dash.getValue("dashboard.list_page_size", "10"))>
<cfif dashboardPageSize LT 1><cfset dashboardPageSize = 10></cfif>
<cfif dashboardPageSize GT 50><cfset dashboardPageSize = 50></cfif>

<cfset staleThresholdMonths = val(appConfigService_dash.getValue("dashboard.stale_months", "6"))>
<cfif staleThresholdMonths LT 1><cfset staleThresholdMonths = 6></cfif>
<cfif staleThresholdMonths GT 60><cfset staleThresholdMonths = 60></cfif>

<cfset staleThresholdLabel = staleThresholdMonths & " month" & (staleThresholdMonths EQ 1 ? "" : "s")>

<cfset suPage = (isNumeric(url.suPage ?: "") AND val(url.suPage) GT 0) ? val(url.suPage) : 1>
<cfset uvPage = (isNumeric(url.uvPage ?: "") AND val(url.uvPage) GT 0) ? val(url.uvPage) : 1>
<cfset smPage = (isNumeric(url.smPage ?: "") AND val(url.smPage) GT 0) ? val(url.smPage) : 1>
<cfset dashboardReturnTo = "/admin/dashboard.cfm?suPage=" & suPage & "&uvPage=" & uvPage & "&smPage=" & smPage>

<cfset staleUsersPageData = { data = [], totalCount = 0, pageSize = dashboardPageSize, pageNumber = suPage }>
<cfset staleMediaPageData = { data = [], totalCount = 0, pageSize = dashboardPageSize, pageNumber = smPage }>
<cfset unpublishedPageData = { data = [], totalCount = 0, pageSize = dashboardPageSize, pageNumber = uvPage }>

<cftry>
    <cfset staleUsersPageData = usersDAO_dash.getStaleUsersForDashboardPage(pageSize=dashboardPageSize, pageNumber=suPage, staleMonths=staleThresholdMonths, excludeTestUsers=hideTestUsersForAdmin_dash)>
<cfcatch></cfcatch>
</cftry>

<cftry>
    <cfset staleMediaPageData = variantsDAO_dash.getStaleMediaUsersForDashboardPage(pageSize=dashboardPageSize, pageNumber=smPage, staleMonths=staleThresholdMonths)>
<cfcatch></cfcatch>
</cftry>

<cftry>
    <cfset unpublishedPageData = variantsDAO_dash.getGeneratedUnpublishedVariantsForDashboardPage(pageSize=dashboardPageSize, pageNumber=uvPage)>
<cfcatch></cfcatch>
</cftry>

<cfset staleUsers = staleUsersPageData.data ?: []>
<cfset staleMediaUsers = staleMediaPageData.data ?: []>
<cfset unpublishedVariants = unpublishedPageData.data ?: []>

<cfset staleUsersTotalCount = val(staleUsersPageData.totalCount ?: 0)>
<cfset staleMediaTotalCount = val(staleMediaPageData.totalCount ?: 0)>
<cfset unpublishedTotalCount = val(unpublishedPageData.totalCount ?: 0)>

<cfset staleUsersTotalPages = max(1, ceiling(staleUsersTotalCount / dashboardPageSize))>
<cfset staleMediaTotalPages = max(1, ceiling(staleMediaTotalCount / dashboardPageSize))>
<cfset unpublishedTotalPages = max(1, ceiling(unpublishedTotalCount / dashboardPageSize))>

<cfif suPage GT staleUsersTotalPages>
    <cfset suPage = staleUsersTotalPages>
    <cftry>
        <cfset staleUsersPageData = usersDAO_dash.getStaleUsersForDashboardPage(pageSize=dashboardPageSize, pageNumber=suPage, staleMonths=staleThresholdMonths, excludeTestUsers=hideTestUsersForAdmin_dash)>
        <cfset staleUsers = staleUsersPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>
<cfif smPage GT staleMediaTotalPages>
    <cfset smPage = staleMediaTotalPages>
    <cftry>
        <cfset staleMediaPageData = variantsDAO_dash.getStaleMediaUsersForDashboardPage(pageSize=dashboardPageSize, pageNumber=smPage, staleMonths=staleThresholdMonths)>
        <cfset staleMediaUsers = staleMediaPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>
<cfif uvPage GT unpublishedTotalPages>
    <cfset uvPage = unpublishedTotalPages>
    <cftry>
        <cfset unpublishedPageData = variantsDAO_dash.getGeneratedUnpublishedVariantsForDashboardPage(pageSize=dashboardPageSize, pageNumber=uvPage)>
        <cfset unpublishedVariants = unpublishedPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>

<cfset staleUsersListHtml = "<div class='small text-muted'>No stale users found.</div>">
<cfif arrayLen(staleUsers)>
    <cfset staleUsersListHtml = "<ul class='list-unstyled small mb-0'>">
    <cfloop array="#staleUsers#" index="su">
        <cfset staleUserName = trim(su.FULLNAME ?: ((su.FIRSTNAME ?: "") & " " & (su.LASTNAME ?: "")))>
        <cfif !len(staleUserName)>
            <cfset staleUserName = "User ##" & val(su.USERID)>
        </cfif>
        <cfset staleUsersActions = "">
        <cfif canUsersEdit>
            <cfset staleUsersActions &= " <a href='/admin/users/edit.cfm?userID=#val(su.USERID)#' class='btn btn-sm btn-edit ms-1 py-0 px-1'>Edit</a>">
        </cfif>
        <cfif canUsersView>
            <cfset staleUsersActions &= " <a href='/admin/users/view.cfm?userID=#val(su.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-outline-secondary ms-1 py-0 px-1'>View</a>">
        </cfif>
        <cfset staleUsersListHtml &= "<li class='mb-1'><span class='fw-semibold'>#val(su.USERID)#</span> &mdash; #encodeForHTML(staleUserName)##staleUsersActions#</li>">
    </cfloop>
    <cfset staleUsersListHtml &= "</ul>">
</cfif>

<cfset staleUsersPagerHtml = "">
<cfif staleUsersTotalCount GT dashboardPageSize>
    <cfset staleUsersPagerHtml = "<div class='mt-3 pt-2 border-top'><div class='small text-muted mb-2'>Showing page #suPage# of #staleUsersTotalPages#</div><div class='d-flex flex-wrap gap-2 align-items-center'>">
    <cfif suPage GT 1>
        <cfset staleUsersPagerHtml &= "<a class='btn btn-sm btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#(suPage - 1)#&uvPage=#uvPage#&smPage=#smPage#'>&laquo; Previous Page</a>">
    </cfif>
    <cfloop from="1" to="#staleUsersTotalPages#" index="pagerPage">
        <cfset staleUsersPagerHtml &= "<a class='btn btn-sm #pagerPage EQ suPage ? "btn-primary disabled" : "btn-outline-secondary"#' href='/admin/dashboard.cfm?suPage=#pagerPage#&uvPage=#uvPage#&smPage=#smPage#'>#pagerPage#</a>">
    </cfloop>
    <cfif suPage LT staleUsersTotalPages>
        <cfset staleUsersPagerHtml &= "<a class='btn btn-sm btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#(suPage + 1)#&uvPage=#uvPage#&smPage=#smPage#'>Next Page &raquo;</a>">
    </cfif>
    <cfset staleUsersPagerHtml &= "</div></div>">
</cfif>

<cfset staleMediaListHtml = "<div class='small text-muted'>No stale media records found.</div>">
<cfif arrayLen(staleMediaUsers)>
    <cfset staleMediaListHtml = "<ul class='list-unstyled small mb-0'>">
    <cfloop array="#staleMediaUsers#" index="sm">
        <cfset staleMediaName = trim((sm.PREFERREDFIRSTNAME ?: sm.FIRSTNAME ?: "") & " " & (sm.PREFERREDLASTNAME ?: sm.LASTNAME ?: ""))>
        <cfif !len(staleMediaName)>
            <cfset staleMediaName = "User ##" & val(sm.USERID)>
        </cfif>
        <cfset staleMediaActions = "">
        <cfif canMediaEdit>
            <cfset staleMediaActions &= " <a href='/admin/user-media/sources.cfm?userid=#val(sm.USERID)#' class='btn btn-sm btn-outline-primary ms-1 py-0 px-1'>Media</a>">
        </cfif>
        <cfif canUsersView>
            <cfset staleMediaActions &= " <a href='/admin/users/view.cfm?userID=#val(sm.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-outline-secondary ms-1 py-0 px-1'>View</a>">
        </cfif>
        <cfset staleMediaListHtml &= "<li class='mb-1'><span class='fw-semibold'>#val(sm.USERID)#</span> &mdash; #encodeForHTML(staleMediaName)##staleMediaActions#</li>">
    </cfloop>
    <cfset staleMediaListHtml &= "</ul>">
</cfif>

<cfset staleMediaPagerHtml = "">
<cfif staleMediaTotalCount GT dashboardPageSize>
    <cfset staleMediaPagerHtml = "<div class='d-flex align-items-center justify-content-between mt-2 small text-muted'><span>Showing page #smPage# of #staleMediaTotalPages#</span><div class='btn-group btn-group-sm'>">
    <cfif smPage GT 1>
        <cfset staleMediaPagerHtml &= "<a class='btn btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#suPage#&uvPage=#uvPage#&smPage=#(smPage - 1)#'>&laquo; Prev</a>">
    </cfif>
    <cfset staleMediaPagerHtml &= "<span class='btn btn-outline-secondary disabled'>#smPage#</span>">
    <cfif smPage LT staleMediaTotalPages>
        <cfset staleMediaPagerHtml &= "<a class='btn btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#suPage#&uvPage=#uvPage#&smPage=#(smPage + 1)#'>Next &raquo;</a>">
    </cfif>
    <cfset staleMediaPagerHtml &= "</div></div>">
</cfif>

<cfset unpublishedVariantsListHtml = "<div class='small text-muted'>No unpublished variants found.</div>">
<cfif arrayLen(unpublishedVariants)>
    <cfset unpublishedVariantsListHtml = "<ul class='list-unstyled small mb-0'>">
    <cfloop array="#unpublishedVariants#" index="uv">
        <cfset unpublishedName = trim((uv.PREFERREDFIRSTNAME ?: uv.FIRSTNAME ?: "") & " " & (uv.PREFERREDLASTNAME ?: uv.LASTNAME ?: ""))>
        <cfif !len(unpublishedName)>
            <cfset unpublishedName = "User ##" & val(uv.USERID)>
        </cfif>
        <cfset unpublishedActions = "">
        <cfif canMediaEdit>
            <cfset unpublishedActions &= " <a href='/admin/user-media/variants.cfm?userid=#val(uv.USERID)#&sourceid=#val(uv.USERIMAGESOURCEID)#' class='btn btn-sm btn-outline-primary ms-1 py-0 px-1'>Open</a>">
        </cfif>
        <cfif canMediaPublish>
            <cfset unpublishedActions &= " <a href='/admin/user-media/variants.cfm?userid=#val(uv.USERID)#&sourceid=#val(uv.USERIMAGESOURCEID)#' class='btn btn-sm btn-outline-success ms-1 py-0 px-1'>Publish</a>">
        </cfif>
        <cfset unpublishedVariantsListHtml &= "<li class='mb-1'><span class='fw-semibold'>#val(uv.USERID)#</span> &mdash; #encodeForHTML(unpublishedName)# <span class='text-muted'>(#encodeForHTML(uv.VARIANTCODE ?: "")#)</span>#unpublishedActions#</li>">
    </cfloop>
    <cfset unpublishedVariantsListHtml &= "</ul>">
</cfif>

<cfset unpublishedPagerHtml = "">
<cfif unpublishedTotalCount GT dashboardPageSize>
    <cfset unpublishedPagerHtml = "<div class='d-flex align-items-center justify-content-between mt-2 small text-muted'><span>Showing page #uvPage# of #unpublishedTotalPages#</span><div class='btn-group btn-group-sm'>">
    <cfif uvPage GT 1>
        <cfset unpublishedPagerHtml &= "<a class='btn btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#suPage#&uvPage=#(uvPage - 1)#&smPage=#smPage#'>&laquo; Prev</a>">
    </cfif>
    <cfset unpublishedPagerHtml &= "<span class='btn btn-outline-secondary disabled'>#uvPage#</span>">
    <cfif uvPage LT unpublishedTotalPages>
        <cfset unpublishedPagerHtml &= "<a class='btn btn-outline-secondary' href='/admin/dashboard.cfm?suPage=#suPage#&uvPage=#(uvPage + 1)#&smPage=#smPage#'>Next &raquo;</a>">
    </cfif>
    <cfset unpublishedPagerHtml &= "</div></div>">
</cfif>

<cfset content = "
<div class='dashboard-shell'>
    <div>
        <h1 class='dashboard-title'>UHCO_<em>Identity</em> Admin Dashboard</h1>
        <p class='dashboard-subtitle mb-0 mt-2'>Manage directory records, review sync health, and access the core operational tools for UHCO Identity.</p>
    </div>

<div class='row'>
    <div class='col-md-9'>
        <div class='row g-4'>
            <div class='col-md-12'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-people-fill sidebar-icon'></i><span>Users</span></h5>
                            <p class='card-text dashboard-card-text'>Manage UHCO user records.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <div class='dropdown'>
                                <button class='btn btn-primary btn-sm dropdown-toggle' type='button' data-bs-toggle='dropdown' data-bs-boundary='viewport' aria-expanded='false'>
                                    <i class='bi bi-people-fill sidebar-icon me-2'></i>Manage Users
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
                        <div class='w-100 d-flex flex-wrap align-items-center justify-content-between gap-3 mt-3 border-top pt-3'>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>Stale Records</h5>
                                <p class='mb-0'>Records that haven't been updated in over #staleThresholdLabel#. Users shown here have been identified for review by automated processes.</p>
                                <div class='mt-2 py-2 border-top'>#staleUsersListHtml##staleUsersPagerHtml#</div>
                            </div>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>Problem Records</h5>
                                <p class='mb-0'>Records with potential issues flagged by the system or users. Users shown here have been identified for review by administrators.</p>
                                <div class='mt-2 py-2 border-top'>-</div>
                            </div>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>UH API Sync Changes</h5>
                                <p class='mb-0'>Changes detected during the last scheduled UH Sync. Users shown here have been identified for review by automated processes.</p>
                                <div class='mt-2 py-2 border-top'>-</div>
                            </div>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>User Review Queue</h5>
                                <p class='mb-0'>Submitted profile updates submitted waiting for approval. Users shown here have submitted a request for review.</p>
                                <div class='mt-2 py-2 border-top'>-</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-12'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-collection-fill sidebar-icon'></i><span>User Media</span></h5>
                            <p class='card-text dashboard-card-text'>Manage Media.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/media/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-collection-fill sidebar-icon me-2'></i>Manage Media</a>
                        </div>
                        <div class='w-100 d-flex flex-wrap align-items-center justify-content-between gap-3 mt-3 border-top pt-3'>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>Unpublished Variants</h5>
                                <p class='mb-0'>Media variants that have been generated but not yet published.</p>
                                <div class='mt-2 py-2 border-top'>#unpublishedVariantsListHtml##unpublishedPagerHtml#</div>
                            </div>
                            <div class='border m-auto p-2 flex-card'>
                                <h5>Stale Media</h5>
                                <p class='mb-0'>Media variants that haven't been updated in over #staleThresholdLabel#.</p>
                                <div class='mt-2 py-2 border-top'>#staleMediaListHtml##staleMediaPagerHtml#</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-4'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-flag-fill sidebar-icon'></i><span>Flags</span></h5>
                            <p class='card-text dashboard-card-text'>Create and manage user-specific display flags.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/flags/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage Flags</a>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-4'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-building-fill sidebar-icon'></i><span>Organizations</span></h5>
                            <p class='card-text dashboard-card-text'>Create and manage organizational groups.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/orgs/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage Orgs</a>
                        </div>
                    </div>
                </div>
            </div>

            <div class='col-md-4'>
                <div class='card shadow-sm dashboard-card'>
                    <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                        <div>
                            <h5 class='card-title dashboard-card-title'><i class='bi bi-person-bounding-box sidebar-icon'></i><span>External IDs</span></h5>
                            <p class='card-text dashboard-card-text'>Create and manage external ID sources.</p>
                        </div>
                        <div class='dashboard-actions'>
                            <a href='/admin/external/index.cfm' class='btn btn-sm btn-primary stretched-link'><i class='bi bi-gear-fill sidebar-icon me-2'></i>Manage IDs</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class='col-md-3'>
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