<!---
    Edit Bulk Exclusion Type — flags, codes, label, icon.
    Permission: settings.bulk_exclusions.manage.
--->

<cfif NOT request.hasPermission("settings.bulk_exclusions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset svc = createObject("component", "cfc.bulkExclusions_service").init()>

<!--- Require type key --->
<cfif NOT structKeyExists(url, "type") OR NOT len(trim(url.type))>
    <cflocation url="#request.webRoot#/admin/settings/bulk-exclusions/" addtoken="false">
</cfif>

<cfset typeKey  = trim(url.type)>
<cfset typeData = svc.getType(typeKey)>

<cfif structIsEmpty(typeData)>
    <cflocation url="#request.webRoot#/admin/settings/bulk-exclusions/?err=Type not found." addtoken="false">
</cfif>

<!--- Handle form POST --->
<cfif structKeyExists(form, "save")>
    <cftry>
        <cfset svc.saveType(
            typeKey     = typeKey,
            flags       = trim(form.flags),
            codes       = trim(form.codes),
            label       = trim(form.label),
            icon        = trim(form.icon),
            extraFilter = trim(form.extraFilter ?: ""),
            updatedBy   = session.username ?: "admin"
        )>
        <cflocation url="#request.webRoot#/admin/settings/bulk-exclusions/?msg=#encodeForURL(typeData.LABEL & ' updated successfully.')#" addtoken="false">
    <cfcatch type="any">
        <cfset saveError = cfcatch.message>
    </cfcatch>
    </cftry>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-bulk-exclusions-edit-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/bulk-exclusions/">Bulk Exclusions</a></li>
        <li class="breadcrumb-item active">Edit: #encodeForHTML(typeData.LABEL)#</li>
    </ol>
</nav>

<h1 class="mb-1">
    <i class="bi #typeData.ICON# me-2"></i>Edit: #encodeForHTML(typeData.LABEL)#
</h1>
<p class="text-muted">Edit the flags, exclusion codes, and display settings for this type.</p>

<cfif structKeyExists(variables, "saveError")>
    <div class="alert alert-danger mt-3">
        <i class="bi bi-exclamation-triangle me-1"></i>#encodeForHTML(saveError)#
    </div>
</cfif>

<div class="card border-0 shadow-sm mt-3 settings-shell settings-summary-card">
    <div class="card-body">
        <form method="post">
            <input type="hidden" name="save" value="1">

            <div class="row g-3">
                <!--- Label --->
                <div class="col-md-6">
                    <label for="label" class="form-label fw-bold">Label</label>
                    <input type="text" id="label" name="label" class="form-control"
                           value="#encodeForHTMLAttribute(typeData.LABEL)#" required maxlength="100">
                </div>

                <!--- Icon --->
                <div class="col-md-6">
                    <label for="icon" class="form-label fw-bold">
                        Icon <small class="text-muted">(Bootstrap Icons class)</small>
                    </label>
                    <div class="input-group">
                        <span class="input-group-text" id="iconPreview">
                            <i class="bi #typeData.ICON#"></i>
                        </span>
                        <input type="text" id="icon" name="icon" class="form-control"
                               value="#encodeForHTMLAttribute(typeData.ICON)#" required maxlength="50"
                               placeholder="bi-person">
                    </div>
                    <div class="form-text">e.g. bi-person-badge, bi-mortarboard, bi-briefcase</div>
                </div>

                <!--- Flags --->
                <div class="col-12">
                    <label for="flags" class="form-label fw-bold">Flags</label>
                    <textarea id="flags" name="flags" class="form-control" rows="3" required
                              placeholder="flag-name-1, flag-name-2">#encodeForHTML(typeData.FLAGS)#</textarea>
                    <div class="form-text">
                        Comma-separated flag names. Users with matching UserFlag assignments will be selected.
                        Matched via <code>LOWER(TRIM(FlagName)) IN (...)</code>.
                    </div>
                </div>

                <!--- Codes --->
                <div class="col-12">
                    <label for="codes" class="form-label fw-bold">Exclusion Codes</label>
                    <textarea id="codes" name="codes" class="form-control" rows="4" required
                              placeholder="missing_email_primary, missing_phone">#encodeForHTML(typeData.CODES)#</textarea>
                    <div class="form-text">
                        Comma-separated issue codes. Each code will be inserted as a DataQualityExclusion row for every matched user.
                    </div>
                </div>

                <!--- Extra Filter (advanced) --->
                <div class="col-12">
                    <label for="extraFilter" class="form-label fw-bold">
                        Extra SQL Filter <small class="text-muted">(advanced, optional)</small>
                    </label>
                    <textarea id="extraFilter" name="extraFilter" class="form-control font-monospace" rows="3"
                              placeholder="LOWER(TRIM(u.Title1)) = 'alumni' AND uai.CurrentGradYear BETWEEN 1955 AND 2025">#encodeForHTML(typeData.EXTRA_FILTER ?: "")#</textarea>
                    <div class="form-text">
                        Optional WHERE clause fragment appended to the query. Use <code>u.</code> for Users table,
                        <code>uai.</code> for UserAcademicInfo (auto-joined if referenced).
                        <strong class="text-warning">Caution:</strong> Invalid SQL will cause the run to fail.
                    </div>
                </div>
            </div>

            <!--- Current code preview --->
            <div class="mt-4">
                <h6 class="text-muted mb-2"><i class="bi bi-eye me-1"></i>Current Codes Preview</h6>
                <div id="codesPreview" class="d-flex flex-wrap gap-1 mb-3">
                    <cfloop list="#typeData.CODES#" index="code">
                        <span class="badge settings-badge-neutral">#trim(code)#</span>
                    </cfloop>
                </div>
            </div>

            <hr>
            <div class="d-flex justify-content-between align-items-center">
                <div class="text-muted small">
                    <cfif len(typeData.UPDATED_BY ?: "")>
                        Last edited by <strong>#encodeForHTML(typeData.UPDATED_BY)#</strong>
                        on #dateTimeFormat(typeData.UPDATED_AT, "MMM d, yyyy h:nn tt")#
                    </cfif>
                </div>
                <div>
                    <a href="/admin/settings/bulk-exclusions/" class="btn btn-outline-secondary me-2">Cancel</a>
                    <button type="submit" class="btn btn-primary">
                        <i class="bi bi-check-lg me-1"></i>Save Changes
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<script>
    // Live icon preview
    document.getElementById('icon').addEventListener('input', function() {
        var preview = document.getElementById('iconPreview');
        preview.innerHTML = '<i class="bi ' + this.value + '"></i>';
    });

    // Live codes badge preview
    document.getElementById('codes').addEventListener('input', function() {
        var container = document.getElementById('codesPreview');
        var codes = this.value.split(',').map(function(c){ return c.trim(); }).filter(Boolean);
        container.innerHTML = codes.map(function(c){
            return '<span class="badge settings-badge-neutral">' + c.replace(/</g,'&lt;') + '</span>';
        }).join(' ');
    });
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
