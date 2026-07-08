<!--- ── Access guard: SUPER_ADMIN only ── --->
<cfif NOT application.authService.hasRole("SUPER_ADMIN")>
    <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>

<cfset appKey    = trim(appConfigService.getValue("dropbox.app_key",    ""))>
<cfset appSecret = trim(appConfigService.getValue("dropbox.app_secret", ""))>

<cfset actionMessage      = "">
<cfset actionMessageClass = "alert-success">
<cfset newRefreshToken    = "">
<cfset exchangeError      = "">

<cfif cgi.REQUEST_METHOD EQ "POST">
    <cfset postAction = trim(form.postAction ?: "")>

    <cfif postAction EQ "exchangeCode">
        <cfset authCode = trim(form.authCode ?: "")>
        <cftry>
            <cfif NOT len(authCode)>
                <cfthrow message="Authorization code is required.">
            </cfif>
            <cfif NOT len(appKey) OR NOT len(appSecret)>
                <cfthrow message="dropbox.app_key and dropbox.app_secret must be set in AppConfig before exchanging a code.">
            </cfif>

            <cfset tokenResp = "">
            <cfhttp
                url="https://api.dropbox.com/oauth2/token"
                method="post"
                result="tokenResp"
                timeout="30"
                throwOnError="false"
            >
                <cfhttpparam type="formField" name="code"          value="#authCode#">
                <cfhttpparam type="formField" name="grant_type"    value="authorization_code">
                <cfhttpparam type="formField" name="client_id"     value="#appKey#">
                <cfhttpparam type="formField" name="client_secret" value="#appSecret#">
            </cfhttp>

            <cfif NOT isJSON(tokenResp.fileContent ?: "")>
                <cfthrow message="Unexpected response from Dropbox: #left(tokenResp.fileContent, 300)#">
            </cfif>

            <cfset parsed = deserializeJSON(tokenResp.fileContent)>

            <cfif structKeyExists(parsed, "error")>
                <cfset exchangeError = parsed.error & (len(parsed.error_description ?: "") ? ": " & parsed.error_description : "")>
            <cfelseif NOT structKeyExists(parsed, "refresh_token")>
                <cfthrow message="Dropbox did not return a refresh_token. Ensure token_access_type=offline was included in the authorization URL.">
            <cfelse>
                <cfset newRefreshToken = parsed.refresh_token>
            </cfif>
        <cfcatch type="any">
            <cfset exchangeError = cfcatch.message>
        </cfcatch>
        </cftry>

    <cfelseif postAction EQ "saveToken">
        <cfset tokenToSave = trim(form.refreshToken ?: "")>
        <cftry>
            <cfif NOT len(tokenToSave)>
                <cfthrow message="Refresh token cannot be empty.">
            </cfif>
            <cfset appConfigService.setValue("dropbox.refresh_token", tokenToSave)>
            <cfset actionMessage = "dropbox.refresh_token saved to AppConfig.">
        <cfcatch type="any">
            <cfset actionMessage = cfcatch.message>
            <cfset actionMessageClass = "alert-danger">
        </cfcatch>
        </cftry>
    </cfif>
</cfif>

<cfset keyHint    = len(appKey)    GTE 6 ? left(appKey, 3)    & "..." & right(appKey, 3)    : (len(appKey)    ? appKey    : "(not set)")>
<cfset secretHint = len(appSecret) GTE 6 ? left(appSecret, 3) & "..." & right(appSecret, 3) : (len(appSecret) ? appSecret : "(not set)")>
<cfset authUrl    = "https://www.dropbox.com/oauth2/authorize?client_id=" & urlEncodedFormat(appKey) & "&response_type=code&token_access_type=offline">
<cfset pageTitle  = "Dropbox Token">

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-dropbox-token-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/app-config/">Application Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Regenerate Dropbox Token</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-key me-2"></i>Regenerate Dropbox Refresh Token</h1>
        <p class="text-muted mb-0">Use this when Dropbox rejects API calls with a scope error after adding new permissions to the app.</p>
    </div>
</div>

<!--- Credentials summary --->
<div class="card shadow-sm mb-4 settings-shell">
    <div class="card-header fw-semibold"><i class="bi bi-shield-lock me-2"></i>App Credentials</div>
    <div class="card-body">
        <dl class="row mb-0 small">
            <dt class="col-sm-3 text-muted fw-normal">dropbox.app_key</dt>
            <dd class="col-sm-9"><code>#encodeForHTML(keyHint)#</code></dd>
            <dt class="col-sm-3 text-muted fw-normal mb-0">dropbox.app_secret</dt>
            <dd class="col-sm-9 mb-0"><code>#encodeForHTML(secretHint)#</code></dd>
        </dl>
    </div>
</div>

