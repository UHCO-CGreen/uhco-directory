
<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset organizationsService = createObject("component", "cfc.organizations_service").init()>
<cfset aliasesService = createObject("component", "cfc.aliases_service").init()>
<cfset bioService = createObject("component", "cfc.bio_service").init()>
<cfset phoneService = createObject("component", "cfc.phone_service").init()>
<cfset editViewHelper = createObject("component", "cfc.adminUsersEditView_service").init()>
<cfset degreesService = createObject("component", "cfc.degrees_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset profile = directoryService.getFullProfile( url.userID )>
<cfset user = profile.user>
<cfset editReturnTo = "/admin/users/edit.cfm?userID=" & urlEncodedFormat(url.userID)>
<cfset uhSyncMsgParam = trim(url.msg ?: "")>
<cfset uhSyncErrParam = trim(url.err ?: "")>
<cfset uhSyncInfoParam = trim(url.info ?: "")>
<cfset aliasTypes = aliasesService.getAliasTypes()>
<cfset freshUserResult = usersService.getUser(val(url.userID))>
<cfset userActiveRaw = val(user.ACTIVE ?: 0)>
<cfif structKeyExists(freshUserResult, "success") AND freshUserResult.success>
    <cfset userActiveRaw = val(freshUserResult.data.ACTIVE ?: userActiveRaw)>
</cfif>
<cftry>
    <cfset activeQry = queryExecute(
        "SELECT TOP 1 Active FROM Users WHERE UserID = :id",
        { id = { value=val(url.userID), cfsqltype="cf_sql_integer" } },
        { datasource=request.datasource, timeout=30 }
    )>
    <cfif activeQry.recordCount GT 0>
        <cfset userActiveRaw = val(activeQry.Active[1] ?: userActiveRaw)>
    </cfif>
    <cfcatch type="any">
        <!--- Keep previously resolved value when direct query is unavailable. --->
    </cfcatch>
</cftry>

<cfset user.ACTIVE = userActiveRaw>
<cfset userFlags = profile.flags>
<cfset userOrganizations = profile.organizations>
<cfif NOT request.canAccessUserProfile(profile)>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data>
<cfset allOrganizationsResult = organizationsService.getAllOrgs()>
<cfset allOrganizations = allOrganizationsResult.data>

<!--- ── Data Quality Exclusions ── --->
<cfset dqDAO            = createObject("component", "dao.dataQuality_DAO").init()>
<cfset dqExclusionsList = dqDAO.getExclusionsForUser(url.userID)>
<cfset dqExclusionMap   = {}>
<cfloop from="1" to="#arrayLen(dqExclusionsList)#" index="i">
    <cfset dqExclusionMap[dqExclusionsList[i]] = true>
</cfloop>

<cfset dqAllCodes = [
    { code="missing_uh_api_id",       label="Missing UH API ID" },
    { code="missing_primary_alias",    label="Missing Primary Alias" },
    { code="missing_email_primary",    label="Missing Primary Email" },
    { code="missing_title1",           label="Missing Title" },
    { code="missing_room",             label="Missing Room" },
    { code="missing_building",         label="Missing Building" },
    { code="missing_phone",            label="Missing Phone" },
    { code="missing_degrees",          label="Missing Degrees" },
    { code="no_flags",                 label="Zero Flags" },
    { code="no_orgs",                  label="Zero Organizations" },
    { code="no_images",                label="No Images" },
    { code="missing_cougarnet",        label="Missing CougarNet ID" },
    { code="missing_peoplesoft",       label="Missing PeopleSoft ID" },
    { code="missing_legacy_id",        label="Missing Legacy ID" },
    { code="missing_grad_year",        label="Missing Grad Year (Students Only)" }
]>

<!--- ── UH Sync pending diffs for this user ── --->
<cfset uhSyncPendingDiffs = []>
<cfset uhSyncPanelHtml    = "">
<cfset uhSyncFlagRows = []>
<cfset uhSyncFlashMessage = "">
<cfset uhSyncFlashIsError = false>
<cftry>
    <cfset uhSyncDAO_edit = createObject("component", "dao.uhSync_DAO").init()>
    <cfset uhSyncPendingDiffs = uhSyncDAO_edit.getUnresolvedDiffsForUser(val(url.userID))>
<cfcatch>
    <!--- Non-fatal: sync panel is suppressed if tables don't exist yet --->
</cfcatch>
</cftry>

<cfset uhSyncFieldLabels_edit = {
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
<cfset uhSyncHasApiId = len(trim(user.UH_API_ID ?: "")) GT 0>
<cfset uhSyncApiStatusCode = "">
<cfset uhSyncApiWarning = "">
<cfset uhSyncApiCredentials = request.runtimeSecretPolicy.getUHApiCredentials()>
<cfset uhSyncApiToken = trim(uhSyncApiCredentials.token ?: "")>
<cfset uhSyncApiSecret = trim(uhSyncApiCredentials.secret ?: "")>

<cfif len(uhSyncInfoParam)>
    <cfset uhSyncFlashMessage = uhSyncInfoParam>
    <cfset uhSyncFlashIsError = false>
<cfelseif len(uhSyncErrParam)>
    <cfset uhSyncFlashMessage = uhSyncErrParam>
    <cfset uhSyncFlashIsError = true>
</cfif>

<cfif uhSyncHasApiId AND len(uhSyncApiToken) AND len(uhSyncApiSecret)>
    <cfsilent>
        <cfset uhSyncLiveApi = createObject("component", "cfc.uh_api").init(apiToken=uhSyncApiToken, apiSecret=uhSyncApiSecret)>
        <cfset uhSyncPersonResponse = uhSyncLiveApi.getPerson(
            trim(user.UH_API_ID ?: ""),
            trim(user.DEPARTMENT ?: ""),
            trim(user.DIVISION ?: ""),
            trim(user.CAMPUS ?: "")
        )>
    </cfsilent>

    <cfset uhSyncApiStatusCode = uhSyncPersonResponse.statusCode ?: "Unknown">
    <cfset uhSyncResponseData = uhSyncPersonResponse.data ?: {}>
    <cfset uhSyncApiPerson = {}>

    <cfif left(uhSyncApiStatusCode, 3) EQ "200">
        <cfif isStruct(uhSyncResponseData)>
            <cfif structKeyExists(uhSyncResponseData, "data") AND isStruct(uhSyncResponseData.data)>
                <cfif structKeyExists(uhSyncResponseData.data, "person") AND isStruct(uhSyncResponseData.data.person)>
                    <cfset uhSyncApiPerson = uhSyncResponseData.data.person>
                <cfelse>
                    <cfset uhSyncApiPerson = uhSyncResponseData.data>
                </cfif>
            <cfelseif structKeyExists(uhSyncResponseData, "person") AND isStruct(uhSyncResponseData.person)>
                <cfset uhSyncApiPerson = uhSyncResponseData.person>
            <cfelse>
                <cfset uhSyncApiPerson = uhSyncResponseData>
            </cfif>
        </cfif>

        <cfscript>
            function editUhSyncFindValueByKeyDeep(any node="", required string keyName) {
                var keys = [];
                var currentKey = "";
                var foundValue = "";
                var index = 1;

                if (isNull(arguments.node)) { return ""; }

                if (isStruct(arguments.node)) {
                    keys = structKeyArray(arguments.node);
                    for (index = 1; index <= arrayLen(keys); index++) {
                        currentKey = keys[index];
                        if (compareNoCase(currentKey, arguments.keyName) EQ 0) {
                            if (isSimpleValue(arguments.node[currentKey])) { return toString(arguments.node[currentKey] ?: ""); }
                            if (isBoolean(arguments.node[currentKey])) { return arguments.node[currentKey] ? "true" : "false"; }
                        }
                    }
                    for (index = 1; index <= arrayLen(keys); index++) {
                        foundValue = editUhSyncFindValueByKeyDeep(node=arguments.node[keys[index]], keyName=arguments.keyName);
                        if (len(trim(toString(foundValue)))) { return foundValue; }
                    }
                } else if (isArray(arguments.node)) {
                    for (index = 1; index <= arrayLen(arguments.node); index++) {
                        foundValue = editUhSyncFindValueByKeyDeep(node=arguments.node[index], keyName=arguments.keyName);
                        if (len(trim(toString(foundValue)))) { return foundValue; }
                    }
                }

                return "";
            }

            function editUhSyncGetApiValue(required any source, required string keyListCsv) {
                var names = listToArray(arguments.keyListCsv);
                var index = 1;
                var valueFound = "";

                for (index = 1; index <= arrayLen(names); index++) {
                    valueFound = editUhSyncFindValueByKeyDeep(node=arguments.source, keyName=trim(names[index]));
                    if (len(trim(toString(valueFound)))) { return toString(valueFound); }
                }

                return "";
            }

            function editUhSyncHasFlag(required array flags, required string flagName) {
                var index = 1;
                var currentFlagName = "";

                for (index = 1; index <= arrayLen(arguments.flags); index++) {
                    if (isStruct(arguments.flags[index])) {
                        currentFlagName = trim(toString(arguments.flags[index].FLAGNAME ?: ""));
                        if (compareNoCase(currentFlagName, arguments.flagName) EQ 0) { return true; }
                    }
                }

                return false;
            }

            function editUhSyncToYesNo(required any value) {
                var normalized = lCase(trim(toString(arguments.value ?: "")));

                if (normalized EQ "true" OR normalized EQ "1" OR normalized EQ "yes" OR normalized EQ "y") { return "Yes"; }
                if (normalized EQ "false" OR normalized EQ "0" OR normalized EQ "no" OR normalized EQ "n") { return "No"; }

                return "N/A";
            }
        </cfscript>

        <cfset uhSyncFlagCompareRows = [
            { label="Student", apiKeys="student,is_student,isStudent", flagName="Current-Student" },
            { label="Staff", apiKeys="staff,is_staff,isStaff", flagName="Staff" },
            { label="Faculty", apiKeys="faculty,is_faculty,isFaculty", flagName="Faculty-Fulltime" }
        ]>

        <cfloop from="1" to="#arrayLen(uhSyncFlagCompareRows)#" index="flagCompareIndex">
            <cfset flagCompareRow = uhSyncFlagCompareRows[flagCompareIndex]>
            <cfset uhSyncApiFlagDisplay = editUhSyncToYesNo(editUhSyncGetApiValue(uhSyncApiPerson, flagCompareRow.apiKeys))>
            <cfset uhSyncLocalFlagDisplay = editUhSyncHasFlag(userFlags, flagCompareRow.flagName) ? "Yes" : "No">

            <cfif (uhSyncApiFlagDisplay EQ "Yes" OR uhSyncApiFlagDisplay EQ "No") AND uhSyncApiFlagDisplay NEQ uhSyncLocalFlagDisplay>
                <cfset arrayAppend(uhSyncFlagRows, {
                    label = flagCompareRow.label,
                    flagName = flagCompareRow.flagName,
                    localValue = uhSyncLocalFlagDisplay,
                    apiValue = uhSyncApiFlagDisplay
                })>
            </cfif>
        </cfloop>
    <cfelse>
        <cfset uhSyncApiWarning = "Live UH API flag checks are unavailable right now. API returned status " & uhSyncApiStatusCode & ".">
    </cfif>
<cfelseif uhSyncHasApiId>
    <cfset uhSyncApiWarning = "Live UH API checks require UH_API_TOKEN and UH_API_SECRET to be configured.">
</cfif>

<cfset uhSyncPanelItemCount = arrayLen(uhSyncPendingDiffs) + arrayLen(uhSyncFlagRows)>
<cfset uhSyncCanShowPanel = uhSyncPanelItemCount GT 0>

<cfif uhSyncCanShowPanel>
    <cfset uhSyncSummaryText = uhSyncPanelItemCount & " UH Sync update(s) available">
    <cfset uhSyncSubText = arrayLen(uhSyncPendingDiffs) GT 0
        ? "field differences from the last sync report"
        : "live Student/Staff/Faculty flag changes detected">

    <cfset uhSyncPanelHtml = "
    <div class='alert alert-warning border-warning mb-4 p-0 users-edit-sync-panel panel-info'>
        <div class='d-flex align-items-center justify-content-between px-3 pt-3 pb-2 border-bottom users-edit-sync-panel-header'>
            <div>
                <i class='bi bi-arrow-left-right me-2 text-warning'></i>
                <strong>#EncodeForHTML(uhSyncSummaryText)#</strong>
                <span class='text-muted small ms-2'>#EncodeForHTML(uhSyncSubText)#</span>
            </div>
            <div class='d-flex gap-2 users-edit-sync-panel-actions'>
                <button class='btn btn-sm btn-ui-warning py-0 users-edit-warning-button' type='button'
                        data-bs-toggle='collapse' data-bs-target='##uhSyncDiffPanel'>
                    <i class='bi bi-chevron-down'></i> Details
                </button>
            </div>
        </div>
        <div class='collapse show' id='uhSyncDiffPanel'>
            <div class='px-3 py-2 users-edit-sync-panel-body'>
    ">

    <cfif len(uhSyncApiWarning)>
        <cfset uhSyncPanelHtml &= "<div class='alert alert-warning mb-3'>#EncodeForHTML(uhSyncApiWarning)#</div>">
    </cfif>

    <cfif uhSyncPanelItemCount GT 0>
        <cfset uhSyncPanelHtml &= "
                <div class='table-responsive'>
                <table class='table table-sm table-bordered mb-2 users-edit-sync-table'>
                    <thead class='table-light users-edit-sync-table-head'>
                        <tr>
                            <th class='users-edit-diff-col-field'>Field</th>
                            <th class='users-edit-diff-col-local'>Local Value</th>
                            <th class='users-edit-diff-col-api'>API Value</th>
                            <th class='text-end users-edit-diff-col-actions'>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
        ">

        <cfloop from="1" to="#arrayLen(uhSyncPendingDiffs)#" index="dIdx">
            <cfset pd = uhSyncPendingDiffs[dIdx]>
            <cfset pdLbl = structKeyExists(uhSyncFieldLabels_edit, pd.FIELDNAME) ? uhSyncFieldLabels_edit[pd.FIELDNAME] : pd.FIELDNAME>
            <cfset uhSyncPanelHtml &= "
                        <tr>
                            <td class='fw-semibold small'>#EncodeForHTML(pdLbl)#</td>
                            <td class='text-muted small'>#(len(trim(pd.LOCALVALUE)) ? EncodeForHTML(pd.LOCALVALUE) : '<em>empty</em>')#</td>
                            <td class='small'><strong>#EncodeForHTML(pd.APIVALUE)#</strong></td>
                            <td class='text-end text-nowrap'>
                                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                                    <input type='hidden' name='diffID' value='#pd.DIFFID#'>
                                    <input type='hidden' name='resolution' value='synced'>
                                    <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(editReturnTo)#'>
                                    <button type='submit' class='btn btn-xs btn-sm btn-ui-save py-0 px-2 users-edit-success-button'>
                                        <i class='bi bi-cloud-download'></i> Sync
                                    </button>
                                </form>
                                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'>
                                    <input type='hidden' name='diffID' value='#pd.DIFFID#'>
                                    <input type='hidden' name='resolution' value='discarded'>
                                    <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(editReturnTo)#'>
                                    <button type='submit' class='btn btn-xs btn-sm btn-ui-cancel py-0 px-2 users-edit-secondary-button'>
                                        <i class='bi bi-x'></i> Discard
                                    </button>
                                </form>
                            </td>
                        </tr>
            ">
        </cfloop>

        <cfloop from="1" to="#arrayLen(uhSyncFlagRows)#" index="flagRowIndex">
            <cfset flagRow = uhSyncFlagRows[flagRowIndex]>
            <cfset uhSyncPanelHtml &= "
                        <tr>
                            <td class='fw-semibold small'>#EncodeForHTML(flagRow.label)# Flag</td>
                            <td class='text-muted small'>#EncodeForHTML(flagRow.localValue)#</td>
                            <td class='small'><strong>#EncodeForHTML(flagRow.apiValue)#</strong></td>
                            <td class='text-end text-nowrap'>
                                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                                    <input type='hidden' name='applyFlagName' value='#EncodeForHTMLAttribute(flagRow.flagName)#'>
                                    <input type='hidden' name='applyFlagApiValue' value='#EncodeForHTMLAttribute(flagRow.apiValue)#'>
                                    <input type='hidden' name='applySourceUserID' value='#EncodeForHTMLAttribute(user.USERID)#'>
                                    <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(editReturnTo)#'>
                                    <button type='submit' class='btn btn-xs btn-sm btn-ui-save py-0 px-2 users-edit-success-button'>
                                        <i class='bi bi-cloud-download'></i> Sync Flag
                                    </button>
                                </form>
                            </td>
                        </tr>
            ">
        </cfloop>

        <cfset uhSyncPanelHtml &= "
                    </tbody>
                </table>
                </div>
        ">
    </cfif>

    <cfset uhSyncPanelHtml &= "
                <div class='d-flex gap-2 pb-1 users-edit-sync-panel-footer'>
    ">

    <cfif uhSyncHasApiId>
        <cfset uhSyncPanelHtml &= "
                    <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                        <input type='hidden' name='syncAll' value='1'>
                        <input type='hidden' name='applySourceUserID' value='#EncodeForHTMLAttribute(user.USERID)#'>
                        <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(editReturnTo)#'>
                        <button type='submit' class='btn btn-sm btn-ui-save'>
                            <i class='bi bi-cloud-download me-1'></i>Sync All Fields &amp; Flags
                        </button>
                    </form>
        ">
    </cfif>

    <cfset uhSyncPanelHtml &= "
                </div>
            </div>
        </div>
    </div>
    ">
</cfif>

<cfset returnTo = structKeyExists(url, "returnTo") AND len(trim(url.returnTo)) ? trim(url.returnTo) : (len(trim(cgi.HTTP_REFERER ?: "")) ? trim(cgi.HTTP_REFERER) : "/admin/users/index.cfm")>
<cfset contentWrapperClass = "">
<cfset toolbarListType = "all">
<cfset toolbarSearchTerm = structKeyExists(url, "search") ? trim(url.search) : "">
<cfset currentAdminUser = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {}>
<cfset currentUserDisplayName = encodeForHTML(trim(currentAdminUser.displayName ?: "Admin User"))>
<cfset currentUserEmail = encodeForHTML(trim(currentAdminUser.email ?: ""))>
<cfset currentUserUsername = encodeForHTML(trim(currentAdminUser.username ?: ""))>
<cfset currentUserRoleLabel = "">
<cfset currentUserImageSrc = "">
<cfset impersonationState = {}>
<cfset currentRequestUrl = cgi.script_name & (len(trim(cgi.query_string ?: "")) ? "?" & cgi.query_string : "")>
<cfset toolbarReturnToMatch = reFindNoCase("(?:\?|&)list=([^&]+)", returnTo, 1, true)>

<cfif isStruct(toolbarReturnToMatch) AND arrayLen(toolbarReturnToMatch.len) GTE 2 AND toolbarReturnToMatch.len[2] GT 0>
    <cfset toolbarListType = lCase(urlDecode(mid(returnTo, toolbarReturnToMatch.pos[2], toolbarReturnToMatch.len[2])))>
</cfif>

<cfif structKeyExists(currentAdminUser, "roles") AND isArray(currentAdminUser.roles) AND arrayLen(currentAdminUser.roles)>
    <cfset currentUserRoleLabel = encodeForHTML(replace(currentAdminUser.roles[1], "_", " ", "all"))>
</cfif>
<cfif NOT len(currentUserImageSrc) AND structKeyExists(currentAdminUser, "image")>
    <cfset currentUserImageSrc = trim(currentAdminUser.image ?: "")>
</cfif>
<cfif NOT len(currentUserImageSrc) AND structKeyExists(currentAdminUser, "avatar")>
    <cfset currentUserImageSrc = trim(currentAdminUser.avatar ?: "")>
</cfif>
<cfif NOT len(currentUserImageSrc)>
    <cfset currentUserImageSrc = request.webRoot & "/assets/images/uh.png">
</cfif>
<cfif application.authService.isImpersonating() AND application.authService.isActualSuperAdmin()>
    <cfset impersonationState = application.authService.getImpersonationState()>
</cfif>

<cfset usersTopToolBar = "
        <nav class='navbar sticky-top users-list-toolbar'>
            <div class='container-fluid users-list-toolbar-shell'>
                <div class='users-list-toolbar-primary'>
                    <button class='btn btn-sm btn-ui-cancel me-2 admin-sidebar-toggle' id='sidebarToggle' type='button' title='Toggle Sidebar' aria-label='Toggle Sidebar'>
                        <i class='bi bi-list'></i>
                    </button>
                    <div class='navbar-brand users-list-toolbar-brand mb-0 fs-5 d-flex align-items-center gap-2'>
                        <span>UHCO_Identity</span>
                        <span class='users-list-toolbar-brand-divider'>|</span>
                        <i class='bi bi-people-fill'></i>
                        <span class='users-list-toolbar-brand-label'>Users</span>
                    </div>
                    <div class='users-list-toolbar-controls'>
                        <form method='get' action='/admin/users/index.cfm' class='users-list-toolbar-search-form'>
                            <input type='hidden' name='list' value='#toolbarListType#'>
                            <input type='hidden' name='page' value='1'>
                            <div class='input-group users-list-toolbar-search users-list-toolbar-input-group'>
                                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#encodeForHTMLAttribute(toolbarSearchTerm)#'>
                                <button class='btn btn-ui-filter' type='submit'><i class='bi bi-search me-1'></i>Search</button>
                            </div>
                        </form>
                    </div>
                </div>
            
                <ul class='navbar-nav d-flex flex-row align-items-center gap-2 ms-auto users-list-toolbar-nav'>
                    <li class='nav-item dropdown ms-3 users-list-toolbar-account'>
                        <a class='nav-link dropdown-toggle p-0 d-flex align-items-center gap-2 text-dark' href='##' role='button' data-bs-toggle='dropdown' aria-expanded='false' aria-label='User menu'>
                            <img src='#encodeForHTMLAttribute(currentUserImageSrc)#' alt='Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#' class='rounded-circle users-list-toolbar-avatar admin-toolbar-avatar'>
                            <span class='d-none d-lg-inline small'>#currentUserDisplayName#</span>
                        </a>
                        <div class='dropdown-menu dropdown-menu-end p-3 users-list-toolbar-dropdown' style='min-width: 320px;'>
                            <div class='d-flex align-items-center gap-3 mb-3 users-list-toolbar-account-header'>
                                <img src='#encodeForHTMLAttribute(currentUserImageSrc)#' alt='Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#' class='users-list-toolbar-avatar rounded-circle'>
                                <div class='users-list-toolbar-account-meta'>
                                    <h6 class='mb-1'>#currentUserDisplayName#</h6>
                                    #(len(currentUserEmail) ? "<div class='small text-muted'>" & currentUserEmail & "</div>" : "")#
                                    #(len(currentUserUsername) ? "<div class='small text-muted'>@" & currentUserUsername & "</div>" : "")#
                                </div>
                            </div>
                            #(len(currentUserRoleLabel) ? "<div class='bg-light p-2 rounded mb-3'><small class='d-block text-uppercase fw-bold text-muted users-list-toolbar-label'>Role</small><span class='badge badge-dark'>" & currentUserRoleLabel & "</span></div>" : "")#
                            #(structCount(impersonationState) ? "<div class='users-list-toolbar-impersonation alert alert-warning mb-3 py-2 px-3'><div class='small fw-semibold text-uppercase mb-1'>Impersonation Active</div><div class='small mb-2'>You are currently using <strong>" & encodeForHTML(impersonationState.label ?: "") & "</strong>.</div><form method='post' action='" & request.webRoot & "/admin/settings/admin-users/save.cfm' class='mb-0'><input type='hidden' name='action' value='clearImpersonation'><input type='hidden' name='returnURL' value='" & encodeForHTMLAttribute(currentRequestUrl) & "'><button type='submit' class='btn btn-sm btn-ui-warning w-100'><i class='bi bi-x-octagon me-1'></i>Stop Impersonating</button></form></div>" : "")#
                            <div class='d-grid'>
                                <a href='#request.webRoot#/admin/logout.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-box-arrow-right me-1'></i>Logout</a>
                            </div>
                        </div>
                    </li>
                </ul>
            </div>
        </nav>
">

<cfset isSuperAdmin = application.authService.hasRole("SUPER_ADMIN")>
<cfset canViewAlumni = application.authService.hasRole("ALUMNI_ADMIN")>
<cfset canManageFacultyAlumni = application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])>
<cfset canManageDropboxFolder = isSuperAdmin OR request.hasPermission("media.folder.manage")>
<cfset dropboxFolderResultClass = "mt-2 d-none">
<cfset dropboxFolderResultHtml  = "">
<cfif canManageDropboxFolder AND len(trim(user.DROPBOXFOLDERPATH ?: ""))>
    <cfset _dbxPath = encodeForHTML(trim(user.DROPBOXFOLDERPATH))>
    <cfset dropboxFolderResultClass = "mt-2">
    <cfset dropboxFolderResultHtml  = "<div class='alert alert-success d-flex align-items-center gap-3 py-2 mb-0'><i class='bi bi-folder-check fs-5 flex-shrink-0'></i><div><strong>Folder on Record</strong> <code class='ms-1'>#_dbxPath#</code><span class='text-muted small ms-2'>(click Verify to refresh)</span></div><a href='/admin/user-media/sources.cfm?userid=#val(user.USERID)#' class='btn btn-sm btn-ui-go ms-auto' target='_blank'><i class='bi bi-card-image me-1'></i>User-Media</a></div>">
