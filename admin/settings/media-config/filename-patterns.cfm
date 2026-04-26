<!--- ── Authorization: settings.media_config.manage ─────────────────────── --->
<cfif NOT request.hasPermission("settings.media_config.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── DAO ──────────────────────────────────────────────────────────────── --->
<cfset patternDAO = createObject("component", "dao.FileNamePatternDAO").init()>

<!--- ── Handle POST actions ──────────────────────────────────────────────── --->
<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>

    <!--- ── Save (insert or update) ──────────────────────────────────── --->
    <cfif action EQ "save">
        <cfset editID  = val(form.fileNamePatternID ?: 0)>
        <cfset pattern = trim(form.pattern ?: "")>

        <cfif NOT len(pattern)>
            <cfset actionMessage      = "Pattern is required.">
            <cfset actionMessageClass = "alert-danger">
        <cfelse>
            <cftry>
                <cfif editID GT 0>
                    <cfset patternDAO.updatePattern(
                        fileNamePatternID = editID,
                        pattern           = pattern,
                        description       = trim(form.description ?: ""),
                        isActive          = structKeyExists(form, "isActive"),
                        sortOrder         = val(form.sortOrder ?: 0)
                    )>
                    <cfset actionMessage = "Pattern '#encodeForHTML(pattern)#' updated.">
                <cfelse>
                    <cfset newID = patternDAO.insertPattern(
                        pattern     = pattern,
                        description = trim(form.description ?: ""),
                        isActive    = structKeyExists(form, "isActive"),
                        sortOrder   = val(form.sortOrder ?: 0)
                    )>
                    <cfset actionMessage = "Pattern '#encodeForHTML(pattern)#' created (ID: #newID#).">
                </cfif>
            <cfcatch type="any">
                <cfset actionMessage      = "Error saving: #encodeForHTML(cfcatch.message)#">
                <cfset actionMessageClass = "alert-danger">
            </cfcatch>
            </cftry>
        </cfif>

    <!--- ── Delete ────────────────────────────────────────────────────── --->
    <cfelseif action EQ "delete">
        <cfset deleteID = val(form.fileNamePatternID ?: 0)>

        <cfif deleteID GT 0>
            <cftry>
                <cfset patternDAO.deletePattern(deleteID)>
                <cfset actionMessage = "Pattern deleted.">
            <cfcatch type="any">
                <cfset actionMessage      = "Error deleting: #encodeForHTML(cfcatch.message)#">
                <cfset actionMessageClass = "alert-danger">
            </cfcatch>
            </cftry>
        </cfif>
    </cfif>
</cfif>

<!--- ── Load data ────────────────────────────────────────────────────────── --->
<cfset patterns = patternDAO.getAllPatterns()>

<!--- ── Edit mode ────────────────────────────────────────────────────────── --->
<cfset editMode   = false>
<cfset editRecord = {}>
<cfif structKeyExists(url, "edit") AND val(url.edit) GT 0>
    <cfset editRecord = patternDAO.getPatternByID(val(url.edit))>
    <cfif NOT structIsEmpty(editRecord)>
        <cfset editMode = true>
    </cfif>
</cfif>

<!--- ── Build page content ───────────────────────────────────────────────── --->
<cfset content = "">
<cfoutput>
<cfset content &= '
<div class="settings-page settings-filename-patterns-page">
    <nav aria-label="breadcrumb" class="mb-3">
        <ol class="breadcrumb">
            <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
            <li class="breadcrumb-item"><a href="/admin/settings/media-config/">User Media Config</a></li>
            <li class="breadcrumb-item active" aria-current="page">Filename Patterns</li>
        </ol>
    </nav>

    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h1 class="mb-1"><i class="bi bi-file-earmark-text me-2"></i>Filename Patterns</h1>
            <p class="text-muted mb-0">Manage patterns used to auto-match source image files to users.</p>
        </div>
    </div>
'>
</cfoutput>

<!--- ── Flash message ────────────────────────────────────────────────────── --->
<cfif len(actionMessage)>
    <cfoutput>
    <cfset content &= '
    <div class="alert #actionMessageClass# alert-dismissible fade show" role="alert">
        #actionMessage#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
    '>
    </cfoutput>
</cfif>

<!--- ── Form Card ────────────────────────────────────────────────────────── --->
<cfoutput>
<cfset content &= '
    <div class="row g-4">
        <div class="col-lg-5">
            <div class="card shadow-sm settings-shell settings-summary-card">
                <div class="card-header">
                    <h5 class="mb-0">#editMode ? "Edit" : "New"# Pattern</h5>
                </div>
                <div class="card-body">
                    <form method="post" action="/admin/settings/media-config/filename-patterns.cfm">
                        <input type="hidden" name="action" value="save">
                        <input type="hidden" name="fileNamePatternID" value="#editMode ? val(editRecord.FILENAMEPATTERNID) : 0#">

                        <div class="mb-3">
                            <label class="form-label fw-semibold">Pattern <span class="text-danger">*</span></label>
                            <input type="text" name="pattern" class="form-control"
                                   value="#editMode ? encodeForHTMLAttribute(editRecord.PATTERN ?: "") : ""#"
                                   placeholder="e.g. {first}-{last}" required>
                            <div class="form-text">Use tokens below. Everything else is literal text.</div>
                        </div>

                        <div class="mb-3">
                            <label class="form-label fw-semibold">Description</label>
                            <input type="text" name="description" class="form-control"
                                   value="#editMode ? encodeForHTMLAttribute(editRecord.DESCRIPTION ?: "") : ""#"
                                   placeholder="Human-readable description">
                        </div>

                        <div class="row g-3 mb-3">
                            <div class="col-6">
                                <label class="form-label fw-semibold">Sort Order</label>
                                <input type="number" name="sortOrder" class="form-control"
                                       value="#editMode ? val(editRecord.SORTORDER ?: 0) : 0#" min="0">
                            </div>
                            <div class="col-6 d-flex align-items-end">
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" name="isActive" id="isActive"
                                        #(editMode ? (isBoolean(editRecord.ISACTIVE ?: true) AND editRecord.ISACTIVE ? "checked" : "") : "checked")#>
                                    <label class="form-check-label" for="isActive">Active</label>
                                </div>
                            </div>
                        </div>

                        <div class="d-flex gap-2">
                            <button type="submit" class="btn btn-primary">
                                <i class="bi bi-check-lg me-1"></i> #editMode ? "Update" : "Create"#
                            </button>
                            <cfif editMode>
                                <a href="/admin/settings/media-config/filename-patterns.cfm" class="btn btn-outline-secondary">Cancel</a>
                            </cfif>
                        </div>
                    </form>
                </div>
            </div>

            <!--- Token Reference Card --->
            <div class="card shadow-sm mt-3 settings-shell settings-reference-card">
                <div class="card-header">
                    <h6 class="mb-0"><i class="bi bi-braces me-1"></i>Available Tokens</h6>
                </div>
                <div class="card-body p-0">
                    <table class="table table-sm mb-0 settings-table">
                        <thead>
                            <tr><th>Token</th><th>Resolves To</th><th>Example</th></tr>
                        </thead>
                        <tbody>
                            <tr><td><code>{first}</code></td><td>Full first name</td><td>john</td></tr>
                            <tr><td><code>{last}</code></td><td>Full last name</td><td>doe</td></tr>
                            <tr><td><code>{middle}</code></td><td>Full middle name</td><td>michael</td></tr>
                            <tr><td><code>{fi}</code></td><td>First initial</td><td>j</td></tr>
                            <tr><td><code>{mi}</code></td><td>Middle initial</td><td>m</td></tr>
                        </tbody>
                    </table>
                </div>
                <div class="card-footer text-muted small">
                    Tokens with empty values (e.g. no middle name) cause the pattern to be skipped for that user.
                    External ID values (CougarNet, PeopleSoft, etc.) are always included automatically.
                </div>
            </div>

            <!--- Preview Card --->
            <div class="card shadow-sm mt-3 settings-shell settings-reference-card">
                <div class="card-header">
                    <h6 class="mb-0"><i class="bi bi-eye me-1"></i>Preview: John Michael Doe</h6>
                </div>
                <div class="card-body p-0">
                    <table class="table table-sm mb-0 settings-table">
                        <thead>
                            <tr><th>Pattern</th><th>Resolved</th></tr>
                        </thead>
                        <tbody id="previewBody">
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!--- ── Patterns Table ─────────────────────────────────────────── --->
        <div class="col-lg-7">
            <div class="card shadow-sm settings-shell">
                <div class="card-header d-flex justify-content-between align-items-center">
                    <h5 class="mb-0">All Patterns</h5>
                    <span class="badge settings-badge-count">#arrayLen(patterns)#</span>
                </div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-hover table-sm align-middle mb-0 settings-table">
                            <thead>
                                <tr>
                                    <th>Pattern</th>
                                    <th>Description</th>
                                    <th class="text-center">Order</th>
                                    <th class="text-center">Active</th>
                                    <th class="text-end">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
'>
</cfoutput>

<cfif arrayLen(patterns) EQ 0>
    <cfset content &= '<tr><td colspan="5" class="text-center text-muted py-3">No patterns defined yet.</td></tr>'>
<cfelse>
    <cfloop from="1" to="#arrayLen(patterns)#" index="i">
        <cfset p = patterns[i]>
        <cfoutput>
        <cfset content &= '
                                <tr>
                                    <td><code>#encodeForHTML(p.PATTERN ?: "")#</code></td>
                                    <td class="text-muted small">#encodeForHTML(p.DESCRIPTION ?: "")#</td>
                                    <td class="text-center">#val(p.SORTORDER ?: 0)#</td>
                                    <td class="text-center">
                                        <cfif isBoolean(p.ISACTIVE ?: false) AND p.ISACTIVE>
                                            <span class="badge settings-badge-active">Yes</span>
                                        <cfelse>
                                            <span class="badge settings-badge-neutral">No</span>
                                        </cfif>
                                    </td>
                                    <td class="text-end">
                                        <a href="/admin/settings/media-config/filename-patterns.cfm?edit=#val(p.FILENAMEPATTERNID)#"
                                           class="btn btn-sm btn-edit users-list-action-button users-list-action-button-edit" title="Edit" aria-label="Edit Pattern">
                                            <i class="bi bi-pencil-square"></i>
                                        </a>
                                        <button type="button" class="btn btn-sm btn-remove users-list-action-button users-list-action-button-delete"
                                                onclick="confirmDelete(#val(p.FILENAMEPATTERNID)#, ''#encodeForJavaScript(p.PATTERN ?: "")#'')"
                                                title="Delete" aria-label="Delete Pattern">
                                            <i class="bi bi-trash"></i>
                                        </button>
                                    </td>
                                </tr>
        '>
        </cfoutput>
    </cfloop>
</cfif>

<cfoutput>
<cfset content &= '
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!--- ── Delete Confirmation Modal ────────────────────────────────────────── --->
<div class="modal fade settings-danger-modal" id="deleteModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header bg-danger text-white">
                <h5 class="modal-title"><i class="bi bi-exclamation-triangle me-2"></i>Confirm Delete</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <p>Are you sure you want to delete the pattern <strong id="deletePatternName"></strong>?</p>
                <p class="text-muted small mb-0">This only removes the pattern definition. It does not affect any existing source assignments or generated images.</p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <form method="post" action="/admin/settings/media-config/filename-patterns.cfm" id="deleteForm" class="d-inline">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="fileNamePatternID" id="deleteID" value="">
                    <button type="submit" class="btn btn-danger">
                        <i class="bi bi-trash me-1"></i> Delete
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>
'>
</cfoutput>

<!--- ── Page Scripts ─────────────────────────────────────────────────────── --->
<cfset pageScripts = "">
<cfoutput>
<cfset pageScripts &= '
<script>
    function confirmDelete(id, pattern) {
        document.getElementById("deleteID").value = id;
        document.getElementById("deletePatternName").textContent = pattern;
        new bootstrap.Modal(document.getElementById("deleteModal")).show();
    }

    // Live preview of all active patterns
    (function() {
        const sample = { first: "john", last: "doe", middle: "michael", fi: "j", mi: "m" };
        const rows = [];
        '>
</cfoutput>

<cfloop from="1" to="#arrayLen(patterns)#" index="i">
    <cfset p = patterns[i]>
    <cfif isBoolean(p.ISACTIVE ?: false) AND p.ISACTIVE>
        <cfoutput>
        <cfset pageScripts &= '
        rows.push({ pattern: "#encodeForJavaScript(p.PATTERN ?: "")#" });
        '>
        </cfoutput>
    </cfif>
</cfloop>

<cfoutput>
<cfset pageScripts &= '
        const tbody = document.getElementById("previewBody");
        rows.forEach(r => {
            let resolved = r.pattern.toLowerCase();
            resolved = resolved.replace(/\{first\}/g, sample.first);
            resolved = resolved.replace(/\{last\}/g, sample.last);
            resolved = resolved.replace(/\{middle\}/g, sample.middle);
            resolved = resolved.replace(/\{fi\}/g, sample.fi);
            resolved = resolved.replace(/\{mi\}/g, sample.mi);

            const tr = document.createElement("tr");
            tr.innerHTML = "<td><code>" + r.pattern + "</code></td><td><code>" + resolved + "</code></td>";
            tbody.appendChild(tr);
        });
        if (!rows.length) {
            tbody.innerHTML = "<tr><td colspan=\"2\" class=\"text-muted text-center\">No active patterns</td></tr>";
        }
    })();
</script>
'>
</cfoutput>

<cfinclude template="/admin/layout.cfm">
