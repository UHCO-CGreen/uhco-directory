<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("app-config")>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset mediaConfigService = createObject("component", "cfc.mediaConfig_service").init()>
<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>

<cfset actionMessage = "">
<cfset actionMessageClass = "alert-success">

<cfif cgi.request_method EQ "POST">
    <cftry>
        <cfset postAction = trim(form.formAction ?: "savePublishedSettings")>

        <cfif postAction EQ "savePublishedSettings">
            <cfset mediaConfigService.setPublishedSiteBaseUrl( trim(form.publishedSiteBaseUrl ?: "") )>
            <cfset actionMessage = "Published image URL saved.">
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
        <cfelseif postAction EQ "updateConfigValue">
            <cfset configKey = trim(form.configKey ?: "")>
            <cfset configValue = trim(form.configValue ?: "")>

            <cfif NOT len(configKey)>
                <cfthrow message="Config key is required.">
            </cfif>

            <cfif appConfigService.isSensitiveKey(configKey)>
                <cfthrow message="Sensitive AppConfig values must be updated in a dedicated settings form.">
            </cfif>

            <cfset appConfigService.setValue(configKey, configValue)>
            <cfset actionMessage = "Config value updated for #configKey#.">
        <cfelseif postAction EQ "addConfigKey">
            <cfset newKey         = trim(form.newConfigKey ?: "")>
            <cfset newValue       = trim(form.newConfigValue ?: "")>
            <cfset newCategory    = trim(form.newConfigCategory ?: "")>
            <cfset newDescription = trim(form.newConfigDescription ?: "")>

            <cfset appConfigService.addKey(
                configKey   = newKey,
                configValue = newValue,
                category    = newCategory,
                description = newDescription
            )>
            <cfset actionMessage = "Config key '#encodeForHTML(newKey)#' added.">
        <cfelse>
            <cfthrow message="Unknown settings action.">
        </cfif>
    <cfcatch type="any">
        <cfset actionMessage = cfcatch.message>
        <cfset actionMessageClass = "alert-danger">
    </cfcatch>
    </cftry>
</cfif>

<cfset userReviewSettings = userReviewService.getSettings()>
<cfset publishedSiteBaseUrl = mediaConfigService.getPublishedSiteBaseUrl()>
<cfset publishedImageBaseUrl = mediaConfigService.getPublishedImageBaseUrl()>
<cfset allConfig = appConfigService.getAll()>

<cfset dashboardListPageSize = val(appConfigService.getValue("dashboard.list_page_size", "10"))>
<cfif dashboardListPageSize LT 1 OR dashboardListPageSize GT 50><cfset dashboardListPageSize = 10></cfif>
<cfset dashboardStaleMonths = val(appConfigService.getValue("dashboard.stale_months", "6"))>
<cfif dashboardStaleMonths LT 1 OR dashboardStaleMonths GT 60><cfset dashboardStaleMonths = 6></cfif>

<!--- Build category list from all config rows --->
<cfscript>
    categories = [];
    for (cfgRow in allConfig) {
        cfgCat = len(cfgRow.CATEGORY) ? cfgRow.CATEGORY : "Uncategorized";
        if (arrayFindNoCase(categories, cfgCat) EQ 0) {
            arrayAppend(categories, cfgCat);
        }
    }
    arraySort(categories, "text", "asc");
</cfscript>

<!--- Category filter (server-side) --->
<cfset filterCategory = trim(url.filterCategory ?: "")>
<cfscript>
    if (len(filterCategory)) {
        filteredConfig = [];
        for (cfgRow in allConfig) {
            rowCat = len(cfgRow.CATEGORY) ? cfgRow.CATEGORY : "Uncategorized";
            if (lCase(rowCat) EQ lCase(filterCategory)) {
                arrayAppend(filteredConfig, cfgRow);
            }
        }
        allConfig = filteredConfig;
    }
</cfscript>

