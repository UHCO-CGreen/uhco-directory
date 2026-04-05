<!--- ── API credentials ── --->
<cfset uhApiToken  = structKeyExists(application, "uhApiToken")  ? trim(application.uhApiToken  ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">

<cfif (uhApiToken EQ "" OR uhApiSecret EQ "") AND structKeyExists(server, "system") AND structKeyExists(server.system, "environment")>
    <cfif structKeyExists(server.system.environment, "UH_API_TOKEN")>
        <cfset uhApiToken  = trim(server.system.environment["UH_API_TOKEN"])>
    </cfif>
    <cfif structKeyExists(server.system.environment, "UH_API_SECRET")>
        <cfset uhApiSecret = trim(server.system.environment["UH_API_SECRET"])>
    </cfif>
</cfif>
<!--- ── Init API — capture verbose debug output from uh_api.cfc ── --->
<cfsavecontent variable="apiDebugOutput">
    <cftry>
        <cfset uhApi = createObject("component", "dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfset authStatus = uhApi.getAuthStatus()>
        <cfset peopleResp = uhApi.getPeople(student=true, staff=false, faculty=false, department="H0113")>
        <cfcatch>
            <cfset apiError = cfcatch.message & " — " & cfcatch.detail>
        </cfcatch>
    </cftry>
</cfsavecontent>

<!--- ── Parse results ── --->
<cfset apiPeople   = []>
<cfset parseError  = "">
<cfset apiError    = structKeyExists(variables, "apiError") ? apiError : "">
<cfset requestUrl  = (NOT len(apiError) AND structKeyExists(peopleResp, "requestUrl")) ? peopleResp.requestUrl : "">
<cfset rawBody     = (NOT len(apiError) AND structKeyExists(peopleResp, "statusCode"))  ? left(serializeJSON(peopleResp.data ?: ""), 2000) : "">

<cfif NOT len(apiError)>
    <cftry>
        <cfif left(peopleResp.statusCode, 3) EQ "200">
            <cfset rData = peopleResp.data ?: {}>
            <cfif isStruct(rData) AND structKeyExists(rData, "data") AND isArray(rData.data)>
                <cfset apiPeople = rData.data>
            <cfelseif isArray(rData)>
                <cfset apiPeople = rData>
            </cfif>
        </cfif>
        <cfcatch>
            <cfset parseError = cfcatch.message>
        </cfcatch>
    </cftry>
</cfif>

<!--- ── Build results table ── --->
<cfset resultsHtml = "">

<cfif arrayLen(apiPeople) GT 0>
    <cfset resultsHtml &= "
    <table class='table table-sm table-bordered align-middle'>
        <thead class='table-dark'>
            <tr>
                <th>##</th>
                <th>ID</th>
                <th>First Name</th>
                <th>Last Name</th>
                <th>Email</th>
                <th>Division</th>
                <th>Division Name</th>
                <th>Department</th>
                <th>Department Name</th>
                <th>Type(s)</th>
            </tr>
        </thead>
        <tbody>
    ">
    <cfloop from="1" to="#arrayLen(apiPeople)#" index="p">
        <cfset person = apiPeople[p]>
        <cfset pFirst      = EncodeForHTML(trim(person.first_name     ?: person.firstName     ?: ""))>
        <cfset pLast       = EncodeForHTML(trim(person.last_name      ?: person.lastName      ?: ""))>
        <cfset pEmail      = EncodeForHTML(trim(person.email          ?: ""))>
        <cfset pId         = EncodeForHTML(trim(person.id             ?: ""))>
        <cfset pDiv        = EncodeForHTML(trim(person.division        ?: ""))>
        <cfset pDivName    = EncodeForHTML(trim(person.division_name   ?: person.divisionName  ?: ""))>
        <cfset pDept       = EncodeForHTML(trim(person.department      ?: ""))>
        <cfset pDeptName   = EncodeForHTML(trim(person.department_name ?: person.departmentName ?: ""))>

        <cfset typeFlags = []>
        <cfif structKeyExists(person, "student")  AND person.student>  <cfset arrayAppend(typeFlags, "<span class='badge bg-primary'>student</span>")>  </cfif>
        <cfif structKeyExists(person, "staff")    AND person.staff>    <cfset arrayAppend(typeFlags, "<span class='badge bg-warning text-dark'>staff</span>")>    </cfif>
        <cfif structKeyExists(person, "faculty")  AND person.faculty>  <cfset arrayAppend(typeFlags, "<span class='badge bg-danger'>faculty</span>")>  </cfif>

        <cfset resultsHtml &= "
        <tr>
            <td>#p#</td>
            <td><code>#pId#</code></td>
            <td>#pFirst#</td>
            <td>#pLast#</td>
            <td>#pEmail#</td>
            <td>#pDiv#</td>
            <td>#pDivName#</td>
            <td>#pDept#</td>
            <td>#pDeptName#</td>
            <td>#arrayToList(typeFlags, ' ')#</td>
        </tr>
        ">
    </cfloop>
    <cfset resultsHtml &= "</tbody></table>">
<cfelse>
    <cfif NOT len(apiError) AND NOT len(parseError)>
        <cfset resultsHtml = "<p class='text-muted'>No students returned.</p>">
    </cfif>
</cfif>

<!--- ── Page content ── --->
<cfset authBadge = "">
<cfif NOT len(apiError)>
    <cfif authStatus.isAuthenticated>
        <cfset authBadge = "<span class='badge bg-success fs-6 me-2'><i class='bi bi-shield-check'></i> Authenticated</span>">
    <cfelse>
        <cfset authBadge = "<span class='badge bg-danger fs-6 me-2'><i class='bi bi-shield-x'></i> NOT Authenticated</span>">
    </cfif>
<cfelse>
    <cfset authBadge = "<span class='badge bg-danger fs-6 me-2'>Error</span>">
</cfif>

<cfset content = "
<h1>UH API — Student Pull</h1>
<div class='mb-3 d-flex align-items-center flex-wrap gap-2'>
    #authBadge#
    <span class='badge bg-secondary fs-6'>#arrayLen(apiPeople)# student(s) returned</span>
    <small class='text-muted ms-2'>student=true, staff=false, faculty=false</small>
</div>

<div class='card mb-3 border-primary'>
    <div class='card-header bg-primary text-white'><strong>Request URL</strong></div>
    <div class='card-body'>
        <code class='d-block' style='word-break:break-all;font-size:0.85rem;'>#len(requestUrl) ? EncodeForHTML(requestUrl) : '<em>URL not available (check debug panel for errors)</em>'#</code>
    </div>
</div>
">

<cfif len(apiError)>
    <cfset content &= "<div class='alert alert-danger'><strong>API Error:</strong> #EncodeForHTML(apiError)#</div>">
</cfif>
<cfif len(parseError)>
    <cfset content &= "<div class='alert alert-warning'><strong>Parse Error:</strong> #EncodeForHTML(parseError)#</div>">
</cfif>

<cfset content &= "
<div class='card mb-4'>
    <div class='card-header d-flex justify-content-between align-items-center'>
        <strong>Authentication &amp; Request Debug</strong>
        <button class='btn btn-sm btn-outline-secondary' type='button' data-bs-toggle='collapse' data-bs-target='##debugCollapse'>Toggle</button>
    </div>
    <div class='collapse' id='debugCollapse'>
        <div class='card-body bg-light' style='font-size:0.8rem;'>
            #apiDebugOutput#
        </div>
    </div>
</div>
">

<cfset content &= "
<div class='table-responsive'>
    #resultsHtml#
</div>
">

<cfinclude template="/dir/admin/layout.cfm">
