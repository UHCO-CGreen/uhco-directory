<!---
    CORS Whitelist — edit an existing trusted IP range.
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif NOT structKeyExists(url, "rangeID") OR NOT isNumeric(url.rangeID) OR val(url.rangeID) LTE 0>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/?err=#urlEncodedFormat('Invalid IP range.')#" addtoken="false">
</cfif>

<cfset corsService = createObject("component", "cfc.cors_service").init()>
<cfset rangeResult = corsService.getIPRangeByID(val(url.rangeID))>
<cfset rangeRow = rangeResult.data>
<cfset errParam = structKeyExists(url, "err") ? trim(url.err) : "">

<cfif NOT rangeResult.success>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/?err=#urlEncodedFormat(rangeResult.message)#" addtoken="false">
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-cors-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/uhco-api/">UHCO API</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/uhco-api/cors/">CORS Whitelist</a></li>
        <li class="breadcrumb-item active">Edit IP Range</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-pencil-square me-2"></i>Edit Trusted IP Range</h1>

<div class="card border-0 shadow-sm mt-3 settings-shell">
    <div class="card-body">
        <form method="post" action="/admin/settings/uhco-api/cors/saveIPRange.cfm" class="row g-3">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="RangeID" value="#rangeRow.RANGEID#">

            <div class="col-md-4">
                <label class="form-label" for="cidr">IP or CIDR Range</label>
                <input class="form-control" id="cidr" name="CIDR"
                       value="#encodeForHTMLAttribute(rangeRow.CIDR)#" required>
                <div class="form-text">IPv4 only.</div>
            </div>

            <div class="col-md-5">
                <label class="form-label" for="rangeDescription">Description</label>
                <input class="form-control" id="rangeDescription" name="Description"
                       value="#encodeForHTMLAttribute(trim(rangeRow.DESCRIPTION ?: ''))#">
            </div>

            <div class="col-12">
                <div class="form-check form-switch">
                    <input class="form-check-input" type="checkbox" role="switch" id="isActive" name="IsActive" value="1"
                           <cfif rangeRow.ISACTIVE>checked</cfif>>
                    <label class="form-check-label" for="isActive">Active</label>
                </div>
            </div>

            <div class="col-12 d-flex gap-2">
                <button type="submit" class="btn btn-ui-save">Save Changes</button>
                <a href="/admin/settings/uhco-api/cors/" class="btn btn-ui-cancel">Cancel</a>
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
