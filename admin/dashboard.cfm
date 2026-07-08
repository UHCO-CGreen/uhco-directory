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

<!--- ── Duplicate Users last run (super-admin only) ── --->
<cfset canRunDuplicateReport = application.authService.hasRole("SUPER_ADMIN") OR request.hasPermission("reporting.duplicate_users.manage")>
<cfset duplicateLastRun = {}>
<cfset duplicatePendingCount = 0>
<cfset duplicateBadgeCls = "bg-secondary text-dark">
<cfset duplicateBadgeTxt = "Never run">
<cfset duplicateSubtitle = "No duplicate scan has been run yet.">
<cfset duplicateBorderCls = "">

<cfif canRunDuplicateReport>
    <cftry>
        <cfset duplicateDAO_dash = createObject("component", "dao.duplicateUsers_DAO").init()>
        <cfset duplicateLastRun = duplicateDAO_dash.getLatestRun()>
        <cfset duplicatePendingCount = duplicateDAO_dash.getLatestPendingPairCount()>
        <cfif NOT structIsEmpty(duplicateLastRun)>
            <cfset duplicateBadgeCls = duplicatePendingCount GT 0 ? "bg-danger" : "bg-success">
            <cfset duplicateBadgeTxt = duplicatePendingCount GT 0 ? duplicatePendingCount & " pending" : "No pending pairs">
            <cfset duplicateSubtitle = "Last run: " & dateTimeFormat(duplicateLastRun.RUNAT, "mmm d, yyyy HH:nn") & " UTC — " & val(duplicateLastRun.TOTALPAIRS ?: 0) & " pair(s)">
            <cfset duplicateBorderCls = duplicatePendingCount GT 0 ? "border-danger" : "border-success">
        </cfif>
    <cfcatch></cfcatch>
    </cftry>
</cfif>

<cfset duplicateUsersCardHtml = "">
<cfif canRunDuplicateReport>
    <cfset duplicateUsersCardHtml = "
    <div class='col-12'>
        <div class='card shadow-sm dashboard-card dashboard-status-card #duplicateBorderCls#'>
            <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                <div class='dashboard-status-copy'>
                    <h5 class='card-title dashboard-card-title mb-0'>
                        <i class='bi bi-people me-2'></i>Duplicate Users Report
                        <span class='badge #duplicateBadgeCls# fs-6'>#duplicateBadgeTxt#</span>
                    </h5>
                    <small class='text-muted'>#duplicateSubtitle#</small>
                </div>
                <div class='dashboard-actions'>
                    <a href='/admin/reporting/duplicate_users_report.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-file-earmark-text-fill me-2'></i>View Report</a>
                    <a href='/admin/reporting/run_duplicate_users_report.cfm?scan=quick&mode=alumni_vs_faculty' class='btn btn-sm btn-ui-filter'><i class='bi bi-play-fill me-2'></i>Run Now</a>
                </div>
            </div>
        </div>
    </div>
    ">
</cfif>

<!--- ── Dashboard summary lists: stale users, unpublished variants, stale media ── --->
<cfset usersDAO_dash = createObject("component", "dao.users_DAO").init()>
<cfset variantsDAO_dash = createObject("component", "dao.UserImageVariantDAO").init()>
<cfset appConfigService_dash = createObject("component", "cfc.appConfig_service").init()>
<cfset usersService_dash = createObject("component", "cfc.users_service").init()>
<cfset flagsService_dash = createObject("component", "cfc.flags_service").init()>
<cfset orgsService_dash = createObject("component", "cfc.organizations_service").init()>
<cfset userReviewService_dash = createObject("component", "cfc.userReview_service").init()>

<cfset canUsersView = request.hasPermission("users.view")>
<cfset canUsersEdit = request.hasPermission("users.edit")>
<cfset canApproveUserReview_dash = request.hasPermission("users.approve_user_review")>
<cfset canMediaEdit = request.hasPermission("media.edit")>
<cfset canMediaPublish = request.hasPermission("media.publish")>
<cfset canManageApi_dash = application.authService.hasRole("SUPER_ADMIN") OR request.hasPermission("settings.api.manage")>
<cfset canViewTestUsers_dash = application.authService.hasRole("SUPER_ADMIN") OR request.hasPermission("users.test_users.manage")>
<cfset showTestUsersForAdmin_dash = request.canManageTestUsers()>
<cfset hideTestUsersForAdmin_dash = request.shouldExcludeTestUsers()>
<cfset dashboardSummaryRowLimit = 8>

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
<cfset uhSyncChangesTableHtml = "<div class='small text-muted'>No UH Sync changes found.</div>">
<cfset uhSyncChangesFooterHtml = "<div class='small text-muted'>Showing 0 of 0 pending UH Sync item(s).</div>">

