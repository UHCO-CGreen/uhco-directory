<!---
    Import — Process / Results.
    Executes import from session temp file, or views past run details.
    Permission: settings.import.manage.
--->

<cfif NOT request.hasPermission("settings.import.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset importSvc = createObject("component", "cfc.import_service").init()>
<cfset runSummary = {}>
<cfset runDetails = []>
<cfset justRan    = false>
<cfset runError   = "">

<!--- ── Mode 1: Execute new import from uploaded file ── --->
<cfif cgi.request_method EQ "POST" AND structKeyExists(form, "confirm") AND form.confirm EQ "1">
    <cftry>
        <!--- Validate session state --->
        <cfif NOT structKeyExists(session, "import_tempFile")
              OR NOT structKeyExists(session, "import_templateKey")
              OR NOT fileExists(session.import_tempFile)>
            <cfset runError = "Upload session expired. Please re-upload your file.">
        <cfelse>
            <!--- Re-parse the file (don't trust session data for row content) --->
            <cfset parsedData = importSvc.parseCSV(session.import_tempFile)>

            <!--- Execute --->
            <cfset newRunID = importSvc.executeImport(
                templateKey = session.import_templateKey,
                rows        = parsedData.rows,
                fileName    = session.import_fileName,
                startedBy   = session.user.cougarnet
            )>

            <!--- Clean up temp file --->
            <cfif fileExists(session.import_tempFile)>
                <cffile action="delete" file="#session.import_tempFile#">
            </cfif>
            <cfset structDelete(session, "import_tempFile")>
            <cfset structDelete(session, "import_templateKey")>
            <cfset structDelete(session, "import_fileName")>
            <cfset structDelete(session, "import_rowCount")>

            <!--- Load results --->
            <cfset runSummary = importSvc.getRunSummary(newRunID)>
            <cfset runDetails = importSvc.getRunDetails(newRunID)>
            <cfset justRan = true>
        </cfif>

    <cfcatch>
        <cfset runError = cfcatch.message>
    </cfcatch>
    </cftry>
</cfif>

<!--- ── Mode 2: View past run by ID ── --->
<cfif NOT justRan AND NOT len(runError) AND structKeyExists(url, "run_id") AND isNumeric(url.run_id)>
    <cftry>
        <cfset runSummary = importSvc.getRunSummary(val(url.run_id))>
        <cfset runDetails = importSvc.getRunDetails(val(url.run_id))>
    <cfcatch>
        <cfset runError = "Import run not found.">
    </cfcatch>
    </cftry>
</cfif>

<!--- ── No context → redirect ── --->
<cfif structIsEmpty(runSummary) AND NOT len(runError)>
    <cflocation url="index.cfm" addtoken="false">
</cfif>

<!--- Resolve template label --->
<cfset tplLabel = "">
<cfif NOT structIsEmpty(runSummary)>
    <cftry>
        <cfset tplLabel = importSvc.getTemplate(runSummary.TEMPLATE_KEY).label>
    <cfcatch>
        <cfset tplLabel = runSummary.TEMPLATE_KEY>
    </cfcatch>
    </cftry>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="index.cfm">Import Data</a></li>
        <li class="breadcrumb-item active">
            <cfif NOT structIsEmpty(runSummary)>Run ###runSummary.RUN_ID#<cfelse>Results</cfif>
        </li>
    </ol>
</nav>

<!--- ── Error state ── --->
<cfif len(runError)>
    <div class="alert alert-danger">
        <i class="bi bi-exclamation-triangle me-2"></i>#runError#
    </div>
    <a href="index.cfm" class="btn btn-outline-primary">Back to Import</a>
</cfif>

<!--- ── Results ── --->
<cfif NOT structIsEmpty(runSummary)>

    <cfif justRan>
        <div class="alert alert-success d-flex align-items-center mb-4">
            <i class="bi bi-check-circle-fill fs-4 me-3"></i>
            <div>
                <strong>Import complete!</strong>
                Processed #runSummary.TOTAL_ROWS# rows using the <strong>#tplLabel#</strong> template.
            </div>
        </div>
    <cfelse>
        <h1 class="mb-1"><i class="bi bi-clipboard-data me-2"></i>Import Run ###runSummary.RUN_ID#</h1>
        <p class="text-muted mb-4">#tplLabel# &mdash; #runSummary.FILE_NAME#</p>
    </cfif>

    <!--- Summary cards --->
    <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
            <div class="card text-center border-0 shadow-sm">
                <div class="card-body">
                    <div class="fs-2 fw-bold">#runSummary.TOTAL_ROWS#</div>
                    <div class="text-muted small">Total Rows</div>
                </div>
            </div>
        </div>
        <div class="col-6 col-md-3">
            <div class="card text-center border-0 shadow-sm bg-success-subtle">
                <div class="card-body">
                    <div class="fs-2 fw-bold text-success">#runSummary.SUCCESS_COUNT#</div>
                    <div class="text-muted small">Successful</div>
                </div>
            </div>
        </div>
        <div class="col-6 col-md-3">
            <div class="card text-center border-0 shadow-sm bg-warning-subtle">
                <div class="card-body">
                    <div class="fs-2 fw-bold text-warning">#runSummary.SKIP_COUNT#</div>
                    <div class="text-muted small">Skipped</div>
                </div>
            </div>
        </div>
        <div class="col-6 col-md-3">
            <div class="card text-center border-0 shadow-sm bg-danger-subtle">
                <div class="card-body">
                    <div class="fs-2 fw-bold text-danger">#runSummary.ERROR_COUNT#</div>
                    <div class="text-muted small">Errors</div>
                </div>
            </div>
        </div>
    </div>

    <!--- Run metadata --->
    <div class="card shadow-sm mb-4">
        <div class="card-body small">
            <div class="row">
                <div class="col-md-3"><strong>Template:</strong> #tplLabel#</div>
                <div class="col-md-3"><strong>File:</strong> #runSummary.FILE_NAME#</div>
                <div class="col-md-3"><strong>Started by:</strong> #runSummary.STARTED_BY#</div>
                <div class="col-md-3"><strong>Date:</strong> #dateFormat(runSummary.STARTED_AT, "mm/dd/yyyy")# #timeFormat(runSummary.STARTED_AT, "h:mm tt")#</div>
            </div>
        </div>
    </div>

    <!--- Row details --->
    <cfif arrayLen(runDetails)>
        <!--- Filter controls --->
        <div class="d-flex align-items-center gap-2 mb-3">
            <h5 class="mb-0">Row Details</h5>
            <span class="text-muted small">(#arrayLen(runDetails)# rows)</span>
            <div class="ms-auto btn-group btn-group-sm" role="group">
                <button type="button" class="btn btn-outline-secondary active filter-btn" data-filter="all">All</button>
                <cfif runSummary.SUCCESS_COUNT GT 0>
                    <button type="button" class="btn btn-outline-success filter-btn" data-filter="success">
                        <i class="bi bi-check"></i> Success (#runSummary.SUCCESS_COUNT#)
                    </button>
                </cfif>
                <cfif runSummary.SKIP_COUNT GT 0>
                    <button type="button" class="btn btn-outline-warning filter-btn" data-filter="skipped">
                        <i class="bi bi-dash"></i> Skipped (#runSummary.SKIP_COUNT#)
                    </button>
                </cfif>
                <cfif runSummary.ERROR_COUNT GT 0>
                    <button type="button" class="btn btn-outline-danger filter-btn" data-filter="error">
                        <i class="bi bi-x"></i> Errors (#runSummary.ERROR_COUNT#)
                    </button>
                </cfif>
            </div>
        </div>

        <div class="table-responsive" style="max-height:500px; overflow-y:auto;">
            <table class="table table-sm table-bordered small" id="detailsTable">
                <thead class="table-light sticky-top">
                    <tr>
                        <th>Row</th>
                        <th>Status</th>
                        <th>Message</th>
                    </tr>
                </thead>
                <tbody>
                    <cfloop array="#runDetails#" index="det">
                        <tr class="detail-row" data-status="#lCase(det.STATUS)#">
                            <td>#det.ROW_NUMBER#</td>
                            <td>
                                <cfswitch expression="#det.STATUS#">
                                    <cfcase value="success"><span class="badge bg-success">Success</span></cfcase>
                                    <cfcase value="skipped"><span class="badge bg-warning text-dark">Skipped</span></cfcase>
                                    <cfcase value="error"><span class="badge bg-danger">Error</span></cfcase>
                                </cfswitch>
                            </td>
                            <td>#encodeForHTML(det.MESSAGE)#</td>
                        </tr>
                    </cfloop>
                </tbody>
            </table>
        </div>
    </cfif>

    <!--- Actions --->
    <div class="d-flex gap-2 mt-4">
        <a href="index.cfm" class="btn btn-outline-primary">
            <i class="bi bi-arrow-left me-1"></i>Back to Import
        </a>
        <cfif NOT structIsEmpty(runSummary)>
            <a href="upload.cfm?template=#runSummary.TEMPLATE_KEY#" class="btn btn-outline-success">
                <i class="bi bi-plus-circle me-1"></i>Import More (#tplLabel#)
            </a>
        </cfif>
    </div>

</cfif>

</cfoutput>
</cfsavecontent>

<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<script>
    // Row filter buttons
    document.querySelectorAll('.filter-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            document.querySelectorAll('.filter-btn').forEach(function(b) { b.classList.remove('active'); });
            this.classList.add('active');
            var filter = this.getAttribute('data-filter');
            document.querySelectorAll('.detail-row').forEach(function(row) {
                row.style.display = (filter === 'all' || row.getAttribute('data-status') === filter) ? '' : 'none';
            });
        });
    });
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
