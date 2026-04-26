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
<!--- ── Search parameters from form ── --->
<cfset paramQ          = structKeyExists(url, "q")          ? trim(url.q)          : "">
<cfset paramDivision   = structKeyExists(url, "division")   ? trim(url.division)   : "">
<cfset paramDepartment = structKeyExists(url, "department") ? trim(url.department) : "H0113">
<!---<cfset paramStaff       = structKeyExists(url, "staff")      ? (url.staff EQ "true") : false>
<cfset paramFaculty     = structKeyExists(url, "faculty")    ? (url.faculty EQ "true") : false>
<cfset paramStudent     = structKeyExists(url, "student")    ? (url.student EQ "true") : true>--->

<!--- Default values --->
<cfset paramStaff   = false>
<cfset paramFaculty = false>
<cfset paramStudent = false>

<cfif NOT structKeyExists(url, "staff")
   AND NOT structKeyExists(url, "faculty")
   AND NOT structKeyExists(url, "student")>
    <!--- initial page load defaults --->
    <cfset paramStudent = true>
<cfelse>
    <cfset paramStaff   = structKeyExists(url, "staff")      ? (url.staff EQ "true") : false>
    <cfset paramFaculty = structKeyExists(url, "faculty")    ? (url.faculty EQ "true") : false>
    <cfset paramStudent = structKeyExists(url, "student")    ? (url.student EQ "true") : false>
</cfif>

<cfif NOT len(paramDepartment)><cfset paramDepartment = "H0113"></cfif>

<!--- ── Init API — capture verbose debug output from uh_api.cfc ── --->
<cfsavecontent variable="apiDebugOutput">
    <cftry>
        <cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfset authStatus = uhApi.getAuthStatus()>
        <cfset peopleResp = uhApi.getPeople(student=paramStudent, staff=paramStaff, faculty=paramFaculty, department=paramDepartment, q=paramQ, division=paramDivision)>
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
        <cfif structKeyExists(person, "student")  AND person.student>  <cfset arrayAppend(typeFlags, "<span class='badge badge-info'>student</span>")>  </cfif>
        <cfif structKeyExists(person, "staff")    AND person.staff>    <cfset arrayAppend(typeFlags, "<span class='badge badge-secondary'>staff</span>")>    </cfif>
        <cfif structKeyExists(person, "faculty")  AND person.faculty>  <cfset arrayAppend(typeFlags, "<span class='badge badge-dark'>faculty</span>")>  </cfif>

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
        <cfset authBadge = "<span class='badge badge-success fs-6 me-2'><i class='bi bi-shield-check'></i> Authenticated</span>">
    <cfelse>
        <cfset authBadge = "<span class='badge badge-danger fs-6 me-2'><i class='bi bi-shield-x'></i> NOT Authenticated</span>">
    </cfif>
<cfelse>
    <cfset authBadge = "<span class='badge badge-danger fs-6 me-2'>Error</span>">
</cfif>

<cfset selDept = structNew()>
<cfloop list="H0113,H0114,H0115,H0311,H0312,H0313,H0314" index="d">
    <cfset selDept[d] = (paramDepartment EQ d ? "selected" : "")>
</cfloop>

<cfset recordCount = arrayLen(apiPeople)>
<cfset resultLabel = "Records">

<cfif paramStudent AND NOT paramStaff AND NOT paramFaculty>
    <cfset resultLabel = "Students">
<cfelseif paramStaff AND NOT paramStudent AND NOT paramFaculty>
    <cfset resultLabel = "Staff">
<cfelseif paramFaculty AND NOT paramStudent AND NOT paramStaff>
    <cfset resultLabel = "Faculty">
</cfif>


<cfset content = "
<h1>Search The UH API</h1>