<cfif uhSyncDbOk AND NOT structIsEmpty(uhSyncLastRun) AND val(uhSyncLastRun.RUNID ?: 0) GT 0>
    <cftry>
        <cfset uhSyncDiffRows_dash = uhSyncDAO_dash.getDiffsByRun(uhSyncLastRun.RUNID)>
        <cfset uhSyncGoneRows_dash = uhSyncDAO_dash.getGoneByRun(uhSyncLastRun.RUNID)>
        <cfset uhSyncNewRows_dash = uhSyncDAO_dash.getNewByRun(uhSyncLastRun.RUNID)>
        <cfset uhSyncDashboardRows = []>
        <cfset uhSyncDiffUserMap = {}>
        <cfset uhSyncDashboardLimit = dashboardSummaryRowLimit>

        <cfloop array="#uhSyncDiffRows_dash#" index="uhSyncDiffRow_dash">
            <cfset diffUserKey = toString(val(uhSyncDiffRow_dash.USERID ?: 0))>
            <cfif len(diffUserKey) AND val(diffUserKey) GT 0>
                <cfif NOT structKeyExists(uhSyncDiffUserMap, diffUserKey)>
                    <cfset uhSyncDiffUserMap[diffUserKey] = {
                        userID = val(uhSyncDiffRow_dash.USERID),
                        displayName = trim((uhSyncDiffRow_dash.FIRSTNAME ?: "") & " " & (uhSyncDiffRow_dash.LASTNAME ?: "")),
                        email = trim(uhSyncDiffRow_dash.EMAILPRIMARY ?: ""),
                        changeCount = 0
                    }>
                </cfif>
                <cfset uhSyncDiffUserMap[diffUserKey].changeCount = uhSyncDiffUserMap[diffUserKey].changeCount + 1>
            </cfif>
        </cfloop>

        <cfloop collection="#uhSyncDiffUserMap#" item="diffUserKey">
            <cfset diffSummaryRow = uhSyncDiffUserMap[diffUserKey]>
            <cfif NOT len(trim(diffSummaryRow.displayName ?: ""))>
                <cfset diffSummaryRow.displayName = "User #diffSummaryRow.userID#">
            </cfif>
            <cfset arrayAppend(uhSyncDashboardRows, {
                sortGroup = 1,
                itemType = "changed",
                badgeClass = "bg-warning text-dark",
                badgeLabel = "Changed",
                displayName = diffSummaryRow.displayName,
                secondaryText = len(diffSummaryRow.email) ? diffSummaryRow.email : "User ID " & diffSummaryRow.userID,
                detailText = diffSummaryRow.changeCount & " field change" & (diffSummaryRow.changeCount EQ 1 ? "" : "s"),
                actionHtml = "<a href='/admin/reporting/uh_sync_report.cfm?runID=" & uhSyncLastRun.RUNID & "&tab=diffs' class='btn btn-sm btn-ui-go py-0'><i class='bi bi-arrow-left-right me-1'></i>Review</a>"
            })>
        </cfloop>

        <cfloop array="#uhSyncGoneRows_dash#" index="uhSyncGoneRow_dash">
            <cfset goneDisplayName = trim((uhSyncGoneRow_dash.FIRSTNAME ?: "") & " " & (uhSyncGoneRow_dash.LASTNAME ?: ""))>
            <cfif NOT len(goneDisplayName)>
                <cfset goneDisplayName = "User #val(uhSyncGoneRow_dash.USERID ?: 0)#">
            </cfif>
            <cfset goneReturnTo_dash = "/admin/dashboard.cfm?suPage=" & suPage & "&uvPage=" & uvPage & "&smPage=" & smPage>
            <cfset arrayAppend(uhSyncDashboardRows, {
                sortGroup = 2,
                itemType = "gone",
                badgeClass = "bg-danger",
                badgeLabel = "Gone",
                displayName = goneDisplayName,
                secondaryText = len(trim(uhSyncGoneRow_dash.EMAILPRIMARY ?: "")) ? trim(uhSyncGoneRow_dash.EMAILPRIMARY) : trim(uhSyncGoneRow_dash.UH_API_ID ?: ""),
                detailText = len(trim(uhSyncGoneRow_dash.UH_API_ID ?: "")) ? "UH API ID " & trim(uhSyncGoneRow_dash.UH_API_ID) : "Missing from UH API",
                actionHtml = "<form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline' data-confirm=""Delete "" & encodeForJavaScript(goneDisplayName) & ""? This cannot be undone.""><input type='hidden' name='goneID' value='" & uhSyncGoneRow_dash.GONEID & "'><input type='hidden' name='resolution' value='deleted'><input type='hidden' name='userID' value='" & uhSyncGoneRow_dash.USERID & "'><input type='hidden' name='returnTo' value='" & encodeForHTMLAttribute(goneReturnTo_dash) & "'><button type='submit' class='btn btn-sm btn-ui-delete py-0'><i class='bi bi-trash me-1'></i>Delete</button></form><form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'><input type='hidden' name='goneID' value='" & uhSyncGoneRow_dash.GONEID & "'><input type='hidden' name='resolution' value='kept'><input type='hidden' name='returnTo' value='" & encodeForHTMLAttribute(goneReturnTo_dash) & "'><button type='submit' class='btn btn-sm btn-ui-cancel py-0'><i class='bi bi-person-check me-1'></i>Keep</button></form>"
            })>
        </cfloop>

        <cfloop array="#uhSyncNewRows_dash#" index="uhSyncNewRow_dash">
            <cfset newDisplayName = trim((uhSyncNewRow_dash.FIRSTNAME ?: "") & " " & (uhSyncNewRow_dash.LASTNAME ?: ""))>
            <cfif NOT len(newDisplayName)>
                <cfset newDisplayName = trim(uhSyncNewRow_dash.UHAPIID ?: "New UH User")>
            </cfif>
            <cfset newReturnTo_dash = "/admin/dashboard.cfm?suPage=" & suPage & "&uvPage=" & uvPage & "&smPage=" & smPage>
            <cfset arrayAppend(uhSyncDashboardRows, {
                sortGroup = 3,
                itemType = "new",
                badgeClass = "bg-info text-dark",
                badgeLabel = "New",
                displayName = newDisplayName,
                secondaryText = len(trim(uhSyncNewRow_dash.EMAIL ?: "")) ? trim(uhSyncNewRow_dash.EMAIL) : trim(uhSyncNewRow_dash.UHAPIID ?: ""),
                detailText = len(trim(uhSyncNewRow_dash.DEPARTMENT ?: "")) ? trim(uhSyncNewRow_dash.DEPARTMENT) : "New in UH API",
                actionHtml = "<form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'><input type='hidden' name='newID' value='" & uhSyncNewRow_dash.NEWID & "'><input type='hidden' name='resolution' value='imported'><input type='hidden' name='returnTo' value='" & encodeForHTMLAttribute(newReturnTo_dash) & "'><button type='submit' class='btn btn-sm btn-ui-save py-0'><i class='bi bi-person-plus me-1'></i>Import</button></form><form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'><input type='hidden' name='newID' value='" & uhSyncNewRow_dash.NEWID & "'><input type='hidden' name='resolution' value='ignored'><input type='hidden' name='returnTo' value='" & encodeForHTMLAttribute(newReturnTo_dash) & "'><button type='submit' class='btn btn-sm btn-ui-cancel py-0'><i class='bi bi-x me-1'></i>Ignore</button></form>"
            })>
        </cfloop>

        <cfif arrayLen(uhSyncDashboardRows) GT 0>
            <cfset arraySort(uhSyncDashboardRows, function(left, right) {
                if (left.sortGroup LT right.sortGroup) { return -1; }
                if (left.sortGroup GT right.sortGroup) { return 1; }
                return compareNoCase(left.displayName ?: "", right.displayName ?: "");
            })>

            <cfset uhSyncChangesTableHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
            <cfloop from="1" to="#min(arrayLen(uhSyncDashboardRows), uhSyncDashboardLimit)#" index="uhSyncRowIndex">
                <cfset uhSyncDashboardRow = uhSyncDashboardRows[uhSyncRowIndex]>
                <cfset uhSyncChangesTableHtml &= "<tr><td><span class='badge " & uhSyncDashboardRow.badgeClass & "'>" & uhSyncDashboardRow.badgeLabel & "</span></td><td><div class='fw-semibold'>" & encodeForHTML(uhSyncDashboardRow.displayName) & "</div><div class='small text-muted'>" & encodeForHTML(uhSyncDashboardRow.secondaryText) & "</div></td><td class='small'>" & encodeForHTML(uhSyncDashboardRow.detailText) & "</td><td class='text-end text-nowrap'>" & uhSyncDashboardRow.actionHtml & "</td></tr>">
            </cfloop>
            <cfset uhSyncChangesTableHtml &= "</tbody></table></div>">
            <cfset uhSyncChangesFooterHtml = "<div class='small text-muted'>Showing " & min(arrayLen(uhSyncDashboardRows), uhSyncDashboardLimit) & " of " & arrayLen(uhSyncDashboardRows) & " pending UH Sync item(s)." & (arrayLen(uhSyncDashboardRows) GT 0 ? " <a href='/admin/reporting/uh_sync_report.cfm?runID=" & uhSyncLastRun.RUNID & "'>View all</a>" : "") & "</div>">
        </cfif>
    <cfcatch>
        <cfset uhSyncChangesTableHtml = "<div class='small text-muted'>Unable to load UH Sync change details.</div>">
        <cfset uhSyncChangesFooterHtml = "">
    </cfcatch>
    </cftry>
