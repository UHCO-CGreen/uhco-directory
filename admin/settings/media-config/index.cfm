<!--- ── User Media Config Hub ────────────────────────────────────────────── --->
<cfif NOT request.hasPermission("settings.media_config.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Load summary stats ───────────────────────────────────────────────── --->
<cfset patternDAO = createObject("component", "dao.FileNamePatternDAO").init()>
<cfset variantDAO = createObject("component", "dao.UserImageVariantDAO").init()>
<cfset patterns   = patternDAO.getAllPatterns()>
<cfset allTypes   = variantDAO.getVariantTypesAllAdmin()>

<cfset activePatterns = 0>
<cfloop from="1" to="#arrayLen(patterns)#" index="i">
    <cfif isBoolean(patterns[i].ISACTIVE ?: false) AND patterns[i].ISACTIVE>
        <cfset activePatterns++>
    </cfif>
</cfloop>

<cfset activeTypes = 0>
<cfloop from="1" to="#arrayLen(allTypes)#" index="i">
    <cfif isBoolean(allTypes[i].ISACTIVE ?: false) AND allTypes[i].ISACTIVE>
        <cfset activeTypes++>
    </cfif>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-media-config-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">User Media Config</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-image me-2"></i>User Media Config</h1>
        <p class="text-muted mb-0">Manage filename patterns and image variant type definitions.</p>
    </div>
</div>

<div class="row g-4">

    <!--- Publishing Settings Card --->
    <div class="col-md-6">
        <div class="card shadow-sm h-100 settings-hub-card settings-hub-card--warning">
            <div class="card-body d-flex flex-column">
                <div class="d-flex align-items-center mb-3">
                    <div class="bg-info bg-opacity-10 rounded-3 p-3 me-3">
                        <i class="bi bi-globe fs-3 settings-hub-icon settings-hub-icon--warning"></i>
                    </div>
                    <div>
                        <h5 class="card-title mb-0">Publishing Settings</h5>
                        <p class="text-muted small mb-0">Environment-specific published media URLs</p>
                    </div>
                </div>
                <p class="card-text small">
                    Configure the base site URL used when writing <code>UserImages.ImageURL</code>
                    so local development and production can use different domains safely.
                </p>
                <div class="mt-auto">
                    <a href="/admin/settings/app-config/" class="btn btn-info text-white">
                        <i class="bi bi-pencil-square me-1"></i> Manage App Settings
                    </a>
                </div>
            </div>
        </div>
    </div>

    <!--- Filename Patterns Card --->
    <div class="col-md-6">
        <div class="card shadow-sm h-100 settings-hub-card settings-hub-card--primary">
            <div class="card-body d-flex flex-column">
                <div class="d-flex align-items-center mb-3">
                    <div class="bg-primary bg-opacity-10 rounded-3 p-3 me-3">
                        <i class="bi bi-file-earmark-text fs-3 settings-hub-icon"></i>
                    </div>
                    <div>
                        <h5 class="card-title mb-0">Filename Patterns</h5>
                        <p class="text-muted small mb-0">Auto-match source image files to users</p>
                    </div>
                </div>
                <p class="card-text small">
                    Define token-based patterns (e.g. <code>{first}-{last}</code>) that the system uses to
                    automatically match uploaded image filenames to user records.
                </p>
                <div class="d-flex gap-3 mb-3">
                    <div>
                        <span class="badge settings-badge-count">#arrayLen(patterns)# total</span>
                    </div>
                    <div>
                        <span class="badge settings-badge-active">#activePatterns# active</span>
                    </div>
                </div>
                <div class="mt-auto">
                    <a href="/admin/settings/media-config/filename-patterns.cfm" class="btn btn-primary">
                        <i class="bi bi-pencil-square me-1"></i> Manage Patterns
                    </a>
                </div>
            </div>
        </div>
    </div>

    <!--- Variant Types Card --->
    <div class="col-md-6">
        <div class="card shadow-sm h-100 settings-hub-card settings-hub-card--success">
            <div class="card-body d-flex flex-column">
                <div class="d-flex align-items-center mb-3">
                    <div class="bg-success bg-opacity-10 rounded-3 p-3 me-3">
                        <i class="bi bi-sliders fs-3 settings-hub-icon settings-hub-icon--success"></i>
                    </div>
                    <div>
                        <h5 class="card-title mb-0">Variant Types</h5>
                        <p class="text-muted small mb-0">Image output format &amp; dimension definitions</p>
                    </div>
                </div>
                <p class="card-text small">
                    Configure the image variant types that control output format, dimensions,
                    crop/resize behavior, and audience targeting for generated user images.
                </p>
                <div class="d-flex gap-3 mb-3">
                    <div>
                        <span class="badge settings-badge-count">#arrayLen(allTypes)# total</span>
                    </div>
                    <div>
                        <span class="badge settings-badge-active">#activeTypes# active</span>
                    </div>
                </div>
                <div class="mt-auto">
                    <a href="/admin/settings/media-config/variant-types.cfm" class="btn btn-success">
                        <i class="bi bi-pencil-square me-1"></i> Manage Variant Types
                    </a>
                </div>
            </div>
        </div>
    </div>

</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
