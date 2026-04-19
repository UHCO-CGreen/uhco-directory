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

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

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
    <cfloop array="#templates#" index="tpl">
        <div class="col-md-6 col-lg-3">
            <a href="upload.cfm?template=#tpl.key#" class="text-decoration-none">
                <div class="card h-100 shadow-sm border-start border-primary border-3">
                    <div class="card-body">
                        <div class="d-flex align-items-center mb-2">
                            <i class="bi #tpl.icon# fs-3 text-primary me-2"></i>
                            <h5 class="card-title text-dark mb-0">#tpl.label#</h5>
                        </div>
                        <p class="card-text text-muted small mb-2">#tpl.description#</p>
                        <div class="mt-2">
                            <span class="badge bg-success-subtle text-success">Required: #arrayToList(tpl.requiredCols, ", ")#</span>
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

<!--- ── Recent Import History ── --->
<h5 class="mb-3">Recent Imports</h5>
<cfif arrayLen(recentRuns)>
    <div class="table-responsive">
        <table class="table table-sm table-striped align-middle">
            <thead class="table-light">
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
                                <cfcase value="users"><span class="badge bg-primary">Users</span></cfcase>
                                <cfcase value="flags"><span class="badge bg-info text-dark">Flags</span></cfcase>
                                <cfcase value="orgs"><span class="badge bg-secondary">Orgs</span></cfcase>
                                <cfcase value="student_academic"><span class="badge bg-dark">Academic</span></cfcase>
                                <cfdefaultcase><span class="badge bg-light text-dark">#run.TEMPLATE_KEY#</span></cfdefaultcase>
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

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