<!--- Sort params --->
<cfset allowedConfigSortCols = ["CONFIGKEY","UPDATEDAT","CATEGORY"]>
<cfset sortCol = (structKeyExists(url, "sortCol") AND arrayFindNoCase(allowedConfigSortCols, url.sortCol) GT 0) ? url.sortCol : "CONFIGKEY">
<cfset sortDir = ((url.sortDir ?: "") EQ "DESC") ? "DESC" : "ASC">
<cfscript>
    arraySort(allConfig, function(a, b) {
        var aVal = lCase(toString(isNull(a[sortCol]) ? "" : a[sortCol]));
        var bVal = lCase(toString(isNull(b[sortCol]) ? "" : b[sortCol]));
        if (aVal LT bVal) return sortDir EQ "ASC" ? -1 : 1;
        if (aVal GT bVal) return sortDir EQ "ASC" ? 1 : -1;
        return 0;
    });

    function configSortLink(col) {
        var dir = (sortCol EQ col AND sortDir EQ "ASC") ? "DESC" : "ASC";
        var base = "?sortCol=" & col & "&sortDir=" & dir;
        if (len(filterCategory)) base &= "&filterCategory=" & encodeForURL(filterCategory);
        return base;
    }
    function configSortArrow(col) {
        if (sortCol EQ col) return sortDir EQ "ASC" ? " &uarr;" : " &darr;";
        return "";
    }
</cfscript>

<!--- Pagination (reset to page 1 when a category filter is active) --->
<cfset pageSize = 10>
<cfset requestedPage = (NOT len(filterCategory)) ? val(url.page ?: form.page ?: 1) : 1>
<cfif requestedPage LT 1><cfset requestedPage = 1></cfif>
<cfset totalConfigRows = arrayLen(allConfig)>
<cfset totalPages = (totalConfigRows GT 0) ? ceiling(totalConfigRows / pageSize) : 1>
<cfset currentPage = requestedPage>
<cfif currentPage GT totalPages><cfset currentPage = totalPages></cfif>
<cfset configStartRow = ((currentPage - 1) * pageSize) + 1>
<cfset configEndRow = min(configStartRow + pageSize - 1, totalConfigRows)>

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
        <p class="text-muted mb-0">Key-value configuration stored in AppConfig and environment-specific settings.</p>
    </div>
    <div class="d-flex align-items-center gap-2">
        <button type="button" class="btn btn-ui-add" data-bs-toggle="modal" data-bs-target="##addConfigKeyModal">
            <i class="bi bi-plus-circle me-1"></i>Add Config Key
        </button>
        <cfif len(sectionStatus)>
            <span class="badge bg-warning text-dark">#sectionStatus#</span>
        </cfif>
    </div>
</div>

<!--- Published Image URL --->
<div class="card shadow-sm mb-4 settings-shell settings-summary-card">
    <div class="card-header">
        <button class="btn btn-link text-start text-decoration-none p-0 w-100 d-flex align-items-center gap-2 fw-semibold" type="button" data-bs-toggle="collapse" data-bs-target="##collapsePublishedSettings" aria-expanded="true" aria-controls="collapsePublishedSettings">
            <i class="bi bi-image"></i>Published Image URL Settings
        </button>
    </div>
    <div id="collapsePublishedSettings" class="collapse show">
        <div class="card-body">
            <form method="post" class="row g-3 align-items-end">
                <input type="hidden" name="formAction" value="savePublishedSettings">
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
                    <button type="submit" class="btn btn-ui-save">
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

