<cfset flagsService    = createObject("component", "cfc.flags_service").init()>
<cfset orgsService     = createObject("component", "cfc.organizations_service").init()>
<cfset academicService = createObject("component", "cfc.academic_service").init()>
<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset imagesService   = createObject("component", "cfc.images_service").init()>
<cfset helpers = createObject("component", "cfc.helpers")>

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

<!--- Load all maps once (1 query each) --->
<cfset allAcademicMap  = academicService.getAllAcademicInfoMap()>
<cfset allUserFlagMap  = flagsService.getAllUserFlagMap()>
<cfset allUserOrgMap   = orgsService.getAllUserOrgMap()>
<cfset webThumbMap     = imagesService.getWebThumbMap()>

<!--- Pre-filter: keep only users with Current-Student flag --->
<cfset studentRows = []>
<cfloop from="1" to="#arrayLen(allUsers)#" index="i">
    <cfset u = allUsers[i]>
    <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset isCurrentStudent = false>
    <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
        <cfif uFlags[f].FLAGNAME EQ "Current-Student">
            <cfset isCurrentStudent = true>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif isCurrentStudent>
        <cfset row = duplicate(u)>
        <cfset acadData = structKeyExists(allAcademicMap, toString(u.USERID)) ? allAcademicMap[toString(u.USERID)] : {}>
        <cfset row.CURRENTGRADYEAR  = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "CURRENTGRADYEAR"))  ? acadData.CURRENTGRADYEAR  : "">
        <cfset row.ORIGINALGRADYEAR = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "ORIGINALGRADYEAR")) ? acadData.ORIGINALGRADYEAR : "">
        <cfset arrayAppend(studentRows, row)>
    </cfif>
</cfloop>

<!--- Get all flags for filter dropdown --->
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data>

<cfset selectedFlagFilter = structKeyExists(url, "filterFlag")     ? trim(url.filterFlag)     : "">
<cfset selectedGradYear   = structKeyExists(url, "filterGradYear") ? trim(url.filterGradYear) : "">
<cfset searchTerm         = structKeyExists(url, "search")         ? trim(url.search)         : "">
<cfset selectedLetter     = structKeyExists(url, "letter") AND len(trim(url.letter)) ? ucase(left(trim(url.letter), 1)) : "">
<cfparam name="pageMessage" default="">
<cfparam name="pageMessageClass" default="alert-info">

<!--- Apply flag filter --->
<cfset filteredStudents = studentRows>
<cfif selectedFlagFilter != "">
    <cfset filteredStudents = []>
    <cfloop from="1" to="#arrayLen(studentRows)#" index="i">
        <cfset u = studentRows[i]>
        <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
        <cfif selectedFlagFilter == "NOFLAGS">
            <cfif arrayLen(userFlags) EQ 0>
                <cfset arrayAppend(filteredStudents, u)>
            </cfif>
        <cfelse>
            <cfset selFlagID = val(selectedFlagFilter)>
            <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
                <cfif userFlags[f].FLAGID == selFlagID>
                    <cfset arrayAppend(filteredStudents, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
</cfif>

<!--- Apply grad year filter --->
<cfif selectedGradYear != "" AND isNumeric(selectedGradYear)>
    <cfset gradYearFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredStudents)#" index="i">
        <cfset u = filteredStudents[i]>
        <cfif isNumeric(u.CURRENTGRADYEAR) AND val(u.CURRENTGRADYEAR) EQ val(selectedGradYear)>
            <cfset arrayAppend(gradYearFiltered, u)>
        </cfif>
    </cfloop>
    <cfset filteredStudents = gradYearFiltered>
</cfif>

<!--- Apply search filter --->
<cfinclude template="/admin/users/_search_helper.cfm">
<cfif searchTerm != "">
    <cfset searchedStudents = []>
    <cfloop from="1" to="#arrayLen(filteredStudents)#" index="i">
        <cfif userMatchesSearch(filteredStudents[i], searchTerm)>
            <cfset arrayAppend(searchedStudents, filteredStudents[i])>
        </cfif>
    </cfloop>
    <cfset filteredStudents = searchedStudents>
</cfif>