</cfif>
<cfset userAliases = aliasesService.getAliases(val(url.userID)).data>
<cfset userAppointments = (structKeyExists(profile, "appointments") AND isArray(profile.appointments)) ? profile.appointments : []>
<cfset userEmails = (structKeyExists(profile, "emails") AND isArray(profile.emails)) ? profile.emails : []>
<cfset userPhones = (structKeyExists(profile, "phones") AND isArray(profile.phones)) ? profile.phones : []>
<cfset userAddresses = (structKeyExists(profile, "addresses") AND isArray(profile.addresses)) ? profile.addresses : []>
<cfset userDegrees = (structKeyExists(profile, "degrees") AND isArray(profile.degrees)) ? profile.degrees : []>
<cfset userExtIDs = (structKeyExists(profile, "externalIDs") AND isArray(profile.externalIDs)) ? profile.externalIDs : []>
<cfset userAccess = (structKeyExists(profile, "access") AND isArray(profile.access)) ? profile.access : []>
<cfset spProfile = (structKeyExists(profile, "studentProfile") AND isStruct(profile.studentProfile)) ? profile.studentProfile : {}>
<cfset spAwards = (structKeyExists(profile, "awards") AND isArray(profile.awards)) ? profile.awards : []>
<cfset spResidencies = (structKeyExists(profile, "residencies") AND isArray(profile.residencies)) ? profile.residencies : []>
<cfset bioRecord = (structKeyExists(profile, "bio") AND isStruct(profile.bio)) ? profile.bio : {}>
<cfset bioContent = trim(toString(bioRecord.BIOCONTENT ?: bioRecord.BioContent ?: ""))>
<cfset bioContent = bioService.sanitizeForRender(bioContent)>
<cfset clinicalBioRecord = (structKeyExists(profile, "clinicalBio") AND isStruct(profile.clinicalBio)) ? profile.clinicalBio : {}>
<cfset clinicalBioContent = trim(toString(clinicalBioRecord.BIOCONTENT ?: clinicalBioRecord.BioContent ?: ""))>
<cfset clinicalBioContent = bioService.sanitizeForRender(clinicalBioContent)>
<cfset aliasTypeOptsJS = "">
<cfset aliasTypeLblsJS = "">
<cfloop from="1" to="#arrayLen(aliasTypes)#" index="local.aliasTypeIndex">
    <cfset local.aliasType = aliasTypes[local.aliasTypeIndex]>
    <cfset aliasTypeOptsJS = listAppend(aliasTypeOptsJS, serializeJSON(trim(toString(local.aliasType.ALIASTYPECODE ?: ""))), ",")>
    <cfset aliasTypeLblsJS = listAppend(aliasTypeLblsJS, serializeJSON(trim(toString(local.aliasType.DESCRIPTION ?: local.aliasType.ALIASTYPECODE ?: ""))), ",")>
</cfloop>

<cfset resolvedFirstName = trim(toString(user.PREFERREDFIRSTNAME ?: user.FIRSTNAME ?: ""))>
<cfset resolvedMiddleName = trim(toString(user.PREFERREDMIDDLENAME ?: user.MIDDLENAME ?: ""))>
<cfset resolvedLastName = trim(toString(user.PREFERREDLASTNAME ?: user.LASTNAME ?: ""))>
<cfset editUserHeading = trim(resolvedFirstName & " " & resolvedLastName)>
<cfif NOT len(editUserHeading)>
    <cfset editUserHeading = trim(toString(user.DISPLAYNAME ?: user.PREFERREDNAME ?: "User #val(user.USERID)#"))>
