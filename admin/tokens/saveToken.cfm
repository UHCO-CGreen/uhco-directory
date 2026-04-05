<cfif NOT (CGI.REQUEST_METHOD EQ "POST")
    OR NOT structKeyExists(form, "tokenName")
    OR NOT len(trim(form.tokenName))
    OR NOT structKeyExists(form, "appName")
    OR NOT len(trim(form.appName))>
    <cflocation url="/dir/admin/tokens/create.cfm" addtoken="false">
</cfif>

<cfset tokenService  = createObject("component", "dir.cfc.token_service").init()>
<cfset secretService = createObject("component", "dir.cfc.secret_service").init()>

<cfset allowedIPs = structKeyExists(form, "allowedIPs") ? trim(form.allowedIPs) : "">
<cfset expiresAt  = structKeyExists(form, "expiresAt")  ? trim(form.expiresAt)  : "">

<cfset result = tokenService.createToken(
    tokenName  = trim(form.tokenName),
    appName    = trim(form.appName),
    scopes     = trim(form.scopes),
    allowedIPs = allowedIPs,
    expiresAt  = expiresAt
)>

<!--- Optionally create a secret in the same request --->
<cfset secretResult  = "">
<cfset createSecret  = structKeyExists(form, "createSecret") AND form.createSecret EQ "1">
<cfif createSecret>
    <!--- protectedFlags arrives as a comma-list when multiple checkboxes are submitted --->
    <cfset rawFlags = structKeyExists(form, "protectedFlags") ? trim(form.protectedFlags) : "">
    <cfif NOT len(rawFlags)>
        <!--- Redirect back with error if no flags selected --->
        <cflocation url="/dir/admin/tokens/create.cfm?err=noflags" addtoken="false">
    </cfif>

    <!--- Inherit IPs/expiry from token when secret fields left blank --->
    <cfset secIPs     = len(trim(form.secretAllowedIPs ?: "")) ? trim(form.secretAllowedIPs) : allowedIPs>
    <cfset secExpires = len(trim(form.secretExpiresAt  ?: "")) ? trim(form.secretExpiresAt)  : expiresAt>

    <cfset secretResult = secretService.createSecret(
        secretName     = trim(form.tokenName),
        appName        = trim(form.appName),
        protectedFlags = rawFlags,
        allowedIPs     = secIPs,
        expiresAt      = secExpires
    )>
</cfif>

<cfset secretBlock = "">
<cfif isStruct(secretResult) AND structKeyExists(secretResult, "rawSecret")>
    <cfset secretBlock = "
<div class='alert alert-success mt-3' role='alert'>
    <h5 class='alert-heading'><i class='bi bi-shield-lock-fill me-2'></i>Secret generated</h5>
    <p class='mb-2'>Copy the secret below. <strong>It will not be shown again.</strong></p>
    <div class='input-group mt-3'>
        <input type='text' class='form-control font-monospace' id='rawSecret' value='#EncodeForHTMLAttribute(secretResult.rawSecret)#' readonly>
        <button class='btn btn-outline-secondary' type='button' onclick=""navigator.clipboard.writeText(document.getElementById('rawSecret').value).then(function(){this.textContent='Copied!';}.bind(this))"">
            <i class='bi bi-clipboard'></i> Copy
        </button>
    </div>
    <p class='mt-3 mb-1 small text-muted fw-semibold'>Usage</p>
    <pre class='bg-dark text-light p-2 rounded small'><code>X-API-Secret: #EncodeForHTML(secretResult.rawSecret)#</code></pre>
</div>">
</cfif>

<cfset content = "
<h1>Token Created</h1>

<div class='alert alert-success mt-4' role='alert'>
    <h5 class='alert-heading'><i class='bi bi-check-circle-fill me-2'></i>Token generated successfully</h5>
    <p class='mb-2'>Copy the token below. <strong>It will not be shown again.</strong></p>
    <div class='input-group mt-3'>
        <input type='text' class='form-control font-monospace' id='rawToken' value='#EncodeForHTMLAttribute(result.rawToken)#' readonly>
        <button class='btn btn-outline-secondary' type='button' onclick=""navigator.clipboard.writeText(document.getElementById('rawToken').value).then(function(){this.textContent='Copied!';}.bind(this))"">
            <i class='bi bi-clipboard'></i> Copy
        </button>
    </div>
    <p class='mt-3 mb-1 small text-muted fw-semibold'>Usage</p>
    <pre class='bg-dark text-light p-2 rounded small'><code>Authorization: Bearer #EncodeForHTML(result.rawToken)#</code></pre>
</div>

#secretBlock#

<div class='mt-4'>
    <a href='/dir/admin/tokens/index.cfm' class='btn btn-primary'>Back to Tokens</a>
</div>
">

<cfinclude template="/dir/admin/layout.cfm">

