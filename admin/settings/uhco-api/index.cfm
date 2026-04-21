<!---
    UHCO API — Settings hub for Tokens & Secrets.
    Permission: settings.api.manage.
--->

<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset tokenService  = createObject("component", "cfc.token_service").init()>
<cfset secretService = createObject("component", "cfc.secret_service").init()>
<cfset tokens  = tokenService.getAllTokens()>
<cfset secrets = secretService.getAllSecrets()>
<cfset actionMessage = trim(url.msg ?: "")>
<cfset actionError = trim(url.error ?: "")>

<cfset activeTokens  = 0>
<cfset activeSecrets = 0>
<cfloop array="#tokens#" index="t">
    <cfif t.ISACTIVE EQ 1><cfset activeTokens++></cfif>
</cfloop>
<cfloop array="#secrets#" index="s">
    <cfif s.ISACTIVE><cfset activeSecrets++></cfif>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-uhco-api-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">UHCO API</li>
    </ol>
</nav>

<h1 class="mb-1"><i class="bi bi-braces me-2"></i>UHCO API</h1>
<p class="text-muted mb-4">Manage API tokens and secrets for external integrations.</p>

<cfif len(actionMessage)>
    <div class="alert alert-success">#encodeForHTML(actionMessage)#</div>
</cfif>
<cfif len(actionError)>
    <div class="alert alert-danger">#encodeForHTML(actionError)#</div>
</cfif>

<div class="row g-4">

    <!--- Tokens Card --->
    <div class="col-lg-4 col-md-6">
        <a href="tokens/index.cfm" class="text-decoration-none">
            <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--primary">
                <div class="card-body">
                    <div class="d-flex align-items-center mb-3">
                        <i class="bi bi-key fs-2 me-3 settings-hub-icon"></i>
                        <div>
                            <h5 class="card-title text-dark mb-0">API Tokens</h5>
                            <p class="card-text text-muted small mb-0">Grant external applications access to the directory API</p>
                        </div>
                    </div>
                    <div class="d-flex gap-3">
                        <span class="badge settings-badge-primary-soft fs-6">#arrayLen(tokens)# total</span>
                        <span class="badge settings-badge-success-soft fs-6">#activeTokens# active</span>
                    </div>
                </div>
            </div>
        </a>
    </div>

    <!--- Secrets Card --->
    <div class="col-lg-4 col-md-6">
        <a href="secrets/index.cfm" class="text-decoration-none">
            <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--warning">
                <div class="card-body">
                    <div class="d-flex align-items-center mb-3">
                        <i class="bi bi-shield-lock fs-2 me-3 settings-hub-icon settings-hub-icon--warning"></i>
                        <div>
                            <h5 class="card-title text-dark mb-0">API Secrets</h5>
                            <p class="card-text text-muted small mb-0">Gate access to protected data (student records, etc.)</p>
                        </div>
                    </div>
                    <div class="d-flex gap-3">
                        <span class="badge settings-badge-warning-soft fs-6">#arrayLen(secrets)# total</span>
                        <span class="badge settings-badge-success-soft fs-6">#activeSecrets# active</span>
                    </div>
                </div>
            </div>
        </a>
    </div>

    <!--- Quickpull Settings Card --->
    <div class="col-lg-4 col-md-12">
        <a href="quickpulls/index.cfm" class="text-decoration-none">
            <div class="card h-100 shadow-sm settings-hub-card settings-hub-card--success">
                <div class="card-body">
                    <div class="d-flex align-items-center mb-3">
                        <i class="bi bi-diagram-3 fs-2 me-3 settings-hub-icon settings-hub-icon--success"></i>
                        <div>
                            <h5 class="card-title text-dark mb-0">Quickpulls</h5>
                            <p class="card-text text-muted small mb-0">Choose endpoint-specific return items, image variants, contact types, orgs, and flags</p>
                        </div>
                    </div>
                    <div class="d-flex gap-3">
                        <span class="badge settings-badge-success-soft fs-6">4 endpoints</span>
                        <span class="badge settings-badge-neutral fs-6">Item-level config</span>
                    </div>
                </div>
            </div>
        </a>
    </div>

</div>

<!--- Documentation link --->
<div class="card shadow-sm mt-4 settings-shell">
    <div class="card-body settings-doc-card">
        <i class="bi bi-book fs-4 text-secondary me-3"></i>
        <div>
            <h6 class="mb-0">API Documentation</h6>
            <p class="text-muted small mb-0">View endpoint reference, usage examples, and authentication details.</p>
        </div>
        <a href="/api/docs.html" target="_blank" class="btn btn-outline-secondary ms-auto">
            <i class="bi bi-box-arrow-up-right me-1"></i>Open Docs
        </a>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