</cfif>

<cftry>
    <cfset staleUsersPageData = usersDAO_dash.getStaleUsersForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=suPage, staleMonths=staleThresholdMonths, excludeTestUsers=hideTestUsersForAdmin_dash)>
<cfcatch></cfcatch>
</cftry>

<cftry>
    <cfset staleMediaPageData = variantsDAO_dash.getStaleMediaUsersForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=smPage, staleMonths=staleThresholdMonths)>
<cfcatch></cfcatch>
</cftry>

<cftry>
    <cfset unpublishedPageData = variantsDAO_dash.getGeneratedUnpublishedVariantsForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=uvPage)>
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
        <cfset staleUsersPageData = usersDAO_dash.getStaleUsersForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=suPage, staleMonths=staleThresholdMonths, excludeTestUsers=hideTestUsersForAdmin_dash)>
        <cfset staleUsers = staleUsersPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>
<cfif smPage GT staleMediaTotalPages>
    <cfset smPage = staleMediaTotalPages>
    <cftry>
        <cfset staleMediaPageData = variantsDAO_dash.getStaleMediaUsersForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=smPage, staleMonths=staleThresholdMonths)>
        <cfset staleMediaUsers = staleMediaPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>
<cfif uvPage GT unpublishedTotalPages>
    <cfset uvPage = unpublishedTotalPages>
    <cftry>
        <cfset unpublishedPageData = variantsDAO_dash.getGeneratedUnpublishedVariantsForDashboardPage(pageSize=dashboardSummaryRowLimit, pageNumber=uvPage)>
        <cfset unpublishedVariants = unpublishedPageData.data ?: []>
    <cfcatch></cfcatch>
    </cftry>
