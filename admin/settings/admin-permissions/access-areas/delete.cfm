<!---
    Access Areas — confirm and delete an access area.
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
<cfset assignmentCount = accessService.countAssignmentsForArea(val(url.areaID))>

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
        <li class="breadcrumb-item active">Delete</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-trash me-2"></i>Delete Access Area</h1>

<div class="card border-0 shadow-sm mt-3 settings-shell">
    <div class="card-body">
        <p class="mb-3">You are about to delete <strong><code>#encodeForHTML(area.ACCESSNAME)#</code></strong>.</p>

        <cfif assignmentCount GT 0>
            <div class="alert alert-warning mb-3">
                This access area is currently assigned to <strong>#assignmentCount#</strong> user<cfif assignmentCount NEQ 1>s</cfif>.
                Remove those assignments before deleting it.
            </div>
        <cfelse>
            <div class="alert alert-warning mb-3">
                This action cannot be undone.
            </div>
        </cfif>

        <form method="post" action="/admin/settings/admin-permissions/access-areas/saveAccess.cfm" class="d-flex gap-2">
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="areaID" value="#area.ACCESSAREAID#">
            <button type="submit" class="btn btn-ui-delete" <cfif assignmentCount GT 0>disabled</cfif>>Delete Access Area</button>
            <a href="/admin/settings/admin-permissions/access-areas/" class="btn btn-ui-cancel">Cancel</a>
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