</cfif>
<cfset editPrefix = trim(toString(user.PREFIX ?: ""))>
<cfset editSuffix = trim(toString(user.SUFFIX ?: ""))>
<cfset editCombinedDegrees = trim(degreesService.buildDegreesString(val(url.userID)))>
<cfset editTitle1 = trim(toString(user.TITLE1 ?: ""))>
<cfset editSubTitle = len(editTitle1) ? "<p class='text-muted fs-5'>#EncodeForHTML(editTitle1)#</p>" : "<p class='text-muted fs-5'>&nbsp;</p>">
<cfset editProfileThumbnail = "/assets/images/uh.png">
<cfif structKeyExists(profile, "images") AND isArray(profile.images) AND arrayLen(profile.images) GT 0>
    <cfset editProfileImageFallback = "">
    <cfloop from="1" to="#arrayLen(profile.images)#" index="i">
        <cfset img = profile.images[i]>
        <cfif NOT len(editProfileImageFallback) AND lCase(trim(img.IMAGEVARIANT ?: "")) EQ "web_profile">
            <cfset editProfileImageFallback = img.IMAGEURL>
        </cfif>
        <cfif lCase(trim(img.IMAGEVARIANT ?: "")) EQ "web_thumb">
            <cfset editProfileThumbnail = img.IMAGEURL>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif editProfileThumbnail EQ "/assets/images/uh.png" AND len(editProfileImageFallback)>
        <cfset editProfileThumbnail = editProfileImageFallback>
    </cfif>
</cfif>

<cfset currentGradYear = trim(toString(spProfile.CURRENTGRADYEAR ?: spProfile.CurrentGradYear ?: ""))>
<cfset originalGradYear = trim(toString(spProfile.ORIGINALGRADYEAR ?: spProfile.OriginalGradYear ?: ""))>
<cfset spCommAge = trim(toString(spProfile.COMMENCEMENTAGE ?: spProfile.CommencementAge ?: ""))>
<cfset spFirstExt = trim(toString(spProfile.FIRSTEXTERNSHIP ?: spProfile.FirstExternship ?: ""))>
<cfset spSecondExt = trim(toString(spProfile.SECONDEXTERNSHIP ?: spProfile.SecondExternship ?: ""))>
<cfset spDissertation = trim(toString(spProfile.DISSERTATIONTHESIS ?: spProfile.DissertationThesis ?: ""))>
<cfset spHometownCity = trim(toString(spProfile.HOMETOWNCITY ?: spProfile.HometownCity ?: ""))>
<cfset spHometownState = trim(toString(spProfile.HOMETOWNSTATE ?: spProfile.HometownState ?: ""))>

<cfset userOrgIDs = []>
<cfset orgRoleMap = {}>
<cfset orgChildrenByParent = { "ROOT" = [] }>
<cfloop from="1" to="#arrayLen(userOrganizations)#" index="i">
    <cfif structKeyExists(userOrganizations[i], "ORGID") AND NOT isNull(userOrganizations[i].ORGID)>
        <cfset arrayAppend(userOrgIDs, val(userOrganizations[i].ORGID))>
        <cfset orgRoleMap[toString(userOrganizations[i].ORGID)] = {
            roleTitle = trim(toString(userOrganizations[i].ROLETITLE ?: "")),
            roleOrder = val(userOrganizations[i].ROLEORDER ?: 0)
        }>
    </cfif>
</cfloop>
<cfloop from="1" to="#arrayLen(allOrganizations)#" index="i">
    <cfset local.org = allOrganizations[i]>
    <cfset local.parentKey = "ROOT">
    <cfif structKeyExists(local.org, "PARENTORGID") AND len(trim(toString(local.org.PARENTORGID ?: ""))) AND val(local.org.PARENTORGID ?: 0) GT 0>
        <cfset local.parentKey = toString(val(local.org.PARENTORGID))>
    </cfif>
    <cfif NOT structKeyExists(orgChildrenByParent, local.parentKey)>
        <cfset orgChildrenByParent[local.parentKey] = []>
    </cfif>
    <cfset arrayAppend(orgChildrenByParent[local.parentKey], local.org)>
</cfloop>

<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset extSystemsResult = externalIDService.getSystems()>
<cfset extSystems = (structKeyExists(extSystemsResult, "success") AND extSystemsResult.success AND isArray(extSystemsResult.data)) ? extSystemsResult.data : []>
<cfset extIdValueBySystemId = {}>
<cfloop from="1" to="#arrayLen(userExtIDs)#" index="i">
    <cfif structKeyExists(userExtIDs[i], "SYSTEMID")>
        <cfset extIdValueBySystemId[toString(val(userExtIDs[i].SYSTEMID))] = trim(toString(userExtIDs[i].EXTERNALVALUE ?: ""))>
    </cfif>
</cfloop>
<cfset extIDHtml = "<div class='row g-3'>">
<cfloop from="1" to="#arrayLen(extSystems)#" index="i">
    <cfset local.sys = extSystems[i]>
    <cfset local.sysId = val(local.sys.SYSTEMID ?: 0)>
    <cfset local.sysName = trim(toString(local.sys.SYSTEMNAME ?: "External ID"))>
    <cfset local.inputId = "extid-" & lCase(reReplace(local.sysName, "[^A-Za-z0-9]+", "-", "all")) & "-input">
    <cfset local.currentValue = structKeyExists(extIdValueBySystemId, toString(local.sysId)) ? extIdValueBySystemId[toString(local.sysId)] : "">
    <cfset local.isCougarnetField = findNoCase("cougarnet", local.sysName) GT 0>
    <cfset local.isPeoplesoftField = findNoCase("peoplesoft", local.sysName) GT 0>
    <cfif local.isCougarnetField>
        <cfset local.inputId = "extid-cougarnet-input">
    <cfelseif local.isPeoplesoftField>
        <cfset local.inputId = "extid-peoplesoft-input">
    </cfif>
    <cfset extIDHtml &= "<div class='col-md-6'><label class='form-label' for='#local.inputId#'>#EncodeForHTML(local.sysName)#</label><div class='input-group'><input class='form-control' id='#local.inputId#' name='extID_#local.sysId#' value='#EncodeForHTMLAttribute(local.currentValue)#'>" & ((local.isCougarnetField OR local.isPeoplesoftField) ? "<button type='button' class='btn btn-ui-go js-cougarnet-lookup' title='Lookup in LDAP'><i class='bi bi-search me-1'></i>LDAP Lookup</button>" : "") & "</div></div>">
</cfloop>
<cfif NOT arrayLen(extSystems)>
    <cfset extIDHtml &= "<div class='col-12'><p class='text-muted mb-0'>No external ID systems are configured.</p></div>">
</cfif>
<cfset extIDHtml &= "</div>">

<cfset userFlagIDs = []>
<cfloop from="1" to="#arrayLen(userFlags)#" index="i">
    <cfif structKeyExists(userFlags[i], "FLAGID") AND NOT isNull(userFlags[i].FLAGID)>
        <cfset arrayAppend(userFlagIDs, val(userFlags[i].FLAGID))>
    </cfif>
</cfloop>

<cfset emeritusFlagIDs = []>
<cfset residentFlagIDs = []>
<cfset showCurrentStudent = false>
<cfset showAlumni = false>
<cfset showFacultyProfile = false>
<cfset showFacultyFullOrAdjunct = false>
<cfset showStaffProfile = false>
<cfset showEmeritusProfile = false>
<cfset showResidentProfile = false>
<cfset showBio = false>
<cfset showPublicationsProfile = false>
<cfset publicationEligibleFlagNames = "faculty-adjunct,faculty-fulltime,professor-emeritus,joint faculty appointment">
<cfset publicationProfiles = isArray(profile.publicationProfiles ?: "") ? profile.publicationProfiles : []>
<cfset userPublications = isArray(profile.publications ?: "") ? profile.publications : []>
<cfset publicationFetchSummary = isArray(profile.publicationFetchSummary ?: "") ? profile.publicationFetchSummary : []>
<cfset publicationConfig = isStruct(profile.publicationConfig ?: "") ? profile.publicationConfig : {}>
<cfset publicationMaxShowcased = val(publicationConfig.maxShowcasedPerUser ?: 10)>
<cfset publicationProfilesByCode = {}>
<cfset publicationFetchByCode = {}>

<cfloop from="1" to="#arrayLen(publicationProfiles)#" index="i">
    <cfset local.serviceCode = lCase(trim(toString(publicationProfiles[i].SERVICECODE ?: "")))>
    <cfif len(local.serviceCode)>
        <cfset publicationProfilesByCode[local.serviceCode] = publicationProfiles[i]>
    </cfif>
</cfloop>

<cfloop from="1" to="#arrayLen(publicationFetchSummary)#" index="i">
    <cfset local.serviceCode = lCase(trim(toString(publicationFetchSummary[i].SERVICECODE ?: "")))>
    <cfif len(local.serviceCode) AND NOT structKeyExists(publicationFetchByCode, local.serviceCode)>
        <cfset publicationFetchByCode[local.serviceCode] = publicationFetchSummary[i]>
    </cfif>
</cfloop>

<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset local.flagName = "">
    <cfset local.flagId = 0>
    <cfif structKeyExists(allFlags[i], "FLAGNAME") AND NOT isNull(allFlags[i].FLAGNAME)>
        <cfset local.flagName = lCase(trim(toString(allFlags[i].FLAGNAME)))>
    </cfif>
    <cfif structKeyExists(allFlags[i], "FLAGID") AND NOT isNull(allFlags[i].FLAGID)>
        <cfset local.flagId = val(allFlags[i].FLAGID)>
    </cfif>

    <cfif local.flagName EQ "current-student" AND arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
        <cfset showCurrentStudent = true>
    </cfif>

    <cfif local.flagName EQ "alumni" AND arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
        <cfset showAlumni = true>
    </cfif>

    <cfif listFindNoCase("clinical-attending,faculty-adjunct,faculty-fulltime", local.flagName)>
        <cfif arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
            <cfset showFacultyProfile = true>
        </cfif>
    </cfif>
    <cfif listFindNoCase("faculty-adjunct,faculty-fulltime", local.flagName) AND arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
        <cfset showFacultyFullOrAdjunct = true>
    </cfif>

    <cfif local.flagName EQ "staff">
        <cfif arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
            <cfset showStaffProfile = true>
        </cfif>
    </cfif>

    <cfif local.flagName EQ "professor-emeritus">
        <cfset arrayAppend(emeritusFlagIDs, local.flagId)>
        <cfif arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
            <cfset showEmeritusProfile = true>
        </cfif>
    </cfif>

    <cfif listFindNoCase(publicationEligibleFlagNames, local.flagName) AND arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
        <cfset showPublicationsProfile = true>
    </cfif>

    <cfif local.flagName EQ "resident">
        <cfset arrayAppend(residentFlagIDs, local.flagId)>
        <cfif arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
            <cfset showResidentProfile = true>
        </cfif>
    </cfif>

    <cfif local.flagName EQ "public-facing" AND arrayFindNoCase(userFlagIDs, local.flagId) GT 0>
        <cfset showBio = true>
    </cfif>
</cfloop>

<cfif showAlumni AND NOT (canViewAlumni OR (showFacultyFullOrAdjunct AND canManageFacultyAlumni))>
    <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfsavecontent variable="publicationsPaneHtml">
    <cfoutput>
        <div class="tab-pane fade users-edit-tab-pane" id="publications-pane" role="tabpanel" aria-labelledby="publications-tab">
            <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3">
                <div>
                    <span class="navbar-text"><strong>ORCID Publications:</strong> ORCID profile settings can be saved and fetched from this tab.</span>
                </div>
                <div class="d-flex align-items-center gap-2">
                    <button type="button" class="btn btn-sm btn-ui-save" id="save-publications-btn"><i class="bi bi-floppy me-1"></i>Save ORCID Publications</button>
                    <span id="save-publications-status" class="ms-1"></span>
                </div>
            </div>

            <div class="alert alert-info d-flex justify-content-between align-items-center flex-wrap gap-2">
                <div class="d-flex flex-column gap-2">
                    <div>Eligible faculty can showcase up to #publicationMaxShowcased# publication(s). Imported ORCID results default to the past 5 years unless you turn that filter off before fetching.</div>
                    <div class="form-check mb-0">
                        <input class="form-check-input" type="checkbox" id="limitRecentPublicationYears" checked>
                        <label class="form-check-label" for="limitRecentPublicationYears">Limit imported publications to the past 5 years</label>
                    </div>
                </div>
                <span class="badge text-bg-light">Phase 1</span>
            </div>

            <div class="row g-3 mb-4">
                <div class="col-12 col-xl-6">
                    <div class="border rounded p-3 h-100 panel-surface">
                        <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                            <h5 class="mb-0">ORCID</h5>
                            <span class="badge text-bg-secondary">Primary provider</span>
                        </div>
                        <div class="row g-3">
                            <div class="col-12">
                                <label class="form-label" for="orcidIdentifier">ORCID iD</label>
                                <input class="form-control" id="orcidIdentifier" name="orcid_identifier" value="#encodeForHTMLAttribute(structKeyExists(publicationProfilesByCode, "orcid") ? (publicationProfilesByCode["orcid"].PROFILEIDENTIFIER ?: "") : "")#" placeholder="0000-0000-0000-0000">
                            </div>
                            <div class="col-12">
                                <label class="form-label" for="orcidUrl">ORCID URL</label>
                                <input class="form-control" id="orcidUrl" name="orcid_url" value="#encodeForHTMLAttribute((structKeyExists(publicationProfilesByCode, "orcid") AND len(trim(publicationProfilesByCode["orcid"].PROFILEURL ?: ""))) ? publicationProfilesByCode["orcid"].PROFILEURL : "https://orcid.org/")#" placeholder="https://orcid.org/" readonly disabled>
                            </div>
                            <div class="col-12 form-check ms-2">
                                <input class="form-check-input" type="checkbox" id="orcidEnabled" name="orcid_enabled" #((!structKeyExists(publicationProfilesByCode, "orcid") OR val(publicationProfilesByCode["orcid"].ISENABLED ?: 0) EQ 1) ? "checked" : "")#>
                                <label class="form-check-label" for="orcidEnabled">Enable ORCID for this user</label>
                            </div>
                            <div class="col-12 d-flex align-items-center gap-2 flex-wrap">
                                <button type="button" class="btn btn-sm btn-ui-filter" id="fetch-orcid-btn">Fetch ORCID Publications</button>
                                <span class="small text-muted" id="fetch-orcid-status">Fetch creates canonical records and links them to this user.</span>
                            </div>
                            <div class="col-12 small text-muted">
                                Last fetch: #encodeForHTML(structKeyExists(publicationFetchByCode, "orcid") ? (publicationFetchByCode["orcid"].STARTEDAT ?: "Never") : "Never")#
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="row g-3" id="publicationsPanels" data-max-showcased="#publicationMaxShowcased#">
                <div class="col-12 col-xl-7">
                    <div class="border rounded p-3 panel-surface h-100">
                        <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
                            <h5 class="mb-0">All Imported Publications</h5>
                            <span class="small text-muted">Fetched ORCID records appear here. Use the right arrow to move a publication into the showcased list.</span>
                        </div>
                        <cfif arrayLen(userPublications) GT 0>
                            <div class="row g-3">
                                <cfloop from="1" to="#arrayLen(userPublications)#" index="local.pubIndex">
                                    <cfset local.pub = userPublications[local.pubIndex]>
                                    <cfset local.sourceLabel = listFindNoCase(local.pub.SOURCESERVICES ?: "", "ORCID") ? "ORCID" : "Imported source">
                                    <div class="col-12">
                                        <div class="border rounded p-3" data-publication-card="#val(local.pub.PUBLICATIONID)#">
                                            <div class="d-flex align-items-start justify-content-between gap-3 flex-wrap">
                                                <div>
                                                    <div class="fw-semibold">#encodeForHTML(local.pub.CANONICALTITLE ?: "Untitled publication")#</div>
                                                    <div class="small text-muted">#encodeForHTML(local.pub.CANONICALAUTHORSTEXT ?: "")#</div>
                                                    <div class="small text-muted">#encodeForHTML(local.pub.PUBLICATIONYEAR ?: "")# #encodeForHTML(local.pub.JOURNALORSOURCE ?: "")#</div>
                                                    <div class="small text-muted">Source: #encodeForHTML(local.sourceLabel)#</div>
                                                </div>
                                                <div class="d-flex align-items-center gap-2">
                                                    <cfif val(local.pub.ISSHOWCASED ?: 0) EQ 1>
                                                        <span class="badge text-bg-success">Showcased</span>
                                                    <cfelse>
                                                        <button type="button" class="btn btn-sm btn-ui-add publication-showcase-move-btn" data-direction="add" data-publication-id="#val(local.pub.PUBLICATIONID)#" aria-label="Move publication to showcased list">&rarr;</button>
                                                    </cfif>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </cfloop>
                            </div>
                        <cfelse>
                            <p class="text-muted mb-0">No publication records have been imported yet. Save the ORCID settings, then fetch from ORCID.</p>
                        </cfif>
                    </div>
                </div>
                <div class="col-12 col-xl-5">
                    <div class="border rounded p-3 panel-surface h-100">
                        <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mb-3">
                            <h5 class="mb-0">Showcased Publications</h5>
                            <span class="small text-muted">Only records currently marked for showcase appear here. Use the left arrow to remove one.</span>
                        </div>
                        <cfif arrayLen(userPublications) GT 0>
                            <cfset local.showcasedCount = 0>
                            <div class="row g-3" id="showcasedPublicationsList">
                                <cfloop from="1" to="#arrayLen(userPublications)#" index="local.pubIndex">
                                    <cfset local.pub = userPublications[local.pubIndex]>
                                    <cfif val(local.pub.ISSHOWCASED ?: 0) EQ 1>
                                        <cfset local.showcasedCount++>
                                        <div class="col-12 showcased-publication-item" data-publication-id="#val(local.pub.PUBLICATIONID)#">
                                            <div class="border rounded p-3 bg-light-subtle">
                                                <div class="d-flex align-items-start justify-content-between gap-3 flex-wrap">
                                                    <div>
                                                        <div class="fw-semibold">#encodeForHTML(local.pub.CANONICALTITLE ?: "Untitled publication")#</div>
                                                        <div class="small text-muted">#encodeForHTML(local.pub.CANONICALAUTHORSTEXT ?: "")#</div>
                                                        <div class="small text-muted">Display order: #val(local.pub.DISPLAYORDER ?: local.pubIndex)#</div>
                                                    </div>
                                                    <button type="button" class="btn btn-sm btn-ui-delete publication-showcase-move-btn" data-direction="remove" data-publication-id="#val(local.pub.PUBLICATIONID)#" aria-label="Remove publication from showcased list">&larr;</button>
                                                </div>
                                            </div>
                                        </div>
                                    </cfif>
                                </cfloop>
                            </div>
                            <cfif local.showcasedCount EQ 0>
                                <p class="text-muted mb-0">No publications are currently set to showcase.</p>
                            </cfif>
                        <cfelse>
                            <p class="text-muted mb-0">No publications are currently set to showcase.</p>
                        </cfif>
                    </div>
                </div>
            </div>
        </div>
    </cfoutput>