</cfif>

<cfset staleUsersListHtml = "<div class='small text-muted'>No stale users found.</div>">
<cfset staleUsersFooterHtml = "<div class='small text-muted'>Showing 0 of 0 stale record(s).</div>">
<cfif arrayLen(staleUsers)>
    <cfset staleUsersListHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
    <cfloop from="1" to="#min(arrayLen(staleUsers), dashboardSummaryRowLimit)#" index="staleIndex">
        <cfset su = staleUsers[staleIndex]>
        <cfset staleUserName = trim(su.FULLNAME ?: ((su.FIRSTNAME ?: "") & " " & (su.LASTNAME ?: "")))>
        <cfif !len(staleUserName)>
            <cfset staleUserName = "User ##" & val(su.USERID)>
        </cfif>
        <cfset staleUsersActions = "">
        <cfif canUsersEdit>
            <cfset staleUsersActions &= " <a href='/admin/users/edit.cfm?userID=#val(su.USERID)#' class='btn btn-sm btn-ui-edit ms-1 py-0 px-1'>Edit</a>">
        </cfif>
        <cfif canUsersView>
            <cfset staleUsersActions &= " <a href='/admin/users/view.cfm?userID=#val(su.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>View</a>">
        </cfif>
        <cfset staleUsersListHtml &= "<tr><td><span class='badge bg-warning text-dark'>Stale</span></td><td><div class='fw-semibold'>" & encodeForHTML(staleUserName) & "</div><div class='small text-muted'>User ID " & val(su.USERID) & "</div></td><td class='small'>Not updated in over " & encodeForHTML(staleThresholdLabel) & ".</td><td class='text-end text-nowrap'>" & staleUsersActions & "</td></tr>">
    </cfloop>
    <cfset staleUsersListHtml &= "</tbody></table></div>">
</cfif>
<cfset staleUsersFooterHtml = "<div class='small text-muted'>Showing " & min(staleUsersTotalCount, dashboardSummaryRowLimit) & " of " & staleUsersTotalCount & " stale record(s).</div>">

<cfset problemFlagNames = "Admin-Check,No-UH-API">
<cfset problemUsers = []>
<cfset problemUsersTotalCount = 0>
<cfset problemUsersListHtml = "<div class='small text-muted'>No problem records found.</div>">
<cfset problemUsersFooterHtml = "<div class='small text-muted'>Showing 0 of 0 problem record(s). <a href='/admin/users/index.cfm?list=problems'>View all</a></div>">
<cftry>
    <cfset dashboardAllUsers = usersService_dash.listUsersForAdminIndex()>
    <cfset dashboardUserFlagMap = flagsService_dash.getAllUserFlagMap()>
    <cfset dashboardUserOrgMap = orgsService_dash.getAllUserOrgMap()>
    <cfset dashboardVisibleUserResult = application.adminAuthorizationPolicyService.filterAccessibleUsers(dashboardAllUsers, dashboardUserFlagMap, dashboardUserOrgMap)>
    <cfset dashboardVisibleUsers = dashboardVisibleUserResult.users>

    <cfloop array="#dashboardVisibleUsers#" index="problemUser">
        <cfset problemUserFlags = structKeyExists(dashboardUserFlagMap, toString(problemUser.USERID)) ? dashboardUserFlagMap[toString(problemUser.USERID)] : []>
        <cfloop array="#problemUserFlags#" index="problemFlag">
            <cfif listFindNoCase(problemFlagNames, trim(problemFlag.FLAGNAME ?: ""))>
                <cfset arrayAppend(problemUsers, problemUser)>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfloop>
<cfcatch>
    <cfset problemUsers = []>
</cfcatch>
</cftry>

