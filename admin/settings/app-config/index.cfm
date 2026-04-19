<cfif NOT request.hasPermission("settings.app_config.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset mediaConfigService = createObject("component", "cfc.mediaConfig_service").init()>

<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cftry>
        <cfset mediaConfigService.setPublishedSiteBaseUrl( trim(form.publishedSiteBaseUrl ?: "") )>
        <cfset actionMessage = "Application settings saved.">
    <cfcatch type="any">
        <cfset actionMessage = cfcatch.message>
        <cfset actionMessageClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<cfset publishedSiteBaseUrl = mediaConfigService.getPublishedSiteBaseUrl()>
<cfset publishedImageBaseUrl = mediaConfigService.getPublishedImageBaseUrl()>
<cfset allConfig = appConfigService.getAll()>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Application Settings</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-sliders me-2"></i>Application Settings</h1>
        <p class="text-muted mb-0">Generic application configuration stored in AppConfig. Start here for environment-specific values that will expand over time.</p>
    </div>
</div>

<cfif len(actionMessage)>
    <div class="alert #actionMessageClass# alert-dismissible fade show" role="alert">
        #encodeForHTML(actionMessage)#
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
</cfif>

<div class="card shadow-sm mb-4">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-image me-2"></i>Published Image URL Settings</h5>
    </div>
    <div class="card-body">
        <form method="post" class="row g-3 align-items-end">
            <div class="col-lg-8">
                <label for="publishedSiteBaseUrl" class="form-label fw-bold">Published Site Base URL</label>
                <input
                    type="url"
                    class="form-control"
                    id="publishedSiteBaseUrl"
                    name="publishedSiteBaseUrl"
                    value="#encodeForHTMLAttribute(publishedSiteBaseUrl)#"
                    placeholder="https://portal.opt.uh.edu/"
                    required
                >
                <div class="form-text">Publishing appends <code>_published_images/filename.ext</code> to this base URL.</div>
            </div>
            <div class="col-lg-4">
                <button type="submit" class="btn btn-primary">
                    <i class="bi bi-save me-1"></i>Save Settings
                </button>
            </div>
        </form>

        <div class="mt-3 small text-muted">
            Effective published image base URL: <code>#encodeForHTML(publishedImageBaseUrl)#</code>
        </div>
    </div>
</div>

<div class="card shadow-sm">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5 class="mb-0"><i class="bi bi-table me-2"></i>Current AppConfig Values</h5>
        <span class="badge bg-secondary">#arrayLen(allConfig)#</span>
    </div>
    <div class="card-body p-0">
        <cfif arrayLen(allConfig)>
            <div class="table-responsive">
                <table class="table table-sm table-hover mb-0 align-middle">
                    <thead class="table-light">
                        <tr>
                            <th>Config Key</th>
                            <th>Config Value</th>
                            <th>Updated</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop from="1" to="#arrayLen(allConfig)#" index="i">
                            <cfset row = allConfig[i]>
                            <tr>
                                <td class="font-monospace">#encodeForHTML(row.CONFIGKEY)#</td>
                                <td class="font-monospace small">#encodeForHTML(row.CONFIGVALUE)#</td>
                                <td class="small text-muted">#len(row.UPDATEDAT ?: "") ? dateTimeFormat(row.UPDATEDAT, "mmm d, yyyy h:nn tt") : ""#</td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="p-3 text-muted">No app settings found.</div>
        </cfif>
    </div>
</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">