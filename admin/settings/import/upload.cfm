<!---
    Import — Upload & Preview.
    Accepts CSV, validates against template, shows preview table.
    Permission: settings.import.manage.
--->

<cfif NOT request.hasPermission("settings.import.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset importSvc = createObject("component", "cfc.import_service").init()>

<!--- Validate template param --->
<cfparam name="url.template" default="">
<cftry>
    <cfset tpl = importSvc.getTemplate(url.template)>
<cfcatch>
    <cflocation url="index.cfm" addtoken="false">
</cfcatch>
</cftry>

<!--- State vars --->
<cfset parsedData     = {}>
<cfset validation     = {}>
<cfset uploadError    = "">
<cfset showPreview    = false>
<cfset uploadedFile   = "">

<!--- ── Handle file upload ── --->
<cfif cgi.request_method EQ "POST" AND structKeyExists(form, "csvFile") AND len(trim(form.csvFile))>
    <cftry>
        <!--- Upload to temp folder --->
        <cffile action="upload"
                filefield="csvFile"
                destination="#getTempDirectory()#"
                nameconflict="makeunique"
                accept=".csv,text/csv,application/vnd.ms-excel">

        <cfset uploadedFile = cffile.serverDirectory & "\" & cffile.serverFile>

        <!--- Size check: 10 MB max --->
        <cfif cffile.fileSize GT 10485760>
            <cfset uploadError = "File exceeds the 10 MB limit.">
            <cffile action="delete" file="#uploadedFile#">
        <cfelse>
            <!--- Parse CSV --->
            <cfset parsedData = importSvc.parseCSV(uploadedFile)>

            <!--- Validate --->
            <cfset validation = importSvc.validateImport(
                templateKey = tpl.key,
                headers     = parsedData.headers,
                rows        = parsedData.rows
            )>

            <cfset showPreview = true>

            <!--- Store temp path in session for process step --->
            <cfset session.import_tempFile     = uploadedFile>
            <cfset session.import_templateKey  = tpl.key>
            <cfset session.import_fileName     = cffile.clientFile>
            <cfset session.import_rowCount     = parsedData.rawRowCount>
        </cfif>

    <cfcatch>
        <cfset uploadError = cfcatch.message>
        <!--- Clean up temp file on error --->
        <cfif len(uploadedFile) AND fileExists(uploadedFile)>
            <cffile action="delete" file="#uploadedFile#">
        </cfif>
    </cfcatch>
    </cftry>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-import-upload-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="index.cfm">Import Data</a></li>
        <li class="breadcrumb-item active">#tpl.label#</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi #tpl.icon# me-2"></i>Import: #tpl.label#</h1>
<p class="text-muted mb-4">#tpl.description#</p>

<cfif tpl.isGeneratedTemplate ?: false>
    <div class="alert alert-info d-flex align-items-start gap-2">
        <i class="bi bi-info-circle fs-5 mt-1"></i>
        <div>
            Generate this template from a filtered cohort first so the file includes the correct identity columns and import mode.
            <a href="generate.cfm?template=#urlEncodedFormat(tpl.key)#" class="alert-link">Open template generator</a>
        </div>
    </div>
</cfif>

<!--- ── Upload Form ── --->
<cfif NOT showPreview>
    <div class="card shadow-sm mb-4 admin-card-max-600 settings-shell settings-summary-card">
        <div class="card-body">
            <h5 class="card-title mb-3">Upload CSV File</h5>

            <cfif len(uploadError)>
                <div class="alert alert-danger">
                    <i class="bi bi-exclamation-triangle me-2"></i>#uploadError#
                </div>
            </cfif>

            <div class="alert alert-info small mb-3">
                <strong>Required columns:</strong> #arrayToList(tpl.requiredCols, ", ")#<br>
                <cfif arrayLen(tpl.optionalCols)>
                    <strong>Optional columns:</strong> #arrayToList(tpl.optionalCols, ", ")#<br>
                </cfif>
                <cfif tpl.isGeneratedTemplate ?: false>
                    <a href="generate.cfm?template=#urlEncodedFormat(tpl.key)#" class="mt-1 d-inline-block">
                        <i class="bi bi-sliders me-1"></i>Generate filtered CSV template
                    </a>
                <cfelse>
                    <a href="templates/#tpl.key#_template.csv" download class="mt-1 d-inline-block">
                        <i class="bi bi-download me-1"></i>Download blank CSV template
                    </a>
                </cfif>
            </div>

            <form method="post" enctype="multipart/form-data">
                <div class="mb-3">
                    <label for="csvFile" class="form-label">CSV File <span class="text-danger">*</span></label>
                    <input type="file" class="form-control" id="csvFile" name="csvFile" accept=".csv" required>
                    <div class="form-text">Max 10 MB. First row must be column headers.</div>
                </div>
                <button type="submit" class="btn btn-primary">
                    <i class="bi bi-cloud-upload me-1"></i>Upload &amp; Validate
                </button>
                <a href="index.cfm" class="btn btn-outline-secondary ms-2">Cancel</a>
            </form>
        </div>
    </div>
</cfif>

<!--- ── Preview & Validation Results ── --->
<cfif showPreview>

    <!--- Validation summary --->
    <cfif validation.valid>
        <div class="alert alert-success d-flex align-items-center">
            <i class="bi bi-check-circle-fill fs-4 me-2"></i>
            <div>
                <strong>Validation passed.</strong>
                #parsedData.rawRowCount# row(s) ready to import via <strong>#tpl.label#</strong> template.
            </div>
        </div>
    <cfelse>
        <div class="alert alert-danger">
            <i class="bi bi-x-circle-fill me-2"></i>
            <strong>Validation failed.</strong> Fix the errors below and re-upload.
        </div>

        <cfif arrayLen(validation.missingHeaders)>
            <div class="alert alert-warning small">
                <strong>Missing required columns:</strong> #arrayToList(validation.missingHeaders, ", ")#
            </div>
        </cfif>

        <cfif arrayLen(validation.errors)>
            <div class="card border-danger mb-3 settings-shell">
                <div class="card-header bg-danger text-white small">
                    Row Errors (#arrayLen(validation.errors)#)
                </div>
                <div class="card-body p-0 admin-scroll-panel-sm">
                    <ul class="list-group list-group-flush small">
                        <cfloop array="#validation.errors#" index="err">
                            <li class="list-group-item list-group-item-danger py-1">#err#</li>
                        </cfloop>
                    </ul>
                </div>
            </div>
        </cfif>

        <cfif arrayLen(validation.warnings)>
            <cfloop array="#validation.warnings#" index="warn">
                <div class="alert alert-warning small">#warn#</div>
            </cfloop>
        </cfif>
    </cfif>

    <!--- Data preview (first 50 rows) --->
    <h5 class="mb-2">Data Preview <span class="text-muted small">(first 50 rows of #parsedData.rawRowCount#)</span></h5>
    <div class="table-responsive mb-4 admin-scroll-panel-md settings-shell">
        <table class="table table-sm table-bordered table-striped small settings-table mb-0">
            <thead class="sticky-top">
                <tr>
                    <th class="text-muted">##</th>
                    <cfloop array="#parsedData.headers#" index="hdr">
                        <th>
                            #trim(hdr)#
                            <cfif arrayFindNoCase(tpl.requiredCols, trim(hdr))>
                                <span class="text-danger">*</span>
                            </cfif>
                        </th>
                    </cfloop>
                </tr>
            </thead>
            <tbody>
                <cfset previewLimit = min(50, arrayLen(parsedData.rows))>
                <cfloop from="1" to="#previewLimit#" index="r">
                    <cfset row = parsedData.rows[r]>
                    <tr>
                        <td class="text-muted">#r#</td>
                        <cfloop array="#parsedData.headers#" index="hdr">
                            <cfset cellVal = row[trim(hdr)] ?: "">
                            <td>
                                <cfif len(cellVal)>
                                    #encodeForHTML(cellVal)#
                                <cfelse>
                                    <span class="text-muted fst-italic">empty</span>
                                </cfif>
                            </td>
                        </cfloop>
                    </tr>
                </cfloop>
            </tbody>
        </table>
    </div>

    <!--- Action buttons --->
    <div class="d-flex gap-2">
        <cfif validation.valid>
            <form method="post" action="process.cfm">
                <input type="hidden" name="confirm" value="1">
                <button type="submit" class="btn btn-success btn-lg"
                        onclick="return confirm('Import #parsedData.rawRowCount# rows using the #tpl.label# template? This cannot be undone.');">
                    <i class="bi bi-play-fill me-1"></i>Run Import (#parsedData.rawRowCount# rows)
                </button>
            </form>
        </cfif>
        <a href="upload.cfm?template=#tpl.key#" class="btn btn-outline-secondary btn-lg">
            <i class="bi bi-arrow-counterclockwise me-1"></i>Re-upload
        </a>
        <a href="index.cfm" class="btn btn-outline-dark btn-lg">Cancel</a>
    </div>

</cfif>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
