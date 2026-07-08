<!--- ============================================================
    Unified User List Page
    URL parameter: ?list=problems|all|alumni|current-students|faculty|staff|inactive
    ============================================================ --->
<cfif NOT request.hasPermission("users.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="url.list" default="all">
<cfset listType = lcase(trim(url.list))>
<cfif NOT listFindNoCase("problems,all,alumni,current-students,faculty,staff,inactive", listType)>
    <cfset listType = "problems">
</cfif>

<cfset canViewAlumni = application.authService.hasRole("ALUMNI_ADMIN")>
<cfset canManageFacultyAlumni = application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])>
<cfif listType EQ "alumni" AND NOT canViewAlumni>
    <cflocation url="#request.webRoot#/admin/users/" addtoken="false">
    <cfabort>
</cfif>

<!--- Feature flags based on list type --->
<cfset needsAcademic      = listFindNoCase("all,alumni,current-students", listType) GT 0>
<cfset needsImages        = listFindNoCase("current-students,faculty,staff,alumni,all", listType) GT 0>
<cfset showPhoto          = needsImages>
<cfset showGradYear       = needsAcademic>
<cfset showOrgFilter      = listFindNoCase("problems,all,staff,inactive,faculty", listType) GT 0>
<cfset showGradFilter     = needsAcademic>
<cfset showDeceased       = (listType EQ "alumni")>
<cfset showManageImages   = needsImages>
<cfset showTitle          = (listType EQ "current-students")>
<cfset highlightFlags     = listFindNoCase("problems,all,inactive", listType) GT 0>

<!--- Page title and empty-state message --->
<cfswitch expression="#listType#">
    <cfcase value="problems"><cfset pageTitle = "Problem Records"><cfset noDataMsg = "No records found."></cfcase>
    <cfcase value="all"><cfset pageTitle = "All Records"><cfset noDataMsg = "No records found."></cfcase>
    <cfcase value="alumni"><cfset pageTitle = "Alumni"><cfset noDataMsg = "No alumni found."></cfcase>
    <cfcase value="current-students"><cfset pageTitle = "Current Students"><cfset noDataMsg = "No students found."></cfcase>
    <cfcase value="faculty"><cfset pageTitle = "Faculty"><cfset noDataMsg = "No faculty found."></cfcase>
    <cfcase value="staff"><cfset pageTitle = "Staff"><cfset noDataMsg = "No staff found."></cfcase>
    <cfcase value="inactive"><cfset pageTitle = "Inactive Users"><cfset noDataMsg = "No records found."></cfcase>
</cfswitch>

<!--- Initialize common services --->
<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService     = createObject("component", "cfc.flags_service").init()>
<cfset orgsService      = createObject("component", "cfc.organizations_service").init()>
<cfset usersService     = createObject("component", "cfc.users_service").init()>
<cfset duplicateSvc     = createObject("component", "cfc.duplicateUsers_service").init()>
<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset helpers          = createObject("component", "cfc.helpers")>
<cfif needsAcademic>
    <cfset academicService = createObject("component", "cfc.academic_service").init()>
</cfif>
<cfif needsImages>
    <cfset imagesService = createObject("component", "cfc.images_service").init()>
</cfif>

<cfset pageMessage = "">
<cfset pageMessageClass = "alert-info">
<cfset canViewTestUsers = application.authService.hasRole("SUPER_ADMIN") OR request.hasPermission("users.test_users.manage")>
<cfset inactiveMergedAccounts = []>
<cfset currentAdminUser = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {}>
<cfset currentUserDisplayName = encodeForHTML(trim(currentAdminUser.displayName ?: "Admin User"))>
<cfset currentUserEmail = encodeForHTML(trim(currentAdminUser.email ?: ""))>
<cfset currentUserUsername = encodeForHTML(trim(currentAdminUser.username ?: ""))>
<cfset currentUserRoleLabel = "">
<cfset currentUserImageSrc = "">
<cfset impersonationState = {}>
<cfset currentRequestUrl = cgi.script_name & (len(trim(cgi.query_string ?: "")) ? "?" & cgi.query_string : "")>

<cfif structKeyExists(currentAdminUser, "roles") AND isArray(currentAdminUser.roles) AND arrayLen(currentAdminUser.roles)>
    <cfset currentUserRoleLabel = encodeForHTML(replace(currentAdminUser.roles[1], "_", " ", "all"))>
</cfif>

<cfif cgi.request_method EQ "POST" AND trim(form.action ?: "") EQ "deleteInactiveMergedUser">
    <cfif canViewTestUsers AND request.hasPermission("users.delete") AND isNumeric(form.userID ?: "") AND request.canAccessUserByID(val(form.userID))>
        <cfset deleteResult = usersService.deleteUser(
            userID = val(form.userID),
            forceDeleteRelatedDuplicatePairs = true
        )>
        <cfset pageMessage = deleteResult.message ?: "Inactive merged account deletion complete.">
        <cfset pageMessageClass = deleteResult.success ? "alert-success" : "alert-danger">
    <cfelse>
        <cfset pageMessage = "You do not have permission to delete inactive merged accounts.">
        <cfset pageMessageClass = "alert-danger">
    </cfif>
</cfif>

<!--- Load all users --->
<cftry>
    <cfset allUsers = directoryService.listUsersForAdminIndex()>
    <cfcatch type="any">
        <cfset allUsers = []>
        <cfset pageMessage = "Unable to load users: #cfcatch.detail ?: cfcatch.message#">
        <cfset pageMessageClass = "alert-danger">
    </cfcatch>
</cftry>

<!--- Load lookup maps --->
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags       = allFlagsResult.data>
<cfset allUserFlagMap = flagsService.getAllUserFlagMap()>
<cfset allUserOrgMap  = orgsService.getAllUserOrgMap()>
<cfset showTestUsersForAdmin = request.canManageTestUsers()>
<cfset hideTestUsersForAdmin = request.shouldExcludeTestUsers()>
<cfset testUserFlagID = "">
<cfset testUserFlagName = "TEST_USER">
<cfloop from="1" to="#arrayLen(allFlags)#" index="iFlag">
    <cfif compareNoCase(trim(allFlags[iFlag].FLAGNAME ?: ""), "TEST_USER") EQ 0>
        <cfset testUserFlagID = toString(allFlags[iFlag].FLAGID)>
        <cfset testUserFlagName = trim(allFlags[iFlag].FLAGNAME ?: "TEST_USER")>
        <cfbreak>
    </cfif>
</cfloop>
<cfif needsImages>
    <cfset webThumbMap = imagesService.getWebThumbMap()>
</cfif>
<cfset emailsService  = createObject("component", "cfc.emails_service").init()>
<cfset allUserEmailMap = emailsService.getAllEmailsMap()>
<cfset phoneService    = createObject("component", "cfc.phone_service").init()>
<cfset extIDService    = createObject("component", "cfc.externalID_service").init()>
<cfset allUserPhoneMap = phoneService.getAllUserPhonesMap()>
<cfset allUserExtIDMap = extIDService.getAllUserExternalIDsMap()>

<cfif canViewTestUsers>
    <cfset inactiveMergedAccounts = duplicateSvc.getInactiveMergedAccounts(75)>
</cfif>

<cfset visibleUserResult = application.adminAuthorizationPolicyService.filterAccessibleUsers(allUsers, allUserFlagMap, allUserOrgMap)>
<cfset allUsers = visibleUserResult.users>
<cfset hasVisibleTestUsers = visibleUserResult.hasVisibleTestUsers>
<cfif hasVisibleTestUsers>
    <cfset showTestUsersForAdmin = true>
</cfif>

<cfif NOT canViewAlumni>
    <cfset _nonAlumniUsers = []>
    <cfloop from="1" to="#arrayLen(allUsers)#" index="_i">
        <cfset _uFlags = structKeyExists(allUserFlagMap, toString(allUsers[_i].USERID)) ? allUserFlagMap[toString(allUsers[_i].USERID)] : []>
        <cfset _isAlumni = false>
        <cfset _isFaculty = false>
        <cfloop from="1" to="#arrayLen(_uFlags)#" index="_f">
            <cfif _uFlags[_f].FLAGNAME EQ "Alumni">
                <cfset _isAlumni = true>
            </cfif>
            <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", _uFlags[_f].FLAGNAME)>
                <cfset _isFaculty = true>
            </cfif>
        </cfloop>
        <cfif NOT _isAlumni OR (_isFaculty AND canManageFacultyAlumni)>
            <cfset arrayAppend(_nonAlumniUsers, allUsers[_i])>
        </cfif>
    </cfloop>
    <cfset allUsers = _nonAlumniUsers>
</cfif>
<cfif needsAcademic>
    <cfset visibleAcademicUserIDs = []>
    <cfloop from="1" to="#arrayLen(allUsers)#" index="visibleAcademicIndex">
        <cfif isNumeric(allUsers[visibleAcademicIndex].USERID ?: "")>
            <cfset arrayAppend(visibleAcademicUserIDs, val(allUsers[visibleAcademicIndex].USERID))>
        </cfif>
    </cfloop>
    <cfset academicMaps = academicService.getAllAcademicMaps(visibleAcademicUserIDs, false)>
    <cfset allAcademicMap = academicMaps.academicInfoMap>
    <cfset allGradYearMap = academicMaps.gradYearMap>
</cfif>

<cfif structKeyExists(currentAdminUser, "adminUserID") AND val(currentAdminUser.adminUserID) GT 0 AND structKeyExists(variables, "webThumbMap") AND isStruct(webThumbMap)>
    <cfset currentUserImageSrc = trim(webThumbMap[toString(val(currentAdminUser.adminUserID))] ?: "")>
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