</cfsavecontent>

<cfset content = "
#usersTopToolBar#
<div class='py-4 px-4 pt-2'>
<div class='users-page-secondary-toolbar users-view-secondary-toolbar mb-4'>
    <div class='users-page-secondary-toolbar-heading users-view-header'>
        <img src='#editProfileThumbnail#' alt='Profile Thumbnail' class='rounded admin-object-cover users-view-profile-thumb'>
        <div class='users-view-header-body'>
            <h1 class='users-view-title'>#(len(editPrefix) ? EncodeForHTML(editPrefix) & ' ' : '')##EncodeForHTML(editUserHeading)##(len(editSuffix) ? ', ' & EncodeForHTML(editSuffix) : '')#<cfif len(editCombinedDegrees)><span class='users-view-degrees'>, #EncodeForHTML(editCombinedDegrees)#</span></cfif></h1>
            <div class='users-view-subtitle'>#editSubTitle#</div>
            <div class='users-edit-record-status #((userActiveRaw EQ 1) ? "users-edit-record-status-active" : "users-edit-record-status-inactive")#' tabindex='0' role='button' aria-label='Toggle record status'>
                <label class='form-label mb-0' for='activeSwitch'><strong>Record Status:</strong></label>
                <div class='form-check form-switch mb-0 users-edit-record-status-switch'>
                    <input class='form-check-input' type='checkbox' value='1'
                        id='activeSwitch'
                        data-userid='#val(user.USERID)#'
                        #((userActiveRaw EQ 1) ? 'checked' : '')#>
                    <label class='form-check-label' id='activeSwitchLabel' for='activeSwitch'>
                        #((userActiveRaw EQ 1) ? 'Active' : 'Inactive')#
                    </label>
                </div>
            </div>
        </div>
    </div>
    <div class='users-page-secondary-toolbar-actions'>
        <a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-sm btn-ui-cancel'><i class='bi bi-people-fill me-1'></i>Back to User List</a>
        <a href='/admin/users/view.cfm?userID=#urlEncodedFormat(user.USERID)#' class='btn btn-sm btn-ui-go'><i class='bi bi-eye-fill me-1'></i>View User Profile</a>
        <button type='button' class='btn btn-sm btn-ui-go' id='refreshPageBtn'><i class='bi bi-arrow-clockwise me-1'></i>Refresh Data</button>
        <cfif request.hasPermission('settings.user_permissions.manage')>
            <a href='/admin/settings/user-permissions/?userID=#user.USERID#&returnTo=#encodeForURL('/admin/users/edit.cfm?userID=' & user.USERID)#' class='btn btn-sm btn-ui-go'><i class='bi bi-shield-check me-1'></i>Permissions</a>
        </cfif>
        <cfif request.hasAnyPermission(['change_log.view','change_log.revert'])>
            <a href='/admin/users/history.cfm?userID=#user.USERID#' class='btn btn-sm btn-ui-go'><i class='bi bi-clock-history me-1'></i>Change History</a>
        </cfif>
    </div>
</div>
<div class='container-fluid users-edit-page'
    data-emeritus-flag-ids='#encodeForHTMLAttribute(arrayToList(emeritusFlagIDs))#'
    data-resident-flag-ids='#encodeForHTMLAttribute(arrayToList(residentFlagIDs))#'>

" & uhSyncPanelHtml & " 


<input type='hidden' id='pageUserID' value='#user.USERID#'>

    <ul class='nav nav-pills mb-3 users-edit-tabs' id='editTabs' role='tablist'>
        <li class='nav-item' role='presentation'>
            <button class='nav-link active' id='general-tab' data-bs-toggle='tab' data-bs-target='##general-pane' type='button' role='tab' aria-controls='general-pane' aria-selected='true'>General Information</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='contact-tab' data-bs-toggle='tab' data-bs-target='##contact-pane' type='button' role='tab' aria-controls='contact-pane' aria-selected='false'>Contact Information</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='bio-info-tab' data-bs-toggle='tab' data-bs-target='##bio-info-pane' type='button' role='tab' aria-controls='bio-info-pane' aria-selected='false'>Biographical Information</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='flags-tab' data-bs-toggle='tab' data-bs-target='##flags-pane' type='button' role='tab' aria-controls='flags-pane' aria-selected='false'>Flags</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='orgs-tab' data-bs-toggle='tab' data-bs-target='##orgs-pane' type='button' role='tab' aria-controls='orgs-pane' aria-selected='false'>Organizations</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='extids-tab' data-bs-toggle='tab' data-bs-target='##extids-pane' type='button' role='tab' aria-controls='extids-pane' aria-selected='false'>External IDs</button>
        </li>
        <li class='nav-item#(showPublicationsProfile ? "" : " d-none")#' role='presentation'>
            <button class='nav-link' id='publications-tab' data-bs-toggle='tab' data-bs-target='##publications-pane' type='button' role='tab' aria-controls='publications-pane' aria-selected='false'>ORCID Publications</button>
        </li>
        <li class='nav-item#(isSuperAdmin ? " ms-auto" : " d-none")#' role='presentation'>
            <button class='nav-link' id='admin-tab' data-bs-toggle='tab' data-bs-target='##admin-pane' type='button' role='tab' aria-controls='admin-pane' aria-selected='false'>Administrative</button>
        </li>
        
    </ul>

    <div class='tab-content users-edit-tab-content' id='editTabsContent'>

        <div class='tab-pane fade show active users-edit-tab-pane' id='general-pane' role='tabpanel' aria-labelledby='general-tab'>
            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div class='d-flex align-items-center flex-wrap gap-2'>
                    #editViewHelper.renderTabActionButtonGroup("refreshGeneralInfoBtn")#
                    <span class='navbar-text'><strong>Actions:</strong></span>
                    <button type='button' class='btn btn-sm btn-ui-add users-edit-outline-button' id='addAliasBtn'><i class='bi bi-person-plus me-1'></i>Add Name Alias</button>
                    <span id='aliasesSaveStatus' class='save-status ms-1'></span>
                    <button type='button' class='btn btn-sm btn-ui-add users-edit-outline-button' id='addAppointmentBtn'><i class='bi bi-briefcase me-1'></i>Add Appointment</button>
                    <span id='appointmentsSaveStatus' class='save-status ms-1'></span>
                </div>
                <div class='d-flex align-items-center gap-2'>
                    <button type='button' class='btn btn-sm btn-ui-save' id='save-general-btn'><i class='bi bi-floppy me-1'></i>Save General Info</button>
                    <span id='save-general-status' class='ms-1'></span>
                </div>
            </div>
            <!--
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>UH API First Name</label>
                    <input class='form-control' name='FirstName' value='#EncodeForHTMLAttribute(resolvedFirstName)#' disabled>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>UH API Middle Name</label>
                    <input class='form-control' name='MiddleName' value='#EncodeForHTMLAttribute(resolvedMiddleName)#' disabled>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>UH API Last Name</label>
                    <input class='form-control' name='LastName' value='#EncodeForHTMLAttribute(resolvedLastName)#' disabled>
                </div>
            </div>

            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Maiden Name</label>
                    <input class='form-control' name='MaidenName' value='#user.MAIDENNAME#' readonly disabled>
                    <small class='text-muted'>(legacy — migrated to aliases)</small>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Preferred Name</label>
                    <input class='form-control' name='PreferredName' value='#user.PREFERREDNAME#' readonly disabled>
                    <small class='text-muted'>(legacy — migrated to aliases)</small>
                </div>
                
            </div>
            -->



            <div class='mb-4'>
                <div class='d-flex align-items-center gap-2 mb-1'>
                    <label class='form-label fw-semibold mb-0'>Name Aliases</label>
                </div>
                <small class='text-muted d-block mb-2'>Name Aliases are alternate names associated with a users record, such as maiden names or preferred names. One alias can be designated as the Primary name, which is used for display purposes across this directory as well as the UH API. Aliases can also be marked Active or Inactive to control whether they are considered in search results and other features.</small>
                <div id='aliasesContainer'>
">

<cfloop from="1" to="#arrayLen(userAliases)#" index="local.ai">
    <cfset local.al = userAliases[local.ai]>
    <cfset local.alDisplay = "">
    <cfif len(trim(local.al.FIRSTNAME ?: ""))><cfset local.alDisplay &= trim(local.al.FIRSTNAME) & " "></cfif>
    <cfif len(trim(local.al.MIDDLENAME ?: ""))><cfset local.alDisplay &= trim(local.al.MIDDLENAME) & " "></cfif>
    <cfif len(trim(local.al.LASTNAME ?: ""))><cfset local.alDisplay &= trim(local.al.LASTNAME)></cfif>

    <cfif len(trim(local.al.ALIASTYPE ?: ""))> <cfset local.aliasTypeBadge = "<span class='badge badge-secondary'>#EncodeForHTML(local.al.ALIASTYPE)#</span>"><cfelse><cfset local.aliasTypeBadge = ""></cfif>
    <cfif len(trim(local.al.SOURCESYSTEM ?: ""))> <cfset local.sourceSystemBadge = "<small class='text-muted'>Source: #EncodeForHTML(local.al.SOURCESYSTEM)#</small>"><cfelse><cfset local.sourceSystemBadge = ""></cfif>

    <cfif val(local.al.ISPRIMARY ?: 0)>
        <cfset local.primaryBadge = " <span class='badge badge-isprimary rounded-pill'><i class='bi bi-check2 me-1'></i>Primary</span>">
        <cfset local.setPrimaryButton = "">
    <cfelse>
        <cfset local.primaryBadge = "">
        <cfset local.setPrimaryButton = "<button type='button' class='btn btn-sm btn-ui-save set-primary-alias-btn users-edit-secondary-button' data-idx='#(local.ai-1)#'>Set Primary</button>">
    </cfif>
    <cfif val(local.al.ISACTIVE ?: 0)>
        <cfset local.activeBadge = "<span class='badge badge-success rounded-pill'>Active</span>">
    <cfelse>
        <cfset local.activeBadge = "<span class='badge badge-danger rounded-pill'>Inactive</span>">
    </cfif>

    <cfset content &= "
                    <div class='card mb-2 alias-card users-edit-item-card card-surface' data-idx='#(local.ai-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(trim(local.alDisplay))#</strong>
                                    #local.aliasTypeBadge#
                                    #local.sourceSystemBadge#
                                    #local.primaryBadge#
                                    #local.activeBadge#
                                </div>
                                <div>
                                    #local.setPrimaryButton#    
                                    <button type='button' class='btn btn-sm btn-ui-edit edit-alias-btn users-edit-secondary-button' data-idx='#(local.ai-1)#'><i class='bi bi-pencil-square me-1'></i>Edit</button>
                                    <button type='button' class='btn btn-sm btn-ui-delete remove-alias-btn users-edit-danger-button' data-idx='#(local.ai-1)#'><i class='bi bi-trash me-1'></i>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='aliasCount' value='#arrayLen(userAliases)#'>
