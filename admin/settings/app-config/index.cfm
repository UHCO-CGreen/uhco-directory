<cfif NOT request.hasPermission("settings.app_config.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset mediaConfigService = createObject("component", "cfc.mediaConfig_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>

<cfset hasAppConfigEncryptionKey = false>
<cfif structKeyExists(server, "system") AND structKeyExists(server.system, "environment") AND structKeyExists(server.system.environment, "UHCO_IDENT_APPCONFIG_ENC_KEY")>
    <cfset hasAppConfigEncryptionKey = len(trim(server.system.environment["UHCO_IDENT_APPCONFIG_ENC_KEY"])) GT 0>
</cfif>

<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cftry>
        <cfset postAction = trim(form.formAction ?: "savePublishedSettings")>

        <cfif postAction EQ "savePublishedSettings">
            <cfset mediaConfigService.setPublishedSiteBaseUrl( trim(form.publishedSiteBaseUrl ?: "") )>
            <cfset actionMessage = "Application settings saved.">
        <cfelseif postAction EQ "saveDashboardSettings">
            <cfset dashboardListPageSize = val(form.dashboardListPageSize ?: 10)>
            <cfset dashboardStaleMonths = val(form.dashboardStaleMonths ?: 6)>

            <cfif dashboardListPageSize LT 1 OR dashboardListPageSize GT 50>
                <cfthrow message="Dashboard list page size must be between 1 and 50.">
            </cfif>
            <cfif dashboardStaleMonths LT 1 OR dashboardStaleMonths GT 60>
                <cfthrow message="Dashboard stale-month threshold must be between 1 and 60.">
            </cfif>

            <cfset appConfigService.setValue("dashboard.list_page_size", toString(dashboardListPageSize))>
            <cfset appConfigService.setValue("dashboard.stale_months", toString(dashboardStaleMonths))>
            <cfset actionMessage = "Dashboard list settings saved.">
        <cfelseif postAction EQ "toggleTestMode">
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
        <cfelseif postAction EQ "saveLdapSettings">
            <cfset appConfigService.setValue("ldap.cougarnet.server", trim(form.ldapServer ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.start_dn", trim(form.ldapStartDn ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.timeout_seconds", trim(form.ldapTimeoutSeconds ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.bind_username", trim(form.ldapBindUsername ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.faculty", trim(form.ldapFacultyGroups ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.staff", trim(form.ldapStaffGroups ?: ""))>
            <cfset appConfigService.setValue("ldap.cougarnet.groups.current_student", trim(form.ldapCurrentStudentGroups ?: ""))>

            <cfif len(trim(form.ldapBindPassword ?: ""))>
                <cfset appConfigService.setValue("ldap.cougarnet.bind_password", trim(form.ldapBindPassword ?: ""))>
            </cfif>

            <cfset actionMessage = "LDAP settings saved.">
        <cfelseif postAction EQ "updateConfigValue">
            <cfset configKey = trim(form.configKey ?: "")>
            <cfset configValue = trim(form.configValue ?: "")>

            <cfif !len(configKey)>
                <cfthrow message="Config key is required.">
            </cfif>

            <cfif appConfigService.isSensitiveKey(configKey)>
                <cfthrow message="Sensitive AppConfig values must be updated in a dedicated settings form.">
            </cfif>

            <cfset appConfigService.setValue(configKey, configValue)>
            <cfset actionMessage = "Config value updated for " & configKey & ".">
        <cfelse>
            <cfthrow message="Unknown settings action.">
        </cfif>
    <cfcatch type="any">
        <cfset actionMessage = cfcatch.message>
        <cfset actionMessageClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<cfset publishedSiteBaseUrl = mediaConfigService.getPublishedSiteBaseUrl()>
<cfset publishedImageBaseUrl = mediaConfigService.getPublishedImageBaseUrl()>
<cfset allConfig = appConfigService.getAll()>
<cfset ldapServer = appConfigService.getValue("ldap.cougarnet.server", "cougarnet.uh.edu")>
<cfset ldapStartDn = appConfigService.getValue("ldap.cougarnet.start_dn", "DC=cougarnet,DC=uh,DC=edu")>
<cfset ldapTimeoutSeconds = appConfigService.getValue("ldap.cougarnet.timeout_seconds", "10")>
<cfset ldapBindUsername = appConfigService.getValue("ldap.cougarnet.bind_username", "")>
<cfset ldapFacultyGroups = appConfigService.getValue("ldap.cougarnet.groups.faculty", "")>
<cfset ldapStaffGroups = appConfigService.getValue("ldap.cougarnet.groups.staff", "")>
<cfset ldapCurrentStudentGroups = appConfigService.getValue("ldap.cougarnet.groups.current_student", "")>
<cfset ldapBindPasswordIsSet = len(appConfigService.getValue("ldap.cougarnet.bind_password", "")) GT 0>
<cfset dashboardListPageSize = val(appConfigService.getValue("dashboard.list_page_size", "10"))>
<cfif dashboardListPageSize LT 1 OR dashboardListPageSize GT 50><cfset dashboardListPageSize = 10></cfif>
<cfset dashboardStaleMonths = val(appConfigService.getValue("dashboard.stale_months", "6"))>
<cfif dashboardStaleMonths LT 1 OR dashboardStaleMonths GT 60><cfset dashboardStaleMonths = 6></cfif>
<cfset testModeEnabled = usersService.isTestModeEnabled()>
<cfset testModeGenerationCount = usersService.getTestUserLimit()>
<cfset existingTestUserCount = usersService.getTestUserCount()>
<cfset pageSize = 10>
<cfset requestedPage = val(url.page ?: form.page ?: 1)>
<cfif requestedPage LT 1><cfset requestedPage = 1></cfif>
<cfset totalConfigRows = arrayLen(allConfig)>
<cfset totalPages = (totalConfigRows GT 0) ? ceiling(totalConfigRows / pageSize) : 1>
<cfset currentPage = requestedPage>
<cfif currentPage GT totalPages><cfset currentPage = totalPages></cfif>
<cfset configStartRow = ((currentPage - 1) * pageSize) + 1>
<cfset configEndRow = min(configStartRow + pageSize - 1, totalConfigRows)>
<cfset openPanel = trim(url.openPanel ?: form.openPanel ?: (len(actionMessage) ? "currentAppConfig" : "publishedSettings"))>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-app-config-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Application Settings</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-sliders me-2"></i>Application Settings</h1>
        <p class="text-muted mb-0">Generic application configuration stored in AppConfig. Start here for environment-specific values that will expand over time.</p>
    </div>
</div>

<cfif len(actionMessage)>
    <div class="alert #actionMessageClass# alert-dismissible fade show" role="alert">
        #encodeForHTML(actionMessage)#
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
</cfif>

<div class="accordion settings-accordion mb-4" id="appConfigAccordion">
    <div class="accordion-item shadow-sm mb-3 settings-shell settings-summary-card">
        <h2 class="accordion-header" id="headingPublishedSettings">
            <button class="accordion-button #(openPanel EQ "publishedSettings" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapsePublishedSettings" aria-expanded="#(openPanel EQ "publishedSettings")#" aria-controls="collapsePublishedSettings">
                <i class="bi bi-image me-2"></i>Published Image URL Settings
            </button>
        </h2>
        <div id="collapsePublishedSettings" class="accordion-collapse collapse #(openPanel EQ "publishedSettings" ? "show" : "")#" aria-labelledby="headingPublishedSettings" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body">
                <form method="post" class="row g-3 align-items-end">
                    <input type="hidden" name="formAction" value="savePublishedSettings">
                    <input type="hidden" name="openPanel" value="publishedSettings">
                    <div class="col-lg-8">
                        <label for="publishedSiteBaseUrl" class="form-label fw-bold">Published Site Base URL</label>
                        <input
                            type="url"
                            class="form-control"
                            id="publishedSiteBaseUrl"
                            name="publishedSiteBaseUrl"
                            value="#encodeForHTMLAttribute(publishedSiteBaseUrl)#"
                            placeholder="https://portal.opt.uh.edu/"
                            required
                        >
                        <div class="form-text">Publishing appends <code>_published_images/filename.ext</code> to this base URL.</div>
                    </div>
                    <div class="col-lg-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-save me-1"></i>Save Settings
                        </button>
                    </div>
                </form>

                <div class="mt-3 small text-muted">
                    Effective published image base URL:
                    <span class="font-monospace">#encodeForHTML(publishedImageBaseUrl)#</span>
                </div>
            </div>
        </div>
    </div>

    <div class="accordion-item shadow-sm mb-3 settings-shell settings-summary-card">
        <h2 class="accordion-header" id="headingDashboardSettings">
            <button class="accordion-button #(openPanel EQ "dashboardSettings" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapseDashboardSettings" aria-expanded="#(openPanel EQ "dashboardSettings")#" aria-controls="collapseDashboardSettings">
                <i class="bi bi-list-columns-reverse me-2"></i>Dashboard List Settings
            </button>
        </h2>
        <div id="collapseDashboardSettings" class="accordion-collapse collapse #(openPanel EQ "dashboardSettings" ? "show" : "")#" aria-labelledby="headingDashboardSettings" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body">
                <form method="post" class="row g-3 align-items-end">
                    <input type="hidden" name="formAction" value="saveDashboardSettings">
                    <input type="hidden" name="openPanel" value="dashboardSettings">

                    <div class="col-lg-4">
                        <label for="dashboardListPageSize" class="form-label fw-bold">dashboard.list_page_size</label>
                        <input
                            type="number"
                            min="1"
                            max="50"
                            class="form-control font-monospace"
                            id="dashboardListPageSize"
                            name="dashboardListPageSize"
                            value="#dashboardListPageSize#"
                            required
                        >
                        <div class="form-text">Rows per page for dashboard list widgets (stale users, stale media, unpublished variants).</div>
                    </div>

                    <div class="col-lg-4">
                        <label for="dashboardStaleMonths" class="form-label fw-bold">dashboard.stale_months</label>
                        <input
                            type="number"
                            min="1"
                            max="60"
                            class="form-control font-monospace"
                            id="dashboardStaleMonths"
                            name="dashboardStaleMonths"
                            value="#dashboardStaleMonths#"
                            required
                        >
                        <div class="form-text">Age threshold in months for stale-record and stale-media dashboard cards.</div>
                    </div>

                    <div class="col-lg-4">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-save me-1"></i>Save Dashboard Settings
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="accordion-item shadow-sm mb-3 settings-shell settings-summary-card">
        <h2 class="accordion-header" id="headingRecommendedKeys">
            <button class="accordion-button #(openPanel EQ "recommendedKeys" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapseRecommendedKeys" aria-expanded="#(openPanel EQ "recommendedKeys")#" aria-controls="collapseRecommendedKeys">
                <i class="bi bi-journal-text me-2"></i>Recommended AppConfig Keys
            </button>
        </h2>
        <div id="collapseRecommendedKeys" class="accordion-collapse collapse #(openPanel EQ "recommendedKeys" ? "show" : "")#" aria-labelledby="headingRecommendedKeys" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body small text-muted">
                <p class="mb-2">These keys are currently consumed by the dashboard summary cards in <span class="font-monospace">/admin/dashboard.cfm</span>:</p>
                <ul class="mb-2">
                    <li><span class="font-monospace">dashboard.list_page_size</span> (default: <strong>10</strong>)</li>
                    <li><span class="font-monospace">dashboard.stale_months</span> (default: <strong>6</strong>)</li>
                </ul>
                <p class="mb-0">Use the Dashboard List Settings panel above to update these values safely.</p>
            </div>
        </div>
    </div>

    <div class="accordion-item shadow-sm mb-3 settings-shell">
        <h2 class="accordion-header" id="headingLdapSettings">
            <button class="accordion-button #(openPanel EQ "ldapSettings" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapseLdapSettings" aria-expanded="#(openPanel EQ "ldapSettings")#" aria-controls="collapseLdapSettings">
                <span class="d-flex justify-content-between align-items-center w-100 pe-3">
                    <span><i class="bi bi-diagram-3 me-2"></i>LDAP Directory Settings</span>
                    <span class="badge #(hasAppConfigEncryptionKey ? "text-bg-success" : "text-bg-warning text-dark")#">
                        #(hasAppConfigEncryptionKey ? "Secret encryption enabled" : "Plaintext compatibility mode")#
                    </span>
                </span>
            </button>
        </h2>
        <div id="collapseLdapSettings" class="accordion-collapse collapse #(openPanel EQ "ldapSettings" ? "show" : "")#" aria-labelledby="headingLdapSettings" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body">
                <p class="text-muted small mb-3">
                    Use this section for CougarNet LDAP connectivity and group filters. Sensitive values are stored encrypted at rest when
                    <span class="font-monospace">UHCO_IDENT_APPCONFIG_ENC_KEY</span> is configured in the environment.
                </p>

                <cfif NOT hasAppConfigEncryptionKey>
                    <div class="alert alert-warning small" role="alert">
                        <strong>Compatibility mode is active.</strong> Sensitive values are currently saved in plaintext to match existing production behavior.
                        Set <span class="font-monospace">UHCO_IDENT_APPCONFIG_ENC_KEY</span> later to enable encrypted-at-rest storage.
                    </div>
                </cfif>

                <form method="post" class="row g-3">
                    <input type="hidden" name="formAction" value="saveLdapSettings">
                    <input type="hidden" name="openPanel" value="ldapSettings">

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
                            Current status:
                            <strong>#ldapBindPasswordIsSet ? "stored" : "not set"#</strong>.
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
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-save me-1"></i>Save LDAP Settings
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="accordion-item shadow-sm mb-3 settings-shell settings-summary-card">
        <h2 class="accordion-header" id="headingTestModeSettings">
            <button class="accordion-button #(openPanel EQ "testModeSettings" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapseTestModeSettings" aria-expanded="#(openPanel EQ "testModeSettings")#" aria-controls="collapseTestModeSettings">
                <span class="d-flex justify-content-between align-items-center w-100 pe-3">
                    <span><i class="bi bi-bezier2 me-2"></i>Test Mode</span>
                    <span class="badge #(testModeEnabled ? "text-bg-success" : "text-bg-secondary")#">
                        #(testModeEnabled ? "Enabled" : "Disabled")#
                    </span>
                </span>
            </button>
        </h2>
        <div id="collapseTestModeSettings" class="accordion-collapse collapse #(openPanel EQ "testModeSettings" ? "show" : "")#" aria-labelledby="headingTestModeSettings" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body">
                <p class="text-muted small mb-3">
                    Test Mode controls synthetic users marked with the dedicated <span class="font-monospace">TEST_USER</span> flag.
                    This workflow is limited to <strong>#testModeGenerationCount#</strong> synthetic users at a time so they can be edited and exercised like real records, then reset or replaced as needed.
                </p>

                <div class="row g-3 align-items-stretch">
                    <div class="col-lg-6">
                        <div class="border rounded p-3 h-100">
                            <h3 class="h6 mb-2">Mode State</h3>
                            <p class="small text-muted mb-3">Toggle the global Test Mode flag stored in <span class="font-monospace">test_mode.enabled</span>.</p>
                            <form method="post" class="d-flex flex-column gap-3">
                                <input type="hidden" name="formAction" value="toggleTestMode">
                                <input type="hidden" name="openPanel" value="testModeSettings">
                                <input type="hidden" name="enableTestMode" value="#testModeEnabled ? "0" : "1"#">
                                <div>
                                    <div class="fw-bold">Current status</div>
                                    <div class="small text-muted">#testModeEnabled ? "Enabled for Phase 1 test-user workflows." : "Disabled. Synthetic users remain excluded from API and quickpull output."#</div>
                                </div>
                                <div>
                                    <button type="submit" class="btn #(testModeEnabled ? "btn-outline-secondary" : "btn-primary")#">
                                        <i class="bi #(testModeEnabled ? "bi-toggle-off" : "bi-toggle-on")# me-1"></i>#testModeEnabled ? "Disable Test Mode" : "Enable Test Mode"#
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>

                    <div class="col-lg-6">
                        <div class="border rounded p-3 h-100">
                            <h3 class="h6 mb-2">Synthetic User Batch</h3>
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
                                        <input type="hidden" name="openPanel" value="testModeSettings">
                                        <button type="submit" class="btn btn-outline-primary js-generate-test-users-btn" data-default-label="#encodeForHTMLAttribute("Create #testModeGenerationCount# Synthetic Users")#">
                                            <i class="bi bi-person-plus me-1"></i>Create #testModeGenerationCount# Synthetic Users
                                        </button>
                                    </form>
                                </cfif>

                                <cfif existingTestUserCount GT 0>
                                    <form method="post" onsubmit="return confirm('Delete all TEST_USER records? This cannot be undone.');">
                                        <input type="hidden" name="formAction" value="deleteTestUsers">
                                        <input type="hidden" name="openPanel" value="testModeSettings">
                                        <button type="submit" class="btn btn-outline-danger">
                                            <i class="bi bi-trash me-1"></i>Delete Current TEST_USER Records
                                        </button>
                                    </form>
                                </cfif>

                                <cfif existingTestUserCount EQ testModeGenerationCount>
                                    <form method="post" onsubmit="return confirm('Reset the current TEST_USER batch back to its initial stale state?');">
                                        <input type="hidden" name="formAction" value="resetTestUsers">
                                        <input type="hidden" name="openPanel" value="testModeSettings">
                                        <button type="submit" class="btn btn-outline-secondary">
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
    </div>

    <div class="accordion-item shadow-sm settings-shell">
        <h2 class="accordion-header" id="headingCurrentAppConfig">
            <button class="accordion-button #(openPanel EQ "currentAppConfig" ? "" : "collapsed")#" type="button" data-bs-toggle="collapse" data-bs-target="##collapseCurrentAppConfig" aria-expanded="#(openPanel EQ "currentAppConfig")#" aria-controls="collapseCurrentAppConfig">
                <span class="d-flex justify-content-between align-items-center w-100 pe-3">
                    <span><i class="bi bi-table me-2"></i>Current AppConfig Values</span>
                    <span class="badge settings-badge-count">#totalConfigRows#</span>
                </span>
            </button>
        </h2>
        <div id="collapseCurrentAppConfig" class="accordion-collapse collapse #(openPanel EQ "currentAppConfig" ? "show" : "")#" aria-labelledby="headingCurrentAppConfig" data-bs-parent="##appConfigAccordion">
            <div class="accordion-body p-0">
                <cfif totalConfigRows>
                    <div class="d-flex justify-content-between align-items-center px-3 py-2 small text-muted border-bottom">
                        <span>Showing #configStartRow#-#configEndRow# of #totalConfigRows#</span>
                        <span>#pageSize# per page</span>
                    </div>
                    <div class="table-responsive">
                        <table class="table table-sm table-hover mb-0 align-middle settings-table">
                            <thead>
                                <tr>
                                    <th>Config Key</th>
                                    <th>Config Value</th>
                                    <th>Updated</th>
                                    <th class="text-end">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <cfloop from="#configStartRow#" to="#configEndRow#" index="i">
                                    <cfset row = allConfig[i]>
                                    <tr>
                                        <td class="font-monospace">#encodeForHTML(row.CONFIGKEY)#</td>
                                        <td class="font-monospace small">
                                            #encodeForHTML(row.CONFIGVALUE_DISPLAY ?: "")#
                                            <cfif row.IS_SENSITIVE>
                                                <span class="badge text-bg-secondary ms-2">sensitive</span>
                                            </cfif>
                                        </td>
                                        <td class="small text-muted">#len(row.UPDATEDAT ?: "") ? dateTimeFormat(row.UPDATEDAT, "mmm d, yyyy h:nn tt") : ""#</td>
                                        <td class="text-end">
                                            <cfif row.IS_SENSITIVE>
                                                <span class="small text-muted">Use dedicated settings</span>
                                            <cfelse>
                                                <button
                                                    type="button"
                                                    class="btn btn-sm btn-edit js-edit-config"
                                                    data-bs-toggle="modal"
                                                    data-bs-target="##editConfigModal"
                                                    data-config-key="#encodeForHTMLAttribute(row.CONFIGKEY)#"
                                                    data-config-value="#encodeForHTMLAttribute(row.CONFIGVALUE ?: "")#"
                                                >
                                                    <i class="bi bi-pencil-square me-1"></i>
                                                </button>
                                            </cfif>
                                        </td>
                                    </tr>
                                </cfloop>
                            </tbody>
                        </table>
                    </div>
                    <cfif totalPages GT 1>
                        <nav aria-label="AppConfig pagination" class="p-3 border-top">
                            <ul class="pagination pagination-sm mb-0 justify-content-end">
                                <li class="page-item #(currentPage EQ 1 ? "disabled" : "")#">
                                    <a class="page-link" href="?page=#max(currentPage - 1, 1)#&openPanel=#encodeForURL("currentAppConfig")#" aria-label="Previous">
                                        <span aria-hidden="true">&laquo;</span>
                                    </a>
                                </li>
                                <cfloop from="1" to="#totalPages#" index="p">
                                    <li class="page-item #(p EQ currentPage ? "active" : "")#">
                                        <a class="page-link" href="?page=#p#&openPanel=#encodeForURL("currentAppConfig")#">#p#</a>
                                    </li>
                                </cfloop>
                                <li class="page-item #(currentPage EQ totalPages ? "disabled" : "")#">
                                    <a class="page-link" href="?page=#min(currentPage + 1, totalPages)#&openPanel=#encodeForURL("currentAppConfig")#" aria-label="Next">
                                        <span aria-hidden="true">&raquo;</span>
                                    </a>
                                </li>
                            </ul>
                        </nav>
                    </cfif>
                <cfelse>
                    <div class="p-3 text-muted">No app settings found.</div>
                </cfif>
            </div>
        </div>
    </div>
</div>

</div>

<div class="modal fade settings-modal" id="editConfigModal" tabindex="-1" aria-labelledby="editConfigModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editConfigModalLabel"><i class="bi bi-gear me-2"></i>Edit AppConfig Value</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form id="editConfigForm" method="post">
                <input type="hidden" name="formAction" value="updateConfigValue">
                <input type="hidden" name="openPanel" value="currentAppConfig">
                <input type="hidden" name="page" value="#currentPage#">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="editConfigKey" class="form-label fw-bold">Config Key</label>
                        <input type="text" class="form-control font-monospace" id="editConfigKey" name="configKey" readonly>
                    </div>
                    <div class="mb-2">
                        <label for="editConfigValue" class="form-label fw-bold">Config Value</label>
                        <textarea class="form-control font-monospace" id="editConfigValue" name="configValue" rows="4"></textarea>
                    </div>
                    <div class="small text-muted text-center">
                        <strong class="text-danger">This change is immediate and affects all environments.</strong><br/><br/>Changing certain config values may have unintended consequences. Please review the value carefully before applying.
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" id="reviewConfigChangeBtn" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="##confirmConfigModal">
                        <i class="bi bi-check2-square me-1"></i>Review Change
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<div class="modal fade settings-modal" id="confirmConfigModal" tabindex="-1" aria-labelledby="confirmConfigModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="confirmConfigModalLabel"><i class="bi bi-exclamation-triangle me-2"></i>Confirm AppConfig Update</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <p class="mb-2">You are about to update this config key:</p>
                <div class="p-2 rounded border bg-light small mb-3">
                    <div><strong>Key:</strong> <span id="confirmConfigKey" class="font-monospace"></span></div>
                    <div class="mt-1"><strong>New Value:</strong></div>
                    <div id="confirmConfigValue" class="font-monospace small text-break"></div>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" value="1" id="confirmConfigCheckbox">
                    <label class="form-check-label" for="confirmConfigCheckbox">
                        I understand this updates live AppConfig values.
                    </label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" id="applyConfigChangeBtn" class="btn btn-danger" disabled>
                    <i class="bi bi-check-circle me-1"></i>Apply Change
                </button>
            </div>
        </div>
    </div>
</div>

<script>
(function () {
    document.addEventListener('DOMContentLoaded', function () {
        var editConfigModal = document.getElementById('editConfigModal');
        var confirmConfigModal = document.getElementById('confirmConfigModal');
        var editForm = document.getElementById('editConfigForm');
        var keyInput = document.getElementById('editConfigKey');
        var valueInput = document.getElementById('editConfigValue');
        var confirmKey = document.getElementById('confirmConfigKey');
        var confirmValue = document.getElementById('confirmConfigValue');
        var confirmCheckbox = document.getElementById('confirmConfigCheckbox');
        var applyBtn = document.getElementById('applyConfigChangeBtn');
        var generateForms = document.querySelectorAll('.js-generate-test-users-form');

        if (!editConfigModal || !confirmConfigModal || !editForm) { return; }

        editConfigModal.addEventListener('show.bs.modal', function (event) {
            var trigger = event.relatedTarget;
            keyInput.value = trigger.getAttribute('data-config-key') || '';
            valueInput.value = trigger.getAttribute('data-config-value') || '';
            confirmCheckbox.checked = false;
            applyBtn.disabled = true;
        });

        confirmConfigModal.addEventListener('show.bs.modal', function () {
            confirmKey.textContent = keyInput.value || '';
            confirmValue.textContent = valueInput.value || '(empty)';
            confirmCheckbox.checked = false;
            applyBtn.disabled = true;
        });

        confirmCheckbox.addEventListener('change', function () {
            applyBtn.disabled = !confirmCheckbox.checked;
        });

        applyBtn.addEventListener('click', function () {
            editForm.submit();
        });

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

<cfinclude template="/admin/layout.cfm">