<cfset problemUsersTotalCount = arrayLen(problemUsers)>
<cfif problemUsersTotalCount GT 0>
    <cfset problemUsersListHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
    <cfloop from="1" to="#min(problemUsersTotalCount, dashboardSummaryRowLimit)#" index="problemIndex">
        <cfset problemUser = problemUsers[problemIndex]>
        <cfset problemUserName = trim(problemUser.FULLNAME ?: ((problemUser.FIRSTNAME ?: "") & " " & (problemUser.LASTNAME ?: "")))>
        <cfset problemUserFlags = structKeyExists(dashboardUserFlagMap, toString(problemUser.USERID)) ? dashboardUserFlagMap[toString(problemUser.USERID)] : []>
        <cfset problemFlagLabels = []>
        <cfif !len(problemUserName)>
            <cfset problemUserName = "User ##" & val(problemUser.USERID)>
        </cfif>
        <cfloop array="#problemUserFlags#" index="problemFlag">
            <cfif listFindNoCase(problemFlagNames, trim(problemFlag.FLAGNAME ?: ""))>
                <cfset arrayAppend(problemFlagLabels, trim(problemFlag.FLAGNAME))>
            </cfif>
        </cfloop>
        <cfset problemUserActions = "">
        <cfif canUsersEdit>
            <cfset problemUserActions &= " <a href='/admin/users/edit.cfm?userID=#val(problemUser.USERID)#' class='btn btn-sm btn-ui-edit ms-1 py-0 px-1'>Edit</a>">
        </cfif>
        <cfif canUsersView>
            <cfset problemUserActions &= " <a href='/admin/users/view.cfm?userID=#val(problemUser.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>View</a>">
        </cfif>
        <cfset problemUsersListHtml &= "<tr><td><span class='badge bg-warning text-dark'>Flagged</span></td><td><div class='fw-semibold'>" & encodeForHTML(problemUserName) & "</div><div class='small text-muted'>User ID " & val(problemUser.USERID) & "</div></td><td class='small'>" & encodeForHTML(arrayToList(problemFlagLabels, ", ")) & "</td><td class='text-end text-nowrap'>" & problemUserActions & "</td></tr>">
    </cfloop>
    <cfset problemUsersListHtml &= "</tbody></table></div>">
</cfif>
<cfset problemUsersFooterHtml = "<div class='small text-muted'>Showing " & min(problemUsersTotalCount, dashboardSummaryRowLimit) & " of " & problemUsersTotalCount & " problem record(s). <a href='/admin/users/index.cfm?list=problems'>View all</a></div>">

<cfset userReviewQueueHtml = canApproveUserReview_dash ? "<div class='small text-muted'>No pending User Review submissions found.</div>" : "<div class='small text-muted'>User Review approval access is required to view this queue.</div>">
<cfset userReviewPendingSubmissions = []>
<cfset userReviewPendingCount = 0>
<cfset userReviewQueueFooterHtml = canApproveUserReview_dash ? "<div class='small text-muted'>Showing 0 of 0 pending submission(s). <a href='/admin/user-review/'>View all</a></div>" : "">
<cfif canApproveUserReview_dash>
    <cftry>
        <cfset userReviewPendingSubmissions = userReviewService_dash.listSubmissions("pending")>
    <cfcatch>
        <cfset userReviewPendingSubmissions = []>
        <cfset userReviewQueueHtml = "<div class='small text-muted'>Unable to load pending User Review submissions.</div>">
    </cfcatch>
    </cftry>

    <cfset userReviewPendingCount = arrayLen(userReviewPendingSubmissions)>
    <cfif userReviewPendingCount GT 0>
        <cfset userReviewQueueHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
        <cfloop from="1" to="#min(userReviewPendingCount, dashboardSummaryRowLimit)#" index="userReviewIndex">
            <cfset userReviewSubmission = userReviewPendingSubmissions[userReviewIndex]>
            <cfset userReviewName = trim((userReviewSubmission.FIRSTNAME ?: "") & " " & (userReviewSubmission.LASTNAME ?: ""))>
            <cfset userReviewActions = " <a href='/admin/user-review/review.cfm?submissionID=#val(userReviewSubmission.SUBMISSIONID)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>Review</a>">
            <cfset userReviewDetails = "Submitted " & dateTimeFormat(userReviewSubmission.SUBMITTEDAT, "mmm d, yyyy h:nn tt")>
            <cfif !len(userReviewName)>
                <cfset userReviewName = "User ##" & val(userReviewSubmission.USERID ?: 0)>
            </cfif>
            <cfif canUsersView AND val(userReviewSubmission.USERID ?: 0) GT 0>
                <cfset userReviewActions &= " <a href='/admin/users/view.cfm?userID=#val(userReviewSubmission.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>View</a>">
            </cfif>
            <cfif len(trim(userReviewSubmission.SECTIONLIST ?: ""))>
                <cfset userReviewDetails &= " &middot; " & encodeForHTML(replace(userReviewSubmission.SECTIONLIST, ",", ", ", "all"))>
            </cfif>
            <cfset userReviewQueueHtml &= "<tr><td><span class='badge bg-warning text-dark'>Pending</span></td><td><div class='fw-semibold'>" & encodeForHTML(userReviewName) & "</div><div class='small text-muted'>" & encodeForHTML(userReviewSubmission.COUGARNETID ?: "") & "</div></td><td class='small'>" & userReviewDetails & "</td><td class='text-end text-nowrap'>" & userReviewActions & "</td></tr>">
        </cfloop>
        <cfset userReviewQueueHtml &= "</tbody></table></div>">
    </cfif>
</cfif>
<cfif canApproveUserReview_dash>
    <cfset userReviewQueueFooterHtml = "<div class='small text-muted'>Showing " & min(userReviewPendingCount, dashboardSummaryRowLimit) & " of " & userReviewPendingCount & " pending submission(s). <a href='/admin/user-review/'>View all</a></div>">
