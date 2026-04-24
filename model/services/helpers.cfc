<cfcomponent displayname="DirectoryHelpers" output="false" hint="CFC of Helper functions">
<cffunction name="init" returntype="any">
    <cfreturn this>
</cffunction>
<cffunction name="getDisplayEmail" returntype="string">
    <cfargument name="emailPrimary"   type="string" required="true">
    <cfif len(emailPrimary)><cfreturn emailPrimary></cfif>
    <cfreturn "">
</cffunction>

<cffunction name="getSortLink" returntype="string">
    <cfargument name="column"      type="string" required="true">
    <cfargument name="currentSort" type="string" required="true">
    <cfargument name="currentDir"  type="string" required="true">
    <cfargument name="selectedFlagFilter" type="string" required="false" default="">
    <cfargument name="selectedGradYear" type="string" required="false" default="">
    <cfargument name="searchTerm" type="string" required="false" default="">
    <cfargument name="sortColumn" type="string" required="false" default="LASTNAME">
    <cfargument name="sortDirection" type="string" required="false" default="ASC">
    <cfargument name="perPage" type="numeric" required="false" default="10">
    <cfargument name="letter" type="string" required="false" default="">
    <cfargument name="selectedOrgFilter" type="string" required="false" default="">
    <cfargument name="list" type="string" required="false" default="">
    <cfset var newDir      = (currentSort == column && currentDir == "ASC") ? "DESC" : "ASC">
    <cfset var listParam   = list                != "" ? "list="            & urlEncodedFormat(list) & "&" : "">
    <cfset var filterParam = selectedFlagFilter  != "" ? "&filterFlag="     & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var orgParam    = selectedOrgFilter   != "" ? "&filterOrg="      & urlEncodedFormat(selectedOrgFilter)  : "">
    <cfset var gradYrParam = selectedGradYear    != "" ? "&filterGradYear=" & urlEncodedFormat(selectedGradYear)   : "">
    <cfset var searchParam = searchTerm          != "" ? "&search="         & urlEncodedFormat(searchTerm)         : "">
    <cfset var letterParam = letter              != "" ? "&letter="         & urlEncodedFormat(letter)             : "">
    <cfreturn "?" & listParam & "sortCol=" & column & "&sortDir=" & newDir & filterParam & orgParam & gradYrParam & searchParam & letterParam & "&perPage=" & perPage & "&page=1">
</cffunction>

<cffunction name="getPageLink" returntype="string">
    <cfargument name="p" type="numeric" required="true">
    <cfargument name="selectedFlagFilter" type="string" required="false" default="">
    <cfargument name="selectedGradYear" type="string" required="false" default="">
    <cfargument name="searchTerm" type="string" required="false" default="">
    <cfargument name="sortColumn" type="string" required="false" default="LASTNAME">
    <cfargument name="sortDirection" type="string" required="false" default="ASC">
    <cfargument name="perPage" type="numeric" required="false" default="10">
    <cfargument name="letter" type="string" required="false" default="">
    <cfargument name="selectedOrgFilter" type="string" required="false" default="">
    <cfargument name="list" type="string" required="false" default="">
    <cfset var listParam   = list                != "" ? "list="            & urlEncodedFormat(list) & "&" : "">
    <cfset var filterParam = selectedFlagFilter  != "" ? "&filterFlag="     & urlEncodedFormat(selectedFlagFilter) : "">
    <cfset var orgParam    = selectedOrgFilter   != "" ? "&filterOrg="      & urlEncodedFormat(selectedOrgFilter)  : "">
    <cfset var gradYrParam = selectedGradYear    != "" ? "&filterGradYear=" & urlEncodedFormat(selectedGradYear)   : "">
    <cfset var searchParam = searchTerm          != "" ? "&search="         & urlEncodedFormat(searchTerm)         : "">
    <cfset var letterParam = letter              != "" ? "&letter="         & urlEncodedFormat(letter)             : "">
    <cfreturn "?" & listParam & "sortCol=" & sortColumn & "&sortDir=" & sortDirection & filterParam & orgParam & gradYrParam & searchParam & letterParam & "&perPage=" & perPage & "&page=" & p>
