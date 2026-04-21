<!---
    Import Data — template picker + recent history.
    Permission: settings.import.manage.
--->

<cfif NOT request.hasPermission("settings.import.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset importSvc = createObject("component", "cfc.import_service").init()>
<cfset templates = importSvc.getTemplates()>
<cfset recentRuns = importSvc.getRecentRuns(maxRows = 20)>

<cfscript>
uploadTemplates = [];
generatedTemplates = [];
for (tpl in templates) {
    if ((tpl.workflow ?: "direct") EQ "generated") {
        arrayAppend(generatedTemplates, tpl);
    } else {
        arrayAppend(uploadTemplates, tpl);
    }
}
</cfscript>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-import-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Import Data</li>
    </ol>
</nav>
<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
<h1 class="mb-1"><i class="bi bi-upload me-2"></i>Import Data</h1>
<p class="text-muted mb-4">Select an import template, upload a CSV file, preview, and process.</p>
</div>
<span class='badge bg-warning text-dark float-end'>Currently in: Alpha</span>
</div>
<!--- ── Template Cards ── --->
<h5 class="mb-3">Choose Import Template</h5>
<div class="row g-3 mb-5">
    <cfloop array="#uploadTemplates#" index="tpl">
        <div class="col-md-6 col-lg-3">
            <a href="upload.cfm?template=#tpl.key#" class="text-decoration-none">
                <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--primary">
                    <div class="card-body">
                        <div class="d-flex align-items-center mb-2">
                            <i class="bi #tpl.icon# fs-3 settings-hub-icon me-2"></i>
                            <h5 class="card-title text-dark mb-0">#tpl.label#</h5>
                        </div>
                        <p class="card-text text-muted small mb-2">#tpl.description#</p>
                        <div class="mt-2">
                            <span class="badge settings-badge-success-soft">Required: #arrayToList(tpl.requiredCols, ", ")#</span>
                        </div>
                        <div class="mt-2">
                            <a href="templates/#tpl.key#_template.csv" download class="small text-primary" onclick="event.stopPropagation();">
                                <i class="bi bi-download me-1"></i>Download CSV template
                            </a>
                        </div>
                    </div>
                </div>
            </a>
        </div>
    </cfloop>
</div>

<h5 class="mb-3">Bulk Section Updates</h5>
<div class="row g-3 mb-5">
    <cfloop array="#generatedTemplates#" index="tpl">
        <div class="col-md-6 col-lg-4">
            <a href="generate.cfm?template=#tpl.key#" class="text-decoration-none">
                <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--success">
                    <div class="card-body">
                        <div class="d-flex align-items-center mb-2">
                            <i class="bi #tpl.icon# fs-3 settings-hub-icon settings-hub-icon--success me-2"></i>
                            <h5 class="card-title text-dark mb-0">#tpl.label#</h5>
                        </div>
                        <p class="card-text text-muted small mb-2">#tpl.description#</p>
                        <div class="mt-2">
                            <span class="badge settings-badge-success-soft">Generated CSV</span>
                            <span class="badge settings-badge-neutral">One section per job</span>
                        </div>
                        <div class="mt-2 small text-success">Filter users, download CSV, then upload the completed file.</div>
                    </div>
                </div>
            </a>
        </div>
    </cfloop>
</div>

<!--- ── Recent Import History ── --->
<h5 class="mb-3">Recent Imports</h5>
<cfif arrayLen(recentRuns)>
    <div class="table-responsive settings-shell">
        <table class="table table-sm table-striped align-middle settings-table mb-0">
            <thead>
                <tr>
                    <th>Run</th>
                    <th>Template</th>
                    <th>File</th>
                    <th>Rows</th>
                    <th class="text-success">OK</th>
                    <th class="text-warning">Skip</th>
                    <th class="text-danger">Err</th>
                    <th>Started By</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                <cfloop array="#recentRuns#" index="run">
                    <tr>
                        <td>###run.RUN_ID#</td>
                        <td>
                            <cfswitch expression="#run.TEMPLATE_KEY#">
                                <cfcase value="users"><span class="badge settings-badge-primary-soft">Users</span></cfcase>
                                <cfcase value="flags"><span class="badge settings-badge-warning-soft">Flags</span></cfcase>
                                <cfcase value="orgs"><span class="badge settings-badge-neutral">Orgs</span></cfcase>
                                <cfcase value="student_academic"><span class="badge settings-badge-count">Academic</span></cfcase>
                                <cfdefaultcase><span class="badge settings-badge-neutral">#run.TEMPLATE_KEY#</span></cfdefaultcase>
                            </cfswitch>
                        </td>
                        <td class="small">#run.FILE_NAME#</td>
                        <td>#run.TOTAL_ROWS#</td>
                        <td class="text-success fw-bold">#run.SUCCESS_COUNT#</td>
                        <td class="text-warning fw-bold">#run.SKIP_COUNT#</td>
                        <td class="text-danger fw-bold">#run.ERROR_COUNT#</td>
                        <td class="small">#run.STARTED_BY#</td>
                        <td class="small">#dateFormat(run.STARTED_AT, "mm/dd/yyyy")# #timeFormat(run.STARTED_AT, "h:mm tt")#</td>
                        <td>
                            <cfif run.STATUS EQ "completed">
                                <span class="badge bg-success">Completed</span>
                            <cfelseif run.STATUS EQ "running">
                                <span class="badge bg-warning text-dark">Running</span>
                            <cfelse>
                                <span class="badge bg-danger">Failed</span>
                            </cfif>
                        </td>
                        <td>
                            <a href="process.cfm?run_id=#run.RUN_ID#" class="btn btn-sm btn-outline-secondary" title="View details">
                                <i class="bi bi-eye"></i>
                            </a>
                        </td>
                    </tr>
                </cfloop>
            </tbody>
        </table>
    </div>
<cfelse>
    <div class="alert alert-light border">
        <i class="bi bi-inbox me-2"></i>No import history yet. Choose a template above to get started.
    </div>
</cfif>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
