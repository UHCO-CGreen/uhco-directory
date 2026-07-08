<!---
    Access Areas — manage permission strings grantable to identity users.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset allAreas = accessService.getAccessAreas().data>
<cfset msgParam = structKeyExists(url, "msg") ? trim(url.msg) : "">
<cfset errParam = structKeyExists(url, "err") ? trim(url.err) : "">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-access-areas-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-permissions/">Admin Permissions</a></li>
        <li class="breadcrumb-item active">Access Areas</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-key me-2"></i>Access Areas</h1>
<p class="text-muted">Manage the permission strings (e.g. <code>module.action</code>) that can be granted to identity users.</p>


<div class="card border-0 shadow-sm mt-3 mb-4 settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-plus-circle me-2"></i>Add Access Area</h5>
        <form class="row g-3 align-items-end" method="post" action="saveAccess.cfm">
            <input type="hidden" name="action" value="create">
            <div class="col-md-6">
                <label class="form-label" for="accessName">Access Name</label>
                <input class="form-control" id="accessName" name="AccessName" required
                       placeholder="e.g. module.action">
                <div class="form-text">Use dot-notation format, for example <span class="font-monospace">module.action</span>.</div>
            </div>
            <div class="col-md-auto">
                <button class="btn btn-ui-add"><i class="bi bi-plus-circle me-1"></i>Add Access Area</button>
            </div>
        </form>
    </div>
</div>

<div class="card border-0 shadow-sm settings-shell">
    <div class="card-body">
        <h5 class="mb-3 settings-section-title"><i class="bi bi-list-ul me-2"></i>All Access Areas</h5>
        <cfif arrayLen(allAreas)>
            <div class="table-responsive">
                <table class="table table-sm table-hover align-middle mb-0 settings-table">
                    <thead>
                        <tr>
                            <th>Access Area</th>
                            <th class="text-end">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#allAreas#" index="a">
                            <tr>
                                <td><code>#encodeForHTML(a.ACCESSNAME)#</code></td>
                                <td class="text-end">
                                    <div class="settings-action-group">
                                        <a href="/admin/settings/admin-permissions/access-areas/edit.cfm?areaID=#a.ACCESSAREAID#"
                                           class="btn btn-sm btn-ui-edit users-list-action-button users-list-action-button-edit"
                                           title="Edit Access Area" data-bs-toggle="tooltip" data-bs-title="Edit Access Area" aria-label="Edit Access Area">
                                            <i class="bi bi-pencil-square"></i>
                                        </a>
                                        <a href="/admin/settings/admin-permissions/access-areas/delete.cfm?areaID=#a.ACCESSAREAID#"
                                           class="btn btn-sm btn-ui-delete users-list-action-button users-list-action-button-delete"
                                           title="Delete Access Area" data-bs-toggle="tooltip" data-bs-title="Delete Access Area" aria-label="Delete Access Area">
                                            <i class="bi bi-trash"></i>
                                        </a>
                                    </div>
                                </td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="alert alert-light border mb-0">No access areas defined yet.</div>
        </cfif>
    </div>
</div>

<div class="mt-3">
    <a href="/admin/settings/admin-permissions/" class="btn btn-ui-cancel">
        <i class="bi bi-arrow-left me-1"></i>Back to Admin Permissions
    </a>
    <a href="/admin/settings/user-permissions/" class="btn btn-ui-go ms-2">
        <i class="bi bi-key-fill me-1"></i>User Permissions
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