<!--- Dashboard List Settings --->
<div class="card shadow-sm mb-4 settings-shell settings-summary-card">
    <div class="card-header">
        <button class="btn btn-link text-start text-decoration-none p-0 w-100 d-flex align-items-center gap-2 fw-semibold" type="button" data-bs-toggle="collapse" data-bs-target="##collapseDashboardSettings" aria-expanded="true" aria-controls="collapseDashboardSettings">
            <i class="bi bi-list-columns-reverse"></i>Dashboard List Settings
        </button>
    </div>
    <div id="collapseDashboardSettings" class="collapse show">
        <div class="card-body">
            <form method="post" class="row g-3 align-items-end">
                <input type="hidden" name="formAction" value="saveDashboardSettings">

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
                    <button type="submit" class="btn btn-ui-save">
                        <i class="bi bi-save me-1"></i>Save Dashboard Settings
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!--- Dropbox Settings (Super Admin only) --->
<cfif application.authService.hasRole("SUPER_ADMIN")>
<div class="card shadow-sm mb-4 settings-shell settings-summary-card">
    <div class="card-header">
        <button class="btn btn-link text-start text-decoration-none p-0 w-100 d-flex align-items-center gap-2 fw-semibold" type="button" data-bs-toggle="collapse" data-bs-target="##collapseDropboxSettings" aria-expanded="true" aria-controls="collapseDropboxSettings">
            <i class="bi bi-dropbox"></i>Dropbox Settings
        </button>
    </div>
    <div id="collapseDropboxSettings" class="collapse show">
        <div class="card-body">
            <p class="mb-2 text-muted small">Manage Dropbox API credentials and OAuth tokens. Dropbox refresh tokens must be regenerated any time app scopes are changed in the Dropbox App Console.</p>
            <a href="/admin/settings/app-config/dropbox-token.cfm" class="btn btn-sm btn-ui-go">
                <i class="bi bi-key me-1"></i>Regenerate Refresh Token
            </a>
        </div>
    </div>
</div>
</cfif>

<!--- User Review Configuration --->
<div class="card shadow-sm mb-4 settings-shell settings-summary-card">
    <div class="card-header">
        <button class="btn btn-link text-start text-decoration-none p-0 w-100 d-flex align-items-center gap-2 fw-semibold" type="button" data-bs-toggle="collapse" data-bs-target="##collapseUserReviewSettings" aria-expanded="true" aria-controls="collapseUserReviewSettings">
            <i class="bi bi-person-lines-fill"></i>User Review Configuration
        </button>
    </div>
    <div id="collapseUserReviewSettings" class="collapse show">
        <div class="card-body">
            <form method="post" action="/admin/user-review/save.cfm">
                <input type="hidden" name="returnTo" value="/admin/settings/app-config/">
                <div class="row g-4">
                    <div class="col-lg-4">
                        <label class="form-label fw-bold d-block">Feature State</label>
                        <div class="form-check form-switch">
                            <input class="form-check-input" type="checkbox" id="ur_enabled" name="enabled" value="1" #(userReviewSettings.enabled ? "checked" : "")#>
                            <label class="form-check-label" for="ur_enabled">Enable UserReview</label>
                        </div>
                    </div>
                    <div class="col-lg-4">
                        <label class="form-label fw-bold d-block">Eligible Audiences</label>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_allowFaculty" name="allowFaculty" value="1" #(userReviewSettings.allowFaculty ? "checked" : "")#><label class="form-check-label" for="ur_allowFaculty">Faculty</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_allowStaff" name="allowStaff" value="1" #(userReviewSettings.allowStaff ? "checked" : "")#><label class="form-check-label" for="ur_allowStaff">Staff</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_allowCurrentStudents" name="allowCurrentStudents" value="1" #(userReviewSettings.allowCurrentStudents ? "checked" : "")#><label class="form-check-label" for="ur_allowCurrentStudents">Current Students</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_allowAlumni" name="allowAlumni" value="1" #(userReviewSettings.allowAlumni ? "checked" : "")#><label class="form-check-label" for="ur_allowAlumni">Alumni</label></div>
                    </div>
                    <div class="col-lg-4">
                        <label class="form-label fw-bold d-block">Editable Sections</label>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_sectionGeneral" name="editableSections" value="general" #(arrayFindNoCase(userReviewSettings.editableSections, "general") ? "checked" : "")#><label class="form-check-label" for="ur_sectionGeneral">General</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_sectionContact" name="editableSections" value="contact" #(arrayFindNoCase(userReviewSettings.editableSections, "contact") ? "checked" : "")#><label class="form-check-label" for="ur_sectionContact">Contact</label></div>
                        <div class="form-check"><input class="form-check-input" type="checkbox" id="ur_sectionBioinfo" name="editableSections" value="bioinfo" #(arrayFindNoCase(userReviewSettings.editableSections, "bioinfo") ? "checked" : "")#><label class="form-check-label" for="ur_sectionBioinfo">Biographical</label></div>
                    </div>
                    <div class="col-12">
                        <label for="ur_externalAuthToken" class="form-label fw-bold">External POST Auth Token</label>
                        <input type="text" class="form-control font-monospace" id="ur_externalAuthToken" name="externalAuthToken" value="#encodeForHTMLAttribute(userReviewSettings.externalAuthToken)#">
                        <div class="form-text">If set, external systems can POST <span class="font-monospace">cougarnetID</span> and this token to <span class="font-monospace">/UserReview/authenticate.cfm</span> for bypass login.</div>
                    </div>
                </div>
                <div class="mt-4">
                    <button type="submit" class="btn btn-ui-save"><i class="bi bi-save me-1"></i>Save User Review Settings</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!--- AppConfig table --->
