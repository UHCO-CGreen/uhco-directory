<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("ldap")>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>

<cfset hasAppConfigEncryptionKey = false>
<cfif structKeyExists(server, "system") AND structKeyExists(server.system, "environment") AND structKeyExists(server.system.environment, "UHCO_IDENT_APPCONFIG_ENC_KEY")>
    <cfset hasAppConfigEncryptionKey = len(trim(server.system.environment["UHCO_IDENT_APPCONFIG_ENC_KEY"])) GT 0>
</cfif>

<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cftry>
        <cfset postAction = trim(form.formAction ?: "saveLdapSettings")>

        <cfif postAction EQ "saveLdapSettings">
            <cfset appConfigService.setValue("ldap.cougarnet.server", trim(form.ldapServer ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.start_dn", trim(form.ldapStartDn ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.timeout_seconds", trim(form.ldapTimeoutSeconds ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.bind_username", trim(form.ldapBindUsername ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.faculty", trim(form.ldapFacultyGroups ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.staff", trim(form.ldapStaffGroups ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.current_student", trim(form.ldapCurrentStudentGroups ?: ""))>

            <cfif len(trim(form.ldapBindPassword ?: ""))>
                <cfset appConfigService.setValue("ldap.cougarnet.bind_password", trim(form.ldapBindPassword))>
            </cfif>

            <cfset actionMessage = "LDAP settings saved.">
        <cfelse>
            <cfthrow message="Unknown settings action.">
        </cfif>
    <cfcatch type="any">
        <cfset actionMessage = cfcatch.message>
        <cfset actionMessageClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<cfset ldapServer = appConfigService.getValue("ldap.cougarnet.server", "cougarnet.uh.edu")>
<cfset ldapStartDn = appConfigService.getValue("ldap.cougarnet.start_dn", "DC=cougarnet,DC=uh,DC=edu")>
<cfset ldapTimeoutSeconds = appConfigService.getValue("ldap.cougarnet.timeout_seconds", "10")>
<cfset ldapBindUsername = appConfigService.getValue("ldap.cougarnet.bind_username", "")>
<cfset ldapFacultyGroups = appConfigService.getValue("ldap.cougarnet.groups.faculty", "")>
<cfset ldapStaffGroups = appConfigService.getValue("ldap.cougarnet.groups.staff", "")>
<cfset ldapCurrentStudentGroups = appConfigService.getValue("ldap.cougarnet.groups.current_student", "")>
<cfset ldapBindPasswordIsSet = len(appConfigService.getValue("ldap.cougarnet.bind_password", "")) GT 0>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-ldap-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">LDAP Settings</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-diagram-3 me-2"></i>LDAP Settings</h1>
        <p class="text-muted mb-0">CougarNet LDAP connectivity and group filters for directory lookups.</p>
    </div>
    <div class="d-flex align-items-center gap-2">
        <span class="badge #(hasAppConfigEncryptionKey ? "text-bg-success" : "text-bg-warning text-dark")#">
            #(hasAppConfigEncryptionKey ? "Secret encryption enabled" : "Plaintext compatibility mode")#
        </span>
        <cfif len(sectionStatus)>
            <span class="badge bg-warning text-dark">#sectionStatus#</span>
        </cfif>
    </div>
</div>

<cfif NOT hasAppConfigEncryptionKey>
    <div class="alert alert-warning small" role="alert">
        <strong>Compatibility mode is active.</strong> Sensitive values are currently saved in plaintext to match existing production behavior.
        Set <span class="font-monospace">UHCO_IDENT_APPCONFIG_ENC_KEY</span> in the environment to enable encrypted-at-rest storage.
    </div>
</cfif>

<div class="card shadow-sm settings-shell">
    <div class="card-body">
        <p class="text-muted small mb-4">
            Sensitive values (bind password) are stored encrypted at rest when
            <span class="font-monospace">UHCO_IDENT_APPCONFIG_ENC_KEY</span> is configured in the environment.
            Leave the password field blank to keep the current stored value.
        </p>

        <form method="post" class="row g-3">
            <input type="hidden" name="formAction" value="saveLdapSettings">

            <div class="col-lg-4">
                <label for="ldapServer" class="form-label fw-bold">LDAP Server</label>
                <input type="text" class="form-control font-monospace" id="ldapServer" name="ldapServer" value="#encodeForHTMLAttribute(ldapServer)#">
            </div>
            <div class="col-lg-5">
                <label for="ldapStartDn" class="form-label fw-bold">Start DN</label>
                <input type="text" class="form-control font-monospace" id="ldapStartDn" name="ldapStartDn" value="#encodeForHTMLAttribute(ldapStartDn)#">
            </div>
            <div class="col-lg-3">
                <label for="ldapTimeoutSeconds" class="form-label fw-bold">Timeout Seconds</label>
                <input type="number" min="1" class="form-control font-monospace" id="ldapTimeoutSeconds" name="ldapTimeoutSeconds" value="#encodeForHTMLAttribute(ldapTimeoutSeconds)#">
            </div>

            <div class="col-lg-6">
                <label for="ldapBindUsername" class="form-label fw-bold">Bind Username</label>
                <input type="text" class="form-control font-monospace" id="ldapBindUsername" name="ldapBindUsername" value="#encodeForHTMLAttribute(ldapBindUsername)#" placeholder="COUGARNET\svc-opt-cfserv">
            </div>
            <div class="col-lg-6">
                <label for="ldapBindPassword" class="form-label fw-bold">Bind Password</label>
                <input type="password" class="form-control font-monospace" id="ldapBindPassword" name="ldapBindPassword" value="" placeholder="#ldapBindPasswordIsSet ? "Stored value retained unless replaced" : "Enter LDAP bind password"#" autocomplete="new-password">
                <div class="form-text">
                    Current status: <strong>#ldapBindPasswordIsSet ? "stored" : "not set"#</strong>.
                    Leave blank to keep the current stored value.
                </div>
            </div>

            <div class="col-12">
                <label for="ldapFacultyGroups" class="form-label fw-bold">Faculty Groups</label>
                <textarea class="form-control font-monospace" id="ldapFacultyGroups" name="ldapFacultyGroups" rows="2">#encodeForHTML(ldapFacultyGroups)#</textarea>
                <div class="form-text">Pipe-delimited distinguished names.</div>
            </div>

            <div class="col-12">
                <label for="ldapStaffGroups" class="form-label fw-bold">Staff Groups</label>
                <textarea class="form-control font-monospace" id="ldapStaffGroups" name="ldapStaffGroups" rows="2">#encodeForHTML(ldapStaffGroups)#</textarea>
                <div class="form-text">Pipe-delimited distinguished names.</div>
            </div>

            <div class="col-12">
                <label for="ldapCurrentStudentGroups" class="form-label fw-bold">Current Student Groups</label>
                <textarea class="form-control font-monospace" id="ldapCurrentStudentGroups" name="ldapCurrentStudentGroups" rows="3">#encodeForHTML(ldapCurrentStudentGroups)#</textarea>
                <div class="form-text">Pipe-delimited distinguished names.</div>
            </div>

            <div class="col-12">
                <button type="submit" class="btn btn-ui-save">
                    <i class="bi bi-save me-1"></i>Save LDAP Settings
                </button>
            </div>
        </form>
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
