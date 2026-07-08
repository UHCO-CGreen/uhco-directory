<!---
    CORS Whitelist — edit an existing allowed origin.
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif NOT structKeyExists(url, "originID") OR NOT isNumeric(url.originID) OR val(url.originID) LTE 0>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/?err=#urlEncodedFormat('Invalid origin.')#" addtoken="false">
</cfif>

<cfset corsService = createObject("component", "cfc.cors_service").init()>
<cfset originResult = corsService.getOriginByID(val(url.originID))>
<cfset originRow = originResult.data>
<cfset errParam = structKeyExists(url, "err") ? trim(url.err) : "">

<cfif NOT originResult.success>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/cors/?err=#urlEncodedFormat(originResult.message)#" addtoken="false">
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
        <li class="breadcrumb-item active">Edit Origin</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-pencil-square me-2"></i>Edit Allowed Origin</h1>

<div class="card border-0 shadow-sm mt-3 settings-shell">
    <div class="card-body">
        <form method="post" action="/admin/settings/uhco-api/cors/saveOrigin.cfm" class="row g-3">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="OriginID" value="#originRow.ORIGINID#">

            <div class="col-md-3">
                <label class="form-label" for="matchType">Match Type</label>
                <select class="form-select" id="matchType" name="MatchType">
                    <option value="exact" <cfif originRow.MATCHTYPE EQ "exact">selected</cfif>>Exact origin</option>
                    <option value="wildcard" <cfif originRow.MATCHTYPE EQ "wildcard">selected</cfif>>Wildcard subdomain</option>
                </select>
            </div>

            <div class="col-md-6">
                <label class="form-label" for="originPattern">Origin / Domain</label>
                <input class="form-control" id="originPattern" name="OriginPattern"
                       value="#encodeForHTMLAttribute(originRow.ORIGINPATTERN)#" required>
            </div>

            <div class="col-md-3">
                <label class="form-label" for="originDescription">Description</label>
                <input class="form-control" id="originDescription" name="Description"
                       value="#encodeForHTMLAttribute(trim(originRow.DESCRIPTION ?: ''))#">
            </div>

            <div class="col-12">
                <div class="form-check form-switch">
                    <input class="form-check-input" type="checkbox" role="switch" id="isActive" name="IsActive" value="1"
                           <cfif originRow.ISACTIVE>checked</cfif>>
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
