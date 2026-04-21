<!---
    Bulk Import Template Generator.
    Permission: settings.import.manage.
--->

<cfsetting showdebugoutput="false">

<cfif NOT request.hasPermission("settings.import.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset importSvc = createObject("component", "cfc.import_service").init()>
<cfset bulkImportSvc = createObject("component", "cfc.bulkImport_service").init()>

<cfparam name="url.template" default="">
<cftry>
    <cfset tpl = importSvc.getTemplate(url.template)>
    <cfif NOT (tpl.isGeneratedTemplate ?: false)>
        <cflocation url="upload.cfm?template=#urlEncodedFormat(tpl.key)#" addtoken="false">
    </cfif>
<cfcatch>
    <cflocation url="index.cfm" addtoken="false">
</cfcatch>
</cftry>

<cfset filterOptions = bulkImportSvc.getFilterOptions()>
<cfset selectedFlag = trim(form.filterFlag ?: "")>
<cfset selectedOrg = trim(form.filterOrg ?: "")>
<cfset selectedGradYear = trim(form.filterClass ?: "")>
<cfset includeExistingData = !structKeyExists(form, "includeExistingData") OR form.includeExistingData EQ "1">
<cfset generationError = "">

<cfif cgi.request_method EQ "POST" AND structKeyExists(form, "generateTemplate")>
    <cftry>
        <cfset exportResult = bulkImportSvc.generateTemplate(
            templateKey = tpl.key,
            filterFlag = selectedFlag,
            filterOrg = selectedOrg,
            filterClass = selectedGradYear,
            includeExistingData = includeExistingData
        )>
        <cfheader name="Content-Disposition" value="attachment; filename=#exportResult.fileName#">
        <cfcontent type="text/csv; charset=utf-8" reset="true"><cfoutput>#chr(65279)##exportResult.csvContent#</cfoutput><cfabort>
    <cfcatch>
        <cfset generationError = cfcatch.message>
    </cfcatch>
    </cftry>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-import-generate-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="index.cfm">Import Data</a></li>
        <li class="breadcrumb-item active">Generate #encodeForHTML(tpl.label)#</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
    <div>
        <h1 class="mb-1"><i class="bi #encodeForHTMLAttribute(tpl.icon)# me-2"></i>Generate #encodeForHTML(tpl.label)#</h1>
        <p class="text-muted mb-0">Choose a cohort, download a CSV prebuilt for one bulk section, update it offline, then upload it back into the import pipeline.</p>
    </div>
    <a href="upload.cfm?template=#urlEncodedFormat(tpl.key)#" class="btn btn-outline-primary">
        <i class="bi bi-upload me-1"></i>Upload Completed File
    </a>
</div>

<cfif len(generationError)>
    <div class="alert alert-danger">
        <i class="bi bi-exclamation-triangle me-2"></i>#encodeForHTML(generationError)#
    </div>
</cfif>

<div class="row g-4">
    <div class="col-lg-8">
        <div class="card shadow-sm settings-shell settings-summary-card">
            <div class="card-body">
                <h5 class="card-title mb-3">Template Filters</h5>
                <form method="post">
                    <input type="hidden" name="generateTemplate" value="1">

                    <div class="row g-3">
                        <div class="col-md-6">
                            <label for="filterFlag" class="form-label">Flag</label>
                            <select class="form-select" id="filterFlag" name="filterFlag">
                                <option value="">Any Flag</option>
                                <cfloop array="#filterOptions.flags#" index="flagOption">
                                    <option value="#encodeForHTMLAttribute(flagOption.FLAGNAME)#" #(compareNoCase(selectedFlag, flagOption.FLAGNAME) EQ 0 ? "selected" : "")#>#encodeForHTML(flagOption.FLAGNAME)#</option>
                                </cfloop>
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label for="filterOrg" class="form-label">Organization</label>
                            <select class="form-select" id="filterOrg" name="filterOrg">
                                <option value="">Any Organization</option>
                                <cfloop array="#filterOptions.organizations#" index="orgOption">
                                    <option value="#encodeForHTMLAttribute(orgOption.ORGNAME)#" #(compareNoCase(selectedOrg, orgOption.ORGNAME) EQ 0 ? "selected" : "")#>#encodeForHTML(orgOption.ORGNAME)#</option>
                                </cfloop>
                            </select>
                        </div>
                        <div class="col-md-4" id="gradYearWrapper">
                            <label for="filterClass" class="form-label">Current Grad Year</label>
                            <input type="number" class="form-control" id="filterClass" name="filterClass" value="#encodeForHTMLAttribute(selectedGradYear)#" min="1900" max="#year(now()) + 10#" step="1">
                            <div class="form-text">Only applies to Alumni and Current Student filters.</div>
                        </div>
                        <div class="col-12">
                            <div class="form-check">
                                <input class="form-check-input" type="checkbox" id="includeExistingData" name="includeExistingData" value="1" #(includeExistingData ? "checked" : "")#>
                                <label class="form-check-label" for="includeExistingData">Seed the CSV with existing section rows and use replace mode on import</label>
                            </div>
                            <div class="form-text">Leave checked to export the current rows for each matching user. Uncheck to generate a blank starter sheet that uploads in merge mode.</div>
                        </div>
                    </div>

                    <div class="d-flex gap-2 mt-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-download me-1"></i>Generate CSV
                        </button>
                        <a href="upload.cfm?template=#urlEncodedFormat(tpl.key)#" class="btn btn-outline-secondary">Upload Existing File</a>
                        <a href="index.cfm" class="btn btn-outline-dark">Cancel</a>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="col-lg-4">
        <div class="card shadow-sm mb-4 settings-shell settings-reference-card">
            <div class="card-body">
                <h5 class="card-title mb-3">How It Works</h5>
                <ol class="small mb-0 ps-3">
                    <li>Pick a flag, organization, and optionally a grad year.</li>
                    <li>Download a CSV for this section only.</li>
                    <li>Edit the rows offline without changing the identity columns.</li>
                    <li>Upload the completed file through the import preview screen.</li>
                </ol>
            </div>
        </div>

        <div class="card shadow-sm settings-shell settings-reference-card">
            <div class="card-body">
                <h5 class="card-title mb-3">Columns</h5>
                <div class="small mb-2"><strong>Required:</strong> #encodeForHTML(arrayToList(tpl.requiredCols, ", "))#</div>
                <div class="small text-muted"><strong>Editable Section Fields:</strong> #encodeForHTML(arrayToList(tpl.optionalCols, ", "))#</div>
            </div>
        </div>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<script>
    (function() {
        var flagSelect = document.getElementById('filterFlag');
        var gradYearWrapper = document.getElementById('gradYearWrapper');
        var gradYearInput = document.getElementById('filterClass');

        function supportsGradYear(value) {
            var normalized = (value || '').trim().toLowerCase();
            return normalized === 'alumni' || normalized === 'current student' || normalized === 'current-student';
        }

        function syncGradYearVisibility() {
            var enabled = supportsGradYear(flagSelect.value);
            gradYearWrapper.style.display = enabled ? '' : 'none';
            if (!enabled) {
                gradYearInput.value = '';
            }
        }

        flagSelect.addEventListener('change', syncGradYearVisibility);
        syncGradYearVisibility();
    })();
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">