<div class='card mb-4'>
    <div class='card-body'>
        <form method='get' class='row g-2 align-items-end'>
            <div class='row g-2 align-items-end'>
                
                <div class='col-auto'>
                    <label for='deptInput' class='form-label mb-1'>Department</label>
                    <select class='form-select' aria-label='Department' name='department' id='deptInput'>
                        <option selected>Select A Department</option>
                        <option value=''>All Departments</option>
                        <option value='H0113' #selDept['H0113']#>Dean, Optometry</option>
                        <option value='H0114' #selDept['H0114']#>Vision Sciences</option>
                        <option value='H0115' #selDept['H0115']#>Optometry Clinic</option>
                        <option value='H0311' #selDept['H0311']#>Clinical Sciences</option>
                        <option value='H0312' #selDept['H0312']#>Grad Studies &amp; Research Pgm</option>
                        <option value='H0313' #selDept['H0313']#>Professional Program</option>
                        <option value='H0314' #selDept['H0314']#>Student Services</option>

                    </select>
                </div>
                <div class='col-auto'>
                    <label for='divInput' class='form-label mb-1'>Division</label>
                    <input type='text' id='divInput' name='division' class='form-control' value='#EncodeForHTML(paramDivision)#' placeholder='e.g. H0412'>
                </div>
                <div class='col-auto'>
                    <label for='qInput' class='form-label mb-1'>Search (q)</label>
                    <input type='text' id='qInput' name='q' class='form-control' value='#EncodeForHTML(paramQ)#' placeholder='Name, ID, email...'>
                </div>
                <div class='col-auto form-check'>
                    <input class='form-check-input' type='checkbox' id='staffInput' name='staff' value='true' #IIF(paramStaff, DE("checked"), DE(""))#>
                    <label class='form-check-label' for='staffInput'>Include staff</label>
                </div>
                <div class='col-auto form-check'>
                    <input class='form-check-input' type='checkbox' id='facultyInput' name='faculty' value='true' #IIF(paramFaculty, DE("checked"), DE(""))#>
                    <label class='form-check-label' for='facultyInput'>Include faculty</label>
                </div>
                <div class='col-auto form-check'>
                    <input class='form-check-input' type='checkbox' id='studentInput' name='student' value='true' #IIF(paramStudent, DE("checked"), DE(""))#>
                    <label class='form-check-label' for='studentInput'>Include students</label>
                </div>
            </div>
            <div class='row g-3 align-items-center'>
                <div class='col-auto'>
                    <button type='submit' class='btn btn-primary'>Search</button>
                    #(len(paramQ) OR paramDepartment NEQ 'H0113' ? "<a href='?department=H0113' class='btn btn-outline-secondary ms-1'>Reset</a>" : "")#
                </div>
            </div>
        </form>
    </div>
</div>

<div class='mb-3 d-flex align-items-center flex-wrap gap-2'>
    #authBadge#
    <span class='badge badge-light fs-6'>#arrayLen(apiPeople)# #resultLabel# returned</span>
    <small class='text-muted ms-2'>department=#EncodeForHTML(paramDepartment)##(len(paramQ) ? ', q=' & EncodeForHTML(paramQ) : '')#</small>
</div>

<div class='card mb-3 border-primary'>
    <div class='card-header bg-primary text-white'><strong>Request URL</strong></div>
    <div class='card-body'>
        <code class='d-block admin-code-break-small'>#len(requestUrl) ? EncodeForHTML(requestUrl) : '<em>URL not available (check debug panel for errors)</em>'#</code>
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
        <div class='card-body bg-light admin-debug-body-sm'>
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

<cfset pageScripts = "
<script>
document.addEventListener('DOMContentLoaded', function () {
    const studentCheckbox = document.getElementById('studentInput');
    const staffCheckbox   = document.getElementById('staffInput');
    const facultyCheckbox = document.getElementById('facultyInput');
    const divisionInput   = document.getElementById('divInput');
    const deptSelect      = document.querySelector('select[name=department]');

    
    if (!studentCheckbox || !divisionInput || !deptSelect) {
        return;
    }

    function handleStudentToggle() {
        if (studentCheckbox.checked) {
            divisionInput.value = '';
            divisionInput.disabled = true;
            deptSelect.value = 'H0113';
            deptSelect.disabled = true;
            staffCheckbox.checked = false;
            facultyCheckbox.checked = false;
        } else if (staffCheckbox.checked){
            studentCheckbox.checked = false;
            console.log(studentCheckbox.checked);
            divisionInput.disabled = false;
        } else if (facultyCheckbox.checked){
            studentCheckbox.checked = false;
            divisionInput.disabled = false;
        } else {
            divisionInput.disabled = false;
            deptSelect.disabled = false;
        }
    }
    
    // Run on page load
    handleStudentToggle();

    // Run when checkbox changes
    studentCheckbox.addEventListener('change', handleStudentToggle);
});
</script>
">


<cfinclude template="/admin/layout.cfm">
