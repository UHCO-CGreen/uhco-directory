<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset content = "
<h1>New API Token</h1>

<form method='post' action='/admin/settings/uhco-api/tokens/saveToken.cfm' class='mt-4 admin-form-max-680'>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Token Name <span class='text-danger'>*</span></label>
        <input class='form-control' name='tokenName' required placeholder='e.g. Modern Campus Feed'>
        <div class='form-text'>A short descriptive label for this token.</div>
    </div>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Application Name <span class='text-danger'>*</span></label>
        <input class='form-control' name='appName' required placeholder='e.g. ModernCampus'>
        <div class='form-text'>The consuming system or team that owns this token.</div>
    </div>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Scopes <span class='text-danger'>*</span></label>
        <select class='form-select' name='scopes' required>
            <option value='read'>read — GET endpoints only</option>
            <option value='read write'>read write — GET + PATCH/POST/DELETE</option>
        </select>
    </div>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Allowed IPs</label>
        <input class='form-control' name='allowedIPs' placeholder='e.g. 129.7.0.0/16, 10.0.0.5'>
        <div class='form-text'>Comma-separated IPs or CIDR ranges. Leave blank to allow any IP (not recommended for write tokens).</div>
    </div>

    <div class='mb-4'>
        <label class='form-label fw-semibold'>Expires</label>
        <input class='form-control' name='expiresAt' id='tokenExpiresAt' type='date'>
        <div class='form-text'>Leave blank for a non-expiring token.</div>
    </div>

    <div class='mb-4 border rounded p-3 bg-light'>
        <div class='form-check form-switch'>
            <input class='form-check-input' type='checkbox' id='createSecretCheck' name='createSecret' value='1' onchange='toggleSecretPanel(this)'>
            <label class='form-check-label fw-semibold' for='createSecretCheck'>Also create a secret for this token</label>
        </div>
        <div class='form-text mt-1'>Generates a matching API Secret so this token can also access protected data (Current-Student, Alumni, Academic Programs orgs).</div>

        <div id='secretPanel' class='mt-3 admin-hidden'>
            <hr class='mt-2'>
            <h6 class='fw-semibold mb-3 mt-3'><i class='bi bi-shield-lock me-2'></i>Secret Settings</h6>

            <div class='mb-3'>
                <label class='form-label fw-semibold'>Protected Flags <span class='text-danger'>*</span></label>
                <div class='form-text mb-2'>Records with these flags will be hidden from token-only requests.</div>
                <div class='border rounded p-3 bg-white'>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Current-Student' id='fl_cs' checked><label class='form-check-label' for='fl_cs'>Current-Student</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Alumni' id='fl_al'><label class='form-check-label' for='fl_al'>Alumni</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Faculty-Fulltime' id='fl_ff'><label class='form-check-label' for='fl_ff'>Faculty-Fulltime</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Faculty-Adjunct' id='fl_fa'><label class='form-check-label' for='fl_fa'>Faculty-Adjunct</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Staff' id='fl_st'><label class='form-check-label' for='fl_st'>Staff</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Clinical-Attending' id='fl_ca'><label class='form-check-label' for='fl_ca'>Clinical-Attending</label></div>
                    <div class='form-check'><input class='form-check-input' type='checkbox' name='protectedFlags' value='Professor-Emeritus' id='fl_pe'><label class='form-check-label' for='fl_pe'>Professor-Emeritus</label></div>
                </div>
            </div>

            <div class='mb-3'>
                <label class='form-label fw-semibold'>Secret Allowed IPs</label>
                <input class='form-control' name='secretAllowedIPs' id='secretAllowedIPs' placeholder='Leave blank to inherit from token IPs above'>
                <div class='form-text'>Leave blank to use the same IP restrictions as the token.</div>
            </div>

            <div class='mb-3'>
                <label class='form-label fw-semibold'>Secret Expires</label>
                <input class='form-control' name='secretExpiresAt' id='secretExpiresAt' type='date'>
                <div class='form-text'>Leave blank to use the same expiry as the token.</div>
            </div>
        </div>
    </div>

    <div class='alert alert-warning'>
        <i class='bi bi-exclamation-triangle-fill me-2'></i>
        The raw token (and secret, if requested) will be displayed <strong>once</strong> immediately after creation. Copy them before leaving the page.
    </div>

    <button class='btn btn-primary'>Generate Token</button>
    <a href='/admin/settings/uhco-api/tokens/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</form>

<script>
function toggleSecretPanel(cb) {
    document.getElementById('secretPanel').style.display = cb.checked ? 'block' : 'none';
}
</script>
">

<cfinclude template="/admin/layout.cfm">
