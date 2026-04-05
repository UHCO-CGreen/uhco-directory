<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>
<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>
<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
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
<cfset searchTerm = structKeyExists(url, "search") ? trim(url.search) : "">
<cfparam name="pageMessage" default="">
<cfparam name="pageMessageClass" default="alert-info">

<!--- Load flags and orgs maps once (replaces N+1 per-user queries) --->
<cfset allUserFlagMap = flagsService.getAllUserFlagMap()>
<cfset allUserOrgMap  = orgsService.getAllUserOrgMap()>

<!--- Pre-filter: keep only Staff --->
<cfset staffPreFiltered = []>
<cfloop from="1" to="#arrayLen(allUsers)#" index="i">
    <cfset u = allUsers[i]>
    <cfset uFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset isStaff = false>
    <cfloop from="1" to="#arrayLen(uFlags)#" index="f">
        <cfif uFlags[f].FLAGNAME EQ "Staff">
            <cfset isStaff = true>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif isStaff>
        <cfset arrayAppend(staffPreFiltered, u)>
    </cfif>
</cfloop>
<cfset allUsers = staffPreFiltered>

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
<cfif searchTerm != "">
    <cfset searchedUsers = []>
    <cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
        <cfset u = filteredUsers[i]>
        <cfif findNoCase(searchTerm, u.FIRSTNAME) || 
              findNoCase(searchTerm, u.LASTNAME) || 
              findNoCase(searchTerm, u.EMAILPRIMARY) || 
              findNoCase(searchTerm, u.EMAILSECONDARY)>
            <cfset arrayAppend(searchedUsers, u)>
        </cfif>
    </cfloop>
    <cfset filteredUsers = searchedUsers>
</cfif>

<!--- Handle sorting --->
<cfset sortColumn = structKeyExists(url, "sortCol") ? url.sortCol : "LASTNAME">
<cfset sortDirection = structKeyExists(url, "sortDir") ? url.sortDir : "ASC">

<!--- Sort the users array --->
<cfif sortColumn == "FIRSTNAME">
    <cfset arraySort(filteredUsers, function(a, b) {
        return compare(a.FIRSTNAME, b.FIRSTNAME) * (sortDirection == "DESC" ? -1 : 1);
    })>
<cfelseif sortColumn == "LASTNAME">
    <cfset arraySort(filteredUsers, function(a, b) {
        return compare(a.LASTNAME, b.LASTNAME) * (sortDirection == "DESC" ? -1 : 1);
    })>
<cfelseif sortColumn == "EMAIL">
    <cfset arraySort(filteredUsers, function(a, b) {
        var emailA = len(a.EMAILPRIMARY) ? a.EMAILPRIMARY : a.EMAILSECONDARY;
        var emailB = len(b.EMAILPRIMARY) ? b.EMAILPRIMARY : b.EMAILSECONDARY;
        return compare(emailA, emailB) * (sortDirection == "DESC" ? -1 : 1);
    })>
</cfif>

<!--- Helper function to get email (primary or secondary) --->
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
    <cfargument name="column" type="string" required="true">
    <cfargument name="currentSort" type="string" required="true">
    <cfargument name="currentDir" type="string" required="true">
    <cfset var newDir = (currentSort == column && currentDir == "ASC") ? "DESC" : "ASC">
    <cfset var filterParam = selectedFlagFilter != "" ? "&filterFlag=" & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var searchParam = searchTerm != "" ? "&search=" & urlEncodedFormat(searchTerm) : "">
    <cfreturn "?sortCol=" & column & "&sortDir=" & newDir & filterParam & searchParam>
</cffunction>

<cfset content = "
<div class='d-flex justify-content-between mb-4'>
    <h1>Staff</h1>
    <div class='d-flex gap-2'>
        <a href='/dir/admin/users/new.cfm' class='btn btn-primary'>New User</a>
    </div>
</div>

<!--- Filter Form --->
<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2'>
            <input type='hidden' name='sortCol' value='#sortColumn#'>
            <input type='hidden' name='sortDir' value='#sortDirection#'>
            <div style='min-width:220px; flex:1;'>
                <input type='text' name='search' id='searchInput' class='form-control' placeholder='Search by name or email...' value='#searchTerm#'>
            </div>
            <label for='flagFilter' class='mb-0'>Flag:</label>
            <select name='filterFlag' id='flagFilter' class='form-select' style='width:auto;'>
                <option value=''>All Staff</option>
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

<!--- Build org tabs HTML from top-level orgs --->
<cfset orgTabsHTML = "<nav aria-label='Organization tabs'><div class='nav nav-tabs mb-3' id='orgTabs' role='tablist'><a class='nav-link active' href='##' data-orgfilter=''>All</a>">
<cfloop from="1" to="#arrayLen(topLevelOrgs)#" index="iTab">
    <cfset tabOrg = topLevelOrgs[iTab]>
    <cfset orgTabsHTML &= "<a class='nav-link' href='##' data-orgfilter='#tabOrg.ORGID#'>#EncodeForHTML(tabOrg.ORGNAME)#</a>">