<!--- Load top-level orgs for filter dropdown --->
<cfif showOrgFilter>
    <cfset allOrgsResult = orgsService.getAllOrgs()>
    <cfset allOrgs = allOrgsResult.data>
    <cfset orgChildrenByParent = {}>
    <cfset orgIDs = {}>
    <cfset rootOrgs = []>
    <cfset filterableOrgLookup = {}>
    <cfloop from="1" to="#arrayLen(allOrgs)#" index="iOrg">
        <cfset orgItem = allOrgs[iOrg]>
        <cfset orgIDs[toString(orgItem.ORGID)] = true>
    </cfloop>
    <cfloop from="1" to="#arrayLen(allOrgs)#" index="iOrg">
        <cfset orgItem = allOrgs[iOrg]>
        <cfset parentValue = trim((orgItem.PARENTORGID ?: "") & "")>
        <cfset parentKey = "ROOT">
        <cfif len(parentValue) AND structKeyExists(orgIDs, parentValue)>
            <cfset parentKey = parentValue>
        </cfif>
        <cfif NOT structKeyExists(orgChildrenByParent, parentKey)>
            <cfset orgChildrenByParent[parentKey] = []>
        </cfif>
        <cfset arrayAppend(orgChildrenByParent[parentKey], orgItem)>
    </cfloop>
    <cfset rootOrgs = structKeyExists(orgChildrenByParent, "ROOT") ? orgChildrenByParent["ROOT"] : []>
    <cfloop from="1" to="#arrayLen(rootOrgs)#" index="iRoot">
        <cfset rootOrg = rootOrgs[iRoot]>
        <cfset childKey = toString(rootOrg.ORGID)>
        <cfset childOrgs = structKeyExists(orgChildrenByParent, childKey) ? orgChildrenByParent[childKey] : []>
        <cfloop from="1" to="#arrayLen(childOrgs)#" index="iChild">
            <cfset childOrg = childOrgs[iChild]>
            <cfset filterableOrgLookup[toString(childOrg.ORGID)] = childOrg.ORGNAME>
            <cfset grandChildKey = toString(childOrg.ORGID)>
            <cfset grandChildOrgs = structKeyExists(orgChildrenByParent, grandChildKey) ? orgChildrenByParent[grandChildKey] : []>
            <cfloop from="1" to="#arrayLen(grandChildOrgs)#" index="iGrandChild">
                <cfset grandChildOrg = grandChildOrgs[iGrandChild]>
                <cfset filterableOrgLookup[toString(grandChildOrg.ORGID)] = grandChildOrg.ORGNAME>
            </cfloop>
        </cfloop>
    </cfloop>
</cfif>

<!--- Parse URL filters --->
<cfset selectedFlagFilter = structKeyExists(url, "filterFlag")     ? trim(url.filterFlag)     : "">
<cfset searchTerm         = structKeyExists(url, "search")         ? trim(url.search)         : "">
<cfset selectedOrgFilter  = structKeyExists(url, "filterOrg")      ? trim(url.filterOrg)      : "">
<cfset selectedGradYear   = structKeyExists(url, "filterGradYear") ? trim(url.filterGradYear) : "">
<cfset selectedLetter     = structKeyExists(url, "letter") AND len(trim(url.letter)) ? ucase(left(trim(url.letter), 1)) : "">
<cfset selectedOrgFilterIDs = []>
<cfset selectedOrgFilterLookup = {}>
<cfset includeNoOrgFilter = false>
<cfif showOrgFilter AND len(selectedOrgFilter)>
    <cfloop list="#selectedOrgFilter#" delimiters="," index="selectedOrgItemRaw">
        <cfset selectedOrgItem = trim(selectedOrgItemRaw)>
        <cfif len(selectedOrgItem)>
            <cfif ucase(selectedOrgItem) EQ "NOORGS">
                <cfset includeNoOrgFilter = true>
            <cfelseif structKeyExists(filterableOrgLookup, toString(val(selectedOrgItem)))>
                <cfset selectedOrgKey = toString(val(selectedOrgItem))>
                <cfif NOT structKeyExists(selectedOrgFilterLookup, selectedOrgKey)>
                    <cfset selectedOrgFilterLookup[selectedOrgKey] = true>
                    <cfset arrayAppend(selectedOrgFilterIDs, selectedOrgKey)>
                </cfif>
            </cfif>
        </cfif>
    </cfloop>
</cfif>
<cfset selectedOrgFilter = arrayToList(selectedOrgFilterIDs)>
<cfif includeNoOrgFilter>
    <cfset selectedOrgFilter = len(selectedOrgFilter) ? "NOORGS," & selectedOrgFilter : "NOORGS">
</cfif>
<cfset selectedOrgFilterCount = arrayLen(selectedOrgFilterIDs) + (includeNoOrgFilter ? 1 : 0)>
<cfset orgFilterHasSelection = selectedOrgFilterCount GT 0>
<cfif hideTestUsersForAdmin AND len(testUserFlagID) AND selectedFlagFilter EQ testUserFlagID>
    <cfset selectedFlagFilter = "">
</cfif>
<cfset requestedFilterPanel = structKeyExists(url, "filterPanel") ? lcase(trim(url.filterPanel)) : "">
<cfset activeFilterPanel = "">
<cfif requestedFilterPanel EQ "flags">
    <cfset activeFilterPanel = "flags">
<cfelseif requestedFilterPanel EQ "grad" AND showGradFilter>
    <cfset activeFilterPanel = "grad">
<cfelseif requestedFilterPanel EQ "orgs" AND showOrgFilter>
    <cfset activeFilterPanel = "orgs">
<cfelseif len(selectedFlagFilter)>
    <cfset activeFilterPanel = "flags">
<cfelseif showGradFilter AND len(selectedGradYear)>
    <cfset activeFilterPanel = "grad">
<cfelseif showOrgFilter AND orgFilterHasSelection>
    <cfset activeFilterPanel = "orgs">
</cfif>
<cfset flagFilterCount = len(selectedFlagFilter) ? 1 : 0>
<cfset gradFilterCount = (showGradFilter AND len(selectedGradYear)) ? 1 : 0>
<cfset currentListUrl = cgi.script_name & (len(trim(cgi.query_string ?: "")) ? "?" & trim(cgi.query_string) : "?list=" & urlEncodedFormat(listType))>
<cfparam name="pageMessage" default="">
<cfparam name="pageMessageClass" default="alert-info">

<!--- ======================== PRE-FILTER ======================== --->
<cfset filteredUsers = []>
<cfswitch expression="#listType#">

    <cfcase value="problems">
        <cfset includeByFlagNames = "Admin-Check,No-UH-API">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfset u = allUsers[i]>
            <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfif arrayLen(uFlags) EQ 0>
                <cfset arrayAppend(filteredUsers, u)>
            <cfelse>
                <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
                    <cfif listFindNoCase(includeByFlagNames, uFlags[f].FLAGNAME)>
                        <cfset arrayAppend(filteredUsers, u)>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>
        </cfloop>
    </cfcase>

    <cfcase value="all">
        <cfset filteredUsers = allUsers>
    </cfcase>

    <cfcase value="alumni">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfset u = allUsers[i]>
            <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
                <cfif uFlags[f].FLAGNAME EQ "Alumni">
                    <cfset arrayAppend(filteredUsers, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfloop>
    </cfcase>

    <cfcase value="current-students">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfset u = allUsers[i]>
            <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
                <cfif uFlags[f].FLAGNAME EQ "Current-Student">
                    <cfset arrayAppend(filteredUsers, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfloop>
    </cfcase>

    <cfcase value="faculty">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfset u = allUsers[i]>
            <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
                <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct,Professor-Emeritus", uFlags[f].FLAGNAME)>
                    <cfset arrayAppend(filteredUsers, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfloop>
    </cfcase>

    <cfcase value="staff">
        <cfset includeByFlagNames = "Staff,Temporary-Staff">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfset u = allUsers[i]>
            <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfif arrayLen(uFlags) EQ 0>
                <cfset arrayAppend(filteredUsers, u)>
            <cfelse>
                <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
                    <cfif listFindNoCase(includeByFlagNames, uFlags[f].FLAGNAME)>
                        <cfset arrayAppend(filteredUsers, u)>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>
        </cfloop>
    </cfcase>

    <cfcase value="inactive">
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfif val(allUsers[i].ACTIVE) EQ 0>
                <cfset arrayAppend(filteredUsers, allUsers[i])>
            </cfif>
        </cfloop>
    </cfcase>

</cfswitch>

<!--- Merge academic data if needed --->
<cfif needsAcademic>
    <cfset mergedUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset row = duplicate(filteredUsers[i])>
        <cfset acadData = structKeyExists(allAcademicMap, toString(row.USERID)) ? allAcademicMap[toString(row.USERID)] : {}>
        <cfset gradYearData = structKeyExists(allGradYearMap, toString(row.USERID)) ? allGradYearMap[toString(row.USERID)] : { YEARS = [] }>
        <cfset row.CURRENTGRADYEAR  = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "CURRENTGRADYEAR"))  ? acadData.CURRENTGRADYEAR  : "">
        <cfset row.ORIGINALGRADYEAR = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "ORIGINALGRADYEAR")) ? acadData.ORIGINALGRADYEAR : "">
        <cfset row.GRADYEARS = gradYearData.YEARS>
        <cfset row.GRADYEARPROGRAMMAP = {}>
        <cfset row.GRADYEARDISPLAY = "">

        <cfif structKeyExists(acadData, "EFFECTIVEGRADYEAR") AND isNumeric(acadData.EFFECTIVEGRADYEAR) AND val(acadData.EFFECTIVEGRADYEAR) GT 0>
            <cfset row.CURRENTGRADYEAR = val(acadData.EFFECTIVEGRADYEAR)>
        <cfelseif arrayLen(row.GRADYEARS)>
            <cfset row.CURRENTGRADYEAR = row.GRADYEARS[arrayLen(row.GRADYEARS)]>
        </cfif>

        <cfset arrayAppend(mergedUsers, row)>
    </cfloop>
    <cfset filteredUsers = mergedUsers>

    <!--- Build grad year dropdown options from pre-filtered rows --->
    <cfset allGradYears = []>
    <cfset gradYearSeen = {}>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset userGradYears = structKeyExists(filteredUsers[i], "GRADYEARS") AND isArray(filteredUsers[i].GRADYEARS) ? filteredUsers[i].GRADYEARS : []>
        <cfloop from="1" to="#arrayLen(userGradYears)#" index="gyIdx">
            <cfset gy = userGradYears[gyIdx]>
            <cfif isNumeric(gy) AND val(gy) GT 0 AND NOT structKeyExists(gradYearSeen, toString(val(gy)))>
                <cfset gradYearSeen[toString(val(gy))] = true>
                <cfset arrayAppend(allGradYears, val(gy))>
            </cfif>
        </cfloop>
    </cfloop>
    <cfset arraySort(allGradYears, "numeric", "desc")>
