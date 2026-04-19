<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset content = "
<h1>New API Secret</h1>

<form method='post' action='/admin/settings/uhco-api/secrets/saveSecret.cfm' class='mt-4' style='max-width:680px;'>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Secret Name <span class='text-danger'>*</span></label>
        <input class='form-control' name='secretName' required placeholder='e.g. SIS Student Feed'>
        <div class='form-text'>A short descriptive label for this secret.</div>
    </div>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Application Name <span class='text-danger'>*</span></label>
        <input class='form-control' name='appName' required placeholder='e.g. PowerCampus Integration'>
        <div class='form-text'>The consuming system or team that owns this secret.</div>
    </div>

    <div class='mb-3'>
        <label class='form-label fw-semibold'>Protected Flags <span class='text-danger'>*</span></label>
        <div class='form-text mb-2'>Select the flags whose data requires this secret. Records with any of these flags will be hidden from token-only requests.</div>
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
        <label class='form-label fw-semibold'>Allowed IPs</label>
        <input class='form-control' name='allowedIPs' placeholder='e.g. 129.7.0.0/16, 10.0.0.5'>
        <div class='form-text'>Comma-separated IPs or CIDR ranges. Leave blank to allow any IP.</div>
    </div>

    <div class='mb-4'>
        <label class='form-label fw-semibold'>Expires</label>
        <input class='form-control' name='expiresAt' type='date'>
        <div class='form-text'>Leave blank for a non-expiring secret.</div>
    </div>

    <div class='alert alert-warning'>
        <i class='bi bi-exclamation-triangle-fill me-2'></i>
        The raw secret will be displayed <strong>once</strong> immediately after creation. Copy it before leaving the page.
    </div>

    <button class='btn btn-primary'>Generate Secret</button>
    <a href='/admin/settings/uhco-api/secrets/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</form>
">

<cfinclude template="/admin/layout.cfm">
