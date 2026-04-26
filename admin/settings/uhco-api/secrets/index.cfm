<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset secretService = createObject("component", "cfc.secret_service").init()>
<cfset secrets = secretService.getAllSecrets()>

<cfset content = "
<div class='settings-page settings-api-secrets-page'>
<nav aria-label='breadcrumb'>
    <ol class='breadcrumb'>
        <li class='breadcrumb-item'><a href='/admin/settings/'>Settings</a></li>
        <li class='breadcrumb-item'><a href='/admin/settings/uhco-api/'>UHCO API</a></li>
        <li class='breadcrumb-item active'>Secrets</li>
    </ol>
</nav>

<div class='d-flex justify-content-between align-items-center mb-4'>
    <h1 class='h3 mb-0'>API Secrets</h1>
    <a href='/admin/settings/uhco-api/secrets/create.cfm' class='btn btn-ui-add'>
        <i class='bi bi-plus-lg me-1'></i> New Secret
    </a>
</div>

<div class='alert alert-info d-flex gap-2'>
    <i class='bi bi-info-circle-fill mt-1'></i>
    <div>Secrets gate access to protected data (e.g. student records). A valid API <strong>Token</strong> AND <strong>Secret</strong> are required to retrieve protected records. Without a secret, those records are silently excluded from results.</div>
</div>
">

<cfif arrayLen(secrets) EQ 0>
    <cfset content &= "<p class='text-muted'>No secrets yet. <a href='/admin/settings/uhco-api/secrets/create.cfm'>Create one</a>.</p>">
<cfelse>
    <cfset content &= "
    <div class='settings-shell'>
    <div class='table-responsive'>
    <table class='table table-bordered table-hover align-middle settings-table mb-0'>
        <thead>
            <tr>
                <th>Name</th>
                <th>App</th>
                <th>Protects Flags</th>
                <th>Allowed IPs</th>
                <th>Expires</th>
                <th>Status</th>
                <th>Last Used</th>
                <th></th>
            </tr>
        </thead>
        <tbody>
    ">

    <cfloop array="#secrets#" item="s">
        <cfset statusBadge    = s.ISACTIVE ? "<span class='badge settings-badge-active'>Active</span>" : "<span class='badge bg-secondary'>Revoked</span>">
        <cfset expiresDisplay = (len(trim(s.EXPIRESAT & "")) AND s.EXPIRESAT NEQ "") ? dateFormat(s.EXPIRESAT, "mmm d, yyyy") : "<span class='text-muted'>Never</span>">
        <cfset lastUsedDisplay = (len(trim(s.LASTUSEDAT & "")) AND s.LASTUSEDAT NEQ "") ? dateFormat(s.LASTUSEDAT, "mmm d, yyyy") : "<span class='text-muted'>Never</span>">
        <cfset ipDisplay = len(trim(s.ALLOWEDIPS & "")) ? EncodeForHTML(s.ALLOWEDIPS) : "<span class='text-muted'>Any</span>">

        <cfset content &= "
        <tr>
            <td class='fw-semibold'>#EncodeForHTML(s.SECRETNAME)#</td>
            <td>#EncodeForHTML(s.APPNAME)#</td>
            <td><code>#EncodeForHTML(s.PROTECTEDFLAGS)#</code></td>
            <td>#ipDisplay#</td>
            <td>#expiresDisplay#</td>
            <td>#statusBadge#</td>
            <td>#lastUsedDisplay#</td>
            <td class='text-end'>
                <div class='settings-action-group'>
                <cfif s.ISACTIVE>
                <form method='post' action='/admin/settings/uhco-api/secrets/revokeSecret.cfm' class='d-inline' onsubmit=""return confirm('Revoke this secret?')"">
                    <input type='hidden' name='secretID' value='#s.SECRETID#'>
                    <button class='btn btn-sm btn-outline-warning' title='Revoke Secret' data-bs-toggle='tooltip' data-bs-title='Revoke Secret' aria-label='Revoke Secret'><i class='bi bi-pause-circle'></i></button>
                </form>
                </cfif>
                <form method='post' action='/admin/settings/uhco-api/secrets/deleteSecret.cfm' class='d-inline ms-1' onsubmit=""return confirm('Permanently delete this secret?')"">
                    <input type='hidden' name='secretID' value='#s.SECRETID#'>
                    <button class='btn btn-sm btn-remove users-list-action-button users-list-action-button-delete' title='Delete Secret' data-bs-toggle='tooltip' data-bs-title='Delete Secret' aria-label='Delete Secret'><i class='bi bi-trash'></i></button>
                </form>
                </div>
            </td>
        </tr>
        ">
    </cfloop>

    <cfset content &= "</tbody></table></div></div>">
</cfif>

<cfset content &= "</div>">

<cfinclude template="/admin/layout.cfm">