<div class="card shadow-sm settings-shell">
    <div class="card-header d-flex justify-content-between align-items-center">
        <div class="d-flex align-items-center gap-2">
            <i class="bi bi-table"></i>
            <span class="fw-semibold">AppConfig Values</span>
            <span class="badge settings-badge-count">#arrayLen(appConfigService.getAll())#</span>
        </div>
    </div>
    <div class="card-body pb-2">
        <!--- Category filter pills --->
        <div class="d-flex flex-wrap gap-1 mb-3">
            <a href="?" class="btn btn-sm #(NOT len(filterCategory) ? "btn-ui-filter" : "btn-ui-cancel")#">All</a>
            <cfloop array="#categories#" index="cat">
                <a href="?filterCategory=#encodeForURL(cat)#" class="btn btn-sm #(lCase(filterCategory) EQ lCase(cat) ? "btn-ui-filter" : "btn-ui-cancel")#">#encodeForHTML(cat)#</a>
            </cfloop>
        </div>
        <!--- Client-side search --->
        <div class="mb-3">
            <input type="search" id="configSearchInput" class="form-control form-control-sm" placeholder="Search by key, value, category, or description...">
        </div>
    </div>

    <cfif totalConfigRows GT 0>
        <div class="d-flex justify-content-between align-items-center px-3 py-2 small text-muted border-top border-bottom">
            <span>Showing #configStartRow#-#configEndRow# of #totalConfigRows#</span>
            <span>#pageSize# per page</span>
        </div>
        <div class="table-responsive">
            <table class="table table-sm table-hover mb-0 align-middle settings-table">
                <thead>
                    <tr>
                        <th style="width:10%"><a href="#configSortLink('CATEGORY')#" class="settings-sort-link">Category#configSortArrow('CATEGORY')#</a></th>
                        <th style="width:25%"><a href="#configSortLink('CONFIGKEY')#" class="settings-sort-link">Config Key#configSortArrow('CONFIGKEY')#</a></th>
                        <th style="width:20%">Value</th>
                        <th style="width:30%">Description</th>
                        <th style="width:10%"><a href="#configSortLink('UPDATEDAT')#" class="settings-sort-link">Updated#configSortArrow('UPDATEDAT')#</a></th>
                        <th class="text-end" style="width:5%">Actions</th>
                    </tr>
                </thead>
                <tbody id="configTableBody">
                    <cfloop from="#configStartRow#" to="#configEndRow#" index="i">
                        <cfset row = allConfig[i]>
                        <cfset displayCat = len(row.CATEGORY) ? row.CATEGORY : "Uncategorized">
                        <tr>
                            <td>
                                <span class="badge text-bg-secondary">#encodeForHTML(displayCat)#</span>
                            </td>
                            <td class="font-monospace small">#encodeForHTML(row.CONFIGKEY)#</td>
                            <td class="font-monospace small text-break">
                                #encodeForHTML(row.CONFIGVALUE_DISPLAY ?: "")#
                                <cfif row.IS_SENSITIVE>
                                    <span class="badge text-bg-secondary ms-1">sensitive</span>
                                </cfif>
                            </td>
                            <td class="small text-muted">#encodeForHTML(row.DESCRIPTION)#</td>
                            <td class="small text-muted text-nowrap">#len(row.UPDATEDAT ?: "") ? dateTimeFormat(row.UPDATEDAT, "mmm d, yyyy") : ""#</td>
                            <td class="text-end">
                                <cfif row.IS_SENSITIVE>
                                    <span class="small text-muted">Use dedicated settings</span>
                                <cfelse>
                                    <button
                                        type="button"
                                        class="btn btn-sm btn-ui-edit js-edit-config"
                                        data-bs-toggle="modal"
                                        data-bs-target="##editConfigModal"
                                        data-config-key="#encodeForHTMLAttribute(row.CONFIGKEY)#"
                                        data-config-value="#encodeForHTMLAttribute(row.CONFIGVALUE ?: "")#"
                                        data-config-description="#encodeForHTMLAttribute(row.DESCRIPTION)#"
                                    >
                                        <i class="bi bi-pencil-square"></i>
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
                        <a class="page-link" href="?page=#max(currentPage - 1, 1)#&sortCol=#encodeForURL(sortCol)#&sortDir=#encodeForURL(sortDir)##(len(filterCategory) ? "&filterCategory=" & encodeForURL(filterCategory) : "")#" aria-label="Previous">
                            <span aria-hidden="true">&laquo;</span>
                        </a>
                    </li>
                    <cfloop from="1" to="#totalPages#" index="p">
                        <li class="page-item #(p EQ currentPage ? "active" : "")#">
                            <a class="page-link" href="?page=#p#&sortCol=#encodeForURL(sortCol)#&sortDir=#encodeForURL(sortDir)##(len(filterCategory) ? "&filterCategory=" & encodeForURL(filterCategory) : "")#">#p#</a>
                        </li>
                    </cfloop>
                    <li class="page-item #(currentPage EQ totalPages ? "disabled" : "")#">
                        <a class="page-link" href="?page=#min(currentPage + 1, totalPages)#&sortCol=#encodeForURL(sortCol)#&sortDir=#encodeForURL(sortDir)##(len(filterCategory) ? "&filterCategory=" & encodeForURL(filterCategory) : "")#" aria-label="Next">
                            <span aria-hidden="true">&raquo;</span>
                        </a>
                    </li>
                </ul>
            </nav>
        </cfif>
    <cfelse>
        <div class="p-3 text-muted border-top">No AppConfig values found.</div>
    </cfif>