</cfif>

<cfset staleMediaListHtml = "<div class='small text-muted'>No stale media records found.</div>">
<cfset staleMediaFooterHtml = "<div class='small text-muted'>Showing 0 of 0 stale media record(s).</div>">
<cfif arrayLen(staleMediaUsers)>
    <cfset staleMediaListHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
    <cfloop from="1" to="#min(arrayLen(staleMediaUsers), dashboardSummaryRowLimit)#" index="staleMediaIndex">
        <cfset sm = staleMediaUsers[staleMediaIndex]>
        <cfset staleMediaName = trim((sm.PREFERREDFIRSTNAME ?: sm.FIRSTNAME ?: "") & " " & (sm.PREFERREDLASTNAME ?: sm.LASTNAME ?: ""))>
        <cfif !len(staleMediaName)>
            <cfset staleMediaName = "User ##" & val(sm.USERID)>
        </cfif>
        <cfset staleMediaActions = "">
        <cfif canMediaEdit>
            <cfset staleMediaActions &= " <a href='/admin/user-media/sources.cfm?userid=#val(sm.USERID)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>Media</a>">
        </cfif>
        <cfif canUsersView>
            <cfset staleMediaActions &= " <a href='/admin/users/view.cfm?userID=#val(sm.USERID)#&returnTo=#urlEncodedFormat(dashboardReturnTo)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>View</a>">
        </cfif>
        <cfset staleMediaListHtml &= "<tr><td><span class='badge bg-warning text-dark'>Stale</span></td><td><div class='fw-semibold'>" & encodeForHTML(staleMediaName) & "</div><div class='small text-muted'>User ID " & val(sm.USERID) & "</div></td><td class='small'>Media has not been updated in over " & encodeForHTML(staleThresholdLabel) & ".</td><td class='text-end text-nowrap'>" & staleMediaActions & "</td></tr>">
    </cfloop>
    <cfset staleMediaListHtml &= "</tbody></table></div>">
</cfif>
<cfset staleMediaFooterHtml = "<div class='small text-muted'>Showing " & min(staleMediaTotalCount, dashboardSummaryRowLimit) & " of " & staleMediaTotalCount & " stale media record(s). <a href='/admin/media/index.cfm'>View all</a></div>">

<cfset unpublishedVariantsListHtml = "<div class='small text-muted'>No unpublished variants found.</div>">
<cfset unpublishedFooterHtml = "<div class='small text-muted'>Showing 0 of 0 unpublished variant(s).</div>">
<cfif arrayLen(unpublishedVariants)>
    <cfset unpublishedVariantsListHtml = "<div class='table-responsive'><table class='table table-sm table-striped align-middle mb-0'><thead class='table-light'><tr><th>Status</th><th>User</th><th>Details</th><th class='text-end'>Actions</th></tr></thead><tbody>">
    <cfloop from="1" to="#min(arrayLen(unpublishedVariants), dashboardSummaryRowLimit)#" index="unpublishedIndex">
        <cfset uv = unpublishedVariants[unpublishedIndex]>
        <cfset unpublishedName = trim((uv.PREFERREDFIRSTNAME ?: uv.FIRSTNAME ?: "") & " " & (uv.PREFERREDLASTNAME ?: uv.LASTNAME ?: ""))>
        <cfif !len(unpublishedName)>
            <cfset unpublishedName = "User ##" & val(uv.USERID)>
        </cfif>
        <cfset unpublishedActions = "">
        <cfif canMediaEdit>
            <cfset unpublishedActions &= " <a href='/admin/user-media/variants.cfm?userid=#val(uv.USERID)#&sourceid=#val(uv.USERIMAGESOURCEID)#' class='btn btn-sm btn-ui-go ms-1 py-0 px-1'>Open</a>">
        </cfif>
        <cfif canMediaPublish>
            <cfset unpublishedActions &= " <a href='/admin/user-media/variants.cfm?userid=#val(uv.USERID)#&sourceid=#val(uv.USERIMAGESOURCEID)#' class='btn btn-sm btn-ui-save ms-1 py-0 px-1'>Publish</a>">
        </cfif>
        <cfset unpublishedVariantsListHtml &= "<tr><td><span class='badge bg-info text-dark'>Unpublished</span></td><td><div class='fw-semibold'>" & encodeForHTML(unpublishedName) & "</div><div class='small text-muted'>User ID " & val(uv.USERID) & "</div></td><td class='small'>" & encodeForHTML(uv.VARIANTCODE ?: "") & " variant pending publication.</td><td class='text-end text-nowrap'>" & unpublishedActions & "</td></tr>">
    </cfloop>
    <cfset unpublishedVariantsListHtml &= "</tbody></table></div>">
</cfif>
<cfset unpublishedFooterHtml = "<div class='small text-muted'>Showing " & min(unpublishedTotalCount, dashboardSummaryRowLimit) & " of " & unpublishedTotalCount & " unpublished variant(s). <a href='/admin/media/index.cfm'>View all</a></div>">

