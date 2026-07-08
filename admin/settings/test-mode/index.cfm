<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("test-mode")>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>

<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cftry>
        <cfset postAction = trim(form.formAction ?: "")>

        <cfif postAction EQ "toggleTestMode">
            <cfset usersService.setTestModeEnabled( (form.enableTestMode ?: "0") EQ "1" )>
            <cfset actionMessage = ((form.enableTestMode ?: "0") EQ "1") ? "Test Mode enabled." : "Test Mode disabled.">
        <cfelseif postAction EQ "generateTestUsers">
            <cfset generationResult = usersService.generateTestUsers()>
            <cfif NOT generationResult.success>
                <cfthrow message="#generationResult.message#">
            </cfif>
            <cfset actionMessage = generationResult.message>
        <cfelseif postAction EQ "deleteTestUsers">
            <cfset deleteResult = usersService.deleteAllTestUsers()>
            <cfif NOT deleteResult.success>
                <cfthrow message="#deleteResult.message#">
            </cfif>
            <cfset actionMessage = deleteResult.message>
        <cfelseif postAction EQ "resetTestUsers">
            <cfset resetResult = usersService.resetTestUsers()>
            <cfif NOT resetResult.success>
                <cfthrow message="#resetResult.message#">
            </cfif>
            <cfset actionMessage = resetResult.message>
        <cfelse>
            <cfthrow message="Unknown settings action.">
        </cfif>
    <cfcatch type="any">
        <cfset actionMessage = cfcatch.message>
        <cfset actionMessageClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<cfset testModeEnabled = usersService.isTestModeEnabled()>
<cfset testModeGenerationCount = usersService.getTestUserLimit()>
<cfset existingTestUserCount = usersService.getTestUserCount()>
<cfset dashboardStaleMonths = val(appConfigService.getValue("dashboard.stale_months", "6"))>
<cfif dashboardStaleMonths LT 1 OR dashboardStaleMonths GT 60><cfset dashboardStaleMonths = 6></cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-test-mode-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Test Mode</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-bezier2 me-2"></i>Test Mode</h1>
        <p class="text-muted mb-0">Synthetic user batch management and test mode toggle.</p>
    </div>
    <div class="d-flex align-items-center gap-2">
        <span class="badge #(testModeEnabled ? "text-bg-success" : "text-bg-secondary")#">
            #(testModeEnabled ? "Enabled" : "Disabled")#
        </span>
        <cfif len(sectionStatus)>
            <span class="badge bg-warning text-dark">#sectionStatus#</span>
        </cfif>
    </div>
</div>

<p class="text-muted small mb-4">
    Test Mode controls synthetic users marked with the dedicated <span class="font-monospace">TEST_USER</span> flag.
    This workflow is limited to <strong>#testModeGenerationCount#</strong> synthetic users at a time so they can be edited and exercised like real records, then reset or replaced as needed.
</p>

