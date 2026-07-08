<!---
    UHCO API — CORS Whitelist (allowed origins + trusted IP/CIDR ranges).
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset corsService = createObject("component", "cfc.cors_service").init()>
<cfset origins = corsService.getAllOrigins().data>
<cfset ipRanges = corsService.getAllIPRanges().data>
<cfset ipRangeCheckEnabled = corsService.isIPRangeCheckEnabled()>
<cfset msgParam = structKeyExists(url, "msg") ? trim(url.msg) : "">
<cfset errParam = structKeyExists(url, "err") ? trim(url.err) : "">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-cors-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/uhco-api/">UHCO API</a></li>
        <li class="breadcrumb-item active">CORS Whitelist</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-globe2 me-2"></i>CORS Whitelist</h1>
<p class="text-muted mb-4">
    Any subdomain of <code>opt.uh.edu</code> is always allowed to call the API from a browser.
    Use this page to trust additional domains, or to allow calls from a range of source IPs
    (e.g. a developer's machine on the campus network) regardless of the Origin they send.
</p>

<!--- IP Range Check toggle --->
<div class="card border-0 shadow-sm mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-2 settings-section-title"><i class="bi bi-toggle2-off me-2"></i>IP Range Trust Check</h5>
        <p class="text-muted small">
            When enabled, any request whose source IP matches an active range below is trusted
            to make a cross-origin call using <strong>any</strong> Origin — not just the ones listed
            above. Scope ranges as narrowly as practical. Off by default, and cannot be turned on
            until at least one active IP range exists.
        </p>
        <form method="post" action="/admin/settings/uhco-api/cors/saveIPRangeCheckToggle.cfm" class="d-flex align-items-center gap-3">
            <div class="form-check form-switch mb-0">
                <input class="form-check-input" type="checkbox" role="switch" id="ipRangeCheckEnabled"
                       name="enabled" value="1" onchange="this.form.requestSubmit()"
                       <cfif ipRangeCheckEnabled>checked</cfif>>
                <label class="form-check-label" for="ipRangeCheckEnabled">
                    #(ipRangeCheckEnabled ? "Enabled" : "Disabled")#
                </label>
            </div>
        </form>
    </div>
</div>

<!--- Allowed Origins --->
<div class="card border-0 shadow-sm mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-plus-circle me-2"></i>Add Allowed Origin</h5>
        <form class="row g-3 align-items-end" method="post" action="/admin/settings/uhco-api/cors/saveOrigin.cfm">
            <input type="hidden" name="action" value="create">
            <div class="col-md-3">
                <label class="form-label" for="matchType">Match Type</label>
                <select class="form-select" id="matchType" name="MatchType">
                    <option value="exact">Exact origin</option>
                    <option value="wildcard">Wildcard subdomain</option>
                </select>
            </div>
            <div class="col-md-5">
                <label class="form-label" for="originPattern">Origin / Domain</label>
                <input class="form-control" id="originPattern" name="OriginPattern" required
                       placeholder="https://partner.example.edu or partner.example.edu">
                <div class="form-text">Exact: full <span class="font-monospace">scheme://host[:port]</span>. Wildcard: bare domain, matches any subdomain.</div>
            </div>
            <div class="col-md-3">
                <label class="form-label" for="originDescription">Description</label>
                <input class="form-control" id="originDescription" name="Description" placeholder="Optional">
            </div>
            <div class="col-md-auto">
                <button class="btn btn-ui-add"><i class="bi bi-plus-circle me-1"></i>Add</button>
            </div>
        </form>
    </div>
</div>

<div class="card border-0 shadow-sm mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>Allowed Origins</h5>
        <cfif arrayLen(origins)>
            <div class="table-responsive">
                <table class="table table-sm table-hover align-middle mb-0 settings-table">
                    <thead>
                        <tr>
                            <th>Origin / Domain</th>
                            <th>Type</th>
                            <th>Description</th>
                            <th>Status</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#origins#" index="o">
                            <tr>
                                <td><code>#encodeForHTML(o.ORIGINPATTERN)#</code></td>
                                <td class="small text-capitalize">#encodeForHTML(o.MATCHTYPE)#</td>
                                <td class="small">#encodeForHTML(trim(o.DESCRIPTION ?: ""))#</td>
                                <td>
                                    <cfif o.ISACTIVE>
                                        <span class="badge settings-badge-active">Active</span>
                                    <cfelse>
                                        <span class="badge bg-secondary">Inactive</span>
                                    </cfif>
                                </td>
                                <td class="text-end">
                                    <div class="settings-action-group">
                                        <a href="/admin/settings/uhco-api/cors/edit-origin.cfm?originID=#o.ORIGINID#"
                                           class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit"
                                           title="Edit Origin" data-bs-toggle="tooltip" data-bs-title="Edit Origin" aria-label="Edit Origin">
                                            <i class="bi bi-pencil-square"></i>
                                        </a>
                                        <form method="post" action="/admin/settings/uhco-api/cors/saveOrigin.cfm" class="d-inline" data-confirm="Delete this allowed origin?">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="OriginID" value="#o.ORIGINID#">
                                            <button class="btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete" title="Delete Origin" data-bs-toggle="tooltip" data-bs-title="Delete Origin" aria-label="Delete Origin">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="alert alert-light border mb-0">No additional origins whitelisted yet.</div>
        </cfif>
    </div>
</div>

<!--- Allowed IP Ranges --->
<div class="card border-0 shadow-sm mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-plus-circle me-2"></i>Add Trusted IP Range</h5>
        <form class="row g-3 align-items-end" method="post" action="/admin/settings/uhco-api/cors/saveIPRange.cfm">
            <input type="hidden" name="action" value="create">
            <div class="col-md-4">
                <label class="form-label" for="cidr">IP or CIDR Range</label>
                <input class="form-control" id="cidr" name="CIDR" required placeholder="e.g. 129.7.0.0/16 or 10.0.0.5">
                <div class="form-text">IPv4 only.</div>
            </div>
            <div class="col-md-5">
                <label class="form-label" for="rangeDescription">Description</label>
                <input class="form-control" id="rangeDescription" name="Description" placeholder="Optional">
            </div>
            <div class="col-md-auto">
                <button class="btn btn-ui-add"><i class="bi bi-plus-circle me-1"></i>Add</button>
            </div>
        </form>
    </div>
</div>

<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>Trusted IP Ranges</h5>
        <cfif arrayLen(ipRanges)>
            <div class="table-responsive">
                <table class="table table-sm table-hover align-middle mb-0 settings-table">
                    <thead>
                        <tr>
                            <th>CIDR / IP</th>
                            <th>Description</th>
                            <th>Status</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#ipRanges#" index="r">
                            <tr>
                                <td><code>#encodeForHTML(r.CIDR)#</code></td>
                                <td class="small">#encodeForHTML(trim(r.DESCRIPTION ?: ""))#</td>
                                <td>
                                    <cfif r.ISACTIVE>
                                        <span class="badge settings-badge-active">Active</span>
                                    <cfelse>
                                        <span class="badge bg-secondary">Inactive</span>
                                    </cfif>
                                </td>
                                <td class="text-end">
                                    <div class="settings-action-group">
                                        <a href="/admin/settings/uhco-api/cors/edit-iprange.cfm?rangeID=#r.RANGEID#"
                                           class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit"
                                           title="Edit IP Range" data-bs-toggle="tooltip" data-bs-title="Edit IP Range" aria-label="Edit IP Range">
                                            <i class="bi bi-pencil-square"></i>
                                        </a>
                                        <form method="post" action="/admin/settings/uhco-api/cors/saveIPRange.cfm" class="d-inline" data-confirm="Delete this trusted IP range?">
                                            <input type="hidden" name="action" value="delete">
                                            <input type="hidden" name="RangeID" value="#r.RANGEID#">
                                            <button class="btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete" title="Delete IP Range" data-bs-toggle="tooltip" data-bs-title="Delete IP Range" aria-label="Delete IP Range">
                                                <i class="bi bi-trash"></i>
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="alert alert-light border mb-0">No trusted IP ranges defined yet.</div>
        </cfif>
    </div>
</div>

<div class="mt-3">
    <a href="/admin/settings/uhco-api/" class="btn btn-ui-cancel">
        <i class="bi bi-arrow-left me-1"></i>Back to UHCO API
    </a>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif len(msgParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(msgParam)#", { tone: 'success' });
}
</cfif>
<cfif len(errParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'danger' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