<!--- Apply letter filter --->
<cfif selectedLetter != "">
    <cfset letterFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredStudents)#" index="i">
        <cfif len(filteredStudents[i].LASTNAME) AND ucase(left(filteredStudents[i].LASTNAME, 1)) == selectedLetter>
            <cfset arrayAppend(letterFiltered, filteredStudents[i])>
        </cfif>
    </cfloop>
    <cfset filteredStudents = letterFiltered>
</cfif>

<!--- Build distinct sorted grad year list from all student rows --->
<cfset allGradYears = []>
<cfset gradYearSeen = {}>
<cfloop from="1" to="#arrayLen(studentRows)#" index="i">
    <cfset gy = studentRows[i].CURRENTGRADYEAR ?: "">
    <cfif isNumeric(gy) AND val(gy) GT 0 AND NOT structKeyExists(gradYearSeen, toString(val(gy)))>
        <cfset gradYearSeen[toString(val(gy))] = true>
        <cfset arrayAppend(allGradYears, val(gy))>
    </cfif>
</cfloop>
<cfset arraySort(allGradYears, "numeric", "desc")>

<!--- Sorting --->
<cfset sortColumn    = structKeyExists(url, "sortCol") ? url.sortCol : "LASTNAME">
<cfset sortDirection = structKeyExists(url, "sortDir") ? url.sortDir : "ASC">

<cfset filteredStudents = helpers.sortUsers(
    users = filteredStudents,
    sortColumn = sortColumn,
    sortDirection = sortDirection
)>

<!--- Server-side pagination --->
<cfset validPerPage   = [10, 25, 50, 100]>
<cfset perPage        = structKeyExists(url, "perPage") AND isNumeric(url.perPage) AND arrayContains(validPerPage, val(url.perPage)) ? val(url.perPage) : 25>
<cfset totalRecords   = arrayLen(filteredStudents)>
<cfset totalPages     = max(1, ceiling(totalRecords / perPage))>
<cfset currentPage    = structKeyExists(url, "page") AND isNumeric(url.page) ? max(1, min(val(url.page), totalPages)) : 1>
<cfset sliceStart     = ((currentPage - 1) * perPage) + 1>
<cfset sliceEnd       = min(sliceStart + perPage - 1, totalRecords)>
<cfset pageRows       = totalRecords GT 0 ? arraySlice(filteredStudents, sliceStart, min(perPage, totalRecords - sliceStart + 1)) : []>

<!--- Build page content --->
<cfset content = "
<div class='d-flex justify-content-between align-items-center mb-4'>
    <h1>Current Students <span class='badge bg-secondary fs-6'>#totalRecords#</span></h1>
    <div class='d-flex gap-2'>
        <a href='/admin/users/new.cfm' class='btn btn-primary'>New User</a>
    </div>
</div>

<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2 my-0'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <input type='hidden' name='page'    value='1'>
            <div class='input-group' style='min-width:220px; flex:1;'>
                <button type='button' class='btn btn-sm btn-outline-secondary' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
            </div>
            
            <label for='flagFilter' class='mb-0'>Flag:</label>
            <select name='filterFlag' id='flagFilter' class='form-select' style='width:auto;'>
                <option value=''>All Flags</option>
                <option value='NOFLAGS'#(selectedFlagFilter == 'NOFLAGS' ? ' selected' : '')#>No Flags</option>
">



<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flag = allFlags[i]>
    <cfset content &= "<option value='#flag.FLAGID#'" & (selectedFlagFilter == toString(flag.FLAGID) ? " selected" : "") & ">#flag.FLAGNAME#</option>">
</cfloop>

<cfset content &= "
            </select>
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
            <label for='perPageSelect' class='mb-0'>Per page:</label>
            <select name='perPage' id='perPageSelect' class='form-select' style='width:auto;'>
                <option value='10'  #(perPage == 10  ? 'selected' : '')#>10</option>
                <option value='25'  #(perPage == 25  ? 'selected' : '')#>25</option>
                <option value='50'  #(perPage == 50  ? 'selected' : '')#>50</option>
                <option value='100' #(perPage == 100 ? 'selected' : '')#>100</option>
            </select>
            <button type='submit' class='btn btn-sm btn-secondary'>Apply</button>
            
            " & ((selectedFlagFilter != "" OR selectedGradYear != "" OR searchTerm != "" OR selectedLetter != "") ? "<a href='?sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage & "' class='btn btn-sm btn-warning'>Clear</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "
">


<!--- Pagination controls --->
<cfinclude  template="/includes/pagination.cfm">