</div>

</div>

<!--- Edit Config Modal --->
<div class="modal fade settings-modal" id="editConfigModal" tabindex="-1" aria-labelledby="editConfigModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editConfigModalLabel"><i class="bi bi-pencil-square me-2"></i>Edit AppConfig Value</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form id="editConfigForm" method="post">
                <input type="hidden" name="formAction" value="updateConfigValue">
                <input type="hidden" name="page" value="#currentPage#">
                <cfif len(filterCategory)><input type="hidden" name="filterCategory" value="#encodeForHTMLAttribute(filterCategory)#"></cfif>
                <div class="modal-body">
                    <div class="mb-2">
                        <label for="editConfigKey" class="form-label fw-bold">Config Key</label>
                        <input type="text" class="form-control font-monospace" id="editConfigKey" name="configKey" readonly>
                    </div>
                    <div class="mb-1 small text-muted" id="editConfigDescriptionDisplay"></div>
                    <div class="mb-2">
                        <label for="editConfigValue" class="form-label fw-bold">Config Value</label>
                        <textarea class="form-control font-monospace" id="editConfigValue" name="configValue" rows="4"></textarea>
                    </div>
                    <div class="small text-muted text-center">
                        <strong class="text-danger">This change is immediate and affects all environments.</strong><br><br>Review the value carefully before applying.
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" id="reviewConfigChangeBtn" class="btn btn-ui-go" data-bs-toggle="modal" data-bs-target="##confirmConfigModal">
                        <i class="bi bi-check2-square me-1"></i>Review Change
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!--- Confirm Edit Modal --->
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
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" id="applyConfigChangeBtn" class="btn btn-ui-save" disabled>
                    <i class="bi bi-check-circle me-1"></i>Apply Change
                </button>
            </div>
        </div>
    </div>
</div>