">
<cfloop from="1" to="#arrayLen(userAliases)#" index="local.ai">
    <cfset local.al = userAliases[local.ai]>
    <cfset content &= "
                <input type='hidden' data-alias-field='first' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.FIRSTNAME ?: "")#'>
                <input type='hidden' data-alias-field='middle' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.MIDDLENAME ?: "")#'>
                <input type='hidden' data-alias-field='last' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.LASTNAME ?: "")#'>
                <input type='hidden' data-alias-field='type' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.ALIASTYPE ?: "")#'>
                <input type='hidden' data-alias-field='source' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.SOURCESYSTEM ?: "")#'>
                <input type='hidden' data-alias-field='active' data-alias-idx='#(local.ai-1)#' value='#val(local.al.ISACTIVE ?: 0)#'>
                <input type='hidden' data-alias-field='primary' data-alias-idx='#(local.ai-1)#' value='#val(local.al.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
            </div>

            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Prefix</label>
                    <input class='form-control' name='Prefix' value='#(user.PREFIX ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Suffix</label>
                    <input class='form-control' name='Suffix' value='#(user.SUFFIX ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Pronouns</label>
                    <input class='form-control' name='Pronouns' value='#(user.PRONOUNS ?: "")#'>
                </div>
            </div>

            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Title 1 (UH Title)" & (isSuperAdmin ? " <span class='badge badge-warning'>Super Admin</span>" : "") & "</label>
                    <input class='form-control' name='Title1' value='#user.TITLE1#'" & (isSuperAdmin ? "" : " readonly") & ">
                </div>
            </div>

            <div class='mb-4'>
                <div class='d-flex align-items-center gap-2 mb-1'>
                    <label class='form-label fw-semibold mb-0'>Appointments</label>
                </div>
                <small class='text-muted d-block mb-2'>UHCO Appointments are additional titles or roles associated with this person, such as secondary or affiliated appointments.</small>
                <div id='appointmentsContainer'>
                    " & (arrayLen(userAppointments) EQ 0 ? "<p class='text-muted small mb-0'>No appointments on file.</p>" : "") & "
">

<cfloop from="1" to="#arrayLen(userAppointments)#" index="local.pi">
    <cfset local.appt = userAppointments[local.pi]>
    <cfif len(trim(local.appt.APPOINTMENTTYPE ?: ""))> <cfset local.apptTypeBadge = "<span class='badge badge-secondary'>#EncodeForHTML(local.appt.APPOINTMENTTYPE)#</span>"><cfelse><cfset local.apptTypeBadge = ""></cfif>

    <cfset content &= "
                    <div class='card mb-2 appointment-card users-edit-item-card card-surface' data-idx='#(local.pi-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(trim(local.appt.APPOINTMENTNAME ?: ""))#</strong>
                                    #local.apptTypeBadge#
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-ui-edit edit-appointment-btn users-edit-secondary-button' data-idx='#(local.pi-1)#'><i class='bi bi-pencil-square me-1'></i>Edit</button>
                                    <button type='button' class='btn btn-sm btn-ui-delete remove-appointment-btn users-edit-danger-button' data-idx='#(local.pi-1)#'><i class='bi bi-trash me-1'></i>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='appointmentCount' value='#arrayLen(userAppointments)#'>
">
<cfloop from="1" to="#arrayLen(userAppointments)#" index="local.pi">
    <cfset local.appt = userAppointments[local.pi]>
    <cfset content &= "
                <input type='hidden' data-appointment-field='name' data-appointment-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.appt.APPOINTMENTNAME ?: "")#'>
                <input type='hidden' data-appointment-field='type' data-appointment-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.appt.APPOINTMENTTYPE ?: "")#'>
    ">
</cfloop>
<cfset content &= "
                </div>
            </div>
" & (canManageDropboxFolder ? "
            <div class='row mt-4 pt-3 border-top' id='dropboxFolderSection'>
                <div class='col-12'>
                    <h6 class='fw-semibold mb-1'><i class='bi bi-folder2-open me-1'></i>User's Dropbox Folder</h6>
                    <p class='text-muted small mb-2'>Checks for <code>[lastname]-[firstname]-[peoplesoftid]</code> under the configured Dropbox root.</p>
                    <button type='button' id='verifyDropboxFolderBtn' class='btn btn-sm btn-ui-filter' data-userid='#val(user.USERID)#'><i class='bi bi-cloud-check me-1'></i>Verify Dropbox Folder</button>
                    <span id='dropboxFolderCheckStatus' class='ms-2 small text-muted'></span>
                    <div id='dropboxFolderCheckResult' class='#dropboxFolderResultClass#'>#dropboxFolderResultHtml#</div>
                </div>
            </div>
" : "") & "
        </div>

        <div class='tab-pane fade users-edit-tab-pane' id='contact-pane' role='tabpanel' aria-labelledby='contact-tab'>
            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div class='d-flex align-items-center flex-wrap gap-2'>
                    #editViewHelper.renderTabActionButtonGroup("refreshContactInfoBtn")#
                    <span class='navbar-text'><strong>Actions:</strong></span>
                    <button type='button' class='btn btn-sm btn-ui-add users-edit-outline-button' id='addEmailBtn'><i class='bi bi-envelope-plus me-1'></i>Add Email</button>
                    <button type='button' class='btn btn-sm btn-ui-add users-edit-outline-button' id='addPhoneBtn'><i class='bi bi-telephone-plus me-1'></i>Add Phone</button>
                    <button type='button' class='btn btn-sm btn-ui-add users-edit-outline-button' id='addAddressBtn'><i class='bi bi-geo-alt me-1'></i>Add Address</button>
                    <span id='emailsSaveStatus' class='save-status ms-1'></span>
                    <span id='phonesSaveStatus' class='save-status ms-1'></span>
                    <span id='addressesSaveStatus' class='save-status ms-1'></span>
                </div>
            </div>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Email Addresses</label>
" & (len(trim(user.EMAILPRIMARY)) ? "
                <p class='text-muted mb-2'><strong>@UH Email:</strong> #EncodeForHTML(user.EMAILPRIMARY)#</p>
" : "") & "
                <div id='emailsContainer'>
"> 
<cfloop from="1" to="#arrayLen(userEmails)#" index="local.ei">
    <cfset local.em = userEmails[local.ei]>
    <cfset content &= "
                    <div class='card mb-2 email-card users-edit-item-card card-surface' data-idx='#(local.ei-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(local.em.EMAILADDRESS)#</strong>
                                    <cfif len(trim(local.em.EMAILTYPE ?: ""))> <span class='badge badge-secondary'>#EncodeForHTML(local.em.EMAILTYPE)#</span></cfif>
                                    <cfif val(local.em.ISPRIMARY ?: 0)> <span class='badge badge-isprimary'><i class='bi bi-check2 me-1'></i>Primary</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-ui-edit edit-email-btn users-edit-secondary-button' data-idx='#(local.ei-1)#'><i class='bi bi-pencil-square me-1'></i>Edit</button>
                                    <button type='button' class='btn btn-sm btn-ui-delete remove-email-btn users-edit-danger-button' data-idx='#(local.ei-1)#'><i class='bi bi-trash me-1'></i>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='emailCount' value='#arrayLen(userEmails)#'>
">
<cfloop from="1" to="#arrayLen(userEmails)#" index="local.ei">
    <cfset local.em = userEmails[local.ei]>
    <cfset content &= "
                <input type='hidden' data-email-field='addr' data-email-idx='#(local.ei-1)#' value='#EncodeForHTMLAttribute(local.em.EMAILADDRESS)#'>
                <input type='hidden' data-email-field='type' data-email-idx='#(local.ei-1)#' value='#EncodeForHTMLAttribute(local.em.EMAILTYPE ?: "")#'>
                <input type='hidden' data-email-field='primary' data-email-idx='#(local.ei-1)#' value='#val(local.em.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
            </div>

            <hr>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Phone Numbers</label>
                <div id='phonesContainer'>
">
<cfloop from="1" to="#arrayLen(userPhones)#" index="local.pi">
    <cfset local.ph = userPhones[local.pi]>
    <cfset content &= "
                    <div class='card mb-2 phone-card users-edit-item-card card-surface' data-idx='#(local.pi-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(phoneService.formatForDisplay(local.ph.PHONENUMBER, "NATIONAL"))#</strong>
                                    <cfif len(trim(local.ph.PHONETYPE ?: ""))> <span class='badge badge-secondary'>#EncodeForHTML(local.ph.PHONETYPE)#</span></cfif>
                                    <cfif val(local.ph.ISPRIMARY ?: 0)> <span class='badge badge-isprimary'><i class='bi bi-check2 me-1'></i>Primary</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-ui-edit edit-phone-btn users-edit-secondary-button' data-idx='#(local.pi-1)#'><i class='bi bi-pencil-square me-1'></i>Edit</button>
                                    <button type='button' class='btn btn-sm btn-ui-delete remove-phone-btn users-edit-danger-button' data-idx='#(local.pi-1)#'><i class='bi bi-trash me-1'></i>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='phoneCount' value='#arrayLen(userPhones)#'>
">
<cfloop from="1" to="#arrayLen(userPhones)#" index="local.pi">
    <cfset local.ph = userPhones[local.pi]>
    <cfset content &= "
                <input type='hidden' data-phone-field='number' data-phone-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.ph.PHONENUMBER)#'>
                <input type='hidden' data-phone-field='type' data-phone-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.ph.PHONETYPE ?: "")#'>
                <input type='hidden' data-phone-field='primary' data-phone-idx='#(local.pi-1)#' value='#val(local.ph.ISPRIMARY ?: 0)#'>
                <input type='hidden' data-phone-field='country' data-phone-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.ph.COUNTRYCODE ?: "US")#'>
    ">
</cfloop>
<cfset content &= "
                </div>
            </div>

            <hr>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Addresses</label>
                <div id='addressesContainer'>
">
<cfloop from="1" to="#arrayLen(userAddresses)#" index="local.adi">
    <cfset local.addr = userAddresses[local.adi]>
    <cfset content &= "
                <div class='card mb-2 address-card users-edit-item-card card-surface'>
                    <div class='card-body py-2 px-3 users-edit-item-card-body'>
                        <div class='d-flex justify-content-between align-items-start'>
                            <div>
                                <strong>#EncodeForHTML(local.addr.ADDRESSTYPE ?: "")#</strong>
                                <cfif val(local.addr.ISPRIMARY ?: 0)> <span class='badge badge-isprimary'><i class='bi bi-check2 me-1'></i>Primary</span></cfif>
                                <br>
                                <small class='text-muted'>
                                    #EncodeForHTML(local.addr.ADDRESS1 ?: "")#
                                    <cfif len(trim(local.addr.ADDRESS2 ?: ""))>, #EncodeForHTML(local.addr.ADDRESS2)#</cfif>
                                    <cfif len(trim(local.addr.CITY ?: "")) OR len(trim(local.addr.STATE ?: "")) OR len(trim(local.addr.ZIPCODE ?: ""))>
                                        <br>#EncodeForHTML(local.addr.CITY ?: "")#<cfif len(trim(local.addr.STATE ?: ""))>, #EncodeForHTML(local.addr.STATE)#</cfif> #EncodeForHTML(local.addr.ZIPCODE ?: "")#
                                    </cfif>
                                    <cfif len(trim(local.addr.BUILDING ?: ""))> | Bldg: #EncodeForHTML(local.addr.BUILDING)#</cfif>
                                    <cfif len(trim(local.addr.ROOM ?: ""))> Rm: #EncodeForHTML(local.addr.ROOM)#</cfif>
                                    <cfif len(trim(local.addr.MAILCODE ?: ""))> | MC: #EncodeForHTML(local.addr.MAILCODE)#</cfif>
                                </small>
                            </div>
                            <div>
                                <button type='button' class='btn btn-sm btn-ui-edit edit-address-btn users-edit-secondary-button' data-idx='#(local.adi-1)#'><i class='bi bi-pencil-square me-1'></i>Edit</button>
                                <button type='button' class='btn btn-sm btn-ui-delete remove-address-btn users-edit-danger-button' data-idx='#(local.adi-1)#'><i class='bi bi-trash me-1'></i>Remove</button>
                            </div>
                        </div>
                    </div>
                </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='addressCount' value='#arrayLen(userAddresses)#'>
">
<cfloop from="1" to="#arrayLen(userAddresses)#" index="local.adi">
    <cfset local.addr = userAddresses[local.adi]>
    <cfset content &= "
                <input type='hidden' data-addr-field='type' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESSTYPE ?: "")#'>
                <input type='hidden' data-addr-field='addr1' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESS1 ?: "")#'>
                <input type='hidden' data-addr-field='addr2' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESS2 ?: "")#'>
                <input type='hidden' data-addr-field='city' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.CITY ?: "")#'>
                <input type='hidden' data-addr-field='state' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.STATE ?: "")#'>
                <input type='hidden' data-addr-field='zip' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ZIPCODE ?: "")#'>
                <input type='hidden' data-addr-field='building' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.BUILDING ?: "")#'>
                <input type='hidden' data-addr-field='room' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ROOM ?: "")#'>
                <input type='hidden' data-addr-field='mailcode' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.MAILCODE ?: "")#'>
                <input type='hidden' data-addr-field='primary' data-addr-idx='#(local.adi-1)#' value='#val(local.addr.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
            </div>
        </div>

        <div class='tab-pane fade users-edit-tab-pane' id='flags-pane' role='tabpanel' aria-labelledby='flags-tab'>
            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div>#editViewHelper.renderTabActionButtonGroup("refreshFlagsBtn")#</div>
                <div></div>
                <div class='d-flex align-items-center gap-2'>
                    <button type='button' class='btn btn-sm btn-ui-save' id='save-flags-btn'><i class='bi bi-floppy me-1'></i>Save Flags</button>
                    <span id='save-flags-status' class='ms-1'></span>
                </div>
            </div>
            <div class='border p-3 rounded users-edit-scroll-panel panel-surface panel-scroll-md'>
" />

