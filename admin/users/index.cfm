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
<cfset aliasesDAO       = createObject("component", "dao.aliases_DAO").init()>
<cfset helpers          = createObject("component", "cfc.helpers")>
<cfif needsAcademic>
    <cfset academicService = createObject("component", "cfc.academic_service").init()>
</cfif>
<cfif needsImages>
    <cfset imagesService = createObject("component", "cfc.images_service").init()>
</cfif>

<cfset pageMessage = "">
<cfset pageMessageClass = "alert-info">

<!--- Load all users --->
<cftry>
    <cfset allUsers = directoryService.listUsers()>
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
<cfif needsAcademic>
    <cfset allAcademicMap = academicService.getAllAcademicInfoMap()>
</cfif>
<cfif needsImages>
    <cfset webThumbMap = imagesService.getWebThumbMap()>
</cfif>
<cfset emailsService  = createObject("component", "cfc.emails_service").init()>
<cfset allUserEmailMap = emailsService.getAllEmailsMap()>

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
        <cfset row.CURRENTGRADYEAR  = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "CURRENTGRADYEAR"))  ? acadData.CURRENTGRADYEAR  : "">
        <cfset row.ORIGINALGRADYEAR = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "ORIGINALGRADYEAR")) ? acadData.ORIGINALGRADYEAR : "">
        <cfset arrayAppend(mergedUsers, row)>
    </cfloop>
    <cfset filteredUsers = mergedUsers>

    <!--- Build grad year dropdown options from pre-filtered rows --->
    <cfset allGradYears = []>
    <cfset gradYearSeen = {}>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset gy = filteredUsers[i].CURRENTGRADYEAR ?: "">
        <cfif isNumeric(gy) AND val(gy) GT 0 AND NOT structKeyExists(gradYearSeen, toString(val(gy)))>
            <cfset gradYearSeen[toString(val(gy))] = true>
            <cfset arrayAppend(allGradYears, val(gy))>
        </cfif>
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
        <cfif isNumeric(filteredUsers[i].CURRENTGRADYEAR) AND val(filteredUsers[i].CURRENTGRADYEAR) EQ val(selectedGradYear)>
            <cfset arrayAppend(gradYearFiltered, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = gradYearFiltered>
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
<cfset pageUserIDs  = []>
<cfset preferredAliasMap = {}>

<cfloop array="#pageRows#" index="pageUserRow">
    <cfif structKeyExists(pageUserRow, "USERID") AND isNumeric(pageUserRow.USERID)>
        <cfset arrayAppend(pageUserIDs, val(pageUserRow.USERID))>
    </cfif>
</cfloop>

<cfif arrayLen(pageUserIDs)>
    <cfset preferredAliasMap = aliasesDAO.getPreferredAliasMap(pageUserIDs)>
</cfif>

<cfloop from="1" to="#arrayLen(pageRows)#" index="pageRowIndex">
    <cfset aliasKey = toString(val(pageRows[pageRowIndex].USERID ?: 0))>
    <cfset preferredAlias = structKeyExists(preferredAliasMap, aliasKey) ? preferredAliasMap[aliasKey] : {}>
    <cfset pageRows[pageRowIndex].RESOLVEDFIRSTNAME = len(trim(preferredAlias.FIRSTNAME ?: "")) ? trim(preferredAlias.FIRSTNAME) : trim(pageRows[pageRowIndex].FIRSTNAME ?: "")>
    <cfset pageRows[pageRowIndex].RESOLVEDLASTNAME = len(trim(preferredAlias.LASTNAME ?: "")) ? trim(preferredAlias.LASTNAME) : trim(pageRows[pageRowIndex].LASTNAME ?: "")>
</cfloop>

<!--- Column count for no-data colspan --->
<cfset colCount = 7>
<cfif showPhoto><cfset colCount = colCount + 1></cfif>
<cfif showGradYear><cfset colCount = colCount + 1></cfif>
<cfif showTitle><cfset colCount = colCount + 1></cfif>

<!--- Precompute clear-filters link --->
<cfset hasActiveFilters = (selectedFlagFilter NEQ "" OR selectedOrgFilter NEQ "" OR selectedGradYear NEQ "" OR searchTerm NEQ "" OR selectedLetter NEQ "")>
<cfset clearLink = "?list=" & listType & "&sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage>
<cfset orgFilterToggleButtonClass = orgFilterHasSelection ? "btn-primary" : "btn-outline-secondary">
<cfset orgFilterToggleButtonHTML = "">
<cfset orgFilterPanelHTML = "">
<cfif showOrgFilter>
    <cfset orgFilterToggleButtonHTML = "
            <button type='button' class='btn btn-sm users-list-org-filter-toggle #orgFilterToggleButtonClass#' data-bs-toggle='collapse' data-bs-target='##orgFilterPanel' aria-expanded='#(orgFilterHasSelection ? "true" : "false")#' aria-controls='orgFilterPanel'>
                <i class='bi bi-diagram-3 me-1'></i>Org Filters#(selectedOrgFilterCount GT 0 ? " <span class='badge text-bg-light ms-1'>" & selectedOrgFilterCount & "</span>" : "")#
            </button>
    ">
    <cfset orgFilterPanelHTML = "
            <div class='w-100 users-list-org-filter-wrap'>
                <div id='orgFilterPanel' class='collapse#(orgFilterHasSelection ? " show" : "")# mt-2'>
                    <div class='card border-light-subtle shadow-sm users-list-org-filter-panel'>
                        <div class='card-body p-3 users-list-org-filter-panel-body'>
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
                    </div>
                </div>
            </div>
    ">
</cfif>

<cfset usersListMenuHTML = "
            <div class='dropdown'>
                <button class='btn btn-sm btn-secondary text-dark dropdown-toggle' type='button' data-bs-toggle='dropdown' aria-expanded='false'>
                    <i class='bi bi-person-fill me-1'></i>Change User Type
                </button>
                <ul class='dropdown-menu dropdown-menu-end'>
                    <li><a class='dropdown-item#(listType EQ "problems" ? " active" : "")#' href='/admin/users/index.cfm?list=problems'><i class='bi bi-exclamation-triangle me-2'></i>Problem Records</a></li>
                    <li><a class='dropdown-item#(listType EQ "faculty" ? " active" : "")#' href='/admin/users/index.cfm?list=faculty'><i class='bi bi-people-fill me-2'></i>Faculty</a></li>
                    <li><a class='dropdown-item#(listType EQ "staff" ? " active" : "")#' href='/admin/users/index.cfm?list=staff'><i class='bi bi-people-fill me-2'></i>Staff</a></li>
                    <li><a class='dropdown-item#(listType EQ "current-students" ? " active" : "")#' href='/admin/users/index.cfm?list=current-students'><i class='bi bi-people-fill me-2'></i>Current Students</a></li>
                    <li><a class='dropdown-item#(listType EQ "alumni" ? " active" : "")#' href='/admin/users/index.cfm?list=alumni'><i class='bi bi-mortarboard me-2'></i>Alumni</a></li>
                    <li><a class='dropdown-item#(listType EQ "inactive" ? " active" : "")#' href='/admin/users/index.cfm?list=inactive'><i class='bi bi-person-dash me-2'></i>Inactive Records</a></li>
                    <li><a class='dropdown-item#(listType EQ "all" ? " active" : "")#' href='/admin/users/index.cfm?list=all'><i class='bi bi-list me-2'></i>All Records</a></li>
                </ul>
            </div>
">

<!--- ======================== BUILD PAGE CONTENT ======================== --->
<cfset content = "
<div class='d-flex flex-wrap align-items-center gap-2 mb-4'>
    <a href='/admin/users/search_UH_API.cfm' class='btn btn-sm btn-secondary text-dark'>
        <i class='bi bi-search me-1'></i>Search The UH API
    </a>
    <a href='/admin/users/search_UH_LDAP.cfm' class='btn btn-sm btn-secondary text-dark'>
        <i class='bi bi-person-vcard me-1'></i>Search The UH LDAP
    </a>
</div>

<div class='d-flex justify-content-between align-items-center flex-wrap gap-2 mb-4 users-list-page-header'>
    <div class='d-flex align-items-center gap-2 flex-wrap'>
        <h1 class='mb-0'><i class='bi bi-people-fill me-2'></i>#pageTitle# </h1>
        #usersListMenuHTML#
    </div>
    <div class='d-flex gap-2'>
        <a href='/admin/users/new.cfm' class='btn btn-lg btn-primary'><i class='bi bi-plus me-1'></i>New User</a>
    </div>
</div>

<div class='card mb-4 users-list-filter-card'>
    <div class='card-body users-list-filter-card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form'>
            <input type='hidden' name='list'    value='#listType#'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <input type='hidden' name='page'    value='1'>
            <div class='input-group users-list-toolbar-search'>
                <button type='button' class='btn btn-sm btn-outline-secondary users-list-help-button' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
            </div>
            <label for='flagFilter' class='mb-0 users-list-filter-label'>Flag:</label>
            <select name='filterFlag' id='flagFilter' class='form-select users-list-select-auto'>
                <option value=''>All</option>
                <option value='NOFLAGS'#(selectedFlagFilter == 'NOFLAGS' ? ' selected' : '')#>No Flags</option>
">

<!--- Flag dropdown options --->
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flag = allFlags[i]>
    <cfset content &= "<option value='#flag.FLAGID#'" & (selectedFlagFilter == toString(flag.FLAGID) ? " selected" : "") & ">#flag.FLAGNAME#</option>">
</cfloop>

<cfset content &= "
            </select>
            #orgFilterToggleButtonHTML#
">

<!--- Grad year filter (conditional) --->
<cfif showGradFilter>
    <cfset content &= "
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
    ">
</cfif>

<!--- Per page + buttons --->
<cfset content &= "
            <label for='perPageSelect' class='mb-0 users-list-filter-label'>Per page:</label>
            <select name='perPage' id='perPageSelect' class='form-select users-list-select-auto'>
                <option value='10'  #(perPage == 10  ? 'selected' : '')#>10</option>
                <option value='25'  #(perPage == 25  ? 'selected' : '')#>25</option>
                <option value='50'  #(perPage == 50  ? 'selected' : '')#>50</option>
                <option value='100' #(perPage == 100 ? 'selected' : '')#>100</option>
            </select>
            <button type='submit' class='btn btn-sm btn-secondary users-list-apply-button'>Apply Filter</button>
            " & (hasActiveFilters ? "<a href='#clearLink#' class='btn btn-sm btn-warning users-list-clear-button'>Clear Filters</a>" : "") & "
            #orgFilterPanelHTML#
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "
">

<!--- Top pagination --->
<cfinclude template="/includes/pagination.cfm">

<!--- Table header --->
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
        <cfset orgsHTML &= "<span class='badge rounded-pill bg-primary text-wrap text-start users-list-badge-org'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>

    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfif highlightFlags AND (userFlags[f].FLAGNAME EQ "Admin - Check" OR userFlags[f].FLAGNAME EQ "No-UH")>
            <cfset flagsHTML &= "<span class='badge rounded-pill bg-danger text-wrap text-start users-list-badge-flag'>#userFlags[f].FLAGNAME#</span>">
        <cfelse>
            <cfset flagsHTML &= "<span class='badge rounded-pill bg-secondary text-wrap text-start users-list-badge-flag'>#userFlags[f].FLAGNAME#</span>">
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
        <cfset mediaLink = "<a href='/admin/user-media/sources.cfm?userid=#u.USERID#' class='btn btn-sm btn-outline-primary users-list-action-button users-list-action-button-media' title='Manage Images' data-bs-toggle='tooltip' data-bs-title='Manage Images'><i class='bi bi-card-image'></i></a>">
    </cfif>

    <cfset deleteLink = "">
    <cfif request.hasPermission("users.delete")>
        <cfset deleteLink = "<a class='btn btn-sm btn-danger users-list-action-button users-list-action-button-delete' href='/admin/users/deleteConfirm.cfm?userID=#u.USERID#' title='Delete User' data-bs-toggle='tooltip' data-bs-title='Delete User'><i class='bi bi-trash'></i></a>">
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
            <td class='users-list-email-cell'>#displayEmail##(displayEmailExternal ? " <span class='badge text-dark users-list-external-badge' title='Non-UH email'>External</span>" : "")#</td>
    ">

    <cfif showGradYear>
        <cfset gradYear      = (structKeyExists(u, "CURRENTGRADYEAR") AND isNumeric(u.CURRENTGRADYEAR) AND val(u.CURRENTGRADYEAR) GT 0) ? u.CURRENTGRADYEAR : "">
        <cfset hasOrigChange = (structKeyExists(u, "ORIGINALGRADYEAR") AND isNumeric(u.ORIGINALGRADYEAR) AND val(u.ORIGINALGRADYEAR) GT 0) ? true : false>
        <cfset gradYearDisplay = len(gradYear) ? gradYear & (hasOrigChange ? " *" : "") : "">
        <cfset content &= "<td class='text-center'>#gradYearDisplay#</td>">
    </cfif>

    <cfif showTitle>
        <cfset content &= "<td class='text-center'>#u.TITLE1#</td>">
    </cfif>

    <cfset editLink = "">
    <cfif request.hasPermission("users.edit")>
        <cfset editLink = "<a class='btn btn-sm btn-info users-list-action-button users-list-action-button-edit' href='/admin/users/edit.cfm?userID=#u.USERID#&returnTo=#urlEncodedFormat(currentListUrl)#' title='Edit User' data-bs-toggle='tooltip' data-bs-title='Edit User'><i class='bi bi-pencil-square'></i></a>">
    </cfif>

    <cfset content &= "
            <td class='users-list-col-orgs'><div class='d-flex flex-wrap gap-1 align-items-start users-list-pill-stack'>#orgsHTML#</div></td>
            <td class='users-list-col-flags'><div class='d-flex flex-wrap gap-1 align-items-start users-list-pill-stack'>#flagsHTML#</div></td>
            <td class='users-list-col-actions text-end'><div class='d-flex flex-wrap gap-1 align-items-start users-list-actions'>
                #editLink#
                <a class='btn btn-sm btn-secondary users-list-action-button users-list-action-button-view' href='/admin/users/view.cfm?userID=#u.USERID#&returnTo=#urlEncodedFormat(currentListUrl)#' title='View User' data-bs-toggle='tooltip' data-bs-title='View User'><i class='bi bi-eye'></i></a>
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

<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<script>
(function () {
    var filterForm = document.querySelector('.users-list-filter-form');
    if (!filterForm) return;

    var currentUrl = window.location.href;
    history.replaceState({ usersListUrl: currentUrl }, '', currentUrl);

    filterForm.addEventListener('submit', function () {
        var params = new URLSearchParams();
        filterForm.querySelectorAll('input, select, textarea').forEach(function (el) {
            if (!el.name || el.disabled) return;
            if ((el.type === 'checkbox' || el.type === 'radio') && !el.checked) return;
            params.append(el.name, el.value);
        });

        // Collapse multiple filterOrg values into a single comma-joined param
        var orgValues = [];
        filterForm.querySelectorAll('input[name="filterOrg"]:checked').forEach(function (cb) {
            orgValues.push(cb.value);
        });
        params.delete('filterOrg');
        if (orgValues.length) {
            params.set('filterOrg', orgValues.join(','));
        }

        var newUrl = window.location.pathname + '?' + params.toString();
        history.pushState({ usersListUrl: newUrl }, '', newUrl);
    });

    window.addEventListener('popstate', function (e) {
        if (e.state && e.state.usersListUrl) {
            window.location.href = e.state.usersListUrl;
        }
    });
})();
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">