<!--- ── Statistics panels ── --->
<cfset statsDefs_dash = [
    { key="stats.dashboard.total_users",            label="Total Users",           queryType="users",        flags=[],                                                              icon="bi-people-fill",       colorClass="stat-panel-icon--primary"  },
    { key="stats.dashboard.total_faculty",          label="Total Faculty",         queryType="flags",        flags=["Faculty-Fulltime","Faculty-Adjunct","Professor-Emeritus"],     icon="bi-mortarboard-fill",  colorClass="stat-panel-icon--purple"   },
    { key="stats.dashboard.total_faculty_fulltime", label="Total Fulltime Faculty",queryType="flags",        flags=["Faculty-Fulltime"],                                            icon="bi-person-workspace",  colorClass="stat-panel-icon--info"     },
    { key="stats.dashboard.total_faculty_adjunct",  label="Total Adjunct Faculty", queryType="flags",        flags=["Faculty-Adjunct"],                                             icon="bi-person-workspace",  colorClass="stat-panel-icon--teal"     },
    { key="stats.dashboard.total_staff",            label="Total Staff",           queryType="flags",        flags=["Staff"],                                                       icon="bi-briefcase-fill",    colorClass="stat-panel-icon--secondary"},
    { key="stats.dashboard.total_residents",        label="Total Residents",       queryType="flags",        flags=["Resident"],                                                    icon="bi-hospital-fill",     colorClass="stat-panel-icon--danger"   },
    { key="stats.dashboard.total_alumni",           label="Total Alumni",          queryType="flags",        flags=["Alumni"],                                                      icon="bi-award-fill",        colorClass="stat-panel-icon--warning"  },
    { key="stats.dashboard.total_published_images", label="Total Published User Images",queryType="images",       flags=[],                                                              icon="bi-images",            colorClass="stat-panel-icon--success"  },
    { key="stats.dashboard.total_publications",     label="Total Faculty Publications",    queryType="publications", flags=[],                                                              icon="bi-journal-text",      colorClass="stat-panel-icon--orange"   }
]>
<cfset enabledStatPanels = []>
<cftry>
    <cfset statsDAO_dash = createObject("component", "dao.stats_DAO").init()>
    <cfloop array="#statsDefs_dash#" index="statDef_dash">
        <cfif trim(appConfigService_dash.getValue(statDef_dash.key, "0")) EQ "1">
            <cfset panelCount = 0>
            <cftry>
                <cfswitch expression="#statDef_dash.queryType#">
                    <cfcase value="users">
                        <cfset panelCount = statsDAO_dash.getTotalUsers()>
                    </cfcase>
                    <cfcase value="flags">
                        <cfset panelCount = statsDAO_dash.getTotalUsersByFlags(statDef_dash.flags)>
                    </cfcase>
                    <cfcase value="images">
                        <cfset panelCount = statsDAO_dash.getTotalPublishedImages()>
                    </cfcase>
                    <cfcase value="publications">
                        <cfset panelCount = statsDAO_dash.getTotalPublications()>
                    </cfcase>
                </cfswitch>
            <cfcatch>
                <cfset panelCount = 0>
            </cfcatch>
            </cftry>
            <cfset arrayAppend(enabledStatPanels, {
                label      = statDef_dash.label,
                value      = panelCount,
                icon       = statDef_dash.icon,
                colorClass = statDef_dash.colorClass
            })>
        </cfif>
    </cfloop>
<cfcatch>
    <!--- stats DAO unavailable — skip panels silently --->
</cfcatch>
</cftry>

<cfset statPanelsHtml = "">
<cfif arrayLen(enabledStatPanels)>
    <cfsavecontent variable="statPanelsHtml">
    <cfoutput>
    <div class="row g-3 mb-0 mt-2">
        <cfloop array="#enabledStatPanels#" index="sp">
        <div class="col-sm-6 col-lg-3">
            <div class="card shadow-sm h-100 stat-panel-card">
                <div class="card-body d-flex align-items-center justify-content-between">
                    <div>
                        <div class="h3 mb-0 fw-bold stat-panel-value">#numberFormat(sp.value)#</div>
                        <div class="text-muted small stat-panel-label">#encodeForHTML(sp.label)#</div>
                    </div>
                    <div class="stat-panel-icon #encodeForHTMLAttribute(sp.colorClass)#">
                        <i class="bi #encodeForHTMLAttribute(sp.icon)#"></i>
                    </div>
                </div>
            </div>
        </div>
        </cfloop>
    </div>
    </cfoutput>
    </cfsavecontent>
</cfif>

<!--- ── UH Sync panel (super-admin or settings.uh_sync.view) ── --->
<cfset canViewUhSyncPanel_dash = application.authService.hasRole("SUPER_ADMIN") OR request.hasPermission("settings.uh_sync.view")>
<cfset uhSyncPanelHtml = "">
<cfif canViewUhSyncPanel_dash>
    <cfset uhSyncPanelHtml = "
    <div class='col-12'>
        <div class='card shadow-sm dashboard-card dashboard-status-card #uhSyncBorderCls#'>
            <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                <div class='dashboard-status-copy'>
                    <h5 class='card-title dashboard-card-title mb-0'>
                        <i class='bi bi-arrow-left-right me-2'></i>UH API Sync Report
                        <span class='badge #uhSyncBadgeCls# fs-6'>#uhSyncBadgeTxt#</span>
                    </h5>
                    <small class='text-muted'>#uhSyncSubtitle#</small>
                </div>
                <div class='dashboard-actions'>
                    <a href='/admin/reporting/uh_sync_report.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-file-earmark-text-fill me-2'></i>View Report</a>
                    <a href='/admin/reporting/run_uh_sync_report.cfm' class='btn btn-sm btn-ui-filter'><i class='bi bi-play-fill me-2'></i>Run Now</a>
                </div>
            </div>
        </div>
    </div>
    ">
