<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset quickpullService = createObject("component", "cfc.quickpull_service").init()>
<cfset quickpulls = quickpullService.getQuickpullDefinitions()>
<cfset actionMessage = trim(url.msg ?: "")>
<cfset actionError = trim(url.error ?: "")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-quickpulls-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/uhco-api/">UHCO API</a></li>
        <li class="breadcrumb-item active">Quickpulls</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-diagram-3 me-2"></i>Quickpulls</h1>
        <p class="text-muted mb-0">Select a quickpull to manage its fixed return items and appendable fields.</p>
    </div>
    <a href="/admin/settings/uhco-api/" class="btn btn-outline-secondary">
        <i class="bi bi-arrow-left me-1"></i>Back to UHCO API
    </a>
</div>

<cfif len(actionMessage)>
    <div class="alert alert-success">#encodeForHTML(actionMessage)#</div>
</cfif>
<cfif len(actionError)>
    <div class="alert alert-danger">#encodeForHTML(actionError)#</div>
</cfif>

<div class="row g-4">
    <cfloop array="#quickpulls#" index="quickpull">
        <cfset config = quickpullService.getQuickpullConfig(quickpull.key)>
        <cfset selectedItemCount = arrayLen(config.generalFields) + arrayLen(config.emailTypes) + arrayLen(config.phoneTypes) + arrayLen(config.addressTypes) + arrayLen(config.biographicalItems) + arrayLen(config.imageVariants) + arrayLen(config.externalSystems) + (config.appendOrganizations ? 1 : 0) + (config.appendFlags ? 1 : 0)>
        <div class="col-lg-6">
            <div class="card shadow-sm h-100 settings-hub-card settings-hub-card--primary">
                <div class="card-body">
                    <div class="d-flex justify-content-between align-items-start gap-3 mb-3">
                        <div>
                            <h5 class="card-title mb-1">#encodeForHTML(quickpull.label)#</h5>
                            <div class="small text-muted font-monospace mb-2">#encodeForHTML(quickpull.endpoint)#</div>
                            <p class="text-muted small mb-0">#encodeForHTML(quickpull.description)#</p>
                        </div>
                        <span class="badge settings-badge-count">#selectedItemCount# appended items</span>
                    </div>

                    <div class="small text-uppercase text-muted fw-semibold mb-2">Default Return Items</div>
                    <div class="d-flex flex-wrap gap-2 mb-3">
                        <cfloop array="#quickpull.baseFields#" index="baseField">
                            <span class="badge settings-badge-neutral">#encodeForHTML(baseField)#</span>
                        </cfloop>
                    </div>

                    <a href="edit.cfm?quickpull=#urlEncodedFormat(quickpull.key)#" class="btn btn-primary">
                        <i class="bi bi-sliders me-1"></i>Edit #encodeForHTML(quickpull.label)#
                    </a>
                </div>
            </div>
        </div>
    </cfloop>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">