<div class="row g-3 align-items-stretch">
    <div class="col-lg-6">
        <div class="card shadow-sm settings-shell h-100">
            <div class="card-body">
                <h2 class="h5 mb-2"><i class="bi bi-toggle-on me-2"></i>Mode State</h2>
                <p class="small text-muted mb-3">Toggle the global Test Mode flag stored in <span class="font-monospace">test_mode.enabled</span>.</p>
                <form method="post" class="d-flex flex-column gap-3">
                    <input type="hidden" name="formAction" value="toggleTestMode">
                    <input type="hidden" name="enableTestMode" value="#testModeEnabled ? "0" : "1"#">
                    <div>
                        <div class="fw-bold">Current status</div>
                        <div class="small text-muted">#testModeEnabled ? "Enabled for Phase 1 test-user workflows." : "Disabled. Synthetic users remain excluded from API and quickpull output."#</div>
                    </div>
                    <div>
                        <button type="submit" class="btn btn-ui-warning">
                            <i class="bi #(testModeEnabled ? "bi-toggle-off" : "bi-toggle-on")# me-1"></i>#testModeEnabled ? "Disable Test Mode" : "Enable Test Mode"#
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="col-lg-6">
        <div class="card shadow-sm settings-shell h-100">
            <div class="card-body">
                <h2 class="h5 mb-2"><i class="bi bi-people me-2"></i>Synthetic User Batch</h2>
                <p class="small text-muted mb-3">The system supports one batch of <strong>#testModeGenerationCount#</strong> TEST_USER records at a time. Create the batch when none exist, reset the current batch back to its initial stale state, or delete the batch to regenerate from scratch.</p>
                <dl class="row small mb-3">
                    <dt class="col-sm-6">Existing TEST_USER records</dt>
                    <dd class="col-sm-6 font-monospace">#existingTestUserCount#</dd>
                    <dt class="col-sm-6">Batch size</dt>
                    <dd class="col-sm-6 font-monospace">#testModeGenerationCount#</dd>
                    <dt class="col-sm-6">Stale after</dt>
                    <dd class="col-sm-6 font-monospace">#dashboardStaleMonths# month(s)</dd>
                </dl>
                <cfif existingTestUserCount GT testModeGenerationCount>
                    <div class="alert alert-warning small py-2" role="alert">
                        More than #testModeGenerationCount# TEST_USER records currently exist. Delete the current TEST_USER records to clean up orphaned test users before generating a fresh batch.
                    </div>
                <cfelseif existingTestUserCount GT 0 AND existingTestUserCount LT testModeGenerationCount>
                    <div class="alert alert-warning small py-2" role="alert">
                        The current TEST_USER batch is incomplete (#existingTestUserCount# of #testModeGenerationCount#). Delete the current TEST_USER records and generate a fresh batch.
                    </div>
                <cfelseif existingTestUserCount EQ testModeGenerationCount>
                    <div class="alert alert-info small py-2" role="alert">
                        Reset restores the current batch to its initial stale state without changing the TEST_USER count.
                    </div>
                </cfif>
                <div class="d-flex flex-wrap gap-2">
                    <cfif existingTestUserCount EQ 0>
                        <form method="post" class="js-generate-test-users-form">
                            <input type="hidden" name="formAction" value="generateTestUsers">
                            <button type="submit" class="btn btn-ui-add js-generate-test-users-btn" data-default-label="#encodeForHTMLAttribute("Create #testModeGenerationCount# Synthetic Users")#">
                                <i class="bi bi-person-plus me-1"></i>Create #testModeGenerationCount# Synthetic Users
                            </button>
                        </form>
                    </cfif>

                    <cfif existingTestUserCount GT 0>
                        <form method="post" data-confirm="Delete all TEST_USER records? This cannot be undone.">
                            <input type="hidden" name="formAction" value="deleteTestUsers">
                            <button type="submit" class="btn btn-ui-delete">
                                <i class="bi bi-trash me-1"></i>Delete Current TEST_USER Records
                            </button>
                        </form>
                    </cfif>

                    <cfif existingTestUserCount EQ testModeGenerationCount>
                        <form method="post" data-confirm="Reset the current TEST_USER batch back to its initial stale state?">
                            <input type="hidden" name="formAction" value="resetTestUsers">
                            <button type="submit" class="btn btn-ui-clear">
                                <i class="bi bi-arrow-counterclockwise me-1"></i>Reset Current TEST_USER Batch
                            </button>
                        </form>
                    </cfif>
                </div>
            </div>
        </div>
    </div>
</div>

</div>

<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
(function () {
    document.addEventListener('DOMContentLoaded', function () {
        var generateForms = document.querySelectorAll('.js-generate-test-users-form');
        generateForms.forEach(function (form) {
            form.addEventListener('submit', function () {
                var button = form.querySelector('.js-generate-test-users-btn');
                if (!button) { return; }
                button.disabled = true;
                button.innerHTML = '<i class="bi bi-hourglass-split me-1"></i>Creating Users...';
            });
        });
    });
}());
</script>

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