</cfif>

<!--- ── UHCO API panel (super-admin or settings.api.manage) ── --->
<cfset apiPanelHtml = "">
<cfif canManageApi_dash>
    <cfset apiPanelHtml = "
    <div class='col-md-12'>
        <div class='card shadow-sm dashboard-card'>
            <div class='card-body d-flex flex-wrap align-items-center justify-content-between gap-3'>
                <div>
                    <h5 class='card-title dashboard-card-title'><i class='bi bi-braces sidebar-icon'></i><span>UHCO API</span></h5>
                    <p class='card-text dashboard-card-text'>Manage UHCO API settings and integrations.</p>
                </div>
                <div class='dashboard-actions'>
                    <a href='/admin/settings/uhco-api/tokens/index.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-key-fill sidebar-icon me-2'></i>Manage Tokens</a>
                    <a href='/admin/settings/uhco-api/secrets/index.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-shield-lock-fill sidebar-icon me-2'></i>Manage Secrets</a>
                    <a href='/api/docs.html' class='btn btn-sm btn-ui-help'><i class='bi bi-book-fill me-2'></i>Documentation</a>
                </div>
            </div>
        </div>
    </div>
    ">
</cfif>

<cfset content = "
<div class='dashboard-shell'>

" & statPanelsHtml & "

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
                            #(canUsersView ? "<a href='/admin/users/index.cfm' class='btn btn-ui-go btn-sm'><i class='bi bi-people-fill sidebar-icon me-2'></i>Manage Users</a>" : "")#
                        </div>
                        <div class='w-100 mt-3 pt-3 border-top dashboard-summary-grid'>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>Stale Records</h5>
                                <p class='mb-0'>Records that haven't been updated in over #staleThresholdLabel#. Users shown here have been identified for review by automated processes.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#staleUsersListHtml#</div>
                                <div class='dashboard-summary-footer'>#staleUsersFooterHtml#</div>
                            </div>
                            </div>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>Problem Records</h5>
                                <p class='mb-0'>Records flagged for follow-up with either Admin-Check or No-UH-API. Users shown here have been identified for review by administrators.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#problemUsersListHtml#</div>
                                <div class='dashboard-summary-footer'>#problemUsersFooterHtml#</div>
                            </div>
                            </div>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>UH API Sync Changes</h5>
                                <p class='mb-0'>Changes detected during the last scheduled UH Sync. Users shown here have been identified for review by automated processes.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#uhSyncChangesTableHtml#</div>
                                <div class='dashboard-summary-footer'>#uhSyncChangesFooterHtml#</div>
                            </div>
                            </div>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>User Review Queue</h5>
                                <p class='mb-0'>Submitted profile updates waiting for approval. Users shown here have staged profile changes that have not been approved yet.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#userReviewQueueHtml#</div>
                                <div class='dashboard-summary-footer'>#userReviewQueueFooterHtml#</div>
                            </div>
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
                            <a href='/admin/media/index.cfm' class='btn btn-sm btn-ui-go stretched-link'><i class='bi bi-collection-fill sidebar-icon me-2'></i>Manage Media</a>
                        </div>
                        <div class='w-100 mt-3 pt-3 border-top dashboard-summary-grid'>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>Unpublished Variants</h5>
                                <p class='mb-0'>Media variants that have been generated but not yet published.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#unpublishedVariantsListHtml#</div>
                                <div class='dashboard-summary-footer'>#unpublishedFooterHtml#</div>
                            </div>
                            </div>
                            <div class='dashboard-summary-cell'>
                            <div class='border rounded p-2 dashboard-summary-panel w-100 h-100'>
                                <h5>Stale Media</h5>
                                <p class='mb-0'>Media variants that haven't been updated in over #staleThresholdLabel#.</p>
                                <div class='mt-2 py-2 border-top dashboard-summary-table-wrap'>#staleMediaListHtml#</div>
                                <div class='dashboard-summary-footer'>#staleMediaFooterHtml#</div>
                            </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class='col-md-3'>
        <div class='row g-4'>
            #apiPanelHtml#
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
                            
                            <a href='/admin/reporting/data_quality_report.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-file-earmark-text-fill me-2'></i>View Report</a>
                            <a href='/admin/reporting/run_data_quality_report.cfm' class='btn btn-sm btn-ui-filter'><i class='bi bi-play-fill me-2'></i>Run Now</a>
                        </div>
                    </div>
                </div>
            </div>
            #uhSyncPanelHtml#
            #duplicateUsersCardHtml#
        </div>
    </div>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">