<cfset helpers = createObject("component", "cfc.helpers")>
<cfparam name="selectedOrgFilter" default="">
<cfparam name="listType" default="">

<cfset alphabet = []>
<cfloop from="65" to="90" index="i">
    <cfset arrayAppend(alphabet, chr(i))>
</cfloop>
<cfparam name="url.letter" default="">
<cfset selectedLetter = ucase(trim(url.letter))>
<cfset content &= "<nav class='users-list-pagination-shell navbar navbar-expand-lg bg-body-tertiary'><div class='container-fluid flex-column'>">
<cfset content &= "<div class='users-list-pagination-summary w-100 mt-2 mb-1'><span class='text-muted small'>Showing #sliceStart#&ndash;#sliceEnd# of #totalRecords# records</span></div>">
<cfset content &= "<div class='d-flex flex-wrap align-items-center w-100 gap-2'>">
<cfset content &= "<div class='me-auto'>">

<cfif totalPages GT 1>
    <!--- Windowed pagination: show at most 10 page links at a time --->
    <cfset pageWindow = 10>
    <cfset winStart   = max(1, currentPage - int(pageWindow / 2))>
    <cfset winEnd     = min(totalPages, winStart + pageWindow - 1)>
    <!--- Shift window back if near the end --->
    <cfif winEnd - winStart + 1 LT pageWindow>
        <cfset winStart = max(1, winEnd - pageWindow + 1)>
    </cfif>

    <cfset content &= "<nav class='users-list-pagination-nav' aria-label='Page navigation'><ul class='pagination pagination-sm flex-wrap mb-0 users-list-pagination-pages'>">
    <!--- Prev --->
    <cfset content &= "<li class='page-item" & (currentPage == 1 ? " disabled" : "") & "'><a class='page-link' href='" & helpers.getPageLink(currentPage - 1,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,selectedLetter,selectedOrgFilter,listType) & "'>&laquo;</a></li>">
    <!--- First page + ellipsis --->
    <cfif winStart GT 1>
        <cfset content &= "<li class='page-item'><a class='page-link' href='" & helpers.getPageLink(1,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,selectedLetter,selectedOrgFilter,listType) & "'>1</a></li>">
        <cfif winStart GT 2>
            <cfset content &= "<li class='page-item disabled'><span class='page-link'>&hellip;</span></li>">
        </cfif>
    </cfif>
    <!--- Page window --->
    <cfloop from="#winStart#" to="#winEnd#" index="p">
        <cfset content &= "<li class='page-item" & (p == currentPage ? " active" : "") & "'><a class='page-link' href='" & helpers.getPageLink(p,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,selectedLetter,selectedOrgFilter,listType) & "'>#p#</a></li>">
    </cfloop>
    <!--- Ellipsis + last page --->
    <cfif winEnd LT totalPages>
        <cfif winEnd LT totalPages - 1>
            <cfset content &= "<li class='page-item disabled'><span class='page-link'>&hellip;</span></li>">
        </cfif>
        <cfset content &= "<li class='page-item'><a class='page-link' href='" & helpers.getPageLink(totalPages,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,selectedLetter,selectedOrgFilter,listType) & "'>#totalPages#</a></li>">
    </cfif>
    <!--- Next --->
    <cfset content &= "<li class='page-item" & (currentPage == totalPages ? " disabled" : "") & "'><a class='page-link' href='" & helpers.getPageLink(currentPage + 1,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,selectedLetter,selectedOrgFilter,listType) & "'>&raquo;</a></li>">
    <cfset content &= "</ul></nav>">
</cfif>

<cfset content &= "</div>">
<cfset content &= "<div id='aTOz' class='users-list-pagination-az ms-auto'><div class='d-flex flex-wrap gap-1 my-2 users-list-pagination-letters'>">

<cfset content &= "<a class='btn btn-sm users-list-pagination-letter" & (selectedLetter EQ "" ? " active" : "") & "' href='" & helpers.getPageLink(1,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,"",selectedOrgFilter,listType) & "' aria-current='" & (selectedLetter EQ "" ? "true" : "false") & "'>All</a>">
<cfloop array="#alphabet#" index="letter">
    <cfset content &= "
        <a class='btn btn-sm users-list-pagination-letter #(selectedLetter EQ letter ? " active" : "")#'
        href='#helpers.getPageLink(1,selectedFlagFilter,selectedGradYear,searchTerm,sortColumn,sortDirection,perPage,letter,selectedOrgFilter,listType)#'
        aria-current='#(selectedLetter EQ letter ? "true" : "false")#'>
            #letter#
        </a>
    ">
</cfloop>

<cfset content &= "</div></div>">
<cfset content &= "</div>">
<cfset content &= "</div></nav>">
