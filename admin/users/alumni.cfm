<cfset flagsService    = createObject("component", "dir.cfc.flags_service").init()>
<cfset orgsService     = createObject("component", "dir.cfc.organizations_service").init()>
<cfset academicService = createObject("component", "dir.cfc.academic_service").init()>
<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>

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

<!--- Pre-filter: keep only users with Alumni flag --->
<cfset alumniRows = []>
<cfloop from="1" to="#arrayLen(allUsers)#" index="i">
    <cfset u = allUsers[i]>
    <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset isAlumni = false>
    <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
        <cfif uFlags[f].FLAGNAME EQ "Alumni">
            <cfset isAlumni = true>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif isAlumni>
        <cfset row = duplicate(u)>
        <cfset acadData = structKeyExists(allAcademicMap, toString(u.USERID)) ? allAcademicMap[toString(u.USERID)] : {}>
        <cfset row.CURRENTGRADYEAR  = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "CURRENTGRADYEAR"))  ? acadData.CURRENTGRADYEAR  : "">
        <cfset row.ORIGINALGRADYEAR = (NOT structIsEmpty(acadData) AND structKeyExists(acadData, "ORIGINALGRADYEAR")) ? acadData.ORIGINALGRADYEAR : "">
        <cfset arrayAppend(alumniRows, row)>
    </cfif>
</cfloop>

<!--- Get all flags for filter dropdown --->
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data>

<cfset selectedFlagFilter = structKeyExists(url, "filterFlag")     ? trim(url.filterFlag)     : "">
<cfset selectedGradYear   = structKeyExists(url, "filterGradYear") ? trim(url.filterGradYear) : "">
<cfset searchTerm         = structKeyExists(url, "search")         ? trim(url.search)         : "">
<cfparam name="pageMessage" default="">
<cfparam name="pageMessageClass" default="alert-info">

