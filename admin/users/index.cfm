<!--- ============================================================
     Unified User List Page
     URL parameter: ?list=problems|all|alumni|current-students|faculty|staff|inactive
     ============================================================ --->
<cfparam name="url.list" default="problems">
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
    <cfset topLevelOrgs = []>
    <cfloop from="1" to="#arrayLen(allOrgs)#" index="iOrg">
        <cfset orgItem = allOrgs[iOrg]>
        <cfif NOT (isNumeric(orgItem.PARENTORGID) AND val(orgItem.PARENTORGID) GT 0)>
            <cfset arrayAppend(topLevelOrgs, orgItem)>
        </cfif>
    </cfloop>
</cfif>

<!--- Parse URL filters --->
<cfset selectedFlagFilter = structKeyExists(url, "filterFlag")     ? trim(url.filterFlag)     : "">
<cfset searchTerm         = structKeyExists(url, "search")         ? trim(url.search)         : "">
<cfset selectedOrgFilter  = structKeyExists(url, "filterOrg")      ? trim(url.filterOrg)      : "">
<cfset selectedGradYear   = structKeyExists(url, "filterGradYear") ? trim(url.filterGradYear) : "">
<cfset selectedLetter     = structKeyExists(url, "letter") AND len(trim(url.letter)) ? ucase(left(trim(url.letter), 1)) : "">
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
<cfif showOrgFilter AND selectedOrgFilter NEQ "">
    <cfset orgFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset u = filteredUsers[i]>
        <cfset userOrgsList = structKeyExists(allUserOrgMap, toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)] : []>
        <cfif selectedOrgFilter EQ "NOORGS">
            <cfif arrayLen(userOrgsList) EQ 0>
                <cfset arrayAppend(orgFiltered, u)>
            </cfif>
        <cfelse>
            <cfloop from="1" to="#arrayLen(userOrgsList)#" index="o">
                <cfif toString(userOrgsList[o].ORGID) EQ selectedOrgFilter>
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

<!--- Column count for no-data colspan --->
<cfset colCount = 7>
<cfif showPhoto><cfset colCount = colCount + 1></cfif>
<cfif showGradYear><cfset colCount = colCount + 1></cfif>
<cfif showTitle><cfset colCount = colCount + 1></cfif>

<!--- Precompute clear-filters link --->
<cfset hasActiveFilters = (selectedFlagFilter NEQ "" OR selectedOrgFilter NEQ "" OR selectedGradYear NEQ "" OR searchTerm NEQ "" OR selectedLetter NEQ "")>
<cfset clearLink = "?list=" & listType & "&sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage>

<!--- ======================== BUILD PAGE CONTENT ======================== --->
<cfset content = "
<div class='d-flex justify-content-between mb-4'>
    <h1><i class='bi bi-people-fill me-2'></i>#pageTitle# <span class='badge bg-secondary fs-6'>#totalRecords#</span></h1>
    <div class='d-flex gap-2'>
        <a href='/admin/users/new.cfm' class='btn btn-primary'>New User</a>
    </div>
</div>

<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2 my-0'>
            <input type='hidden' name='list'    value='#listType#'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <input type='hidden' name='page'    value='1'>
            <div class='input-group' style='min-width:220px; flex:1;'>
                <button type='button' class='btn btn-sm btn-outline-secondary' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
            </div>
            <label for='flagFilter' class='mb-0'>Flag:</label>
            <select name='filterFlag' id='flagFilter' class='form-select' style='width:auto;'>
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
">

<!--- Org filter (conditional) --->
<cfif showOrgFilter>
    <cfset content &= "
            <label for='orgFilter' class='mb-0'>Org:</label>
            <select name='filterOrg' id='orgFilter' class='form-select' style='width:auto;'>
                <option value=''>All Orgs</option>
                <option value='NOORGS'#(selectedOrgFilter == 'NOORGS' ? ' selected' : '')#>No Org</option>
    ">
    <cfloop from="1" to="#arrayLen(topLevelOrgs)#" index="iTab">
        <cfset tabOrg = topLevelOrgs[iTab]>
        <cfset content &= "<option value='#tabOrg.ORGID#'" & (selectedOrgFilter == toString(tabOrg.ORGID) ? " selected" : "") & ">#EncodeForHTML(tabOrg.ORGNAME)#</option>">
    </cfloop>
    <cfset content &= "
            </select>
    ">
</cfif>

<!--- Grad year filter (conditional) --->
<cfif showGradFilter>
    <cfset content &= "
            <label for='gradYearFilter' class='mb-0'>Grad Year:</label>
            <select name='filterGradYear' id='gradYearFilter' class='form-select' style='width:auto;'>
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
            <label for='perPageSelect' class='mb-0'>Per page:</label>
            <select name='perPage' id='perPageSelect' class='form-select' style='width:auto;'>
                <option value='10'  #(perPage == 10  ? 'selected' : '')#>10</option>
                <option value='25'  #(perPage == 25  ? 'selected' : '')#>25</option>
                <option value='50'  #(perPage == 50  ? 'selected' : '')#>50</option>
                <option value='100' #(perPage == 100 ? 'selected' : '')#>100</option>
            </select>
            <button type='submit' class='btn btn-sm btn-secondary'>Apply Filter</button>
            " & (hasActiveFilters ? "<a href='#clearLink#' class='btn btn-sm btn-warning'>Clear Filters</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "
">

<!--- Top pagination --->
<cfinclude template="/includes/pagination.cfm">