</cffunction>



    <!---
        Sort an array of user structs
        @users         Array of user structs
        @sortColumn    FIRSTNAME | LASTNAME | EMAIL
        @sortDirection ASC | DESC
    --->
    <cffunction name="sortUsers"
                access="public"
                returntype="array"
                output="false">

        <cfargument name="users" type="array" required="true">
        <cfargument name="sortColumn" type="string" required="false" default="LASTNAME">
        <cfargument name="sortDirection" type="string" required="false" default="ASC">

        <!--- Normalize inputs --->
        <cfset var directionMultiplier =
            (ucase(arguments.sortDirection) EQ "DESC" ? -1 : 1)>
        <cfset var column = ucase(arguments.sortColumn)>

        <!--- FIRST NAME --->
        <cfif column EQ "FIRSTNAME">
            <cfset arraySort(arguments.users, function(a, b) {
                return compare(a.FIRSTNAME, b.FIRSTNAME) * directionMultiplier;
            })>

        <!--- EMAIL (PRIMARY fallback to SECONDARY) --->
        <cfelseif column EQ "EMAIL">
            <cfset arraySort(arguments.users, function(a, b) {
                var emailA = len(a.EMAILPRIMARY) ? a.EMAILPRIMARY : '';
                var emailB = len(b.EMAILPRIMARY) ? b.EMAILPRIMARY : '';
                return compare(emailA, emailB) * directionMultiplier;
            })>

        <cfelseif column EQ "CURRENTGRADYEAR">
            <cfset arraySort(arguments.users, function(a,b){
                var ya = isNumeric(a.CURRENTGRADYEAR) ? val(a.CURRENTGRADYEAR) : 0;
                var yb = isNumeric(b.CURRENTGRADYEAR) ? val(b.CURRENTGRADYEAR) : 0;
                return (ya - yb) * (sortDirection=="DESC"?-1:1);
            })>

        <!--- LAST NAME (default) --->
        <cfelse>
            <cfset arraySort(arguments.users, function(a, b) {
                return compare(a.LASTNAME, b.LASTNAME) * directionMultiplier;
            })>
        </cfif>

        <cfreturn arguments.users>

    </cffunction>

    <!---<cffunction name="formatOrgs" access="public" returntype="string" output="false">
        <cfargument name="items" type="array" required="true">
        <cfargument name="labelKey" type="string" default="ORGNAME">
        <cfargument name="ulClass" type="string" default="list-unstyled mb-0">
        <cfargument name="liClass" type="string" default="">
        <cfargument name="container" type="boolean" default="true">

        <cfset var buffer = "">
        <cfset var total = arrayLen(arguments.items)>
        <cfset var i = 0>
        <cfset var j = 0>
        <cfset var item = "">

        <cfif total EQ 0>
            <cfreturn buffer>
        </cfif>

        <cfif arguments.container>
            <cfset buffer &= '<div class="container">'>
        </cfif>

        <cfset buffer &= '<div class="row g-3">'>


        <!--- Step through array in groups of 3 (per column) --->
        <cfloop from="1" to="#total#" index="i" step="3">

            <!--- Start a new row every 6 items --->
            <cfif ((i - 1) MOD 6 EQ 0) AND (i NEQ 1)>
                <cfset buffer &= '</div><div class="row g-3">'>
            </cfif>

            <cfset buffer &= '<div class="col-12 col-md-6">'>
            <cfset buffer &= '<ul class="#encodeForHTML(arguments.ulClass)#">>

            <!--- Output up to 3 items --->
            <cfloop from="#i#" to="#min(i + 2, total)#" index="j">
                <cfset item = arguments.items[j]>

                
                <cfif structKeyExists(item, arguments.labelKey)>
                    <cfset buffer = buffer &
                        '<li class="' &
                        encodeForHTMLAttribute(arguments.liClass) &
                        '">' &
                        encodeForHTML(item[arguments.labelKey]) &
                        '</li>'>
                </cfif>

            </cfloop>

            <cfset buffer &= '</ul></div>'>

        </cfloop>

        <cfset buffer &= '</div>'>

        <cfif arguments.container>
            <cfset buffer &= '</div>'>
        </cfif>

        <cfreturn buffer>
    </cffunction>--->

<!---
    getMemorialDayDate — Returns the Memorial Day date (last Monday of May)
    for the given year.
    @year  Calendar year (e.g. 2026)
    @returns  Date object for Memorial Day of that year
--->
<cffunction name="getMemorialDayDate" access="public" returntype="date" output="false">
    <cfargument name="year" type="numeric" required="true">
    <cfset var may31    = createDate(arguments.year, 5, 31)>
    <cfset var dow      = dayOfWeek(may31)>
    <cfset var daysBack = (dow - 2 + 7) MOD 7>
    <cfreturn dateAdd("d", -daysBack, may31)>
</cffunction>

<!---
    getGradYearWindow — Returns a struct with the current 4-year graduation
    window based on the Memorial Day boundary.
    Before Memorial Day: startYear = currentYear  (e.g. 2026 → 2026-2029)
    On/After Memorial Day: startYear = currentYear + 1  (e.g. 2027 → 2027-2030)
    @returns  Struct { memorialDay, startYear, endYear, graduatingYear }
--->
<cffunction name="getGradYearWindow" access="public" returntype="struct" output="false">
    <cfset var currentYear  = year(now())>
    <cfset var memDay       = getMemorialDayDate(currentYear)>
    <cfset var start        = (now() LT memDay) ? currentYear : currentYear + 1>
    <cfreturn {
        memorialDay    = memDay,
        startYear      = start,
        endYear        = start + 3,
        graduatingYear = start
    }>
</cffunction>

</cfcomponent>