<!--- Add New Config Key Modal --->
<div class="modal fade settings-modal" id="addConfigKeyModal" tabindex="-1" aria-labelledby="addConfigKeyModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="addConfigKeyModalLabel"><i class="bi bi-plus-circle me-2"></i>Add Config Key</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form id="addConfigKeyForm" method="post">
                <input type="hidden" name="formAction" value="addConfigKey">
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="newConfigKey" class="form-label fw-bold">Config Key <span class="text-danger">*</span></label>
                        <input type="text" class="form-control font-monospace" id="newConfigKey" name="newConfigKey" required placeholder="e.g. dashboard.page_size">
                        <div class="form-text">Lowercase letters, numbers, dots, and underscores only (e.g. <code>feature.max_items</code>).</div>
                    </div>
                    <div class="mb-3">
                        <label for="newConfigCategory" class="form-label fw-bold">Category</label>
                        <input type="text" class="form-control" id="newConfigCategory" name="newConfigCategory" list="existingCategoriesList" placeholder="e.g. Dashboard">
                        <datalist id="existingCategoriesList">
                            <cfloop array="#categories#" index="cat">
                                <cfif cat NEQ "Uncategorized"><option value="#encodeForHTMLAttribute(cat)#"></cfif>
                            </cfloop>
                        </datalist>
                        <div class="form-text">Select an existing category or type a new one.</div>
                    </div>
                    <div class="mb-3">
                        <label for="newConfigDescription" class="form-label fw-bold">Description</label>
                        <textarea class="form-control" id="newConfigDescription" name="newConfigDescription" rows="2" maxlength="500" placeholder="What does this key control?"></textarea>
                    </div>
                    <div class="mb-3">
                        <label for="newConfigValue" class="form-label fw-bold">Value</label>
                        <textarea class="form-control font-monospace" id="newConfigValue" name="newConfigValue" rows="3"></textarea>
                    </div>
                    <div class="alert alert-warning small mb-0" role="alert">
                        <strong>This applies immediately to all environments.</strong>
                        Review the key name and value carefully before saving.
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" id="reviewAddKeyBtn" class="btn btn-ui-go">
                        <i class="bi bi-check2-square me-1"></i>Review &amp; Add
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!--- Confirm Add Key Modal --->
<div class="modal fade settings-modal" id="confirmAddKeyModal" tabindex="-1" aria-labelledby="confirmAddKeyModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="confirmAddKeyModalLabel"><i class="bi bi-exclamation-triangle me-2"></i>Confirm New Config Key</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <p class="mb-2">You are about to add this config key:</p>
                <div class="p-2 rounded border bg-light small mb-3">
                    <div><strong>Key:</strong> <span id="confirmAddKey" class="font-monospace"></span></div>
                    <div class="mt-1"><strong>Category:</strong> <span id="confirmAddCategory"></span></div>
                    <div class="mt-1"><strong>Description:</strong> <span id="confirmAddDescription" class="text-muted"></span></div>
                    <div class="mt-1"><strong>Value:</strong></div>
                    <div id="confirmAddValue" class="font-monospace small text-break"></div>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" value="1" id="confirmAddKeyCheckbox">
                    <label class="form-check-label" for="confirmAddKeyCheckbox">
                        I understand this adds a new live AppConfig key.
                    </label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Cancel</button>
                <button type="button" id="applyAddKeyBtn" class="btn btn-ui-add" disabled>
                    <i class="bi bi-plus-circle me-1"></i>Add Key
                </button>
            </div>
        </div>
    </div>
</div>