<!--- Table header --->
<cfset content &= "
<table class='table table-striped table-hover align-middle'>
    <thead class='table-dark'>
        <tr>
            <th style='width: 50px; min-width: 50px;' class='text-center'>##</th>
">
<cfif showPhoto>
    <cfset content &= "            <th style='width: 32px; min-width: 32px;' class='text-center'></th>
">
</cfif>
<cfset content &= "
            <th><a href='#helpers.getSortLink("FIRSTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' style='color: ##fff; text-decoration: none;'>First Name #(sortColumn == "FIRSTNAME" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
            <th><a href='#helpers.getSortLink("LASTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' style='color: ##fff; text-decoration: none;'>Last Name #(sortColumn == "LASTNAME" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
            <th><a href='#helpers.getSortLink("EMAIL", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' style='color: ##fff; text-decoration: none;'>Email #(sortColumn == "EMAIL" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
">
<cfif showGradYear>
    <cfset content &= "
            <th class='text-center'><a href='#helpers.getSortLink("CURRENTGRADYEAR", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter, selectedOrgFilter, listType)#' style='color: ##fff; text-decoration: none;'>Grad Year #(sortColumn == "CURRENTGRADYEAR" ? (sortDirection == "ASC" ? "&uarr;" : "&darr;") : "")#</a></th>
">
</cfif>
<cfif showTitle>
    <cfset content &= "
            <th class='text-center'>Title</th>
">
</cfif>
<cfset content &= "
            <th style='width: 210px; min-width: 210px;'>Organizational Units</th>
            <th style='width: 150px; min-width: 150px;'>Flags</th>
            <th style='width: 160px; min-width: 160px;'>Actions</th>
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
        <cfset orgsHTML &= "<span class='badge rounded-pill bg-primary text-wrap text-start' style='font-size: 0.7rem; line-height: 1.15;'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>

    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfif highlightFlags AND (userFlags[f].FLAGNAME EQ "Admin - Check" OR userFlags[f].FLAGNAME EQ "No-UH")>
            <cfset flagsHTML &= "<span class='badge rounded-pill bg-danger text-wrap text-start' style='font-size: 0.68rem; line-height: 1.15;'>#userFlags[f].FLAGNAME#</span>">
        <cfelse>
            <cfset flagsHTML &= "<span class='badge rounded-pill bg-secondary text-wrap text-start' style='font-size: 0.68rem; line-height: 1.15;'>#userFlags[f].FLAGNAME#</span>">
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
    <cfif showManageImages AND (request.hasRole("USER_MEDIA_ADMIN") OR request.hasRole("SUPER_ADMIN"))>
        <cfset mediaLink = "<a href='/admin/user-media/sources.cfm?userid=#u.USERID#' class='btn btn-sm btn-outline-primary' title='Manage Images' data-bs-toggle='tooltip' data-bs-title='Manage Images'><i class='bi bi-card-image'></i></a>">
    </cfif>

    <cfset deleteLink = "">
    <cfif request.hasRole("SUPER_ADMIN")>
        <cfset deleteLink = "<a class='btn btn-sm btn-danger' href='/admin/users/deleteConfirm.cfm?userID=#u.USERID#' title='Delete User' data-bs-toggle='tooltip' data-bs-title='Delete User'><i class='bi bi-trash'></i></a>">
    </cfif>

    <!--- Deceased icon (alumni only) --->
    <cfset deceasedIcon = "">
    <cfif showDeceased>
        <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
            <cfif lCase(trim(userFlags[f].FLAGNAME)) EQ "deceased">
                <cfset deceasedIcon = "<i class='bi bi-record-fill me-1' title='Deceased' data-bs-toggle='tooltip' data-bs-title='Deceased'></i>">
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
        <cfset content &= "<td class='text-center'>" & (len(thumbURL) ? "<img src='" & thumbURL & "' alt='thumb' style='width:32px;height:32px;object-fit:cover;border-radius:4px;'>" : "") & "</td>">
    </cfif>

    <cfset content &= "
            <td>#deceasedIcon##u.FIRSTNAME#</td>
            <td>#u.LASTNAME#</td>
            <td>#displayEmail##(displayEmailExternal ? " <span class='badge bg-warning text-dark' title='Non-UH email'>External</span>" : "")#</td>
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

    <cfset content &= "
            <td style='width: 210px; min-width: 210px;'><div class='d-flex flex-wrap gap-1 align-items-start'>#orgsHTML#</div></td>
            <td style='width: 150px; min-width: 150px;'><div class='d-flex flex-wrap gap-1 align-items-start'>#flagsHTML#</div></td>
            <td style='width: 165px; min-width: 165px;' class='text-end'><div class='d-flex flex-wrap gap-1 align-items-start'>
                <a class='btn btn-sm btn-info' href='/admin/users/edit.cfm?userID=#u.USERID#' title='Edit User' data-bs-toggle='tooltip' data-bs-title='Edit User'><i class='bi bi-pencil-square'></i></a>
                <a class='btn btn-sm btn-secondary' href='/admin/users/view.cfm?userID=#u.USERID#' title='View User' data-bs-toggle='tooltip' data-bs-title='View User'><i class='bi bi-eye'></i></a>
                #deleteLink#
                #mediaLink#</div>
            </td>
        </tr>
    ">
</cfloop>

<cfif arrayLen(pageRows) EQ 0>
    <cfset content &= "<tr><td colspan='#colCount#' class='text-center text-muted'>#noDataMsg#</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
">

<!--- Bottom pagination --->
<cfinclude template="/includes/pagination.cfm">

<cfinclude template="/admin/layout.cfm">