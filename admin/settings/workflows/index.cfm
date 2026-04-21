<!---
    Workflows Hub — placeholder.
    Permission: settings.workflows.manage.
--->

<cfif NOT request.hasPermission("settings.workflows.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-workflows-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Workflows</li>
    </ol>
</nav>
<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
<h1 class="mb-1"><i class="bi bi-diagram-3-fill me-2"></i>Workflows</h1>
<p class="text-muted">Manage automated workflows and processing pipelines.</p>
</div>
<span class='badge settings-status-badge settings-status-badge--soon float-end'>Coming Soon</span>
</div>
<div class="card shadow-sm settings-shell settings-reference-card mt-3">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-info-circle me-2"></i>Coming Soon</h5>
    </div>
    <div class="card-body">
        Workflow configuration is coming soon. This section will allow you to create, schedule, and monitor automated data processing workflows.
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