<cfif arrayLen(allFlags) gt 0>
    <cfset content &= "<div class='row g-3'>">
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset flag = allFlags[i]>
        <cfif NOT canViewAlumni AND compareNoCase(trim(flag.FLAGNAME ?: ""), "Alumni") EQ 0>
            <cfcontinue>
        </cfif>
        <cfset isChecked = arrayFindNoCase(userFlagIDs, flag.FLAGID) gt 0>
        <cfset flagDescription = "">
        <cfif structKeyExists(flag, "FLAGDESCRIPTION") AND NOT isNull(flag.FLAGDESCRIPTION)>
            <cfset flagDescription = trim(toString(flag.FLAGDESCRIPTION))>
        </cfif>
        <cfset content &= "
            <div class='col-12 col-lg-6'>
                <div class='border rounded p-3 h-100 panel-surface users-edit-flag-card' data-flag-checkbox-id='flag#flag.FLAGID#'>
                    <div class='form-check mb-2'>
                        <input class='form-check-input' type='checkbox' name='Flags' value='#flag.FLAGID#' id='flag#flag.FLAGID#' data-flagname='#lCase(flag.FLAGNAME)#' " & (isChecked ? "checked" : "") & ">
                        <label class='form-check-label fw-semibold' for='flag#flag.FLAGID#'>
                            #encodeForHTML(flag.FLAGNAME)#
                        </label>
                    </div>
                    <div class='small text-muted ps-4'>#len(flagDescription) ? encodeForHTML(flagDescription) : "&nbsp;"#</div>
                </div>
            </div>
        ">
    </cfloop>
    <cfset content &= "</div>">
<cfelse>
    <cfset content &= "<p class='text-muted'>No flags available</p>">
</cfif>

<cfset content &= "
            </div>
        </div>

        <div class='tab-pane fade users-edit-tab-pane' id='orgs-pane' role='tabpanel' aria-labelledby='orgs-tab'>

            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div>#editViewHelper.renderTabActionButtonGroup("refreshOrgsBtn")#</div>
                <div></div>
                <div class='d-flex align-items-center gap-2'>
                    <button type='button' class='btn btn-sm btn-ui-save' id='save-orgs-btn'><i class='bi bi-floppy me-1'></i>Save Organizations</button>
                    <span id='save-orgs-status' class='ms-1'></span>
                </div>
            </div>

" />

<cfset content &= editViewHelper.renderOrgPanels(selectedOrgIDs=userOrgIDs, orgChildrenByParent=orgChildrenByParent, orgRoleMap=orgRoleMap)>

<cfset content &= "
        </div>

        <div class='tab-pane fade users-edit-tab-pane' id='extids-pane' role='tabpanel' aria-labelledby='extids-tab'>
            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div>#editViewHelper.renderTabActionButtonGroup("refreshExtidsBtn")#</div>
                <div></div>
                <div class='d-flex align-items-center gap-2'>
                    <button type='button' class='btn btn-sm btn-ui-save' id='save-extids-btn'><i class='bi bi-floppy me-1'></i>Save External IDs</button>
                    <span id='save-extids-status' class='ms-1'></span>
                </div>
            </div>
            #extIDHtml#
        </div>

            #publicationsPaneHtml#

" & (isSuperAdmin ? "
        <div class='tab-pane fade users-edit-tab-pane' id='admin-pane' role='tabpanel' aria-labelledby='admin-tab'>
            <div class='d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3'>
                <div>#editViewHelper.renderTabActionButtonGroup("refreshUhBtn")#</div>
                <div></div>
                <div class='d-flex align-items-center gap-2'>
                    <button type='button' class='btn btn-sm btn-ui-save' id='save-uh-btn'><i class='bi bi-floppy me-1'></i>Save UH Info</button>
                    <span id='save-uh-status' class='ms-1'></span>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-12'>
                    <label class='form-label fw-semibold' for='recordNotes'>Record Notes</label>
                    <textarea class='form-control' id='recordNotes' name='Notes' rows='4'>#encodeForHTML(user.NOTES ?: "")#</textarea>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='row pt-3'>
                    <div class='col-12'>
                    <h5>UH Sync Data</h5>
                    </div>
                </div>
                <div class='col-md-6'>
                    <label class='form-label text-muted'>@UH Primary Email</label>
                    <input class='form-control form-control-sm' id='emailPrimary' name='EmailPrimary' value='#user.EMAILPRIMARY#' type='email'>
                    <div class='invalid-feedback' id='emailPrimaryErr'></div>
                </div>
                <div class='col-md-6'>
                    <label class='form-label'>UH API ID</label>
                    <input class='form-control' name='UH_API_ID' value='#user.UH_API_ID#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Room</label>
                    <input class='form-control' name='Room' value='#(user.ROOM ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Building</label>
                    <input class='form-control' name='Building' value='#(user.BUILDING ?: "")#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Campus</label>
                    <input class='form-control' name='Campus' value='#(user.CAMPUS ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Division</label>
                    <input class='form-control' name='Division' value='#(user.DIVISION ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Division Name</label>
                    <input class='form-control' name='DivisionName' value='#(user.DIVISIONNAME ?: "")#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Department</label>
                    <input class='form-control' name='Department' value='#(user.DEPARTMENT ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Department Name</label>
                    <input class='form-control' name='DepartmentName' value='#(user.DEPARTMENTNAME ?: "")#'>
                </div>
                <div class='col-md-4'></div>
            </div>
            
            <div class='row mb-3'>
                <div class='col-md-8'>
                    <label class='form-label'>Office Mailing Address</label>
                    <div class='input-group'>
                        <input class='form-control' name='Office_Mailing_Address' id='officeMailingAddress' value='#(user.OFFICE_MAILING_ADDRESS ?: "")#'>
                        <button type='button' class='btn btn-ui-go' id='copyToAddressesBtn' title='Parse and copy to Addresses tab'>
                            <i class='bi bi-arrow-right-square'></i> Copy to Addresses
                        </button>
                    </div>
                    <small class='text-muted'>Copies parsed address as a new Office entry on the Contact tab</small>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Mailcode</label>
                    <input class='form-control' name='Mailcode' value='#(user.MAILCODE ?: "")#'>
                </div>
            </div>
            <div class='row mt-5 border-top pt-3 mb-3'>
                <div class='col-12'>
                <h5>Mirrored Data</h5>
                <small class='text-muted'>Mirrored from various tables and used for quick access via API.</small>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    
                    <label class='form-label text-muted'>Hometown City</label>
                    <div class='input-group mb-3'>
                    <input class='form-control' value='#EncodeForHTMLAttribute(spHometownCity)#' readonly>
                    <span class='input-group-text' id='basic-addon2'>Hometown City from userAddress</span>
                    </div>
                </div>
                <div class='col-md-4'>
                    
                    <label class='form-label text-muted'>Hometown State</label>
                    <div class='input-group mb-3'>
                    <input class='form-control' value='#EncodeForHTMLAttribute(spHometownState)#' readonly>
                    <span class='input-group-text' id='basic-addon2'>Hometown State from userAddress</span>
                    </div>
                </div>
                <div class='col-md-4 d-flex align-items-end'>
                    
                </div>
            </div>
        </div>
" : "") & "

">

