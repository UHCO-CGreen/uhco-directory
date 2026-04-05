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
<cfif searchTerm != "">
    <cfset searchedStudents = []>
    <cfloop from="1" to="#arrayLen(filteredStudents)#" index="i">
        <cfset u = filteredStudents[i]>
        <cfif findNoCase(searchTerm, u.FIRSTNAME) ||
              findNoCase(searchTerm, u.LASTNAME)  ||
              findNoCase(searchTerm, u.EMAILPRIMARY) ||
              findNoCase(searchTerm, u.EMAILSECONDARY)>
            <cfset arrayAppend(searchedStudents, u)>
        </cfif>
    </cfloop>
    <cfset filteredStudents = searchedStudents>
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

<cfif sortColumn == "FIRSTNAME">
    <cfset arraySort(filteredStudents, function(a,b){ return compare(a.FIRSTNAME, b.FIRSTNAME) * (sortDirection=="DESC"?-1:1); })>
<cfelseif sortColumn == "LASTNAME">
    <cfset arraySort(filteredStudents, function(a,b){ return compare(a.LASTNAME, b.LASTNAME) * (sortDirection=="DESC"?-1:1); })>
<cfelseif sortColumn == "EMAIL">
    <cfset arraySort(filteredStudents, function(a,b){
        var ea = len(a.EMAILPRIMARY) ? a.EMAILPRIMARY : a.EMAILSECONDARY;
        var eb = len(b.EMAILPRIMARY) ? b.EMAILPRIMARY : b.EMAILSECONDARY;
        return compare(ea, eb) * (sortDirection=="DESC"?-1:1);
    })>
<cfelseif sortColumn == "CURRENTGRADYEAR">
    <cfset arraySort(filteredStudents, function(a,b){
        var ya = isNumeric(a.CURRENTGRADYEAR) ? val(a.CURRENTGRADYEAR) : 0;
        var yb = isNumeric(b.CURRENTGRADYEAR) ? val(b.CURRENTGRADYEAR) : 0;
        return (ya - yb) * (sortDirection=="DESC"?-1:1);
    })>
</cfif>

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
    <cfreturn "?sortCol=" & column & "&sortDir=" & newDir & filterParam & gradYrParam & searchParam>
</cffunction>

<!--- Build page content --->
<cfset content = "
<div class='d-flex justify-content-between align-items-center mb-4'>
    <h1>Current Students <span class='badge bg-secondary fs-6'>#arrayLen(filteredStudents)#</span></h1>
    <div class='d-flex gap-2'>
        <a href='/dir/admin/users/new.cfm' class='btn btn-primary'>New User</a>
    </div>
</div>

<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <div style='min-width:220px; flex:1;'>
                <input type='text' name='search' class='form-control' placeholder='Search by name or email...' value='#searchTerm#'>
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
            <label for='pageSizeSelect' class='mb-0'>Per page:</label>
            <select id='pageSizeSelect' class='form-select' style='width:auto;'>
                <option value='10'>10</option>
                <option value='25' selected>25</option>
                <option value='50'>50</option>
                <option value='100'>100</option>
                <option value='9999'>All</option>
            </select>
            <button type='submit' class='btn btn-sm btn-secondary'>Apply</button>
            " & ((selectedFlagFilter != "" OR selectedGradYear != "" OR searchTerm != "") ? "<a href='?sortCol=" & sortColumn & "&sortDir=" & sortDirection & "' class='btn btn-sm btn-warning'>Clear</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "

<table class='table table-striped table-hover'>
    <thead class='table-dark'>
        <tr>
            <th><a href='#getSortLink("FIRSTNAME", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>First Name #(sortColumn=="FIRSTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("LASTNAME", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Last Name #(sortColumn=="LASTNAME" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("EMAIL", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Email #(sortColumn=="EMAIL" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("CURRENTGRADYEAR", sortColumn, sortDirection)#' style='color:##fff;text-decoration:none;'>Grad Year #(sortColumn=="CURRENTGRADYEAR" ? (sortDirection=="ASC" ? "↑" : "↓") : "")#</a></th>
            <th>Title</th>
            <th>Organizations</th>
            <th>Flags</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
">

<cfloop from="1" to="#arrayLen(filteredStudents)#" index="i">
    <cfset u = filteredStudents[i]>
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
    <cfset content &= "
        <tr>
            <td>#u.FIRSTNAME#</td>
            <td>#u.LASTNAME#</td>
            <td>#displayEmail#</td>
            <td>#gradYearDisplay#</td>
            <td>#u.TITLE1#</td>
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

<cfset content &= "
    </tbody>
</table>
<div class='d-flex align-items-center gap-3 mt-3 mb-3'>
    <button id='prevBtn' class='btn btn-sm btn-outline-secondary' disabled>&laquo; Prev</button>
    <span id='pageInfo' class='text-muted small'></span>
    <button id='nextBtn' class='btn btn-sm btn-outline-secondary'>Next &raquo;</button>
</div>
<script>
(function() {
    var sel = document.getElementById('pageSizeSelect');
    var pageSize = sel ? (parseInt(sel.value) || 25) : 25;
    var currentPage = 1;
    function allRows() { return Array.from(document.querySelectorAll('tbody tr')); }
    function visibleRows() { return allRows().filter(function(r) { return r.dataset.pagehidden !== '1'; }); }
    function applyPagination() {
        var rows = visibleRows();
        var total = rows.length;
        var totalPages = Math.ceil(total / pageSize) || 1;
        if (currentPage > totalPages) currentPage = totalPages;
        var start = (currentPage - 1) * pageSize;
        var end = start + pageSize;
        allRows().forEach(function(r) { r.style.display = 'none'; });
        rows.forEach(function(r, idx) {
            r.style.display = (idx >= start && idx < end) ? '' : 'none';
        });
        var infoEl = document.getElementById('pageInfo');
        var prevEl = document.getElementById('prevBtn');
        var nextEl = document.getElementById('nextBtn');
        if (infoEl) infoEl.textContent = 'Page ' + currentPage + ' of ' + totalPages + ' (' + total + ' total)';
        if (prevEl) prevEl.disabled = currentPage <= 1;
        if (nextEl) nextEl.disabled = currentPage >= totalPages;
    }
    if (sel) sel.addEventListener('change', function() { pageSize = parseInt(this.value) || 25; currentPage = 1; applyPagination(); });
    var prevEl = document.getElementById('prevBtn');
    var nextEl = document.getElementById('nextBtn');
    if (prevEl) prevEl.addEventListener('click', function() { if (currentPage > 1) { currentPage--; applyPagination(); } });
    if (nextEl) nextEl.addEventListener('click', function() { var tp = Math.ceil(visibleRows().length / pageSize) || 1; if (currentPage < tp) { currentPage++; applyPagination(); } });
    applyPagination();
})();
</script>
">

<cfinclude template="/dir/admin/layout.cfm">