<!--- Apply flag filter --->
<cfset filteredAlumni = alumniRows>
<cfif selectedFlagFilter != "">
    <cfset filteredAlumni = []>
    <cfloop from="1" to="#arrayLen(alumniRows)#" index="i">
        <cfset u = alumniRows[i]>
        <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
        <cfif selectedFlagFilter == "NOFLAGS">
            <cfif arrayLen(userFlags) EQ 0>
                <cfset arrayAppend(filteredAlumni, u)>
            </cfif>
        <cfelse>
            <cfset selFlagID = val(selectedFlagFilter)>
            <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
                <cfif userFlags[f].FLAGID == selFlagID>
                    <cfset arrayAppend(filteredAlumni, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
</cfif>

<!--- Apply grad year filter --->
<cfif selectedGradYear != "" AND isNumeric(selectedGradYear)>
    <cfset gradYearFiltered = []>
    <cfloop from="1" to="#arrayLen(filteredAlumni)#" index="i">
        <cfset u = filteredAlumni[i]>
        <cfif isNumeric(u.CURRENTGRADYEAR) AND val(u.CURRENTGRADYEAR) EQ val(selectedGradYear)>
            <cfset arrayAppend(gradYearFiltered, u)>
        </cfif>
    </cfloop>
    <cfset filteredAlumni = gradYearFiltered>
</cfif>

<!--- Apply search filter --->
<cfinclude template="/dir/admin/users/_search_helper.cfm">
<cfif searchTerm != "">
    <cfset searchedAlumni = []>
    <cfloop from="1" to="#arrayLen(filteredAlumni)#" index="i">
        <cfif userMatchesSearch(filteredAlumni[i], searchTerm)>
            <cfset arrayAppend(searchedAlumni, filteredAlumni[i])>
        </cfif>
    </cfloop>
    <cfset filteredAlumni = searchedAlumni>
</cfif>

<!--- Build distinct sorted grad year list from all alumni rows --->
<cfset allGradYears = []>
<cfset gradYearSeen = {}>
<cfloop from="1" to="#arrayLen(alumniRows)#" index="i">
    <cfset gy = alumniRows[i].CURRENTGRADYEAR ?: "">
    <cfif isNumeric(gy) AND val(gy) GT 0 AND NOT structKeyExists(gradYearSeen, toString(val(gy)))>
        <cfset gradYearSeen[toString(val(gy))] = true>
        <cfset arrayAppend(allGradYears, val(gy))>
    </cfif>
</cfloop>
<cfset arraySort(allGradYears, "numeric", "desc")>

<!--- Sorting --->
<cfset sortColumn    = structKeyExists(url, "sortCol") ? url.sortCol : "LASTNAME">
<cfset sortDirection = structKeyExists(url, "sortDir") ? url.sortDir : "ASC">

<cfif sortColumn == "FIRSTNAME">
    <cfset arraySort(filteredAlumni, function(a,b){ return compare(a.FIRSTNAME, b.FIRSTNAME) * (sortDirection=="DESC"?-1:1); })>
<cfelseif sortColumn == "LASTNAME">
    <cfset arraySort(filteredAlumni, function(a,b){ return compare(a.LASTNAME, b.LASTNAME) * (sortDirection=="DESC"?-1:1); })>
<cfelseif sortColumn == "EMAIL">
    <cfset arraySort(filteredAlumni, function(a,b){
        var ea = len(a.EMAILPRIMARY) ? a.EMAILPRIMARY : a.EMAILSECONDARY;
        var eb = len(b.EMAILPRIMARY) ? b.EMAILPRIMARY : b.EMAILSECONDARY;
        return compare(ea, eb) * (sortDirection=="DESC"?-1:1);
    })>
<cfelseif sortColumn == "CURRENTGRADYEAR">
    <cfset arraySort(filteredAlumni, function(a,b){
        var ya = isNumeric(a.CURRENTGRADYEAR) ? val(a.CURRENTGRADYEAR) : 0;
        var yb = isNumeric(b.CURRENTGRADYEAR) ? val(b.CURRENTGRADYEAR) : 0;
        return (ya - yb) * (sortDirection=="DESC"?-1:1);
    })>
</cfif>

<!--- Server-side pagination --->
<cfset validPerPage   = [10, 25, 50, 100]>
<cfset perPage        = structKeyExists(url, "perPage") AND isNumeric(url.perPage) AND arrayContains(validPerPage, val(url.perPage)) ? val(url.perPage) : 25>
<cfset totalRecords   = arrayLen(filteredAlumni)>
<cfset totalPages     = max(1, ceiling(totalRecords / perPage))>
<cfset currentPage    = structKeyExists(url, "page") AND isNumeric(url.page) ? max(1, min(val(url.page), totalPages)) : 1>
<cfset sliceStart     = ((currentPage - 1) * perPage) + 1>
<cfset sliceEnd       = min(sliceStart + perPage - 1, totalRecords)>
<cfset pageRows       = totalRecords GT 0 ? arraySlice(filteredAlumni, sliceStart, min(perPage, totalRecords - sliceStart + 1)) : []>

<!--- Helpers --->
<cffunction name="getDisplayEmail" returntype="string">
    <cfargument name="emailPrimary"   type="string" required="true">
    <cfargument name="emailSecondary" type="string" required="true">
    <cfif len(emailPrimary)><cfreturn emailPrimary></cfif>
    <cfif len(emailSecondary)><cfreturn emailSecondary></cfif>
    <cfreturn "">
</cffunction>

<cffunction name="getSortLink" returntype="string">
    <cfargument name="column"      type="string" required="true">
    <cfargument name="currentSort" type="string" required="true">
    <cfargument name="currentDir"  type="string" required="true">
    <cfset var newDir      = (currentSort == column && currentDir == "ASC") ? "DESC" : "ASC">
    <cfset var filterParam = selectedFlagFilter != "" ? "&filterFlag="     & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var gradYrParam = selectedGradYear   != "" ? "&filterGradYear=" & urlEncodedFormat(selectedGradYear)   : "">
    <cfset var searchParam = searchTerm         != "" ? "&search="         & urlEncodedFormat(searchTerm)         : "">
    <cfreturn "?sortCol=" & column & "&sortDir=" & newDir & filterParam & gradYrParam & searchParam & "&perPage=" & perPage & "&page=1">
</cffunction>

<cffunction name="getPageLink" returntype="string">
    <cfargument name="p" type="numeric" required="true">
    <cfset var filterParam = selectedFlagFilter != "" ? "&filterFlag="     & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var gradYrParam = selectedGradYear   != "" ? "&filterGradYear=" & urlEncodedFormat(selectedGradYear)   : "">
    <cfset var searchParam = searchTerm         != "" ? "&search="         & urlEncodedFormat(searchTerm)         : "">
    <cfreturn "?sortCol=" & sortColumn & "&sortDir=" & sortDirection & filterParam & gradYrParam & searchParam & "&perPage=" & perPage & "&page=" & p>
</cffunction>

<!--- Build page content --->
<cfset content = "
<div class='d-flex justify-content-between align-items-center mb-4'>
    <h1>Alumni <span class='badge bg-secondary fs-6'>#totalRecords#</span></h1>
    <div class='d-flex gap-2'>
        <a href='/dir/admin/users/new.cfm' class='btn btn-primary'>New User</a>
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
            " & ((selectedFlagFilter != "" OR selectedGradYear != "" OR searchTerm != "") ? "<a href='?sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage & "' class='btn btn-sm btn-warning'>Clear</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "

<table class='table table-striped table-hover align-middle'>
    <thead class='table-dark'>
        <tr>
            <th><a href='#getSortLink("FIRSTNAME", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>First Name #(sortColumn=="FIRSTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("LASTNAME", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Last Name #(sortColumn=="LASTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("EMAIL", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Email #(sortColumn=="EMAIL" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("CURRENTGRADYEAR", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Grad Year #(sortColumn=="CURRENTGRADYEAR" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th>Organizations</th>
            <th>Flags</th>
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
    <cfset displayEmail = getDisplayEmail(u.EMAILPRIMARY, u.EMAILSECONDARY)>
    <cfset gradYear     = (isNumeric(u.CURRENTGRADYEAR)  AND val(u.CURRENTGRADYEAR)  GT 0) ? u.CURRENTGRADYEAR  : "">
    <cfset hasOrigChange = (isNumeric(u.ORIGINALGRADYEAR) AND val(u.ORIGINALGRADYEAR) GT 0) ? true : false>
    <cfset gradYearDisplay = len(gradYear) ? gradYear & (hasOrigChange ? " *" : "") : "">
    <cfset isDeceased = false>
    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfif lCase(trim(userFlags[f].FLAGNAME)) EQ "deceased">
            <cfset isDeceased = true>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfset deceasedIcon = isDeceased ? "<i class='bi bi-record-fill me-1' title='Deceased' data-bs-toggle='tooltip' data-bs-title='Deceased'></i>" : "">
    <cfset content &= "
        <tr>
            <td>#deceasedIcon##u.FIRSTNAME#</td>
            <td>#u.LASTNAME#</td>
            <td>#displayEmail#</td>
            <td>#gradYearDisplay#</td>
            <td>#orgsHTML#</td>
            <td>#flagsHTML#</td>
            <td>
                <a class='btn btn-sm btn-info'      href='/dir/admin/users/edit.cfm?userID=#u.USERID#'>Edit</a>
                <a class='btn btn-sm btn-secondary' href='/dir/admin/users/view.cfm?userID=#u.USERID#'>View</a>
                <a class='btn btn-sm btn-danger'    href='/dir/admin/users/deleteConfirm.cfm?userID=#u.USERID#'>Delete</a>
            </td>
        </tr>
    ">
</cfloop>

<cfif arrayLen(pageRows) EQ 0>
    <cfset content &= "<tr><td colspan='7' class='text-center text-muted'>No alumni found.</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
">

<!--- Pagination controls --->
<cfif totalPages GT 1>
    <cfset content &= "<nav><ul class='pagination pagination-sm flex-wrap'>">
    <cfset content &= "<li class='page-item" & (currentPage == 1 ? " disabled" : "") & "'><a class='page-link' href='" & getPageLink(currentPage - 1) & "'>&laquo;</a></li>">
    <cfloop from="1" to="#totalPages#" index="p">
        <cfset content &= "<li class='page-item" & (p == currentPage ? " active" : "") & "'><a class='page-link' href='" & getPageLink(p) & "'>#p#</a></li>">
    </cfloop>
    <cfset content &= "<li class='page-item" & (currentPage == totalPages ? " disabled" : "") & "'><a class='page-link' href='" & getPageLink(currentPage + 1) & "'>&raquo;</a></li>">
    <cfset content &= "</ul></nav>">
</cfif>

<cfset content &= "<p class='text-muted small'>Showing #sliceStart#&##8211;#sliceEnd# of #totalRecords# alumni</p>">

<cfinclude template="/dir/admin/layout.cfm">