<!--- Step 1 --->
<div class="card shadow-sm mb-4 settings-shell">
    <div class="card-header fw-semibold">
        <span class="badge bg-secondary me-2">Step 1</span>Authorize in Dropbox
    </div>
    <div class="card-body">
        <p class="mb-3">Open the link below while logged into the Dropbox account that owns the app. Click <strong>Allow</strong> — Dropbox will display an authorization code on screen. Copy it.</p>
        <cfif len(appKey)>
            <a href="#authUrl#" target="_blank" class="btn btn-ui-go">
                <i class="bi bi-box-arrow-up-right me-1"></i>Authorize on Dropbox
            </a>
            <div class="mt-3 p-2 bg-light rounded border small font-monospace text-break">#encodeForHTML(authUrl)#</div>
        <cfelse>
            <div class="alert alert-warning mb-0 py-2"><i class="bi bi-exclamation-triangle me-1"></i>Set <code>dropbox.app_key</code> in App Config first.</div>
        </cfif>
    </div>
</div>

<!--- Step 2 --->
<div class="card shadow-sm mb-4 settings-shell">
    <div class="card-header fw-semibold">
        <span class="badge bg-secondary me-2">Step 2</span>Exchange Code for Refresh Token
    </div>
    <div class="card-body">
        <cfif len(exchangeError)>
            <div class="alert alert-danger py-2 mb-3">
                <i class="bi bi-exclamation-triangle me-1"></i>#encodeForHTML(exchangeError)#
            </div>
        </cfif>
        <p class="mb-3">Paste the code Dropbox gave you and click <strong>Exchange Code</strong>.</p>
        <form method="post" action="/admin/settings/app-config/dropbox-token.cfm">
            <input type="hidden" name="postAction" value="exchangeCode">
            <input type="hidden" name="_csrf" value="#encodeForHTMLAttribute(request.adminCsrfToken ?: '')#">
            <div class="row g-2 align-items-end">
                <div class="col-lg-8">
                    <label class="form-label fw-semibold" for="authCode">Authorization Code</label>
                    <input type="text" class="form-control font-monospace" id="authCode" name="authCode"
                           placeholder="Paste the code from Dropbox here" autocomplete="off" spellcheck="false">
                </div>
                <div class="col-auto">
                    <button type="submit" class="btn btn-ui-save">
                        <i class="bi bi-arrow-repeat me-1"></i>Exchange Code
                    </button>
                </div>
            </div>
        </form>

        <cfif len(newRefreshToken)>
        <div class="alert alert-success mt-4 mb-0">
            <div class="fw-semibold mb-2"><i class="bi bi-check-circle me-1"></i>New Refresh Token</div>
            <div class="input-group mb-3">
                <input type="text" class="form-control form-control-sm font-monospace" id="newTokenDisplay"
                       value="#encodeForHTMLAttribute(newRefreshToken)#" readonly>
                <button class="btn btn-ui-go btn-sm" type="button"
                        onclick="navigator.clipboard.writeText(this.previousElementSibling.value).then(() => { this.innerHTML = '<i class=\'bi bi-check me-1\'></i>Copied'; setTimeout(() => { this.innerHTML = '<i class=\'bi bi-clipboard me-1\'></i>Copy'; }, 2000); })">
                    <i class="bi bi-clipboard me-1"></i>Copy
                </button>
            </div>
            <form method="post" action="/admin/settings/app-config/dropbox-token.cfm">
                <input type="hidden" name="postAction"    value="saveToken">
                <input type="hidden" name="refreshToken"  value="#encodeForHTMLAttribute(newRefreshToken)#">
                <input type="hidden" name="_csrf"         value="#encodeForHTMLAttribute(request.adminCsrfToken ?: '')#">
                <button type="submit" class="btn btn-ui-save btn-sm">
                    <i class="bi bi-floppy me-1"></i>Save to AppConfig
                </button>
                <span class="text-muted small ms-2">Writes to <code>dropbox.refresh_token</code></span>
            </form>
        </div>
        </cfif>
    </div>
</div>

<!--- Info callout --->
<div class="card shadow-sm settings-shell bg-light">
    <div class="card-body py-2 small text-muted">
        <i class="bi bi-info-circle me-1"></i>
        <strong>Why a new token?</strong>
        Dropbox refresh tokens carry the scopes that were active when they were generated.
        Adding a scope to your app in the Dropbox Console does not update existing tokens —
        you must generate a new one after saving the scope change.
    </div>
</div>

</div>
</cfoutput>
</cfsavecontent>

<cfif len(actionMessage)>
<cfset toastTone = actionMessageClass CONTAINS "success" ? "success" : (actionMessageClass CONTAINS "warning" ? "warning" : "danger")>
</cfif>
<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif len(actionMessage)>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("#encodeForJavaScript(actionMessage)#", { tone: '#toastTone#' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
