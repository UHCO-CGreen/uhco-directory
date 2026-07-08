<!---
    Rosters — generate printable class roster PDFs.
    Permission: rosters.manage.
--->

<cfif NOT request.hasPermission("rosters.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("rosters")>

<cfset rosterService = createObject("component", "cfc.roster_service").init()>
<cfset yearOptions = rosterService.getAvailableGradYears()>
<cfset programOptions = rosterService.getProgramOptions()>
<cfset layoutConfig = rosterService.getLayoutConfig()>
<cfset compactLayoutConfig = rosterService.getLayoutConfig(101)>

<cfset msgParam = trim(url.msg ?: "")>
<cfset errParam = trim(url.err ?: "")>
<cfset generatedYear = trim(url.year ?: "")>
<cfset generatedCount = trim(url.count ?: "")>
<cfset generatedPages = trim(url.pages ?: "")>
<cfset publishStatus = lCase(trim(url.publish ?: ""))>
<cfset publishPath = trim(url.publishPath ?: "")>
<cfset publishErr = trim(url.publishErr ?: "")>

<cfset rosterDirectory = expandPath("/_temp_rosters")>
<cfset publishMetaPath = rosterDirectory & "/.publish-status.json">
<cfset publishMeta = {}>

<cfif fileExists(publishMetaPath)>
    <cftry>
        <cfset publishMetaRaw = trim(fileRead(publishMetaPath, "utf-8"))>
        <cfif len(publishMetaRaw) AND isJSON(publishMetaRaw)>
            <cfset publishMeta = deserializeJSON(publishMetaRaw)>
            <cfif NOT isStruct(publishMeta)>
                <cfset publishMeta = {}>
            </cfif>
        </cfif>
    <cfcatch>
        <cfset publishMeta = {}>
    </cfcatch>
    </cftry>
</cfif>

<!--- Sort params for available rosters table --->
<cfset allowedRosterSortCols = {"NAME": "name", "DATELASTMODIFIED": "dateLastModified", "SIZE": "size"}>
<cfset rosterSortCol = (structKeyExists(url, "sortCol") AND structKeyExists(allowedRosterSortCols, uCase(url.sortCol))) ? uCase(url.sortCol) : "DATELASTMODIFIED">
<cfset rosterSortDir = ((url.sortDir ?: "") EQ "ASC") ? "ASC" : "DESC">
<cfset rosterCfDirSort = allowedRosterSortCols[rosterSortCol] & " " & rosterSortDir>

<cfscript>
    function rosterSortLink(col) {
        var dir = (rosterSortCol EQ col AND rosterSortDir EQ "ASC") ? "DESC" : "ASC";
        return "?sortCol=" & col & "&sortDir=" & dir;
    }
    function rosterSortArrow(col) {
        if (rosterSortCol EQ col) return rosterSortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
</cfscript>

<cfif directoryExists(rosterDirectory)>
    <cfdirectory
        action="list"
        directory="#rosterDirectory#"
        name="availableRosters"
        filter="class-of-*-roster.pdf"
        sort="#rosterCfDirSort#"
        type="file"
    >
<cfelse>
    <cfset availableRosters = queryNew("name,size,dateLastModified,type")>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-rosters-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item active">Rosters</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-card-image me-2"></i>Rosters</h1>
        <p class="text-muted mb-0">Generate printable class roster PDFs.</p>
    </div>
    <cfif len(sectionStatus)>
        <span class="badge bg-warning text-dark">Currently in: #sectionStatus#</span>
    </cfif>
</div>

<cfif len(msgParam)>
    <div class="alert alert-success">#encodeForHTML(msgParam)#</div>
</cfif>

<cfif publishStatus EQ "ok" AND len(publishPath)>
    <div class="alert alert-info">
        Dropbox publish complete: <span class="small">#encodeForHTML(publishPath)#</span>
    </div>
<cfelseif publishStatus EQ "fail">
    <div class="alert alert-warning">
        Roster was generated locally, but Dropbox publish failed.
        <cfif len(publishErr)><div class="small mt-1">#encodeForHTML(publishErr)#</div></cfif>
    </div>
</cfif>

<cfif len(errParam)>
    <div class="alert alert-danger">#encodeForHTML(errParam)#</div>
</cfif>

<div class="row g-4">
    <div class="col-lg-7">
        <div class="card shadow-sm settings-shell">
            <div class="card-body">
                <h5 class="card-title mb-3">Generate Roster</h5>

                <cfif NOT arrayLen(yearOptions)>
                    <div class="alert alert-warning mb-0">
                        No Current-Student classes were found for the supported programs.
                    </div>
                <cfelse>
                    <form method="post" action="generate.cfm">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label for="gradYear" class="form-label">Grad Year</label>
                                <select class="form-select" id="gradYear" name="gradYear" required>
                                    <option value="">Select year...</option>
                                    <cfloop array="#yearOptions#" index="yearVal">
                                        <option value="#yearVal#">#yearVal#</option>
                                    </cfloop>
                                </select>
                            </div>

                            <div class="col-md-6">
                                <label for="programName" class="form-label">Program Org</label>
                                <select class="form-select" id="programName" name="programName" required>
                                    <option value="">Select program...</option>
                                    <cfloop array="#programOptions#" index="programOption">
                                        <option value="#encodeForHTMLAttribute(programOption.value)#">#encodeForHTML(programOption.label)#</option>
                                    </cfloop>
                                </select>
                            </div>
                        </div>

                        <div class="mt-4 d-flex gap-2">
                            <button type="submit" class="btn btn-ui-filter">
                                <i class="bi bi-file-earmark-pdf me-1"></i>Generate Roster
                            </button>
                        </div>
                    </form>
                </cfif>
            </div>
        </div>

        <div class="card shadow-sm settings-shell mt-4">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center mb-3 gap-2 flex-wrap">
                    <h5 class="card-title mb-0">Available Rosters</h5>
                    <cfif availableRosters.recordCount GT 0>
                        <form method="post" action="publish_all.cfm" class="d-inline">
                            <button type="submit" class="btn btn-sm btn-ui-save">
                                <i class="bi bi-cloud-upload me-1"></i>Publish All
                            </button>
                        </form>
                    </cfif>
                </div>

                <cfif availableRosters.recordCount EQ 0>
                    <div class="alert alert-light border mb-0">
                        No roster PDFs found in /_temp_rosters.
                    </div>
                <cfelse>
                    <div class="table-responsive settings-shell">
                        <table class="table table-sm table-hover align-middle mb-0 settings-table">
                            <thead>
                                <tr>
                                    <th><a href="#rosterSortLink('NAME')#" class="settings-sort-link">File#rosterSortArrow('NAME')#</a></th>
                                    <th><a href="#rosterSortLink('DATELASTMODIFIED')#" class="settings-sort-link">Modified#rosterSortArrow('DATELASTMODIFIED')#</a></th>
                                    <th class="text-center"><a href="#rosterSortLink('SIZE')#" class="settings-sort-link">Size (KB)#rosterSortArrow('SIZE')#</a></th>
                                    <th>Last Publish</th>
                                    <!---<th>Dropbox Path</th>--->
                                    <th></th>
                                </tr>
                            </thead>
                            <tbody>
                                <cfloop query="availableRosters">
                                    <cfset metaKey = lCase(availableRosters.name)>
                                    <cfset fileMeta = structKeyExists(publishMeta, metaKey) AND isStruct(publishMeta[metaKey]) ? publishMeta[metaKey] : {}>
                                    <cfset lastStatus = lCase(trim(fileMeta.lastStatus ?: ""))>
                                    <cfset lastAttemptAt = trim(fileMeta.lastAttemptAt ?: "")>
                                    <cfset lastPath = trim(fileMeta.lastPublishedPath ?: "")>
                                    <cfset lastError = trim(fileMeta.lastError ?: "")>
                                    <tr>
                                        <td class="small">#encodeForHTML(availableRosters.name)#</td>
                                        <td class="small">#dateFormat(availableRosters.dateLastModified, "mm/dd/yyyy")# #timeFormat(availableRosters.dateLastModified, "h:mm tt")#</td>
                                        <td class="small text-center">#numberFormat(availableRosters.size / 1024, "9,999.0")#</td>
                                        <td class="small">
                                            <cfif lastStatus EQ "ok">
                                                <span class="badge bg-success">Published</span>
                                            <cfelseif lastStatus EQ "fail">
                                                <span class="badge bg-warning text-dark">Failed</span>
                                            <cfelse>
                                                <span class="text-muted">Not published</span>
                                            </cfif>
                                            <cfif len(lastAttemptAt)>
                                                <div class="text-muted mt-1">#encodeForHTML(lastAttemptAt)#</div>
                                            </cfif>
                                            <cfif lastStatus EQ "fail" AND len(lastError)>
                                                <div class="text-warning mt-1">#encodeForHTML(lastError)#</div>
                                            </cfif>
                                        </td>
                                        <!---<td class="small">
                                            <cfif len(lastPath)>
                                                #encodeForHTML(lastPath)#
                                            <cfelse>
                                                <span class="text-muted">-</span>
                                            </cfif>
                                        </td>--->
                                        <td class="text-end">
                                            <a class="btn btn-sm btn-ui-go me-1" href="/_temp_rosters/#encodeForURL(availableRosters.name)#" target="_blank" rel="noopener">
                                                <i class="bi bi-eye"></i>
                                            </a>
                                            <a class="btn btn-sm btn-ui-go" href="download.cfm?filename=#urlEncodedFormat(availableRosters.name)#">
                                                <i class="bi bi-download"></i>
                                            </a>
                                            <form method="post" action="publish.cfm" class="d-inline ms-1">
                                                <input type="hidden" name="filename" value="#encodeForHTMLAttribute(availableRosters.name)#">
                                                <button type="submit" class="btn btn-sm btn-ui-save">
                                                    <i class="bi bi-cloud-arrow-up"></i>
                                                </button>
                                            </form>
                                        </td>
                                    </tr>
                                </cfloop>
                            </tbody>
                        </table>
                    </div>
                </cfif>
            </div>
        </div>
    </div>

    <div class="col-lg-5">
        <div class="card shadow-sm settings-shell settings-reference-card mb-4">
            <div class="card-body">
                <h5 class="card-title mb-3">Output Rules</h5>
                <ul class="small mb-0 ps-3">
                    <li>File name: <strong>class-of-{gradyear}-roster.pdf</strong></li>
                    <li>Saved to: <strong>/_temp_rosters</strong></li>
                    <li>Regenerating the same class year overwrites the prior PDF</li>
                    <li>Image fallback: <strong>/assets/images/uh.png</strong></li>
                    <li>Header image: <strong>#encodeForHTML(layoutConfig.headerImage)#</strong></li>
                </ul>
            </div>
        </div>

        <div class="card shadow-sm settings-shell settings-reference-card mb-4">
            <div class="card-body">
                <h5 class="card-title mb-3">Capacity Preflight</h5>
                <div class="small">Standard mode (<=100 users): <strong>#layoutConfig.cardsPerPage# per page</strong> (5 x #layoutConfig.columns#)</div>
                <div class="small">Compact mode (>100 users): <strong>#compactLayoutConfig.cardsPerPage# per page</strong> (6 x #compactLayoutConfig.columns#)</div>
                <div class="small">2-page max support: <strong>#compactLayoutConfig.maxSupportedCount# users</strong></div>
                <div class="small text-muted mt-2">Classes over 100 automatically switch to compact image sizing and a 6-row layout.</div>
            </div>
        </div>

        <cfif len(generatedYear)>
            <div class="card shadow-sm settings-shell">
                <div class="card-body">
                    <h5 class="card-title mb-3">Latest Generated File</h5>
                    <div class="small mb-1"><strong>Year:</strong> #encodeForHTML(generatedYear)#</div>
                    <cfif len(generatedCount)>
                        <div class="small mb-1"><strong>Users:</strong> #encodeForHTML(generatedCount)#</div>
                    </cfif>
                    <cfif len(generatedPages)>
                        <div class="small mb-3"><strong>Projected Pages:</strong> #encodeForHTML(generatedPages)#</div>
                    </cfif>
                    <cfif publishStatus EQ "ok" AND len(publishPath)>
                        <div class="small mb-3"><strong>Dropbox:</strong> Published to #encodeForHTML(publishPath)#</div>
                    <cfelseif publishStatus EQ "fail">
                        <div class="small mb-3 text-warning"><strong>Dropbox:</strong> Publish failed (local PDF still available).</div>
                    </cfif>
                    <a class="btn btn-ui-go" href="download.cfm?year=#urlEncodedFormat(generatedYear)#">
                        <i class="bi bi-download me-1"></i>Download PDF
                    </a>
                </div>
            </div>
        </cfif>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">