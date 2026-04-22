<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data />

<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset allSystemsResult = externalIDService.getSystems()>
<cfset allSystems = allSystemsResult.data>

<!--- Build ordered quick-add flags list from configured UserFlags. --->
<cfset quickFlagDefs = [
    { key = "alumni", label = "Alumni" },
    { key = "current-student", label = "Current Student" },
    { key = "faculty-fulltime", label = "Faculty-Fulltime" },
    { key = "faculty-adjunct", label = "Faculty-Adjunct" },
    { key = "joint faculty appointment", label = "Joint Faculty Appointment" },
    { key = "resident", label = "Resident" },
    { key = "staff", label = "Staff" }
]>
<cfset quickFlags = []>

<cfloop array="#quickFlagDefs#" index="flagDef">
    <cfset matchedFlag = {}>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset row = allFlags[i]>
        <cfif lCase(trim(row.FLAGNAME ?: "")) EQ flagDef.key>
            <cfset matchedFlag = {
                FLAGID = row.FLAGID,
                FLAGNAME = flagDef.label
            }>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif NOT structIsEmpty(matchedFlag)>
        <cfset arrayAppend(quickFlags, matchedFlag)>
    </cfif>
</cfloop>

<!--- Locate ExternalSystems IDs for CougarNet + PeopleSoft fields. --->
<cfset cougarNetSystemID = 0>
<cfset peopleSoftSystemID = 0>
<cfloop from="1" to="#arrayLen(allSystems)#" index="i">
    <cfset sys = allSystems[i]>
    <cfset scanText = lCase(trim((sys.SYSTEMNAME ?: "") & " " & (sys.SYSTEMCODE ?: "")))>
    <cfif cougarNetSystemID EQ 0 AND findNoCase("cougarnet", scanText)>
        <cfset cougarNetSystemID = val(sys.SYSTEMID)>
    </cfif>
    <cfif peopleSoftSystemID EQ 0 AND findNoCase("peoplesoft", scanText)>
        <cfset peopleSoftSystemID = val(sys.SYSTEMID)>
    </cfif>
</cfloop>

<cfset cougarNetDisabledAttr = (cougarNetSystemID GT 0 ? "" : "disabled")>
<cfset peopleSoftDisabledAttr = (peopleSoftSystemID GT 0 ? "" : "disabled")>
<cfset cougarNetMissingHtml = (cougarNetSystemID GT 0 ? "" : "<div class='form-text text-warning'>CougarNet system not configured.</div>")>
<cfset peopleSoftMissingHtml = (peopleSoftSystemID GT 0 ? "" : "<div class='form-text text-warning'>PeopleSoft system not configured.</div>")>

<cfset content = "
<h1>Quick Add User</h1>

<form class='mt-4' method='POST' action='/admin/users/saveUser.cfm'>
    <input type='hidden' name='processExternalIDs' value='1'>
    <input type='hidden' name='returnTo' value='/admin/users/index.cfm'>

    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>First Name</label>
            <input class='form-control' name='FirstName' required>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Middle Name</label>
            <input class='form-control' name='MiddleName'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Last Name</label>
            <input class='form-control' name='LastName' required>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>@UH Email</label>
            <input class='form-control' id='emailPrimary' name='EmailPrimary' type='email' required>
            <div class='invalid-feedback' id='emailPrimaryErr'></div>
        </div>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Flags</label>
        <div class='border p-3 rounded admin-scroll-panel-xs'>
">

<cfif arrayLen(quickFlags) GT 0>
    <cfloop from="1" to="#arrayLen(quickFlags)#" index="i">
        <cfset qf = quickFlags[i]>
        <cfset content &= "
            <div class='form-check'>
                <input class='form-check-input' type='checkbox' name='Flags' value='#qf.FLAGID#' id='flag#qf.FLAGID#'>
                <label class='form-check-label' for='flag#qf.FLAGID#'>
                    #EncodeForHTML(qf.FLAGNAME)#
                </label>
            </div>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted mb-0'>No matching quick-add flags were found in UserFlags.</p>">
</cfif>

<cfset content &= "
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>COUGARNET ID</label>
            <input class='form-control' name='extID_#cougarNetSystemID#' #cougarNetDisabledAttr#>
            #cougarNetMissingHtml#
        </div>
        <div class='col-md-6'>
            <label class='form-label'>PEOPLESOFT ID</label>
            <input class='form-control' name='extID_#peopleSoftSystemID#' #peopleSoftDisabledAttr#>
            #peopleSoftMissingHtml#
        </div>
    </div>

    <script>
    (function () {
        var epEl  = document.getElementById('emailPrimary');
        var epErr = document.getElementById('emailPrimaryErr');
        function showError(el, errEl, msg) { el.classList.add('is-invalid'); errEl.textContent = msg; }
        function clearError(el, errEl) { el.classList.remove('is-invalid'); errEl.textContent = ''; }
        function validatePrimary() {
            var val = (epEl ? epEl.value : '').trim().toLowerCase();
            if (val && !val.endsWith('@uh.edu')) {
                showError(epEl, epErr, 'Must be a @uh.edu address (e.g. jsmith@uh.edu).');
                return false;
            }
            if (epEl) clearError(epEl, epErr);
            return true;
        }
        if (epEl) epEl.addEventListener('blur', validatePrimary);
        var form = epEl ? epEl.closest('form') : null;
        if (form) {
            form.addEventListener('submit', function (e) {
                if (!validatePrimary()) {
                    e.preventDefault();
                    var inv = document.querySelector('.is-invalid');
                    if (inv) inv.focus();
                }
            });
        }
    })();
    </script>

    <button class='btn btn-success'>Save User</button>
    <a href='/admin/users/index.cfm' class='btn btn-secondary'>Cancel</a>
</form>
" />

<cfinclude template="/admin/layout.cfm">