<cfset content &= "
<table class='table table-striped table-hover align-middle'>
    <thead class='table-dark'>
        <tr>
            <th class='text-center'>##</th>
            <th class='text-center'>Photo</th>
            <th><a href='#helpers.getSortLink("FIRSTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter)#' style='color:##fff;text-decoration:none;'>First Name #(sortColumn=="FIRSTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#helpers.getSortLink("LASTNAME", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter)#' style='color:##fff;text-decoration:none;'>Last Name #(sortColumn=="LASTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#helpers.getSortLink("EMAIL", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter)#' style='color:##fff;text-decoration:none;'>Email #(sortColumn=="EMAIL" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th class='text-center'><a href='#helpers.getSortLink("CURRENTGRADYEAR", sortColumn, sortDirection, selectedFlagFilter, selectedGradYear, searchTerm, sortColumn, sortDirection, perPage, selectedLetter)#' style='color:##fff;text-decoration:none;'>Grad Year #(sortColumn=="CURRENTGRADYEAR" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th class='text-center'>Title</th>
            <th class='text-center'>Organizational Units</th>
            <th class='text-center'>Flags</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
">

<cfloop from="1" to="#arrayLen(pageRows)#" index="i">
    <cfset u = pageRows[i]>
    <cfset userFlags    = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset userOrgsData = structKeyExists(allUserOrgMap,  toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)]  : []>
    <cfset flagsHTML = "">
    <cfset orgsHTML  = "">
    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfset flagsHTML &= "<span class='badge bg-secondary me-1'>#userFlags[f].FLAGNAME#</span>">
    </cfloop>
    <cfloop from="1" to="#arrayLen(userOrgsData)#" index="o">
        <cfset orgsHTML &= "<span class='badge bg-primary me-1'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>
    <cfset displayEmail = helpers.getDisplayEmail(u.EMAILPRIMARY, u.EMAILSECONDARY)>
    <cfset gradYear      = (isNumeric(u.CURRENTGRADYEAR)  AND val(u.CURRENTGRADYEAR)  GT 0) ? u.CURRENTGRADYEAR  : "">
    <cfset hasOrigChange = (isNumeric(u.ORIGINALGRADYEAR) AND val(u.ORIGINALGRADYEAR) GT 0) ? true : false>
    <cfset gradYearDisplay = len(gradYear) ? gradYear & (hasOrigChange ? " *" : "") : "">
    <cfset thumbURL = structKeyExists(webThumbMap, toString(u.USERID)) ? webThumbMap[toString(u.USERID)] : "">
    <cfif request.hasPermission("media.edit")>
        <cfset mediaLink= "
                    <a href='/admin/user-media/sources.cfm?userid=#u.USERID#'
                    class='btn btn-sm btn-outline-primary'>
                        <i class='bi bi-pencil-square me-1'></i> Manage Images
                    </a>
            ">
        </cfif>
    <cfset content &= "
        <tr>
            <td class='text-center'>#u.USERID#</td>
            <td class='text-center'>" & (len(thumbURL) ? "<img src='" & thumbURL & "' alt='thumb' style='width:32px;height:32px;object-fit:cover;border-radius:4px;'>" : "") & "</td>
            <td>#u.FIRSTNAME#</td>
            <td>#u.LASTNAME#</td>
            <td>#displayEmail#</td>
            <td class='text-center'>#gradYearDisplay#</td>
            <td class='text-center'>#u.TITLE1#</td>
            <td class='text-center bg-light'>#orgsHTML#</td>
            <td class='text-center bg-light'>#flagsHTML#</td>
            <td>
                <a class='btn btn-sm btn-info'      href='/admin/users/edit.cfm?userID=#u.USERID#'>Edit</a>
                <a class='btn btn-sm btn-secondary' href='/admin/users/view.cfm?userID=#u.USERID#'>View</a>
                <a class='btn btn-sm btn-danger'    href='/admin/users/deleteConfirm.cfm?userID=#u.USERID#'>Delete</a>
                #mediaLink#
            </td>
        </tr>
    ">
</cfloop>

<cfif arrayLen(pageRows) EQ 0>
    <cfset content &= "<tr><td colspan='9' class='text-center text-muted'>No students found.</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
">

<cfinclude  template="/includes/pagination.cfm">

<cfinclude template="/admin/layout.cfm">
