<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif CGI.REQUEST_METHOD NEQ "POST"
    OR NOT structKeyExists(form, "secretName") OR NOT len(trim(form.secretName))
    OR NOT structKeyExists(form, "appName")    OR NOT len(trim(form.appName))
    OR NOT structKeyExists(form, "protectedFlags") OR NOT len(trim(form.protectedFlags))>
    <cflocation url="#request.webRoot#/admin/settings/uhco-api/secrets/create.cfm" addtoken="false">
</cfif>

<cfset secretService = createObject("component", "cfc.secret_service").init()>

<!--- protectedFlags may be a list (multiple checkboxes) or single value --->
<cfset flagsVal   = isArray(form.protectedFlags) ? arrayToList(form.protectedFlags, ",") : trim(form.protectedFlags)>
<cfset allowedIPs = structKeyExists(form, "allowedIPs") ? trim(form.allowedIPs) : "">
<cfset expiresAt  = structKeyExists(form, "expiresAt")  ? trim(form.expiresAt)  : "">

<cfset result = secretService.createSecret(
    secretName     = trim(form.secretName),
    appName        = trim(form.appName),
    protectedFlags = flagsVal,
    allowedIPs     = allowedIPs,
    expiresAt      = expiresAt
)>

<cfset content = "
<h1>Secret Created</h1>

<div class='alert alert-success mt-4' role='alert'>
    <h5 class='alert-heading'><i class='bi bi-check-circle-fill me-2'></i>Secret generated successfully</h5>
    <p class='mb-2'>Copy the secret below. <strong>It will not be shown again.</strong></p>
    <div class='input-group mt-3'>
        <input type='text' class='form-control font-monospace' id='rawSecret' value='#EncodeForHTMLAttribute(result.rawSecret)#' readonly>
        <button class='btn btn-outline-secondary' type='button' onclick=""navigator.clipboard.writeText(document.getElementById('rawSecret').value).then(function(){this.textContent='Copied!';}.bind(this))"">
            <i class='bi bi-clipboard'></i> Copy
        </button>
    </div>
</div>

<div class='mt-3'>
    <h6 class='fw-semibold'>Usage</h6>
    <p class='text-muted mb-1'>Pass the secret alongside your token in every request that needs protected data:</p>
    <pre class='bg-dark text-light p-3 rounded'><code>GET /api/v1/people?secret=#EncodeForHTML(result.rawSecret)#&amp;token=uhcs_...</code></pre>
    <p class='text-muted mt-2 small'>Or use the <code>X-API-Secret</code> header:</p>
    <pre class='bg-dark text-light p-3 rounded'><code>X-API-Secret: #EncodeForHTML(result.rawSecret)#</code></pre>
</div>

<div class='mt-4'>
    <a href='/admin/settings/uhco-api/secrets/index.cfm' class='btn btn-primary'>Back to Secrets</a>
</div>
">

<cfinclude template="/admin/layout.cfm">
