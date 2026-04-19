<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset orgsService = createObject("component", "cfc.organizations_service").init()>
<cfset imagesService   = createObject("component", "cfc.images_service").init()>
<cfset helpers = createObject("component", "cfc.helpers")>

<cfset pageMessage = "">
<cfset pageMessageClass = "alert-info">

<!--- Get all users --->
<cftry>
    <cfset allUsers = directoryService.listUsers()>
    <cfcatch type="any">
        <cfset allUsers = []>
        <cfset pageMessage = "Unable to load users: #cfcatch.detail ?: cfcatch.message#">
        <cfset pageMessageClass = "alert-danger">
    </cfcatch>
</cftry>

<!--- Get all flags for filter dropdown --->
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data />

<!--- Get top-level orgs (no parent) for tabs --->
<cfset allOrgsResult = orgsService.getAllOrgs()>
<cfset allOrgs = allOrgsResult.data>
<cfset topLevelOrgs = []>
<cfloop from="1" to="#arrayLen(allOrgs)#" index="iOrg">
    <cfset orgItem = allOrgs[iOrg]>
    <cfif NOT (isNumeric(orgItem.PARENTORGID) AND val(orgItem.PARENTORGID) GT 0)>
        <cfset arrayAppend(topLevelOrgs, orgItem)>
    </cfif>
</cfloop>

<cfset selectedFlagFilter = structKeyExists(url, "filterFlag") ? trim(url.filterFlag) : "">
<cfset searchTerm         = structKeyExists(url, "search")     ? trim(url.search)     : "">
<cfset selectedOrgFilter  = structKeyExists(url, "filterOrg")  ? trim(url.filterOrg)  : "">
<cfset selectedGradYear="">
<cfset selectedLetter     = structKeyExists(url, "letter") AND len(trim(url.letter)) ? ucase(left(trim(url.letter), 1)) : "">
<cfparam name="pageMessage" default="">
<cfparam name="pageMessageClass" default="alert-info">

<!--- Load flags and orgs maps once (replaces N+1 per-user queries) --->
<cfset allUserFlagMap = flagsService.getAllUserFlagMap()>
<cfset allUserOrgMap  = orgsService.getAllUserOrgMap()>
<cfset webThumbMap     = imagesService.getWebThumbMap()>

<!--- Pre-filter: keep only Faculty-Fulltime and Faculty-Adjunct --->
<cfset facPreFiltered = []>
<cfloop from="1" to="#arrayLen(allUsers)#" index="i">
    <cfset u = allUsers[i]>
    <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset isFaculty = false>
    <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
        <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct,Professor-Emeritus", uFlags[f].FLAGNAME)>
            <cfset isFaculty = true>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif isFaculty>
        <cfset arrayAppend(facPreFiltered, u)>
    </cfif>
</cfloop>
<cfset allUsers = facPreFiltered>