</cfif>

<!--- ======================== APPLY FILTERS ======================== --->

<!--- Flag filter --->
<cfif selectedFlagFilter NEQ "">
    <cfset flagFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset u = filteredUsers[i]>
        <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
        <cfif selectedFlagFilter EQ "NOFLAGS">
            <cfif arrayLen(userFlags) EQ 0>
                <cfset arrayAppend(flagFiltered, u)>
            </cfif>
        <cfelse>
            <cfset selectedFlagID = val(selectedFlagFilter)>
            <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
                <cfif userFlags[f].FLAGID EQ selectedFlagID>
                    <cfset arrayAppend(flagFiltered, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
    <cfset filteredUsers = flagFiltered>
</cfif>

<!--- Grad year filter --->
<cfif showGradFilter AND selectedGradYear NEQ "" AND isNumeric(selectedGradYear)>
    <cfset gradYearFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset userGradYears = structKeyExists(filteredUsers[i], "GRADYEARS") AND isArray(filteredUsers[i].GRADYEARS) ? filteredUsers[i].GRADYEARS : []>
        <cfset hasSelectedGradYear = false>
        <cfloop from="1" to="#arrayLen(userGradYears)#" index="gyIdx">
            <cfif val(userGradYears[gyIdx]) EQ val(selectedGradYear)>
                <cfset hasSelectedGradYear = true>
                <cfbreak>
            </cfif>
        </cfloop>
        <cfif hasSelectedGradYear>
            <cfset arrayAppend(gradYearFiltered, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = gradYearFiltered>
</cfif>

<!--- Pre-populate extended searchable fields on filtered users (only when a search is active) --->
<cfif len(trim(searchTerm))>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="searchPrepIdx">
        <cfset searchPrepUID = toString(filteredUsers[searchPrepIdx].USERID)>
        <!--- Flag names as CSV --->
        <cfset searchPrepFlags = structKeyExists(allUserFlagMap, searchPrepUID) ? allUserFlagMap[searchPrepUID] : []>
        <cfset searchPrepFlagNames = []>
        <cfloop from="1" to="#arrayLen(searchPrepFlags)#" index="spfi">
            <cfset arrayAppend(searchPrepFlagNames, searchPrepFlags[spfi].FLAGNAME ?: "")>
        </cfloop>
        <cfset filteredUsers[searchPrepIdx].SEARCH_FLAGS = arrayToList(searchPrepFlagNames, ",")>
        <!--- Org names as CSV --->
        <cfset searchPrepOrgs = structKeyExists(allUserOrgMap, searchPrepUID) ? allUserOrgMap[searchPrepUID] : []>
        <cfset searchPrepOrgNames = []>
        <cfloop from="1" to="#arrayLen(searchPrepOrgs)#" index="spoi">
            <cfset arrayAppend(searchPrepOrgNames, searchPrepOrgs[spoi].ORGNAME ?: "")>
        </cfloop>
        <cfset filteredUsers[searchPrepIdx].SEARCH_ORGS = arrayToList(searchPrepOrgNames, ",")>
        <!--- Primary phone --->
        <cfset searchPrepPhone = structKeyExists(allUserPhoneMap, searchPrepUID) ? allUserPhoneMap[searchPrepUID] : {}>
        <cfset filteredUsers[searchPrepIdx].SEARCH_PHONE = searchPrepPhone.PHONE ?: "">
        <!--- CougarNet and PeopleSoft external IDs --->
        <cfset searchPrepExtIDs = structKeyExists(allUserExtIDMap, searchPrepUID) ? allUserExtIDMap[searchPrepUID] : {}>
        <cfset searchPrepCN = "">
        <cfset searchPrepPSID = "">
        <cfloop collection="#searchPrepExtIDs#" item="searchPrepSysKey">
            <cfif findNoCase("cougarnet", searchPrepSysKey) AND NOT len(searchPrepCN)>
                <cfset searchPrepCN = searchPrepExtIDs[searchPrepSysKey]>
            <cfelseif findNoCase("peoplesoft", searchPrepSysKey) AND NOT len(searchPrepPSID)>
                <cfset searchPrepPSID = searchPrepExtIDs[searchPrepSysKey]>
            </cfif>
        </cfloop>
        <cfset filteredUsers[searchPrepIdx].SEARCH_COUGARNET = searchPrepCN>
        <cfset filteredUsers[searchPrepIdx].SEARCH_PSID = searchPrepPSID>
        <!--- Grad years as CSV --->
        <cfif structKeyExists(filteredUsers[searchPrepIdx], "GRADYEARS") AND isArray(filteredUsers[searchPrepIdx].GRADYEARS)>
            <cfset searchPrepGYArr = []>
            <cfloop from="1" to="#arrayLen(filteredUsers[searchPrepIdx].GRADYEARS)#" index="spgyi">
                <cfset arrayAppend(searchPrepGYArr, toString(filteredUsers[searchPrepIdx].GRADYEARS[spgyi]))>
            </cfloop>
            <cfset filteredUsers[searchPrepIdx].SEARCH_GRADYEARS = arrayToList(searchPrepGYArr, ",")>
        <cfelse>
            <cfset filteredUsers[searchPrepIdx].SEARCH_GRADYEARS = (structKeyExists(filteredUsers[searchPrepIdx], "CURRENTGRADYEAR") AND isNumeric(filteredUsers[searchPrepIdx].CURRENTGRADYEAR) AND val(filteredUsers[searchPrepIdx].CURRENTGRADYEAR) GT 0) ? toString(val(filteredUsers[searchPrepIdx].CURRENTGRADYEAR)) : "">
        </cfif>
    </cfloop>
</cfif>

<!--- Search filter --->
<cfinclude template="/admin/users/_search_helper.cfm">
<cfif searchTerm NEQ "">
    <cfset searchedUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfif userMatchesSearch(filteredUsers[i], searchTerm)>
            <cfset arrayAppend(searchedUsers, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = searchedUsers>
</cfif>

<!--- Org filter --->
<cfif showOrgFilter AND orgFilterHasSelection>
    <cfset orgFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset u = filteredUsers[i]>
        <cfset userOrgsList = structKeyExists(allUserOrgMap, toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)] : []>
        <cfif includeNoOrgFilter AND arrayLen(userOrgsList) EQ 0>
            <cfset arrayAppend(orgFiltered, u)>
        <cfelse>
            <cfloop from="1" to="#arrayLen(userOrgsList)#" index="o">
                <cfif structKeyExists(selectedOrgFilterLookup, toString(userOrgsList[o].ORGID))>
                    <cfset arrayAppend(orgFiltered, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
    <cfset filteredUsers = orgFiltered>
</cfif>

<!--- Letter filter --->
<cfif selectedLetter NEQ "">
    <cfset letterFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfif len(filteredUsers[i].LASTNAME) AND ucase(left(filteredUsers[i].LASTNAME, 1)) EQ selectedLetter>
            <cfset arrayAppend(letterFiltered, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = letterFiltered>
</cfif>

<!--- ======================== SORT ======================== --->
<cfset sortColumn    = structKeyExists(url, "sortCol") ? url.sortCol : "LASTNAME">
<cfset sortDirection = structKeyExists(url, "sortDir") ? url.sortDir : "ASC">
<cfset filteredUsers = helpers.sortUsers(users=filteredUsers, sortColumn=sortColumn, sortDirection=sortDirection)>

<!--- ======================== PAGINATE ======================== --->
<cfset validPerPage = [10, 25, 50, 100]>
<cfset perPage      = structKeyExists(url, "perPage") AND isNumeric(url.perPage) AND arrayContains(validPerPage, val(url.perPage)) ? val(url.perPage) : 25>
<cfset totalRecords = arrayLen(filteredUsers)>
<cfset totalPages   = max(1, ceiling(totalRecords / perPage))>
<cfset currentPage  = structKeyExists(url, "page") AND isNumeric(url.page) ? max(1, min(val(url.page), totalPages)) : 1>
<cfset sliceStart   = ((currentPage - 1) * perPage) + 1>
<cfset sliceEnd     = min(sliceStart + perPage - 1, totalRecords)>
<cfset pageRows     = totalRecords GT 0 ? arraySlice(filteredUsers, sliceStart, min(perPage, totalRecords - sliceStart + 1)) : []>

<cfif showGradYear AND arrayLen(pageRows)>
    <cfset pageAcademicUserIDs = []>
    <cfloop from="1" to="#arrayLen(pageRows)#" index="pageAcademicIndex">
        <cfif isNumeric(pageRows[pageAcademicIndex].USERID ?: "")>
            <cfset arrayAppend(pageAcademicUserIDs, val(pageRows[pageAcademicIndex].USERID))>
        </cfif>
    </cfloop>
    <cfset pageAcademicMaps = academicService.getAllAcademicMaps(pageAcademicUserIDs, true)>
    <cfset pageGradYearMap = pageAcademicMaps.gradYearMap>
</cfif>

<cfloop from="1" to="#arrayLen(pageRows)#" index="pageRowIndex">
    <cfset pageRows[pageRowIndex].RESOLVEDFIRSTNAME = trim(pageRows[pageRowIndex].FIRSTNAME ?: "")>
    <cfset pageRows[pageRowIndex].RESOLVEDLASTNAME = trim(pageRows[pageRowIndex].LASTNAME ?: "")>
    <cfif showGradYear>
        <cfset pageGradYearData = structKeyExists(pageGradYearMap ?: {}, toString(pageRows[pageRowIndex].USERID)) ? pageGradYearMap[toString(pageRows[pageRowIndex].USERID)] : {}>
        <cfset pageRows[pageRowIndex].GRADYEARPROGRAMMAP = structKeyExists(pageGradYearData, "YEARPROGRAMMAP") ? pageGradYearData.YEARPROGRAMMAP : {}>
        <cfset pageRows[pageRowIndex].GRADYEARDISPLAY = academicService.buildGradYearDisplay({
            YEARS = structKeyExists(pageRows[pageRowIndex], "GRADYEARS") ? pageRows[pageRowIndex].GRADYEARS : [],
            YEARPROGRAMMAP = structKeyExists(pageRows[pageRowIndex], "GRADYEARPROGRAMMAP") ? pageRows[pageRowIndex].GRADYEARPROGRAMMAP : {}
        })>
    </cfif>
</cfloop>

<!--- Column count for no-data colspan --->
<cfset colCount = 7>
<cfif showPhoto><cfset colCount = colCount + 1></cfif>
<cfif showGradYear><cfset colCount = colCount + 1></cfif>
<cfif showTitle><cfset colCount = colCount + 1></cfif>

<!--- Precompute clear-filters link --->
<cfset hasActiveFilters = (selectedFlagFilter NEQ "" OR selectedOrgFilter NEQ "" OR selectedGradYear NEQ "" OR selectedLetter NEQ "" OR len(searchTerm))>
<cfset clearLink = "?list=" & listType & "&sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage>
<cfset testUsersLink = "">
<cfif showTestUsersForAdmin AND len(testUserFlagID)>
    <cfset testUsersLink = "?list=all&filterFlag=" & urlEncodedFormat(testUserFlagID) & "&sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage & "&page=1&filterPanel=flags">
</cfif>
<cfset selectedFlagLabel = "">
<cfif selectedFlagFilter EQ "NOFLAGS">
    <cfset selectedFlagLabel = "No Flags">
<cfelseif len(selectedFlagFilter) AND isNumeric(selectedFlagFilter)>
    <cfloop array="#allFlags#" index="flagOption">
        <cfif toString(flagOption.FLAGID) EQ toString(selectedFlagFilter)>
            <cfset selectedFlagLabel = flagOption.FLAGNAME>
            <cfbreak>
        </cfif>
    </cfloop>
</cfif>
<cfset activeFilterChipsHTML = "">
<cfif len(selectedFlagLabel)>
    <cfset activeFilterChipsHTML &= "<span class='badge rounded-pill badge-light users-list-active-chip'><i class='bi bi-flag me-1'></i>Flag: " & encodeForHTML(selectedFlagLabel) & "</span>">
</cfif>
<cfif showGradFilter AND len(selectedGradYear)>
    <cfset activeFilterChipsHTML &= "<span class='badge rounded-pill badge-light users-list-active-chip'><i class='bi bi-mortarboard me-1'></i>Grad Year: " & encodeForHTML(selectedGradYear) & "</span>">
</cfif>
<cfif showOrgFilter AND orgFilterHasSelection>
    <cfset activeFilterChipsHTML &= "<span class='badge rounded-pill badge-light users-list-active-chip'><i class='bi bi-diagram-3 me-1'></i>Organizations: " & selectedOrgFilterCount & "</span>">
</cfif>
<cfif len(selectedLetter)>
    <cfset activeFilterChipsHTML &= "<span class='badge rounded-pill badge-light users-list-active-chip'><i class='bi bi-type me-1'></i>Last Name: " & encodeForHTML(selectedLetter) & "</span>">
</cfif>
<cfset orgFilterPanelHTML = "">
<cfif showOrgFilter>
    <cfset orgFilterPanelHTML = "
            <div class='users-list-org-filter-wrap'>
                <div class='d-flex flex-column flex-lg-row justify-content-between align-items-lg-center gap-2 mb-3'>
                    <div>
                        <div class='fw-semibold users-list-org-filter-title'>Organization Filters</div>
                        <div class='text-muted small users-list-org-filter-note'>Top-level organizations are headings only. Select child organizations or their children to filter results.</div>
                    </div>
                </div>
                <div class='form-check mb-3'>
                    <input class='form-check-input' type='checkbox' name='filterOrg' value='NOORGS' id='filterOrgNoOrg'#(includeNoOrgFilter ? " checked" : "")#>
                    <label class='form-check-label' for='filterOrgNoOrg'>No Org</label>
                </div>
                <div class='row row-cols-1 row-cols-xl-2 g-3 users-list-org-filter-grid'>
    ">
    <cfloop from="1" to="#arrayLen(rootOrgs)#" index="iRoot">
        <cfset rootOrg = rootOrgs[iRoot]>
        <cfset childOrgs = structKeyExists(orgChildrenByParent, toString(rootOrg.ORGID)) ? orgChildrenByParent[toString(rootOrg.ORGID)] : []>
        <cfset orgFilterPanelHTML &= "
                                <div class='col'>
                                    <div class='card h-100 border-light-subtle users-list-org-group-card'>
                                        <div class='card-header bg-white users-list-org-group-header'>
                                            <div class='fw-semibold users-list-org-group-title'>#EncodeForHTML(rootOrg.ORGNAME)#</div>
                                            #(len(trim(rootOrg.ORGDESCRIPTION ?: "")) ? "<div class='small text-muted mt-1 users-list-org-group-description'>" & EncodeForHTML(rootOrg.ORGDESCRIPTION) & "</div>" : "")#
                                        </div>
                                        <div class='card-body p-3 users-list-org-group-body'>
        ">
        <cfif arrayLen(childOrgs) EQ 0>
            <cfset orgFilterPanelHTML &= "<div class='text-muted small'>No child organizations available.</div>">
        <cfelse>
            <cfloop from="1" to="#arrayLen(childOrgs)#" index="iChild">
                <cfset childOrg = childOrgs[iChild]>
                <cfset childOrgKey = toString(childOrg.ORGID)>
                <cfset grandChildOrgs = structKeyExists(orgChildrenByParent, childOrgKey) ? orgChildrenByParent[childOrgKey] : []>
                <cfset orgFilterPanelHTML &= "
                                            <div class='mb-3'>
                                                <div class='form-check mb-1'>
                                                    <input class='form-check-input' type='checkbox' name='filterOrg' value='#childOrg.ORGID#' id='filterOrg#childOrg.ORGID#'#(structKeyExists(selectedOrgFilterLookup, childOrgKey) ? " checked" : "")#>
                                                    <label class='form-check-label user-select-none' for='filterOrg#childOrg.ORGID#'>#EncodeForHTML(childOrg.ORGNAME)#</label>
                                                </div>
                ">
                <cfif arrayLen(grandChildOrgs) GT 0>
                    <cfset orgFilterPanelHTML &= "<div class='ms-4 mt-2 d-flex flex-column gap-2'>">
                    <cfloop from="1" to="#arrayLen(grandChildOrgs)#" index="iGrandChild">
                        <cfset grandChildOrg = grandChildOrgs[iGrandChild]>
                        <cfset grandChildOrgKey = toString(grandChildOrg.ORGID)>
                        <cfset orgFilterPanelHTML &= "
                                                    <div class='form-check'>
                                                        <input class='form-check-input' type='checkbox' name='filterOrg' value='#grandChildOrg.ORGID#' id='filterOrg#grandChildOrg.ORGID#'#(structKeyExists(selectedOrgFilterLookup, grandChildOrgKey) ? " checked" : "")#>
                                                        <label class='form-check-label user-select-none small text-muted' for='filterOrg#grandChildOrg.ORGID#'>#EncodeForHTML(grandChildOrg.ORGNAME)#</label>
                                                    </div>
                        ">
                    </cfloop>
                    <cfset orgFilterPanelHTML &= "</div>">
                </cfif>
                <cfset orgFilterPanelHTML &= "</div>">
            </cfloop>
        </cfif>
        <cfset orgFilterPanelHTML &= "
                                        </div>
                                    </div>
                                </div>
        ">
    </cfloop>
    <cfset orgFilterPanelHTML &= "
                </div>
            </div>
    ">
</cfif>

<cfset advSearchIsActive = len(searchTerm) AND (find(":", searchTerm) GT 0 OR find("&&", searchTerm) GT 0 OR find("||", searchTerm) GT 0)>
<cfset filtersBadgeCount = flagFilterCount + gradFilterCount + selectedOrgFilterCount + (len(selectedLetter) ? 1 : 0)>

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
                    <form method='get' class='users-list-toolbar-search-form'>
                        <input type='hidden' name='list'    value='#listType#'>
                        <input type='hidden' name='sortCol' value='#sortColumn#'>
                        <input type='hidden' name='sortDir' value='#sortDirection#'>
                        <input type='hidden' name='filterFlag' value='#encodeForHTMLAttribute(selectedFlagFilter)#'>
                        <input type='hidden' name='filterGradYear' value='#encodeForHTMLAttribute(selectedGradYear)#'>
                        <input type='hidden' name='filterOrg' value='#encodeForHTMLAttribute(selectedOrgFilter)#'>
                        <input type='hidden' name='perPage' value='#perPage#'>
                        <input type='hidden' name='letter' value='#encodeForHTMLAttribute(selectedLetter)#'>
                        <input type='hidden' name='filterPanel' value='#encodeForHTMLAttribute(activeFilterPanel)#'>
                        <input type='hidden' name='page'    value='1'>
                        <div class='input-group users-list-toolbar-search users-list-toolbar-input-group'>
                            <button type='button' class='btn btn-sm btn-ui-help users-list-help-button' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                            <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
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

<!--- ======================== BUILD PAGE CONTENT ======================== --->

<!---
<div class='d-flex justify-content-between align-items-center flex-wrap gap-2 mb-4 users-list-page-header'>
        <div class='d-flex align-items-center gap-2 flex-wrap'>
            <h1 class='mb-0'><i class='bi bi-people-fill me-2'></i>#pageTitle# </h1>
            #usersListMenuHTML#
        </div>
        <div class='d-flex gap-2'>
            <a href='/admin/users/new.cfm' class='btn btn-lg btn-ui-add'><i class='bi bi-plus me-1'></i>New User</a>
        </div>
    </div>
<div class='input-group users-list-toolbar-search'>
                    #usersListMenuHTML#
                    <button type='button' class='btn btn-sm btn-ui-help users-list-help-button' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                    <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
                </div>#usersListMenuHTML#
--->
<cfset content = "
#usersTopToolBar#
<div class='py-4 px-4 pt-2'>
    <form method='get' class='users-list-advanced-filter-form'>
        <input type='hidden' name='list' value='#listType#'>
        <input type='hidden' name='sortCol' value='#sortColumn#'>
        <input type='hidden' name='sortDir' value='#sortDirection#'>
        <input type='hidden' name='search' value='#encodeForHTMLAttribute(searchTerm)#'>
        <input type='hidden' name='letter' value='#encodeForHTMLAttribute(selectedLetter)#'>
        <input type='hidden' name='page' value='1'>
        <input type='hidden' name='filterPanel' value='#encodeForHTMLAttribute(activeFilterPanel)#' id='usersListFilterPanelInput'>
        <div class='users-page-secondary-toolbar users-list-secondary-toolbar'>
            <div class='users-page-secondary-toolbar-heading'>
                <div class='users-page-secondary-toolbar-eyebrow'>User Records</div>
                <h1 class='users-page-secondary-toolbar-title'>#pageTitle#</h1>
                <div class='users-page-secondary-toolbar-meta'>#numberFormat(totalRecords)# matching records#(hasActiveFilters ? " with filters applied" : "")#.</div>
            </div>
            <div class='users-page-secondary-toolbar-actions users-list-filter-toolbar-actions'>
                #(request.canCreateUsers() ? "<button type='button' class='btn btn-sm btn-ui-add' data-bs-toggle='modal' data-bs-target='##quickAddUserModal'><i class='bi bi-plus me-1'></i>Add A New User</button>" : "")#
            </div>
        </div>
        <div class='card mb-3 users-search-filter-card'>
            <div class='card-header p-0' style='--bs-card-cap-padding-y: 0'>
                <ul class='nav nav-tabs card-header-tabs border-bottom-0 px-2' id='usersSearchFilterTabs' role='tablist'>
                    <li class='nav-item' role='presentation'>
                        <button class='nav-link#(advSearchIsActive ? "" : " active")# py-2 px-3' id='usersFiltersTabBtn' data-bs-toggle='tab' data-bs-target='##usersFiltersTabPane' type='button' role='tab' aria-controls='usersFiltersTabPane' aria-selected='#(advSearchIsActive ? "false" : "true")#'>
                            <i class='bi bi-funnel me-1'></i>Filters#(filtersBadgeCount GT 0 ? " <span class='badge text-bg-secondary ms-1'>" & filtersBadgeCount & "</span>" : "")#
                        </button>
                    </li>
                    <li class='nav-item' role='presentation'>
                        <button class='nav-link#(advSearchIsActive ? " active" : "")# py-2 px-3' id='usersAdvSearchTabBtn' data-bs-toggle='tab' data-bs-target='##usersAdvSearchTabPane' type='button' role='tab' aria-controls='usersAdvSearchTabPane' aria-selected='#(advSearchIsActive ? "true" : "false")#'>
                            <i class='bi bi-sliders me-1'></i>Advanced Search
                            <span id='usersAdvSearchBadge' class='badge text-bg-secondary ms-1' style='display:none'></span>
                        </button>
                    </li>
                </ul>
            </div>
            <div class='card-body tab-content py-3 pb-2'>
                <div class='tab-pane fade#(advSearchIsActive ? "" : " show active")#' id='usersFiltersTabPane' role='tabpanel' aria-labelledby='usersFiltersTabBtn'>
                <div class='users-list-filter-toolbar-row users-list-action-row'>
                    <div class='users-list-filter-toolbar-group'>
                    <button type='button' class='btn btn-sm users-list-filter-panel-toggle #(activeFilterPanel EQ "flags" ? "btn-ui-filter" : "btn-ui-cancel")#' data-filter-panel-trigger='flags' aria-expanded='#(activeFilterPanel EQ "flags" ? "true" : "false")#' aria-controls='usersListFilterPanel'>
                        <i class='bi bi-flag me-1'></i>Flags#(flagFilterCount GT 0 ? " <span class='badge badge-light ms-1'>" & flagFilterCount & "</span>" : "")#
                    </button>
                    #(showGradFilter ? "<button type='button' class='btn btn-sm users-list-filter-panel-toggle " & (activeFilterPanel EQ "grad" ? "btn-ui-filter" : "btn-ui-cancel") & "' data-filter-panel-trigger='grad' aria-expanded='" & (activeFilterPanel EQ "grad" ? "true" : "false") & "' aria-controls='usersListFilterPanel'><i class='bi bi-mortarboard me-1'></i>Grad Year" & (gradFilterCount GT 0 ? " <span class='badge badge-light ms-1'>" & gradFilterCount & "</span>" : "") & "</button>" : "")#
                    #(showOrgFilter ? "<button type='button' class='btn btn-sm users-list-filter-panel-toggle " & (activeFilterPanel EQ "orgs" ? "btn-ui-filter" : "btn-ui-cancel") & "' data-filter-panel-trigger='orgs' aria-expanded='" & (activeFilterPanel EQ "orgs" ? "true" : "false") & "' aria-controls='usersListFilterPanel'><i class='bi bi-diagram-3 me-1'></i>Organizations" & (selectedOrgFilterCount GT 0 ? " <span class='badge badge-light ms-1'>" & selectedOrgFilterCount & "</span>" : "") & "</button>" : "")#
                    #(request.isSuperAdmin() AND len(testUsersLink) ? "<a href='" & testUsersLink & "' class='btn btn-sm " & ((listType EQ "all" AND selectedFlagFilter EQ testUserFlagID) ? "btn-ui-filter" : "btn-ui-cancel") & " users-list-test-users-button'><i class='bi bi-person-badge me-1'></i>Test Users</a>" : "")#
                    <label for='perPageSelect' class='mb-0 users-list-filter-label'>Per Page:</label>
                    <select name='perPage' id='perPageSelect' class='form-select users-list-select-auto'>
                        <option value='10'  #(perPage == 10  ? 'selected' : '')#>10</option>
                        <option value='25'  #(perPage == 25  ? 'selected' : '')#>25</option>
                        <option value='50'  #(perPage == 50  ? 'selected' : '')#>50</option>
                        <option value='100' #(perPage == 100 ? 'selected' : '')#>100</option>
                    </select>
                    </div>
                    " & (len(activeFilterChipsHTML) ? "<div class='d-flex flex-wrap gap-2 align-items-center users-list-active-filters'>" & activeFilterChipsHTML & "</div>" : "") & "
                </div>
                <div class='users-list-filter-panel#(len(activeFilterPanel) ? "" : " d-none")#' id='usersListFilterPanel'>
                <div class='users-list-filter-section#(activeFilterPanel EQ "flags" ? "" : " d-none")#' data-filter-panel='flags'>
                    <div class='d-flex flex-wrap align-items-center gap-2'>
                        <label for='flagFilter' class='mb-0 users-list-filter-label'>Flag:</label>
                        <select name='filterFlag' id='flagFilter' class='form-select users-list-select-auto'>
                            <option value=''>All</option>
                            <option value='NOFLAGS'#(selectedFlagFilter == 'NOFLAGS' ? ' selected' : '')#>No Flags</option>
">

<cfif showTestUsersForAdmin AND len(testUserFlagID)>
    <cfset content &= "<option value='#testUserFlagID#'" & (selectedFlagFilter == testUserFlagID ? " selected" : "") & ">#testUserFlagName#</option>">
</cfif>

<!--- Flag dropdown options --->
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flag = allFlags[i]>
    <cfif compareNoCase(trim(flag.FLAGNAME ?: ""), "TEST_USER") EQ 0>
        <cfcontinue>
    </cfif>
    <cfif NOT canViewAlumni AND compareNoCase(trim(flag.FLAGNAME ?: ""), "Alumni") EQ 0>
        <cfcontinue>
    </cfif>
    <cfset content &= "<option value='#flag.FLAGID#'" & (selectedFlagFilter == toString(flag.FLAGID) ? " selected" : "") & ">#flag.FLAGNAME#</option>">
</cfloop>

<cfset content &= "
                        </select>
                    </div>
                </div>
">

<!--- Grad year filter (conditional) --->
<cfif showGradFilter>
    <cfset content &= "
                <div class='users-list-filter-section#(activeFilterPanel EQ "grad" ? "" : " d-none")#' data-filter-panel='grad'>
                    <div class='d-flex flex-wrap align-items-center gap-2'>
                        <label for='gradYearFilter' class='mb-0 users-list-filter-label'>Grad Year:</label>
                        <select name='filterGradYear' id='gradYearFilter' class='form-select users-list-select-auto'>
                            <option value=''>All Years</option>
    ">
    <cfloop from="1" to="#arrayLen(allGradYears)#" index="i">
        <cfset gy = allGradYears[i]>
        <cfset content &= "<option value='#gy#'" & (selectedGradYear == toString(gy) ? " selected" : "") & ">#gy#</option>">
    </cfloop>
    <cfset content &= "
                        </select>
                    </div>
                </div>
    ">
</cfif>

<!--- Organization filter panel --->
<cfif showOrgFilter>
    <cfset content &= "
                <div class='users-list-filter-section#(activeFilterPanel EQ "orgs" ? "" : " d-none")#' data-filter-panel='orgs'>
                    #orgFilterPanelHTML#
                </div>
    ">
</cfif>

<cfset content &= "
                </div><!-- /users-list-filter-panel -->
                </div><!-- /usersFiltersTabPane -->
                <div class='tab-pane fade#(advSearchIsActive ? " show active" : "")#' id='usersAdvSearchTabPane' role='tabpanel' aria-labelledby='usersAdvSearchTabBtn'>
                    <div id='usersAdvSearchRows' class='d-flex flex-column gap-2'></div>
                </div><!-- /usersAdvSearchTabPane -->
            </div><!-- /card-body tab-content -->
            <div class='card-footer'>
                <div id='usersFiltersFooter' class='d-flex align-items-center gap-2#(advSearchIsActive ? " d-none" : "")#'>
                    <button type='submit' class='btn btn-sm btn-ui-filter users-list-apply-button'><i class='bi bi-funnel me-1'></i>Apply Filters</button>
                    " & (hasActiveFilters ? "<a href='#clearLink#' class='btn btn-sm btn-ui-clear users-list-clear-button'><i class='bi bi-x-circle me-1'></i>Clear All</a>" : "") & "
                </div>
                <div id='usersAdvSearchFooter' class='d-flex align-items-center gap-2 flex-wrap w-100#(advSearchIsActive ? "" : " d-none")#'>
                    <button type='button' class='btn btn-sm btn-ui-filter' id='usersAdvSearchApply'><i class='bi bi-search me-1'></i>Search</button>
                    <a href='##' class='btn btn-sm btn-ui-clear users-list-clear-button#(advSearchIsActive ? "" : " d-none")#' id='usersAdvSearchClear'><i class='bi bi-x-circle me-1'></i>Clear All</a>
                    <span class='text-muted small ms-1'>Conditions are combined with AND/OR. Searching with this panel replaces any text in the toolbar search box.</span>
                </div>
            </div><!-- /card-footer -->
        </div><!-- /users-search-filter-card -->
    </form>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "
">

<cfif canViewTestUsers AND arrayLen(inactiveMergedAccounts) GT 0>
    <cfset content &= "
<div class='card mb-4 border-warning-subtle'>
    <div class='card-header bg-warning-subtle d-flex justify-content-between align-items-center'>
        <div><strong>Inactive Merged Accounts</strong></div>
        <span class='badge text-bg-dark'>#arrayLen(inactiveMergedAccounts)#</span>
    </div>
    <div class='card-body'>
        <p class='text-muted mb-3'>These are secondary records from merges that are inactive and safe candidates for permanent delete.</p>
    ">
        <cfset content &= "
        <div class='table-responsive'>
            <table class='table table-sm align-middle mb-0'>
                <thead>
                    <tr>
                        <th>User ID</th>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Last Primary</th>
                        <th>Last Merged</th>
                        <th>Merges</th>
                        <th class='text-end'>Action</th>
                    </tr>
                </thead>
                <tbody>
        ">
        <cfloop from="1" to="#arrayLen(inactiveMergedAccounts)#" index="inactiveIdx">
            <cfset inactiveRow = inactiveMergedAccounts[inactiveIdx]>
            <cfset content &= "
                    <tr>
                        <td>##" & val(inactiveRow.SECONDARYUSERID ?: 0) & "</td>
                        <td>" & encodeForHTML(trim((inactiveRow.FIRSTNAME ?: "") & " " & (inactiveRow.LASTNAME ?: ""))) & "</td>
                        <td>" & encodeForHTML(inactiveRow.EMAILPRIMARY ?: "") & "</td>
                        <td>##" & val(inactiveRow.LASTPRIMARYUSERID ?: 0) & "</td>
                        <td>" & encodeForHTML(dateTimeFormat(inactiveRow.LASTMERGEDAT, "mmm d, yyyy HH:nn")) & "</td>
                        <td>" & val(inactiveRow.MERGECOUNT ?: 0) & "</td>
                        <td class='text-end'>
                            <a class='btn btn-sm btn-ui-go me-1' href='/admin/users/view.cfm?userID=" & val(inactiveRow.SECONDARYUSERID ?: 0) & "&returnTo=" & urlEncodedFormat(currentListUrl) & "'>View</a>
                            <form method='post' class='d-inline'>
                                <input type='hidden' name='action' value='deleteInactiveMergedUser'>
                                <input type='hidden' name='userID' value='" & val(inactiveRow.SECONDARYUSERID ?: 0) & "'>
                                <button type='submit' class='btn btn-sm btn-ui-delete'" & (request.hasPermission("users.delete") ? "" : " disabled") & ">Delete</button>
                            </form>
                        </td>
                    </tr>
            ">
        </cfloop>
        <cfset content &= "
                </tbody>
            </table>
        </div>
        ">

    <cfset content &= "
    </div>
</div>
    ">
</cfif>

<!--- Top pagination --->
<cfset content &= "
<div class='table-responsive users-list-table-shell'>
<table class='table table-striped table-hover align-middle users-list-table'>
    <thead class='users-list-table-head'>
        <tr>
            <th class='text-center users-list-col-id'>##</th>
">
<cfif showPhoto>
    <cfset content &= "            <th class='text-center users-list-col-photo'></th>
">
</cfif>
<cfset content &= "
            <th><a href='#helpers.getSortLink("FIRSTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' class='users-list-sort-link'>First Name #(sortColumn == "FIRSTNAME" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
            <th><a href='#helpers.getSortLink("LASTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' class='users-list-sort-link'>Last Name #(sortColumn == "LASTNAME" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
            <th><a href='#helpers.getSortLink("EMAIL", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' class='users-list-sort-link'>Email #(sortColumn == "EMAIL" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
">
<cfif showGradYear>
    <cfset content &= "
            <th class='text-center'><a href='#helpers.getSortLink("CURRENTGRADYEAR", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' class='users-list-sort-link'>Grad Year #(sortColumn == "CURRENTGRADYEAR" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
">
</cfif>
<cfif showTitle>
    <cfset content &= "
            <th class='text-center'>Title</th>
">
</cfif>
<cfset content &= "
            <th class='users-list-col-orgs'>Organizational Units</th>
            <th class='users-list-col-flags'>Flags</th>
            <th class='users-list-col-actions'>Actions</th>
        </tr>
    </thead>
    <tbody>
">

<!--- Table rows --->
<cfloop from="1" to="#arrayLen(pageRows)#" index="i">
    <cfset u = pageRows[i]>
    <cfset userFlags    = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset userOrgsData = structKeyExists(allUserOrgMap, toString(u.USERID))  ? allUserOrgMap[toString(u.USERID)]  : []>
    <cfset orgsHTML  = "">
    <cfset flagsHTML = "">

    <cfloop from="1" to="#arrayLen(userOrgsData)#" index="o">
        <cfset orgBadgeClass = findNoCase("clinic", userOrgsData[o].ORGNAME ?: "") ? "badge-orgs-clinic" : "badge-orgs-college">
        <cfset orgsHTML &= "<span class='badge rounded-pill " & orgBadgeClass & " text-wrap text-start users-list-badge-org'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>

    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfif highlightFlags AND (userFlags[f].FLAGNAME EQ "Admin - Check" OR userFlags[f].FLAGNAME EQ "No-UH")>
            <cfset flagsHTML &= "<span class='badge rounded-pill badge-warning text-wrap text-start users-list-badge-flag'>#userFlags[f].FLAGNAME#</span>">
        <cfelse>
            <cfset flagsHTML &= "<span class='badge rounded-pill badge-flags text-wrap text-start users-list-badge-flag'>#userFlags[f].FLAGNAME#</span>">
        </cfif>
    </cfloop>

    <!--- Email display: cascading priority --->
    <cfset userEmailList = structKeyExists(allUserEmailMap, toString(u.USERID)) ? allUserEmailMap[toString(u.USERID)] : []>
    <cfset displayEmail = "">
    <cfset displayEmailExternal = false>
    <!--- 1. Primary-marked email from UserEmails --->
    <cfloop from="1" to="#arrayLen(userEmailList)#" index="em">
        <cfif userEmailList[em].ISPRIMARY EQ 1 AND len(trim(userEmailList[em].EMAILADDRESS))>
            <cfset displayEmail = userEmailList[em].EMAILADDRESS>
            <cfbreak>
        </cfif>
    </cfloop>
    <!--- 2. EmailPrimary (@uh.edu) from Users table --->
    <cfif NOT len(displayEmail) AND len(trim(u.EMAILPRIMARY ?: ""))>
        <cfset displayEmail = u.EMAILPRIMARY>
    </cfif>
    <!--- 3. @cougarnet or @central from UserEmails --->
    <cfif NOT len(displayEmail)>
        <cfloop from="1" to="#arrayLen(userEmailList)#" index="em">
            <cfif reFindNoCase('@cougarnet|@central', userEmailList[em].EMAILADDRESS)>
                <cfset displayEmail = userEmailList[em].EMAILADDRESS>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>
    <!--- 4. Personal or Other from UserEmails (mark as external) --->
    <cfif NOT len(displayEmail)>
        <cfloop from="1" to="#arrayLen(userEmailList)#" index="em">
            <cfif len(trim(userEmailList[em].EMAILADDRESS))>
                <cfset displayEmail = userEmailList[em].EMAILADDRESS>
                <cfset displayEmailExternal = true>
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>

    <!--- Manage Images link (faculty / current-students with media admin role) --->
    <cfset mediaLink = "">
    <cfif showManageImages AND request.hasPermission("media.edit")>
        <cfset mediaLink = "<a href='/admin/user-media/sources.cfm?userid=#u.USERID#' class='btn btn-sm btn-ui-go users-list-action-button users-list-action-button-media' title='Manage Images' data-bs-toggle='tooltip' data-bs-title='Manage Images'><i class='bi bi-card-image'></i></a>">
    </cfif>

    <cfset deleteLink = "">
    <cfif request.hasPermission("users.delete")>
        <cfset deleteLink = "<a class='btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete' href='/admin/users/deleteConfirm.cfm?userID=#u.USERID#' title='Delete User' data-bs-toggle='tooltip' data-bs-title='Delete User'><i class='bi bi-trash'></i></a>">
    </cfif>

    <!--- Deceased icon (alumni only) --->
    <cfset deceasedIcon = "">
    <cfif showDeceased>
        <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
            <cfif lCase(trim(userFlags[f].FLAGNAME)) EQ "deceased">
                <cfset deceasedIcon = "<i class='bi bi-record-fill me-1 users-list-deceased-icon' title='Deceased' data-bs-toggle='tooltip' data-bs-title='Deceased'></i>">
                <cfbreak>
            </cfif>
        </cfloop>
    </cfif>

    <!--- Photo thumbnail --->
    <cfset thumbURL = "">
    <cfif showPhoto>
        <cfset thumbURL = structKeyExists(webThumbMap, toString(u.USERID)) ? webThumbMap[toString(u.USERID)] : "">
    </cfif>

    <cfset content &= "
        <tr>
            <td class='text-center'>#u.USERID#</td>
    ">

    <cfif showPhoto>
        <cfset content &= "<td class='text-center'>" & (len(thumbURL) ? "<img src='" & thumbURL & "' alt='thumb' class='users-list-thumb'>" : "") & "</td>">
    </cfif>

    <cfset content &= "
            <td>#deceasedIcon##EncodeForHTML(u.RESOLVEDFIRSTNAME ?: u.FIRSTNAME ?: '')#</td>
            <td>#EncodeForHTML(u.RESOLVEDLASTNAME ?: u.LASTNAME ?: '')#</td>
            <td class='users-list-email-cell'>#displayEmail##(displayEmailExternal ? " <span class='badge badge-info users-list-external-badge' title='Non-UH email'>External</span>" : "")#</td>
    ">

    <cfif showGradYear>
        <cfset gradYearDisplay = trim(u.GRADYEARDISPLAY ?: "")>
        <cfif NOT len(gradYearDisplay) AND isNumeric(u.CURRENTGRADYEAR ?: "") AND val(u.CURRENTGRADYEAR) GT 0>
            <cfset gradYearDisplay = toString(val(u.CURRENTGRADYEAR))>
        </cfif>
        <cfset content &= "<td class='text-center'>#gradYearDisplay#</td>">
    </cfif>

    <cfif showTitle>
        <cfset content &= "<td class='text-center'>#u.TITLE1#</td>">
    </cfif>

    <cfset editLink = "">
    <cfif request.hasPermission("users.edit")>
        <cfset editLink = "<a class='btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit' href='/admin/users/edit.cfm?userID=#u.USERID#&returnTo=#urlEncodedFormat(currentListUrl)#' title='Edit User' data-bs-toggle='tooltip' data-bs-title='Edit User'><i class='bi bi-pencil-square'></i></a>">
    </cfif>

    <cfset content &= "
            <td class='users-list-col-orgs'><div class='d-flex flex-wrap gap-1 align-items-start users-list-pill-stack'>#orgsHTML#</div></td>
            <td class='users-list-col-flags'><div class='d-flex flex-wrap gap-1 align-items-start users-list-pill-stack'>#flagsHTML#</div></td>
            <td class='users-list-col-actions text-end'><div class='d-flex flex-wrap gap-1 align-items-start users-list-actions'>
                #editLink#
                <a class='btn btn-sm btn-ui-go users-list-action-button users-list-action-button-view' href='/admin/users/view.cfm?userID=#u.USERID#&returnTo=#urlEncodedFormat(currentListUrl)#' title='View User' data-bs-toggle='tooltip' data-bs-title='View User'><i class='bi bi-eye'></i></a>
                #deleteLink#
                #mediaLink#</div>
            </td>
        </tr>
    ">
</cfloop>

<cfif arrayLen(pageRows) EQ 0>
    <cfset content &= "<tr><td colspan='#colCount#' class='text-center text-muted users-list-empty-state'>#noDataMsg#</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
</div>
">

<!--- Bottom pagination --->
<cfinclude template="/includes/pagination.cfm">

<cfif request.canCreateUsers()>
    <cfset content &= "
<div class='modal fade' id='quickAddUserModal' tabindex='-1' aria-labelledby='quickAddUserModalLabel' aria-hidden='true'>
    <div class='modal-dialog modal-xl modal-dialog-scrollable'>
        <div class='modal-content'>
            <div class='modal-header'>
                <h5 class='modal-title' id='quickAddUserModalLabel'><i class='bi bi-person-plus me-2'></i>Quick Add User</h5>
                <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body p-0'>
                <iframe id='quickAddUserFrame' src='/admin/users/new.cfm?embedded=1' class='w-100 border-0' style='min-height: 74vh;' loading='lazy'></iframe>
            </div>
        </div>
    </div>
</div>
">
</cfif>

<cfset content &= "</div>">
<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
(function () {
    var advancedForm = document.querySelector('.users-list-advanced-filter-form');
    if (!advancedForm) return;

    var filterPanelInput = document.getElementById('usersListFilterPanelInput');
    var filterPanelCard = document.getElementById('usersListFilterPanel');
    var filterPanelButtons = Array.prototype.slice.call(document.querySelectorAll('[data-filter-panel-trigger]'));
    var filterPanelSections = Array.prototype.slice.call(document.querySelectorAll('[data-filter-panel]'));
    var toolbarSearchForm = document.querySelector('.users-list-toolbar-search-form');
    var toolbarFilterPanelInput = toolbarSearchForm ? toolbarSearchForm.querySelector('input[name="filterPanel"]') : null;

    function setActiveFilterPanel(panelName) {
        var activePanel = panelName || '';

        if (filterPanelInput) {
            filterPanelInput.value = activePanel;
        }
        if (toolbarFilterPanelInput) {
            toolbarFilterPanelInput.value = activePanel;
        }
        if (filterPanelCard) {
            filterPanelCard.classList.toggle('d-none', !activePanel);
        }

        filterPanelButtons.forEach(function (button) {
            var isActive = button.getAttribute('data-filter-panel-trigger') === activePanel;
            button.classList.toggle('btn-ui-filter', isActive);
            button.classList.toggle('btn-ui-cancel', !isActive);
            button.setAttribute('aria-expanded', isActive ? 'true' : 'false');
        });

        filterPanelSections.forEach(function (section) {
            var isActive = section.getAttribute('data-filter-panel') === activePanel;
            section.classList.toggle('d-none', !isActive);
        });
    }

    filterPanelButtons.forEach(function (button) {
        button.addEventListener('click', function () {
            var panelName = button.getAttribute('data-filter-panel-trigger') || '';
            var nextPanel = filterPanelInput && filterPanelInput.value === panelName ? '' : panelName;
            setActiveFilterPanel(nextPanel);
        });
    });

    setActiveFilterPanel(filterPanelInput ? filterPanelInput.value : '');

    advancedForm.addEventListener('submit', function (event) {
        event.preventDefault();

        var params = new URLSearchParams();
        advancedForm.querySelectorAll('input, select, textarea').forEach(function (el) {
            if (!el.name || el.disabled) return;
            if ((el.type === 'checkbox' || el.type === 'radio') && !el.checked) return;
            params.append(el.name, el.value);
        });

        // Collapse multiple filterOrg values into a single comma-joined param
        var orgValues = [];
        advancedForm.querySelectorAll('input[name="filterOrg"]:checked').forEach(function (cb) {
            orgValues.push(cb.value);
        });
        params.delete('filterOrg');
        if (orgValues.length) {
            params.set('filterOrg', orgValues.join(','));
        }

        window.location.href = window.location.pathname + '?' + params.toString();
    });
})();

// ── Advanced Search Tab ──────────────────────────────────────────────────
(function () {
    var rowsCont        = document.getElementById('usersAdvSearchRows');
    if (!rowsCont) return;
    var applyBtn        = document.getElementById('usersAdvSearchApply');
    var clearBtn        = document.getElementById('usersAdvSearchClear');
    var badge           = document.getElementById('usersAdvSearchBadge');
    var advSearchTabBtn = document.getElementById('usersAdvSearchTabBtn');
    var filtersTabBtn   = document.getElementById('usersFiltersTabBtn');
    var filtersFooter   = document.getElementById('usersFiltersFooter');
    var advSearchFooter = document.getElementById('usersAdvSearchFooter');

    // Toggle footer sections when tabs switch
    if (advSearchTabBtn) {
        advSearchTabBtn.addEventListener('shown.bs.tab', function () {
            if (filtersFooter)   filtersFooter.classList.add('d-none');
            if (advSearchFooter) advSearchFooter.classList.remove('d-none');
            if (rowsCont.querySelectorAll('.users-adv-search-row').length === 0) addRow();
        });
    }
    if (filtersTabBtn) {
        filtersTabBtn.addEventListener('shown.bs.tab', function () {
            if (filtersFooter)   filtersFooter.classList.remove('d-none');
            if (advSearchFooter) advSearchFooter.classList.add('d-none');
        });
    }

    var FIELDS = [
        { value: 'firstname',  label: 'First Name' },
        { value: 'lastname',   label: 'Last Name' },
        { value: 'email',      label: 'Email' },
        { value: 'phone',      label: 'Phone' },
        { value: 'cougarnet',  label: 'CougarNet ID' },
        { value: 'psid',       label: 'PeopleSoft ID' },
        { value: 'flags',      label: 'Flag Name' },
        { value: 'orgs',       label: 'Organization' },
        { value: 'gradyear',   label: 'Grad Year' }
    ];

    function buildFieldOptions(selectedValue) {
        return FIELDS.map(function (f) {
            return '<option value="' + f.value + '"' + (f.value === selectedValue ? ' selected' : '') + '>' + f.label + '</option>';
        }).join('');
    }

    function createRow(isFirst, fieldVal, opVal, textVal) {
        var row = document.createElement('div');
        row.className = 'users-adv-search-row d-flex align-items-center gap-2 flex-wrap';

        var opSel = document.createElement('select');
        opSel.className = 'form-select form-select-sm users-adv-op flex-shrink-0';
        opSel.style.width = '84px';
        opSel.innerHTML = '<option value="AND"' + (opVal === 'OR' ? '' : ' selected') + '>AND</option>' +
                          '<option value="OR"'  + (opVal === 'OR' ? ' selected' : '') + '>OR</option>';
        if (isFirst) { opSel.style.visibility = 'hidden'; }
        row.appendChild(opSel);

        var fieldSel = document.createElement('select');
        fieldSel.className = 'form-select form-select-sm users-adv-field flex-shrink-0';
        fieldSel.style.width = '160px';
        fieldSel.innerHTML = buildFieldOptions(fieldVal || 'firstname');
        row.appendChild(fieldSel);

        var valueIn = document.createElement('input');
        valueIn.type = 'text';
        valueIn.className = 'form-control form-control-sm users-adv-value';
        valueIn.placeholder = 'contains...';
        valueIn.style.minWidth = '140px';
        valueIn.style.flex = '1';
        if (textVal) valueIn.value = textVal;
        valueIn.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); applySearch(); } });
        row.appendChild(valueIn);

        var addInlineBtn = document.createElement('button');
        addInlineBtn.type = 'button';
        addInlineBtn.className = 'btn btn-sm btn-ui-add users-adv-add-inline flex-shrink-0';
        addInlineBtn.innerHTML = '<i class="bi bi-plus"></i>';
        addInlineBtn.style.display = 'none';
        addInlineBtn.addEventListener('click', function () { addRow(); });
        row.appendChild(addInlineBtn);

        if (!isFirst) {
            var removeBtn = document.createElement('button');
            removeBtn.type = 'button';
            removeBtn.className = 'btn btn-sm btn-ui-delete users-adv-remove flex-shrink-0';
            removeBtn.innerHTML = '<i class="bi bi-x"></i>';
            removeBtn.addEventListener('click', function () {
                row.parentNode.removeChild(row);
                fixFirstRowOp();
                refreshRowControls();
                updateBadge();
            });
            row.appendChild(removeBtn);
        }
        return row;
    }

    function refreshRowControls() {
        var rows = rowsCont.querySelectorAll('.users-adv-search-row');
        var count = rows.length;
        rows.forEach(function (r, idx) {
            var addBtn = r.querySelector('.users-adv-add-inline');
            if (addBtn) addBtn.style.display = (idx === count - 1 && count < 4) ? '' : 'none';
        });
    }

    function fixFirstRowOp() {
        var rows = rowsCont.querySelectorAll('.users-adv-search-row');
        rows.forEach(function (r, idx) {
            var op = r.querySelector('.users-adv-op');
            if (op) op.style.visibility = idx === 0 ? 'hidden' : 'visible';
        });
    }

    function addRow(fieldVal, opVal, textVal) {
        var currentCount = rowsCont.querySelectorAll('.users-adv-search-row').length;
        if (currentCount >= 4) return;
        var row = createRow(currentCount === 0, fieldVal, opVal, textVal);
        rowsCont.appendChild(row);
        if (!textVal) row.querySelector('.users-adv-value').focus();
        refreshRowControls();
    }

    function getConditions() {
        var conditions = [];
        rowsCont.querySelectorAll('.users-adv-search-row').forEach(function (row, idx) {
            var field = row.querySelector('.users-adv-field').value;
            var value = (row.querySelector('.users-adv-value').value || '').trim();
            var op    = row.querySelector('.users-adv-op').value;
            if (value) conditions.push({ field: field, value: value, op: idx === 0 ? null : op });
        });
        return conditions;
    }

    function applySearch() {
        var conditions = getConditions();
        if (!conditions.length) return;
        var parts = [];
        conditions.forEach(function (c) {
            var safeVal = c.value.replace(/&&/g, '').replace(/\|\|/g, '').replace(/:/g, '').trim();
            if (!safeVal) return;
            if (parts.length > 0) parts.push(c.op === 'OR' ? '||' : '&&');
            parts.push(c.field + ':' + safeVal);
        });
        var searchStr = parts.join(' ');
        var params = new URLSearchParams(window.location.search);
        if (searchStr) { params.set('search', searchStr); } else { params.delete('search'); }
        params.set('page', '1');
        window.location.href = window.location.pathname + '?' + params.toString();
    }

    function clearSearch() {
        var params = new URLSearchParams(window.location.search);
        params.delete('search');
        params.set('page', '1');
        window.location.href = window.location.pathname + '?' + params.toString();
    }

    function updateBadge() {
        var count = getConditions().length;
        if (count > 0) {
            badge.textContent = count + (count === 1 ? ' condition' : ' conditions');
            badge.style.display = 'inline-block';
            if (clearBtn) clearBtn.classList.remove('d-none');
        } else {
            badge.style.display = 'none';
            if (clearBtn) clearBtn.classList.add('d-none');
        }
    }

    function parseSearchIntoRows(searchStr) {
        // Split into OR groups, then AND within each group
        var conditions = [];
        var orGroups = searchStr.split(/\s*\|\|\s*/);
        orGroups.forEach(function (orGroup, gi) {
            var andParts = orGroup.trim().split(/\s*&&\s*/);
            andParts.forEach(function (term, ai) {
                term = term.trim();
                if (!term) return;
                var op = conditions.length === 0 ? null : (ai === 0 ? 'OR' : 'AND');
                var colonIdx = term.indexOf(':');
                var field = '', value = term;
                if (colonIdx > 0) {
                    var candidate = term.substring(0, colonIdx).toLowerCase().trim();
                    if (FIELDS.some(function (f) { return f.value === candidate; })) {
                        field = candidate;
                        value = term.substring(colonIdx + 1).trim();
                    }
                }
                if (field) conditions.push({ field: field, value: value, op: op });
            });
        });
        return conditions;
    }

    applyBtn.addEventListener('click', applySearch);
    clearBtn.addEventListener('click', clearSearch);
    rowsCont.addEventListener('input', updateBadge);

    // Populate rows if the current search uses field:value syntax (tab is already active server-side)
    var currentSearch = decodeURIComponent((new URLSearchParams(window.location.search).get('search') || ''));
    if (currentSearch && (/\w+:/.test(currentSearch) || currentSearch.indexOf('&&') >= 0 || currentSearch.indexOf('||') >= 0)) {
        var parsedRows = parseSearchIntoRows(currentSearch);
        if (parsedRows.length > 0) {
            parsedRows.forEach(function (c) { addRow(c.field, c.op, c.value); });
            updateBadge();
        }
    }

    // Ensure an empty row exists when Advanced Search tab is the default active tab
    if (advSearchTabBtn && advSearchTabBtn.classList.contains('active')) {
        if (rowsCont.querySelectorAll('.users-adv-search-row').length === 0) addRow();
    }
})();
</script>
</cfsavecontent>

<cfset contentWrapperClass = "">
<cfinclude template="/admin/layout.cfm">