</cfloop>
<cfset orgTabsHTML &= "<a class='nav-link' href='##' data-orgfilter='NOORGS'>No Org</a></div></nav>">

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
            <button type='submit' class='btn btn-sm btn-secondary'>Apply Filter</button>
            " & ((selectedFlagFilter != "" OR searchTerm != "") ? "<a href='?sortCol=" & sortColumn & "&sortDir=" & sortDirection & "' class='btn btn-sm btn-warning'>Clear Filters</a>" : "") & "
        </form>
    </div>
</div>

" & (pageMessage != "" ? "<div class='alert " & pageMessageClass & "'>" & EncodeForHTML(pageMessage) & "</div>" : "") & "

" & orgTabsHTML & "

<table class='table table-striped table-hover'>
    <thead class='table-dark'>
        <tr>
            <th><a href='#getSortLink("FIRSTNAME", sortColumn, sortDirection)#' style='color: ##fff; text-decoration: none;'>First Name #(sortColumn == "FIRSTNAME" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("LASTNAME", sortColumn, sortDirection)#' style='color: ##fff; text-decoration: none;'>LastName #(sortColumn == "LASTNAME" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th><a href='#getSortLink("EMAIL", sortColumn, sortDirection)#' style='color: ##fff; text-decoration: none;'>Email #(sortColumn == "EMAIL" ? (sortDirection == "ASC" ? "↑" : "↓") : "")#</a></th>
            <th>Organizations</th>
            <th>Flags</th>
            <th>Actions</th>
        </tr>
    </thead>

    <tbody>
" />

<cfloop from="1" to="#arrayLen(filteredUsers)#" index="i">
    <cfset u = filteredUsers[i]>
    <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
    <cfset userOrgsData = structKeyExists(allUserOrgMap, toString(u.USERID)) ? allUserOrgMap[toString(u.USERID)] : []>
    <cfset userOrgIdList = "">
    <cfset orgsHTML = "">
    <cfset flagsHTML = "">
    <cfloop from="1" to="#arrayLen(userOrgsData)#" index="o">
        <cfset userOrgIdList = listAppend(userOrgIdList, userOrgsData[o].ORGID)>
        <cfset orgsHTML &= "<span class='badge bg-primary me-1'>#EncodeForHTML(userOrgsData[o].ORGNAME)#</span>">
    </cfloop>
    <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
        <cfset flagsHTML &= "<span class='badge bg-secondary'>#userFlags[f].FLAGNAME#</span> ">
    </cfloop>
    <cfset displayEmail = getDisplayEmail(u.EMAILPRIMARY, u.EMAILSECONDARY)>
    <cfset content &= "
            <tr data-orgids='#userOrgIdList#'>
                <td>#u.FIRSTNAME#</td>
                <td>#u.LASTNAME#</td>
                <td>#displayEmail#</td>
                <td>#orgsHTML#</td>
                <td>#flagsHTML#</td>
                <td>
                    <a class='btn btn-sm btn-info' href='/dir/admin/users/edit.cfm?userID=#u.USERID#'>Edit</a>
                    <a class='btn btn-sm btn-secondary' href='/dir/admin/users/view.cfm?userID=#u.USERID#'>View</a>
                    <a class='btn btn-sm btn-danger' href='/dir/admin/users/deleteConfirm.cfm?userID=#u.USERID#'>Delete</a>
                </td>
            </tr>
    " />
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
    var tabs = document.querySelectorAll('##orgTabs .nav-link');
    tabs.forEach(function(tab) {
        tab.addEventListener('click', function(e) {
            e.preventDefault();
            tabs.forEach(function(t) { t.classList.remove('active'); });
            this.classList.add('active');
            var filter = this.dataset.orgfilter;
            allRows().forEach(function(row) {
                if (filter === '') {
                    row.dataset.pagehidden = '0';
                } else if (filter === 'NOORGS') {
                    row.dataset.pagehidden = (row.dataset.orgids === '') ? '0' : '1';
                } else {
                    var ids = row.dataset.orgids ? row.dataset.orgids.split(',') : [];
                    row.dataset.pagehidden = (ids.indexOf(filter) >= 0) ? '0' : '1';
                }
            });
            currentPage = 1;
            applyPagination();
        });
    });
    if (sel) sel.addEventListener('change', function() { pageSize = parseInt(this.value) || 25; currentPage = 1; applyPagination(); });
    var prevEl = document.getElementById('prevBtn');
    var nextEl = document.getElementById('nextBtn');
    if (prevEl) prevEl.addEventListener('click', function() { if (currentPage > 1) { currentPage--; applyPagination(); } });
    if (nextEl) nextEl.addEventListener('click', function() { var tp = Math.ceil(visibleRows().length / pageSize) || 1; if (currentPage < tp) { currentPage++; applyPagination(); } });
    applyPagination();
})();
</script>
" />

<cfinclude template="/dir/admin/layout.cfm">