<!--- Apply filtering if flag is selected --->
<cfset filteredUsers = allUsers>
<cfif selectedFlagFilter != "">
    <cfset filteredUsers = []>
    
    <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
        <cfset u = allUsers[i]>
        <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>

        <cfif selectedFlagFilter == "NOFLAGS">
            <cfif arrayLen(userFlags) EQ 0>
                <cfset arrayAppend(filteredUsers, u)>
            </cfif>
        <cfelse>
            <cfset selectedFlagID = val(selectedFlagFilter)>

            <!--- Check if user has the selected flag --->
            <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
                <cfif userFlags[f].FLAGID == selectedFlagID>
                    <cfset arrayAppend(filteredUsers, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
</cfif>

<!--- Apply search filter --->
<cfinclude template="/admin/users/_search_helper.cfm">
<cfif searchTerm != "">
    <cfset searchedUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfif userMatchesSearch(filteredUsers[i], searchTerm)>
            <cfset arrayAppend(searchedUsers, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = searchedUsers>
</cfif>

<!--- Apply org filter --->
<cfif selectedOrgFilter != "">
    <cfset orgFilteredUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset u = filteredUsers[i]>
        <cfset userOrgsList = structKeyExists(allUserOrgMap, toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)] : []>
        <cfif selectedOrgFilter == "NOORGS">
            <cfif arrayLen(userOrgsList) EQ 0>
                <cfset arrayAppend(orgFilteredUsers, u)>
            </cfif>
        <cfelse>
            <cfloop from="1" to="#arrayLen(userOrgsList)#" index="o">
                <cfif toString(userOrgsList[o].ORGID) == selectedOrgFilter>
                    <cfset arrayAppend(orgFilteredUsers, u)>
                    <cfbreak>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>
    <cfset filteredUsers = orgFilteredUsers>
</cfif>

<!--- Apply letter filter --->
<cfif selectedLetter != "">
    <cfset letterFilteredUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfif len(filteredUsers[i].LASTNAME) AND ucase(left(filteredUsers[i].LASTNAME, 1)) == selectedLetter>
            <cfset arrayAppend(letterFilteredUsers, filteredUsers[i])>
        </cfif>
    </cfloop>
    <cfset filteredUsers = letterFilteredUsers>
</cfif>

<!--- Handle sorting --->
<cfset sortColumn = structKeyExists(url, "sortCol") ? url.sortCol : "LASTNAME">
<cfset sortDirection = structKeyExists(url, "sortDir") ? url.sortDir : "ASC">

<cfset filteredUsers = helpers.sortUsers(
    users = filteredUsers,
    sortColumn = sortColumn,
    sortDirection = sortDirection
)>

<!--- Server-side pagination --->
<cfset validPerPage   = [10, 25, 50, 100]>
<cfset perPage        = structKeyExists(url, "perPage") AND isNumeric(url.perPage) AND arrayContains(validPerPage, val(url.perPage)) ? val(url.perPage) : 25>
<cfset totalRecords   = arrayLen(filteredUsers)>
<cfset totalPages     = max(1, ceiling(totalRecords / perPage))>
<cfset currentPage    = structKeyExists(url, "page") AND isNumeric(url.page) ? max(1, min(val(url.page), totalPages)) : 1>
<cfset sliceStart     = ((currentPage - 1) * perPage) + 1>
<cfset sliceEnd       = min(sliceStart + perPage - 1, totalRecords)>
<cfset pageRows       = totalRecords GT 0 ? arraySlice(filteredUsers, sliceStart, min(perPage, totalRecords - sliceStart + 1)) : []>

<!--- 
HELPERS MOVED TO CFC - REMOVE THESE AFTER VERIFYING IS SAFELY WORKING

Helper function to get email (primary or secondary) 
<cffunction name="getDisplayEmail" returntype="string">
    <cfargument name="emailPrimary" type="string" required="true">
    <cfargument name="emailSecondary" type="string" required="true">
    <cfif len(emailPrimary)>
        <cfreturn emailPrimary>
    <cfelseif len(emailSecondary)>
        <cfreturn emailSecondary>
    <cfelse>
        <cfreturn "">
    </cfif>
</cffunction>

<!--- Helper function to toggle sort direction --->
<cffunction name="getSortLink" returntype="string">
    <cfargument name="column"      type="string" required="true">
    <cfargument name="currentSort" type="string" required="true">
    <cfargument name="currentDir"  type="string" required="true">
    <cfset var newDir      = (currentSort == column && currentDir == "ASC") ? "DESC" : "ASC">
    <cfset var filterParam = selectedFlagFilter != "" ? "&filterFlag=" & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var orgParam    = selectedOrgFilter  != "" ? "&filterOrg="  & urlEncodedFormat(selectedOrgFilter)  : "">
    <cfset var searchParam = searchTerm         != "" ? "&search="     & urlEncodedFormat(searchTerm)         : "">
    <cfreturn "?sortCol=" & column & "&sortDir=" & newDir & filterParam & orgParam & searchParam & "&perPage=" & perPage & "&page=1">
</cffunction>

<cffunction name="getPageLink" returntype="string">
    <cfargument name="p" type="numeric" required="true">
    <cfset var filterParam = selectedFlagFilter != "" ? "&filterFlag=" & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var orgParam    = selectedOrgFilter  != "" ? "&filterOrg="  & urlEncodedFormat(selectedOrgFilter)  : "">
    <cfset var searchParam = searchTerm         != "" ? "&search="     & urlEncodedFormat(searchTerm)         : "">
    <cfreturn "?sortCol=" & sortColumn & "&sortDir=" & sortDirection & filterParam & orgParam & searchParam & "&perPage=" & perPage & "&page=" & p>
</cffunction>
--->
<cfset content = "
<div class='d-flex justify-content-between mb-4'>
    <h1>Faculty <span class='badge bg-secondary fs-6'>#totalRecords#</span></h1>
    <div class='d-flex gap-2'>
        <a href='/admin/users/new.cfm' class='btn btn-primary'>New User</a>
    </div>
</div>

<!--- Filter Form --->
<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-0 my-0'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <input type='hidden' name='page'    value='1'>
            <div class='input-group' style='min-width:220px; flex:1;'>
                <button type='button' class='btn btn-sm btn-outline-secondary' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#searchTerm#'>
            </div>
            <label for='flagFilter' class='mb-0'>Flag:</label>
            <select name='filterFlag' id='flagFilter' class='form-select' style='width:auto;'>
                <option value=''>All Faculty</option>
                <option value='NOFLAGS'#(selectedFlagFilter == "NOFLAGS" ? " selected" : "")#>No Flags</option>
">

<!--- Add flag options to dropdown --->
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flag = allFlags[i]>
    <cfset isSelected = selectedFlagFilter == toString(flag.FLAGID)>
    <cfset content &= "
                <option value='#flag.FLAGID#'" & (isSelected ? " selected" : "") & ">#flag.FLAGNAME#</option>
">
</cfloop>

<cfset content &= "
            </select>
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
            <label for='perPageSelect' class='mb-0'>Per page:</label>
            <select name='perPage' id='perPageSelect' class='form-select' style='width:auto;'>
                <option value='10'  #(perPage == 10  ? 'selected' : '')#>10</option>
                <option value='25'  #(perPage == 25  ? 'selected' : '')#>25</option>
                <option value='50'  #(perPage == 50  ? 'selected' : '')#>50</option>
                <option value='100' #(perPage == 100 ? 'selected' : '')#>100</option>
            </select>
            <button type='submit' class='btn btn-sm btn-secondary'>Apply Filter</button>
            " & ((selectedFlagFilter != "" OR selectedOrgFilter != "" OR searchTerm != "" OR selectedLetter != "") ? "<a href='?sortCol=" & sortColumn & "&sortDir=" & sortDirection & "&perPage=" & perPage & "' class='btn btn-sm btn-warning'>Clear Filters</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "

">
<cfinclude  template="/includes/pagination.cfm">
<cfset content &= "

<table class='table table-striped table-hover align-middle'>
    <thead class='table-dark'>
        <tr>
            <th>##</th>
            <th class='text-center'>Photo</th>
            <th><a href='#helpers.getSortLink(column="FIRSTNAME", currentSort=sortColumn, currentDir=sortDirection, letter=selectedLetter)#' style='color: ##fff; text-decoration: none;'>First Name #(sortColumn == "FIRSTNAME" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#helpers.getSortLink(column="LASTNAME", currentSort=sortColumn, currentDir=sortDirection, letter=selectedLetter)#' style='color: ##fff; text-decoration: none;'>LastName #(sortColumn == "LASTNAME" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#helpers.getSortLink(column="EMAIL", currentSort=sortColumn, currentDir=sortDirection, letter=selectedLetter)#' style='color: ##fff; text-decoration: none;'>Email #(sortColumn == "EMAIL" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th>Organizational Units</th>
            <th>Flags</th>
            <th>Actions</th>
        </tr>
    </thead>

    <tbody>
" />

<cfloop from="1" to="#arrayLen(pageRows)#" index="i">
    <cfset u = pageRows[i]>
    <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset userOrgsData = structKeyExists(allUserOrgMap, toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)] : []>
    <cfset userOrgIdList = "">
    <cfset orgsHTML = "">
    <cfset flagsHTML = "">
    <cfset flagsContainer = "">

    <cfloop from="1" to="#arrayLen(userOrgsData)#" index="o">
        <cfset userOrgIdList = listAppend(userOrgIdList, userOrgsData[o].ORGID)>
        <cfset orgsHTML &= "<span class='badge bg-secondary'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>

    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfset flagsHTML &= "<span class='badge bg-secondary'>#userFlags[f].FLAGNAME#</span>">
    </cfloop>
    <cfset thumbURL = structKeyExists(webThumbMap, toString(u.USERID)) ? webThumbMap[toString(u.USERID)] : "">
    <cfset displayEmail = helpers.getDisplayEmail(u.EMAILPRIMARY, u.EMAILSECONDARY)>
    <cfif request.hasPermission("media.edit")>
        <cfset mediaLink= "
                    <a href='/admin/user-media/sources.cfm?userid=#u.USERID#'
                    class='btn btn-sm btn-outline-primary'>
                        <i class='bi bi-pencil-square me-1'></i> Manage Images
                    </a>
            ">
        </cfif>
    <cfset content &= "
            <tr data-orgids='#userOrgIdList#'>
                <td class='text-center'>#u.USERID#</td>
                <td class='text-center'>" & (len(thumbURL) ? "<img src='" & thumbURL & "' alt='thumb' style='width:32px;height:32px;object-fit:cover;border-radius:4px;'>" : "") & "</td>
                <td>#u.FIRSTNAME#</td>
                <td>#u.LASTNAME#</td>
                <td>#displayEmail#</td>
                <td>
                    
                    #orgsHTML#

                </div>
                </td>
                <td>
                <small>
                    <ul class='list-unstyled'>
                    #flagsHTML#
                    </ul>
                    </small>
                </td>
                <td>
                    <a class='btn btn-sm btn-info' href='/admin/users/edit.cfm?userID=#u.USERID#'>Edit</a>
                    <a class='btn btn-sm btn-secondary' href='/admin/users/view.cfm?userID=#u.USERID#'>View</a>
                    <a class='btn btn-sm btn-danger' href='/admin/users/deleteConfirm.cfm?userID=#u.USERID#'>Delete</a>
                    #mediaLink#
                </td>
            </tr>
    " />
</cfloop>

<cfif arrayLen(pageRows) EQ 0>
    <cfset content &= "<tr><td colspan='6' class='text-center text-muted'>No faculty found.</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
">

<!--- Pagination controls --->
<cfinclude  template="/includes/pagination.cfm">

<cfinclude template="/admin/layout.cfm">