<!--- Precompute biographical degree/award visibility and safe composite value --->
<!--- ── Biographical Information pane ── --->
<cfset showDegreesAwards = showFacultyProfile OR showAlumni OR showCurrentStudent OR showEmeritusProfile OR showResidentProfile>
<cfset local.bioDegreesDisplayStyle = showDegreesAwards ? "" : " style='display:none'">
<cfset local.compositeDegreesValue = trim(degreesService.buildDegreesString(val(url.userID)))>
<cfsavecontent variable="local.bioTabContent"><!--- Use cfsavecontent to prevent # expression re-parsing by layout.cfm --->
    <div class="tab-pane fade users-edit-tab-pane" id="bio-info-pane" role="tabpanel" aria-labelledby="bio-info-tab">
        <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 border-bottom pb-2 mb-3">
            <div class="d-flex align-items-center flex-wrap gap-2">
                <cfoutput>#editViewHelper.renderTabActionButtonGroup("refreshBiographicalInfoBtn")#</cfoutput>
                <span id="bioActionsLabel" class="navbar-text" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>><strong>Actions:</strong></span>
                <button type="button" class="btn btn-sm btn-ui-add" id="addDegreeBtn" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>><i class="bi bi-mortarboard me-1"></i>Add Degree</button>
                <button type="button" class="btn btn-sm btn-ui-add" id="addAwardBtn" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>><i class="bi bi-award me-1"></i>Add Award</button>
                <button type="button" class="btn btn-sm btn-ui-add" id="addResidencyBtn" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>><i class="bi bi-plus-circle me-1"></i>Add Residency</button>
                <span id="degreesSaveStatus" class="save-status ms-1" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>></span>
                <span id="awardsSaveStatus" class="save-status ms-1" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>></span>
                <span id="residenciesSaveStatus" class="save-status ms-1"></span>
            </div>
            <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-sm btn-ui-save" id="save-bioinfo-btn"><i class="bi bi-floppy me-1"></i>Save Biographical Info</button>
                <span id="save-bioinfo-status" class="ms-1"></span>
            </div>
        </div>
        <h6 class="fw-bold mb-3">Personal</h6>
        <div class="row mb-3">
            <div class="col-md-3">
                <label class="form-label">Date of Birth</label>
                <cfset local.dobVal = (isDate(user.DOB ?: "") ? dateFormat(user.DOB, "yyyy-mm-dd") : "")>
                <input class="form-control" type="date" name="DOB" value="<cfoutput>#local.dobVal#</cfoutput>">
            </div>
            <div class="col-md-3">
                <label class="form-label">Gender</label>
                <select class="form-select" name="Gender">
                    <option value="">--</option>
                    <cfset local.genderVal = user.GENDER ?: "">
                    <option value="Male" <cfoutput>#(local.genderVal EQ "Male" ? "selected" : "")#</cfoutput>>Male</option>
                    <option value="Female" <cfoutput>#(local.genderVal EQ "Female" ? "selected" : "")#</cfoutput>>Female</option>
                </select>
            </div>
        </div>
        <hr id="bioDegreesAwardsDivider" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>>
        <h6 id="bioDegreesAwardsHeading" class="fw-bold mb-3" <cfoutput>#local.bioDegreesDisplayStyle#</cfoutput>>Degrees &amp; Awards</h6>
        <cfif isSuperAdmin AND NOT showStaffProfile>
            <div class="row mb-3">
                <div class="col-auto">
                    <label class="form-label text-muted">Combined Degrees (auto-generated, read-only)</label>
                    <input class="form-control form-control-sm" id="bio_composite" value="<cfoutput>#EncodeForHTMLAttribute(local.compositeDegreesValue)#</cfoutput>" readonly disabled>
                </div>
            </div>
        </cfif>
        <cfset local.bioDegreesHiddenStyle = (NOT showDegreesAwards ? "style='display:none'" : "")>
        <div id="bioDegreesSection" class="mb-4" <cfoutput>#local.bioDegreesHiddenStyle#</cfoutput>>
            <label class="form-label fw-semibold">Degrees</label>
            <div id="degreesContainer">
                <cfif showDegreesAwards>
                    <cfset local.degreeValues = []>
                    <cfloop from="1" to="#arrayLen(userDegrees)#" index="local.di">
                        <cfset local.dg = userDegrees[local.di]>
                        <cfset local.univVal = trim(local.dg.UNIVERSITY ?: '')>
                        <cfset local.gradYearVal = structKeyExists(local.dg, 'GRADUATIONYEAR') ? local.dg.GRADUATIONYEAR : (structKeyExists(local.dg, 'DEGREEYEAR') ? local.dg.DEGREEYEAR : '')>
                        <cfset local.expGradVal = ''>
                        <cfif structKeyExists(local.dg, 'EXPECTEDGRADYEAR')>
                            <cfset local.expGradRaw = local.dg.EXPECTEDGRADYEAR>
                            <cfif len(trim(local.expGradRaw & '')) AND isNumeric(local.expGradRaw)>
                                <cfset local.expGradVal = toString(val(local.expGradRaw))>
                            </cfif>
                        </cfif>
                        <cfset local.origExpGradVal = ''>
                        <cfif structKeyExists(local.dg, 'ORIGINALEXPECTEDGRADYEAR')>
                            <cfset local.origExpGradRaw = local.dg.ORIGINALEXPECTEDGRADYEAR>
                            <cfif len(trim(local.origExpGradRaw & '')) AND isNumeric(local.origExpGradRaw)>
                                <cfset local.origExpGradVal = toString(val(local.origExpGradRaw))>
                            </cfif>
                        </cfif>
                        <cfset local.programVal = structKeyExists(local.dg, 'PROGRAM') ? (local.dg.PROGRAM ?: '') : ''>
                        <cfset local.idx = local.di - 1>
                        <cfset local.nameEncoded = EncodeForHTMLAttribute(local.dg.DEGREENAME)>
                        <cfset local.univEncoded = EncodeForHTMLAttribute(local.univVal)>
                        <cfset local.gradYearEncoded = EncodeForHTMLAttribute(local.gradYearVal)>
                        <cfset local.expGradEncoded = EncodeForHTMLAttribute(local.expGradVal)>
                        <cfset local.origExpGradEncoded = EncodeForHTMLAttribute(local.origExpGradVal)>
                        <cfset local.programEncoded = EncodeForHTMLAttribute(local.programVal)>
                        <cfset arrayAppend(local.degreeValues, {
                            degreeName = local.dg.DEGREENAME,
                            nameEncoded = local.nameEncoded,
                            university = local.univVal,
                            univEncoded = local.univEncoded,
                            gradYear = local.gradYearVal,
                            gradYearEncoded = local.gradYearEncoded,
                            isUhco = (structKeyExists(local.dg, 'ISUHCO') AND ((isBoolean(local.dg.ISUHCO ?: "") AND local.dg.ISUHCO) OR (val(local.dg.ISUHCO ?: 0) EQ 1))) ? 1 : 0,
                            isEnrolled = (structKeyExists(local.dg, 'ISENROLLED') AND ((isBoolean(local.dg.ISENROLLED ?: "") AND local.dg.ISENROLLED) OR (val(local.dg.ISENROLLED ?: 0) EQ 1))) ? 1 : 0,
                            hasChange = (structKeyExists(local.dg, 'HASYEARCHANGE') AND ((isBoolean(local.dg.HASYEARCHANGE ?: "") AND local.dg.HASYEARCHANGE) OR (val(local.dg.HASYEARCHANGE ?: 0) EQ 1))) ? 1 : 0,
                            expGrad = local.expGradVal,
                            expGradEncoded = local.expGradEncoded,
                            origExpGrad = local.origExpGradVal,
                            origExpGradEncoded = local.origExpGradEncoded,
                            program = local.programVal,
                            programEncoded = local.programEncoded,
                            idx = local.idx
                        })>
                    </cfloop>
                    <cfloop from="1" to="#arrayLen(local.degreeValues)#" index="local.di">
                        <cfset local.dv = local.degreeValues[local.di]>
                        <cfset local.uhcoBadge = (val(local.dv.isUhco ?: 0) EQ 1) ? " <span class='badge bg-primary ms-1'>UHCO</span>" : "">
                        <cfset local.programBadge = len(trim(local.dv.program ?: "")) ? " <span class='badge bg-info text-dark ms-1'>" & EncodeForHTML(local.dv.program) & "</span>" : "">
                        <div class="card mb-2 degree-card card-surface" data-idx="<cfoutput>#local.dv.idx#</cfoutput>">
                            <div class="card-body py-2 px-3">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <strong><cfoutput>#local.dv.nameEncoded#</cfoutput></strong><cfif len(local.dv.university)> | <cfoutput>#local.dv.univEncoded#</cfoutput></cfif><cfif len(local.dv.gradYear)> <span class="badge badge-secondary"><cfoutput>#local.dv.gradYearEncoded#</cfoutput></span></cfif><cfoutput>#local.uhcoBadge##local.programBadge#</cfoutput>
                                    </div>
                                    <div>
                                        <button type="button" class="btn btn-sm btn-ui-edit edit-degree-btn" data-idx="<cfoutput>#local.dv.idx#</cfoutput>"><i class="bi bi-pencil-square me-1"></i>Edit</button>
                                        <button type="button" class="btn btn-sm btn-ui-delete remove-degree-btn" data-idx="<cfoutput>#local.dv.idx#</cfoutput>"><i class="bi bi-trash me-1"></i>Remove</button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </cfloop>
                    <cfloop from="1" to="#arrayLen(local.degreeValues)#" index="local.di">
                        <cfset local.dv = local.degreeValues[local.di]>
                        <input type="hidden" data-degree-field="name" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.nameEncoded#</cfoutput>">
                        <input type="hidden" data-degree-field="university" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.univEncoded#</cfoutput>">
                        <input type="hidden" data-degree-field="year" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.gradYearEncoded#</cfoutput>">
                        <input type="hidden" data-degree-field="isuhco" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.isUhco#</cfoutput>">
                        <input type="hidden" data-degree-field="isenrolled" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.isEnrolled#</cfoutput>">
                        <input type="hidden" data-degree-field="haschange" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.hasChange#</cfoutput>">
                        <input type="hidden" data-degree-field="origexpgrad" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.origExpGradEncoded#</cfoutput>">
                        <input type="hidden" data-degree-field="expgrad" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.expGradEncoded#</cfoutput>">
                        <input type="hidden" data-degree-field="program" data-degree-idx="<cfoutput>#local.dv.idx#</cfoutput>" value="<cfoutput>#local.dv.programEncoded#</cfoutput>">
                    </cfloop>
                </cfif>
            </div>
            <cfset local.degreeCountVal = showDegreesAwards ? arrayLen(userDegrees) : 0>
            <input type="hidden" id="degreeCount" value="<cfoutput>#local.degreeCountVal#</cfoutput>">
        </div>
        <cfset local.bioAwardsHiddenStyle = (NOT showDegreesAwards ? "style='display:none'" : "")>
        <div id="bioAwardsSection" class="mb-4 mt-3" <cfoutput>#local.bioAwardsHiddenStyle#</cfoutput>>
            <label class="form-label fw-semibold">Awards &amp; Honors</label>
            <div id="awardsContainer">
                <cfif showDegreesAwards>
                    <cfset awardOptions = 'Gold Key,Summa cum laude,Magna cum laude,BSK Gold,BSK Black & Gold,AOSA Honors,NOSA Honors,Other'>
                    <cfif arrayLen(spAwards) EQ 0>
                        <p class="text-muted fst-italic">No Awards or Honors</p>
                    </cfif>
                    <cfloop from="1" to="#arrayLen(spAwards)#" index="ai">
                        <cfset aw = spAwards[ai]>
                        <cfset local.awName = trim(aw.AWARDNAME)>
                        <cfset local.awType = aw.AWARDTYPE ?: "">
                        <cfset local.awIdx = ai - 1>
                        <cfset local.awNameEncoded = EncodeForHTML(local.awName)>
                        <cfset local.awTypeEncoded = EncodeForHTML(local.awType)>
                        <div class="card mb-2 award-card card-surface" data-idx="<cfoutput>#local.awIdx#</cfoutput>">
                            <div class="card-body py-2 px-3">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <strong><cfoutput>#local.awNameEncoded#</cfoutput></strong><cfif len(local.awType)> <span class="badge badge-secondary"><cfoutput>#local.awTypeEncoded#</cfoutput></span></cfif>
                                    </div>
                                    <div>
                                        <button type="button" class="btn btn-sm btn-ui-edit edit-award-btn" data-idx="<cfoutput>#local.awIdx#</cfoutput>"><i class="bi bi-pencil-square me-1"></i>Edit</button>
                                        <button type="button" class="btn btn-sm btn-ui-delete remove-award-btn" data-idx="<cfoutput>#local.awIdx#</cfoutput>"><i class="bi bi-trash me-1"></i>Remove</button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </cfloop>
                    <cfloop from="1" to="#arrayLen(spAwards)#" index="ai">
                        <cfset aw = spAwards[ai]>
                        <cfset local.awIdx = ai - 1>
                        <input type="hidden" data-award-field="name" data-award-idx="<cfoutput>#local.awIdx#</cfoutput>" value="<cfoutput>#EncodeForHTMLAttribute(trim(aw.AWARDNAME))#</cfoutput>">
                        <input type="hidden" data-award-field="type" data-award-idx="<cfoutput>#local.awIdx#</cfoutput>" value="<cfoutput>#EncodeForHTMLAttribute(aw.AWARDTYPE ?: "")#</cfoutput>">
                    </cfloop>
                </cfif>
            </div>
            <cfset local.awardCountVal = showDegreesAwards ? arrayLen(spAwards) : 0>
            <input type="hidden" id="awardCount" value="<cfoutput>#local.awardCountVal#</cfoutput>">
        </div>
        <cfif showFacultyProfile>
            <hr>
            <h6 class="fw-bold mb-3">Faculty</h6>
            <input type="hidden" name="processBio" value="1">
            <div class="mb-4">
                <ul class="nav nav-tabs mb-2" id="facultyBioTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="professionalBioTabBtn" data-bs-toggle="tab" data-bs-target="#professionalBioTabPane" type="button" role="tab" aria-controls="professionalBioTabPane" aria-selected="true">Professional Bio</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="clinicalBioTabBtn" data-bs-toggle="tab" data-bs-target="#clinicalBioTabPane" type="button" role="tab" aria-controls="clinicalBioTabPane" aria-selected="false">Clinical Bio</button>
                    </li>
                </ul>
                <div class="tab-content" id="facultyBioTabsContent">
                    <div class="tab-pane fade show active" id="professionalBioTabPane" role="tabpanel" aria-labelledby="professionalBioTabBtn">
                        <div class="users-edit-bio-editor" data-bio-type="ProfessionalBio"><cfoutput>#bioContent#</cfoutput></div>
                        <input type="hidden" name="bioContent" value="<cfoutput>#EncodeForHTMLAttribute(bioContent)#</cfoutput>">
                    </div>
                    <div class="tab-pane fade" id="clinicalBioTabPane" role="tabpanel" aria-labelledby="clinicalBioTabBtn">
                        <div class="users-edit-bio-editor" data-bio-type="ClinicalBio"><cfoutput>#clinicalBioContent#</cfoutput></div>
                        <input type="hidden" name="clinicalBioContent" value="<cfoutput>#EncodeForHTMLAttribute(clinicalBioContent)#</cfoutput>">
                    </div>
                </div>
            </div>
        </cfif>
        <cfif showStaffProfile>
            <hr>
            <h6 class="fw-bold mb-3">Staff</h6>
            <cfif showBio AND NOT showFacultyProfile>
                <input type="hidden" name="processBio" value="1">
                <div class="mb-4">
                    <label class="form-label fw-bold">Bio (Public-Facing)</label>
                    <div class="users-edit-bio-editor"><cfoutput>#bioContent#</cfoutput></div>
                    <input type="hidden" name="bioContent" value="<cfoutput>#EncodeForHTMLAttribute(bioContent)#</cfoutput>">
                </div>
            <cfelseif NOT showBio>
                <p class="text-muted">Bio is available when the <em>public-facing</em> flag is enabled.</p>
            <cfelse>
                <p class="text-muted">Bio is managed in the Faculty section above.</p>
            </cfif>
        </cfif>
        <cfif showCurrentStudent OR showAlumni>
            <hr>
            <h6 class="fw-bold mb-3">Student Data</h6>
            <input type="hidden" name="processAcademicInfo" value="1">
            <input type="hidden" name="processStudentProfile" value="1">
            <!---<cfif isSuperAdmin>
                <div class="row mb-3">
                    <div class="col-md-6">
                        <label class="form-label">Current Grad Year <span class="badge badge-warning">Legacy / Super Admin</span></label>
                        <input class="form-control" name="CurrentGradYear" id="currentGradYear" value="<cfoutput>#currentGradYear#</cfoutput>" placeholder="e.g. 2028">
                        <div class="form-text text-muted">Legacy field. Prefer setting Expected Grad Year on the UHCO degree row above.</div>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">Original Grad Year <span class="badge badge-warning">Legacy / Super Admin</span></label>
                        <cfset local.origGradDisabled = (len(currentGradYear) ? "" : "disabled")>
                        <input class="form-control" name="OriginalGradYear" id="originalGradYear" value="<cfoutput>#originalGradYear#</cfoutput>" placeholder="e.g. 2027" <cfoutput>#local.origGradDisabled#</cfoutput>>
                        <div class="form-text">Requires a Current Grad Year.</div>
                    </div>
                </div>
            <cfelse>
                <input type="hidden" name="CurrentGradYear" value="<cfoutput>#EncodeForHTMLAttribute(currentGradYear)#</cfoutput>">
                <input type="hidden" name="OriginalGradYear" value="<cfoutput>#EncodeForHTMLAttribute(originalGradYear)#</cfoutput>">
            </cfif>--->
            <div class="row mb-3">
                <!---<div class="col-auto"><label class="form-label">Age At Commencement</label>
                    <input class="form-control" type="number" name="sp_commencement_age" min="0" max="120" value="<cfoutput>#EncodeForHTMLAttribute(spCommAge)#</cfoutput>">
                </div>--->
                <div class="col-md-5">
                    <label class="form-label">First Externship</label>
                    <input class="form-control" name="sp_first_externship" value="<cfoutput>#EncodeForHTMLAttribute(spFirstExt)#</cfoutput>">
                </div>
                <div class="col-md-5">
                    <label class="form-label">Second Externship</label>
                    <input class="form-control" name="sp_second_externship" value="<cfoutput>#EncodeForHTMLAttribute(spSecondExt)#</cfoutput>">
                </div>
            </div>
            <div class="row mb-3">
                <div class="col-12">
                    <label class="form-label">Dissertation / Thesis</label>
                    <textarea class="form-control" name="sp_dissertation_thesis" rows="3" placeholder="Enter dissertation or thesis title"><cfoutput>#EncodeForHTML(spDissertation)#</cfoutput></textarea>
                </div>
            </div>

            <label class="form-label fw-semibold">Residencies</label>
            <div id="residenciesContainer" class="mb-3">
            <cfif arrayLen(spResidencies) GT 0>
                <cfloop from="1" to="#arrayLen(spResidencies)#" index="local.ri">
                    <cfset local.rr = spResidencies[local.ri]>
                    <cfset local.resIdx = local.ri - 1>
                    <cfset local.location = trim(local.rr.LOCATION ?: "")>
                    <cfset local.specialty = trim(local.rr.SPECIALTY ?: "")>
                    <cfset local.startingYear = trim((local.rr.STARTINGYEAR ?: "") & "")>
                    <cfset local.isUHCO = (structKeyExists(local.rr, "ISUHCO") AND ((isBoolean(local.rr.ISUHCO ?: "") AND local.rr.ISUHCO) OR (val(local.rr.ISUHCO ?: 0) EQ 1))) ? 1 : 0>
                    <cfset local.isCurrent = (structKeyExists(local.rr, "ISCURRENT") AND ((isBoolean(local.rr.ISCURRENT ?: "") AND local.rr.ISCURRENT) OR (val(local.rr.ISCURRENT ?: 0) EQ 1))) ? 1 : 0>
                    <div class="card mb-2 residency-card card-surface" data-idx="<cfoutput>#local.resIdx#</cfoutput>">
                        <div class="card-body py-2 px-3">
                            <div class="d-flex justify-content-between align-items-center">
                                <div>
                                    <strong><cfoutput>#EncodeForHTML(local.location)#</cfoutput></strong>
                                    <cfif len(local.specialty)><span class="text-muted"> - <cfoutput>#EncodeForHTML(local.specialty)#</cfoutput></span></cfif>
                                    <cfif len(local.startingYear)><span class="badge badge-secondary ms-1"><cfoutput>#EncodeForHTML(local.startingYear)#</cfoutput></span></cfif>
                                    <cfif local.isUHCO EQ 1><span class="badge bg-primary ms-1">UHCO</span></cfif>
                                    <cfif local.isCurrent EQ 1><span class="badge bg-success ms-1">Current</span></cfif>
                                </div>
                                <div>
                                    <button type="button" class="btn btn-sm btn-ui-edit edit-residency-btn" data-idx="<cfoutput>#local.resIdx#</cfoutput>"><i class="bi bi-pencil-square me-1"></i>Edit</button>
                                    <button type="button" class="btn btn-sm btn-ui-delete remove-residency-btn" data-idx="<cfoutput>#local.resIdx#</cfoutput>"><i class="bi bi-trash me-1"></i>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <input type="hidden" data-residency-field="location" data-residency-idx="<cfoutput>#local.resIdx#</cfoutput>" value="<cfoutput>#EncodeForHTMLAttribute(local.location)#</cfoutput>">
                    <input type="hidden" data-residency-field="specialty" data-residency-idx="<cfoutput>#local.resIdx#</cfoutput>" value="<cfoutput>#EncodeForHTMLAttribute(local.specialty)#</cfoutput>">
                    <input type="hidden" data-residency-field="startingyear" data-residency-idx="<cfoutput>#local.resIdx#</cfoutput>" value="<cfoutput>#EncodeForHTMLAttribute(local.startingYear)#</cfoutput>">
                    <input type="hidden" data-residency-field="isuhco" data-residency-idx="<cfoutput>#local.resIdx#</cfoutput>" value="<cfoutput>#local.isUHCO#</cfoutput>">
                    <input type="hidden" data-residency-field="iscurrent" data-residency-idx="<cfoutput>#local.resIdx#</cfoutput>" value="<cfoutput>#local.isCurrent#</cfoutput>">
                </cfloop>
            <cfelse>
                <p class="text-muted fst-italic">No Residencies Entered</p>
            </cfif>
            </div>
        </cfif>
</cfsavecontent>
<cfset content &= local.bioTabContent>

<!--- ── Alumni Data section ── 
<cfif showAlumni>
    <cfset content &= "
            <hr>
            <h6 class='fw-bold mb-3'>Alumni Data</h6>
            <p class='text-muted'>Academic data is shared with the Student Data section above.</p>
    ">
</cfif>--->