<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
(function () {
    document.addEventListener('DOMContentLoaded', function () {

        // ── Edit existing key ──
        var editConfigModal   = document.getElementById('editConfigModal');
        var confirmConfigModal = document.getElementById('confirmConfigModal');
        var editForm           = document.getElementById('editConfigForm');
        var keyInput           = document.getElementById('editConfigKey');
        var valueInput         = document.getElementById('editConfigValue');
        var descDisplay        = document.getElementById('editConfigDescriptionDisplay');
        var confirmKey         = document.getElementById('confirmConfigKey');
        var confirmValue       = document.getElementById('confirmConfigValue');
        var confirmCheckbox    = document.getElementById('confirmConfigCheckbox');
        var applyBtn           = document.getElementById('applyConfigChangeBtn');

        if (editConfigModal && confirmConfigModal && editForm) {
            editConfigModal.addEventListener('show.bs.modal', function (event) {
                var trigger = event.relatedTarget;
                keyInput.value   = trigger.getAttribute('data-config-key') || '';
                valueInput.value = trigger.getAttribute('data-config-value') || '';
                var desc = trigger.getAttribute('data-config-description') || '';
                descDisplay.textContent = desc || '';
                descDisplay.style.display = desc ? '' : 'none';
                confirmCheckbox.checked = false;
                applyBtn.disabled = true;
            });

            confirmConfigModal.addEventListener('show.bs.modal', function () {
                confirmKey.textContent   = keyInput.value || '';
                confirmValue.textContent = valueInput.value || '(empty)';
                confirmCheckbox.checked  = false;
                applyBtn.disabled = true;
            });

            confirmCheckbox.addEventListener('change', function () {
                applyBtn.disabled = !confirmCheckbox.checked;
            });

            applyBtn.addEventListener('click', function () {
                editForm.submit();
            });
        }

        // ── Add new key ──
        var addConfigKeyModal   = document.getElementById('addConfigKeyModal');
        var confirmAddKeyModal  = document.getElementById('confirmAddKeyModal');
        var addKeyForm          = document.getElementById('addConfigKeyForm');
        var addKeyInput         = document.getElementById('newConfigKey');
        var addCategoryInput    = document.getElementById('newConfigCategory');
        var addDescInput        = document.getElementById('newConfigDescription');
        var addValueInput       = document.getElementById('newConfigValue');
        var confirmAddKey       = document.getElementById('confirmAddKey');
        var confirmAddCategory  = document.getElementById('confirmAddCategory');
        var confirmAddDesc      = document.getElementById('confirmAddDescription');
        var confirmAddValue     = document.getElementById('confirmAddValue');
        var confirmAddCheckbox  = document.getElementById('confirmAddKeyCheckbox');
        var applyAddBtn         = document.getElementById('applyAddKeyBtn');
        var reviewAddBtn        = document.getElementById('reviewAddKeyBtn');

        if (reviewAddBtn && confirmAddKeyModal) {
            reviewAddBtn.addEventListener('click', function () {
                var key = (addKeyInput.value || '').trim();
                if (!key) {
                    addKeyInput.focus();
                    addKeyInput.setCustomValidity('Config key is required.');
                    addKeyInput.reportValidity();
                    return;
                }
                if (!/^[a-z0-9][a-z0-9._]*$/.test(key)) {
                    addKeyInput.focus();
                    addKeyInput.setCustomValidity('Use lowercase letters, numbers, dots, and underscores only.');
                    addKeyInput.reportValidity();
                    return;
                }
                addKeyInput.setCustomValidity('');
                confirmAddKey.textContent      = key;
                confirmAddCategory.textContent = (addCategoryInput.value || '').trim() || '(none)';
                confirmAddDesc.textContent     = (addDescInput.value || '').trim() || '(none)';
                confirmAddValue.textContent    = (addValueInput.value || '').trim() || '(empty)';
                confirmAddCheckbox.checked     = false;
                applyAddBtn.disabled = true;
                var bsModal = new bootstrap.Modal(confirmAddKeyModal);
                bsModal.show();
            });

            confirmAddCheckbox.addEventListener('change', function () {
                applyAddBtn.disabled = !confirmAddCheckbox.checked;
            });

            applyAddBtn.addEventListener('click', function () {
                addKeyForm.submit();
            });
        }

        // ── Client-side search ──
        var searchInput = document.getElementById('configSearchInput');
        var tableBody   = document.getElementById('configTableBody');
        if (searchInput && tableBody) {
            searchInput.addEventListener('input', function () {
                var term = this.value.toLowerCase();
                var rows = tableBody.querySelectorAll('tr');
                rows.forEach(function (row) {
                    row.style.display = row.textContent.toLowerCase().includes(term) ? '' : 'none';
                });
            });
        }

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
