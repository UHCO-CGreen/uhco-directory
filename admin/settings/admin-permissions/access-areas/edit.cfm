<!---
    Access Areas — edit an existing access area.
    Permission: settings.admin_permissions.manage.
--->

<cfif NOT request.hasPermission("settings.admin_permissions.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif NOT structKeyExists(url, "areaID") OR NOT isNumeric(url.areaID) OR val(url.areaID) LTE 0>
    <cflocation url="#request.webRoot#/admin/settings/admin-permissions/access-areas/?err=#urlEncodedFormat('Invalid access area.')#" addtoken="false">
</cfif>

<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset areaResult = accessService.getAccessAreaByID(val(url.areaID))>
<cfset area = areaResult.data>
<cfset errParam = structKeyExists(url, "err") ? trim(url.err) : "">

<cfif NOT areaResult.success>
    <cflocation url="#request.webRoot#/admin/settings/admin-permissions/access-areas/?err=#urlEncodedFormat(areaResult.message)#" addtoken="false">
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-access-areas-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-permissions/">Admin Permissions</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/admin-permissions/access-areas/">Access Areas</a></li>
        <li class="breadcrumb-item active">Edit</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-pencil-square me-2"></i>Edit Access Area</h1>

<div class="card border-0 shadow-sm mt-3 settings-shell">
    <div class="card-body">
        <form method="post" action="/admin/settings/admin-permissions/access-areas/saveAccess.cfm" class="row g-3">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="areaID" value="#area.ACCESSAREAID#">

            <div class="col-md-8">
                <label class="form-label" for="accessName">Access Name</label>
                <input class="form-control" id="accessName" name="AccessName"
                       value="#encodeForHTMLAttribute(area.ACCESSNAME)#" required>
                <div class="form-text">Use the permission string users will be granted, for example <span class="font-monospace">module.action</span>.</div>
            </div>

            <div class="col-12 d-flex gap-2">
                <button type="submit" class="btn btn-ui-save">Save Changes</button>
                <a href="/admin/settings/admin-permissions/access-areas/" class="btn btn-ui-cancel">Cancel</a>
            </div>
        </form>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif len(errParam)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(errParam)#", { tone: 'danger' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