<!--- ── Emeritus section (bio if no faculty) ── --->
<cfif showEmeritusProfile>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Professor Emeritus</h6>">
    <cfif NOT showFacultyProfile>
        <cfset content &= "
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio / About Me</label>
                <div class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
        ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>Bio is managed in the Faculty section above.</p>">
    </cfif>
</cfif>

<!--- ── Resident section (bio if no faculty/emeritus) ── --->
<cfif showResidentProfile>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Resident</h6>">
    <cfif NOT showFacultyProfile AND NOT showEmeritusProfile>
        <cfset content &= "
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio / About Me</label>
                <div class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
        ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>Bio is managed in the " & (showFacultyProfile ? "Faculty" : "Emeritus") & " section above.</p>">
    </cfif>
</cfif>

<cfset content &= "
    </div>
">

<cfset content &= "
    </div>

</form>

<div class='modal fade' id='orgRoleModal' tabindex='-1' aria-labelledby='orgRoleModalLabel' aria-hidden='true'>
    <div class='modal-dialog modal-sm'>
        <div class='modal-content'>
            <div class='modal-header py-2'>
                <h6 class='modal-title fw-semibold mb-0' id='orgRoleModalLabel'>
                    <i class='bi bi-pencil-square me-1 text-primary'></i>
                    <span id='orgRoleModalOrgName'></span>
                </h6>
                <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body'>
                <div class='mb-3'>
                    <label class='form-label fw-semibold' for='modalRoleTitle'>Role Title</label>
                    <input type='text' class='form-control' id='modalRoleTitle' placeholder='e.g. Program Director'>
                    <div class='form-text'>Optional. Describe this person's role within the organization.</div>
                </div>
                <div class='mb-1'>
                    <label class='form-label fw-semibold' for='modalRoleOrder'>Display Order</label>
                    <input type='number' class='form-control' id='modalRoleOrder' placeholder='e.g. 1' min='0'>
                    <div class='form-text'>Optional. Lower numbers appear first in listings.</div>
                </div>
            </div>
            <div class='modal-footer py-2'>
                <button type='button' class='btn btn-sm btn-ui-cancel' data-bs-dismiss='modal'>Cancel</button>
                <button type='button' class='btn btn-sm btn-ui-save' id='save-orgRoleModal-btn'>Save Role</button>
            </div>
        </div>
    </div>
</div>

"  />

<!--- ── Data Quality Exclusions panel ── --->
<cfsavecontent variable="local.dqPanel">
<cfoutput>
<div class='card mt-4 border-warning d-none' id='dataQualityPanel'>
    <div class='card-header bg-warning bg-opacity-10 d-flex align-items-center justify-content-between'>
        <strong><i class='bi bi-funnel'></i> Data Quality Report Exclusions</strong>
        <span class='text-muted small'>Checked = included in report &nbsp;|&nbsp; Unchecked = excluded</span>
    </div>
    <div class='card-body'>
        <p class='text-muted small mb-3'>Uncheck any item to exclude this user from that specific data quality check.</p>
        <form method='POST' action='/admin/users/saveDQExclusions.cfm'>
            <input type='hidden' name='UserID'   value='#user.USERID#'>
            <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(returnTo)#'>
            <div class='row g-2'>
</cfoutput>
<cfloop array="#dqAllCodes#" item="dqItem">
    <cfset isExcluded = structKeyExists(dqExclusionMap, dqItem.code)>
    <cfoutput>
    <div class='col-sm-6 col-md-4'>
        <div class='form-check'>
            <input class='form-check-input' type='checkbox'
                   name='dqInclude' value='#dqItem.code#'
                   id='dq_#dqItem.code#'
                   #isExcluded ? '' : 'checked'#>
            <label class='form-check-label small' for='dq_#dqItem.code#'>
                #dqItem.label#
            </label>
        </div>
    </div>
    </cfoutput>
</cfloop>
<cfoutput>
            </div>
            <div class='mt-3'>
                <button type='submit' class='btn btn-save-exclusions btn-sm'>
                    <i class='bi bi-save me-1'></i>Save Exclusions
                </button>
            </div>
        </form>
    </div>
</div>
</cfoutput>
</cfsavecontent>
<cfset content &= local.dqPanel>
<cfset content &= "</div></div>">

<cfset ViewContent = "">
<cfset ViewContent &= "
<h1>#EncodeForHTML(resolvedFirstName)# #EncodeForHTML(resolvedLastName)#</h1>

">

<!--- ── Quill.js WYSIWYG for bio editors ── --->
<cfsavecontent variable="pageScripts">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/quill@2/dist/quill.snow.css">
<script src="https://cdn.jsdelivr.net/npm/quill@2/dist/quill.js"></script>

<!--- ── Email Modal ── --->
<div class="modal fade" id="emailModal" tabindex="-1" aria-labelledby="emailModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="emailModalLabel">Add Email</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="emailEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Email Address</label>
                    <input class="form-control" type="email" id="emailAddr">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="emailType">
                        <option value="">-- Type --</option>
                        <option value="@Central">@Central</option>
                        <option value="@CougarNet">@CougarNet</option>
                        <option value="Personal">Personal</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="emailPrimaryChk">
                    <label class="form-check-label">Primary</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveEmailModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Phone Modal ── --->
<div class="modal fade" id="phoneModal" tabindex="-1" aria-labelledby="phoneModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="phoneModalLabel">Add Phone</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="phoneEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Country</label>
                    <select class="form-select" id="phoneCountry"></select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Phone Number</label>
                    <input class="form-control" type="text" id="phoneNumber" inputmode="tel" autocomplete="off">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="phoneType">
                        <option value="">-- Type --</option>
                        <option value="Business">Business</option>
                        <option value="Personal">Personal</option>
                    </select>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="phonePrimaryChk">
                    <label class="form-check-label">Primary</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="savePhoneModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Alias Modal ── --->
<div class="modal fade" id="aliasModal" tabindex="-1" aria-labelledby="aliasModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="aliasModalLabel">Add Alias</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="aliasEditIdx" value="-1">
                <div class="row mb-3">
                    <div class="col-md-4">
                        <label class="form-label">First Name</label>
                        <input class="form-control" id="aliasFirst">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Middle Name</label>
                        <input class="form-control" id="aliasMiddle">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Last Name</label>
                        <input class="form-control" id="aliasLast">
                    </div>
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="aliasType"></select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Source System</label>
                    <input class="form-control" id="aliasSource">
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="aliasActive" checked>
                    <label class="form-check-label">Active</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveAliasModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Appointment Modal ── --->
<div class="modal fade" id="appointmentModal" tabindex="-1" aria-labelledby="appointmentModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="appointmentModalLabel">Add Appointment</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="appointmentEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Appointment Name</label>
                    <input class="form-control" id="appointmentName">
                </div>
                <div class="mb-3">
                    <label class="form-label">Appointment Type</label>
                    <input class="form-control" id="appointmentType">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveAppointmentModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Degree Modal ── --->
<div class="modal fade" id="degreeModal" tabindex="-1" aria-labelledby="degreeModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="degreeModalLabel">Add Degree</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="degreeEditIdx" value="-1">
                <div class="row g-3">
                    <div class="col-md-6">
                        <label class="form-label">Degree Name</label>
                        <input class="form-control" id="degreeName">
                    </div>
                    <div class="col-md-6">
                        <label class="form-label">University</label>
                        <input class="form-control" id="degreeUniversity">
                    </div>
                </div>
                <div class="row g-3 mt-1">
                    <div class="col-md-4">
                        <label class="form-label">Graduation Year</label>
                        <input class="form-control" id="degreeYear" inputmode="numeric">
                    </div>
                    <div class="col-md-8">
                        <label class="form-label">Program</label>
                        <select class="form-select" id="degreeProgram">
                            <option value="">-- None --</option>
                            <option value="OD">OD</option>
                            <option value="MS">MS</option>
                            <option value="PhD">PhD</option>
                            <option value="Residency">Residency</option>
                        </select>
                    </div>
                </div>

                <hr>

                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="degreeIsUHCO">
                    <label class="form-check-label" for="degreeIsUHCO">UHCO Degree</label>
                </div>

                <div id="degreeUhcoFields" class="border rounded p-3 bg-light d-none">
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="checkbox" id="degreeIsEnrolled">
                        <label class="form-check-label" for="degreeIsEnrolled">Currently Enrolled</label>
                    </div>
                    <div class="form-check mb-3">
                        <input class="form-check-input" type="checkbox" id="degreeHasYearChange">
                        <label class="form-check-label" for="degreeHasYearChange">Expected Grad Year Changed</label>
                    </div>
                    <div class="row g-3">
                        <div class="col-md-6">
                            <label class="form-label">Expected Grad Year</label>
                            <input class="form-control" id="degreeExpectedGradYear" inputmode="numeric">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label">Original Expected Grad Year</label>
                            <input class="form-control" id="degreeOriginalExpectedGradYear" inputmode="numeric">
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveDegreeModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Award Modal ── --->
<div class="modal fade" id="awardModal" tabindex="-1" aria-labelledby="awardModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="awardModalLabel">Add Award</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="awardEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Award</label>
                    <select class="form-select" id="awardSelect">
                        <option value="">-- Select --</option>
                        <option value="Gold Key">Gold Key</option>
                        <option value="Summa Cum Laude">Summa Cum Laude</option>
                        <option value="Magna Cum Laude">Magna Cum Laude</option>
                        <option value="BSK Gold">BSK Gold</option>
                        <option value="BSK Black &amp; Gold">BSK Black &amp; Gold</option>
                        <option value="AOSA Honors">AOSA Honors</option>
                        <option value="NOSA Honors">NOSA Honors</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="mb-3 d-none" id="awardOtherWrap">
                    <label class="form-label">Specify Award</label>
                    <input class="form-control" id="awardOtherInput">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="awardType">
                        <option value="">-- Type --</option>
                        <option value="Honor">Honor</option>
                        <option value="Award">Award</option>
                    </select>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveAwardModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Residency Modal ── --->
<div class="modal fade" id="residencyModal" tabindex="-1" aria-labelledby="residencyModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="residencyModalLabel">Add Residency</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="residencyEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Location</label>
                    <input class="form-control" id="residencyLocation" placeholder="University of Houston College of Optometry">
                </div>
                <div class="mb-3">
                    <label class="form-label">Specialty</label>
                    <input class="form-control" id="residencySpecialty" placeholder="Pediatric Optometry">
                </div>
                <div class="mb-3">
                    <label class="form-label">Starting Year</label>
                    <input class="form-control" id="residencyStartingYear" inputmode="numeric" placeholder="2026">
                </div>
                <div class="form-check mb-2">
                    <input class="form-check-input" type="checkbox" id="residencyIsUHCO">
                    <label class="form-check-label" for="residencyIsUHCO">UHCO Residency</label>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="residencyIsCurrent">
                    <label class="form-check-label" for="residencyIsCurrent">Current Residency</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveResidencyModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Address Modal ── --->
<div class="modal fade" id="addressModal" tabindex="-1" aria-labelledby="addressModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="addressModalLabel">Add Address</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="addrEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Address Type</label>
                    <select class="form-select" id="addrType">
                        <option value="">-- Select --</option>
                        <option value="Office">Office</option>
                        <option value="Home">Home</option>
                        <option value="Hometown">Hometown</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Address Line 1</label>
                    <input class="form-control" id="addrAddr1">
                </div>
                <div class="mb-3">
                    <label class="form-label">Address Line 2</label>
                    <input class="form-control" id="addrAddr2">
                </div>
                <div class="row mb-3">
                    <div class="col-md-5">
                        <label class="form-label">City</label>
                        <input class="form-control" id="addrCity">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">State</label>
                        <input class="form-control" id="addrState">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Zipcode</label>
                        <input class="form-control" id="addrZip">
                    </div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4">
                        <label class="form-label">Building</label>
                        <input class="form-control" id="addrBuilding">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Room</label>
                        <input class="form-control" id="addrRoom">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Mail Code</label>
                        <input class="form-control" id="addrMailcode">
                    </div>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="addrPrimary">
                    <label class="form-check-label">Primary Address</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-ui-save" id="saveAddressBtn">Save Address</button>
                <button type="button" class="btn btn-ui-save d-none" id="saveAddressToDbBtn">Save to Database</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Dropbox Confirm Modal ── --->
<div class="modal fade" id="dropboxConfirmModal" tabindex="-1" aria-labelledby="dropboxConfirmModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header py-2">
                <h6 class="modal-title fw-semibold mb-0" id="dropboxConfirmModalLabel">Confirm</h6>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <p id="dropboxConfirmModalBody" class="mb-0 small"></p>
            </div>
            <div class="modal-footer py-2">
                <button type="button" class="btn btn-sm btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-sm btn-ui-save" id="dropboxConfirmModalBtn">Confirm</button>
            </div>
        </div>
    </div>
</div>

<!--- ── LDAP Lookup Modal ── --->
<div class="modal fade" id="extidsLdapModal" tabindex="-1" aria-labelledby="extidsLdapModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg modal-dialog-scrollable">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="extidsLdapModalLabel">LDAP Lookup Results</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div id="extids-ldap-status" class="small text-muted mb-3"></div>
                <div class="table-responsive">
                    <table class="table table-sm align-middle">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>CougarNet</th>
                                <th>Employee ID</th>
                                <th>Email</th>
                                <th class="text-end">Action</th>
                            </tr>
                        </thead>
                        <tbody id="extidsLdapResultsBody">
                            <tr>
                                <td colspan="5" class="text-muted">Run a lookup to see LDAP matches.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Close</button>
            </div>
        </div>
    </div>
</div>

<cfoutput>
<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
var aliasTypeOptions = [#aliasTypeOptsJS#];
var aliasTypeLabels  = [#aliasTypeLblsJS#];
</script>
</cfoutput>
<script src="/assets/vendor/libphonenumber-js/libphonenumber-min.js"></script>
<script src="/assets/js/shared/phone-country-select.js"></script>
<script src="/assets/js/admin/users-edit.js"></script>
<cfif len(uhSyncFlashMessage)>
<cfoutput>
<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
(function () {
    if (!window.AdminUI || typeof window.AdminUI.showToast !== 'function') { return; }
    window.AdminUI.showToast("#encodeForJavaScript(uhSyncFlashMessage)#", {
        tone: #uhSyncFlashIsError ? '"danger"' : '"success"'#
    });
})();
</script>
</cfoutput>
</cfif>
</cfsavecontent>

<!--- ── Save toast ── --->
<div class="position-fixed bottom-0 end-0 p-3" style="z-index:1100">
    <div id="saveToast" class="toast align-items-center border-0" role="alert" aria-live="assertive" aria-atomic="true">
        <div class="d-flex">
            <div class="toast-body fw-semibold" id="saveToastBody"></div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
    </div>
</div>

<cfinclude template="/admin/layout.cfm">