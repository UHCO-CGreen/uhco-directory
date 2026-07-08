<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>UHCO Identity Admin</title>
    <cfset pageCsrfToken = structKeyExists(request, "adminCsrfToken") ? trim(request.adminCsrfToken ?: "") : "">
    <cfif len(pageCsrfToken)>
        <cfoutput><meta name="csrf-token" content="#encodeForHTMLAttribute(pageCsrfToken)#"></cfoutput>
    </cfif>
    <cfoutput><meta name="uhco-webroot" content="#encodeForHTMLAttribute(request.webRoot ?: '')#"></cfoutput>

    <link rel="stylesheet" href="/assets/css/dist/admin/admin.css">
    
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="/assets/vendor/bootstrap-icons/bootstrap-icons.css">

    <cfif structKeyExists(variables, "pageStyles")>
        <cfoutput>#pageStyles#</cfoutput>
    </cfif>

    <script src="/assets/js/admin/admin-shell.js"></script>
</head>

<cfset isSettingsSection = structKeyExists(cgi, "script_name") AND findNoCase("/admin/settings/", cgi.script_name) GT 0>
<cfset isUsersSection = structKeyExists(cgi, "script_name") AND findNoCase("/admin/users/", cgi.script_name) GT 0>
<cfparam name="contentWrapperClass" default="py-4 px-4">
<cfparam name="showGlobalAdminToolbar" default="#NOT isUsersSection#">

<body>
<div class="portal-shell admin-portal-shell">
    <!-- Sidebar -->
    <cfoutput>
    <nav class="main-sidebar admin-sidebar" id="sidebar">
        <script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
            // Apply collapsed state immediately to prevent flicker
            if (localStorage.getItem('sidebarCollapsed') === 'true') {
                document.body.classList.add('sidebar-collapsed');
                document.getElementById('sidebar').classList.add('collapsed');
            }
        </script>
        <div class="main-sidebar-inner">
        <div class="sidebar-brand uhco-logo">
            <img src="/assets/images/uh-primary-college-of-optometry-horizontal.webp" alt="College of Optometry" class="img-fluid">
        </div>
        <div class="sidebar-brand uh-logo">
            <img src="/assets/images/uh.png" alt="University of Houston" class="img-fluid">
        </div>

        <ul class="nav flex-column sidebar-nav">
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/dashboard.cfm">
                    <i class="bi bi-speedometer2 sidebar-icon"></i>
                    <span class="sidebar-label">Dashboard</span>
                </a>
            </li>
            <cfif NOT structKeyExists(request, "_sectionStatusConfigLoaded")>
                <cfinclude template="/admin/settings/feature-gates.cfm">
                <cfinclude template="/admin/settings/section-status-config.cfm">
            </cfif>
            <cfinclude template="/admin/settings/sidebar-registry.cfm">
            <cfset alphaNavItems = []>
            <cfloop array="#request._sidebarNavRegistry#" index="navItem">
                <cfset canSee = NOT len(navItem.permission)>
                <cfif NOT canSee>
                    <cfif find("|", navItem.permission)>
                        <cfset canSee = request.hasAnyPermission(listToArray(navItem.permission, "|"))>
                    <cfelse>
                        <cfset canSee = request.hasPermission(navItem.permission)>
                    </cfif>
                </cfif>
                <cfif canSee>
                    <cfset itemStatus = len(navItem.sectionKey) ? getSettingsSectionStatus(navItem.sectionKey) : "">
                    <cfif itemStatus EQ "Alpha">
                        <cfset arrayAppend(alphaNavItems, navItem)>
                    <cfelseif itemStatus NEQ "Disabled">
                        <li class="nav-item">
                            <a class="nav-link" href="#request.webRoot##navItem.href#">
                                <i class="bi #navItem.icon# sidebar-icon"></i>
                                <span class="sidebar-label">#encodeForHTML(navItem.label)#</span>
                            </a>
                        </li>
                    </cfif>
                </cfif>
            </cfloop>
            <li class="nav-item">
                <a href='/admin/users/search_UH_API.cfm' class='nav-link'>
                    <i class='bi bi-search sidebar-icon'></i><span class="sidebar-label">Search UH API</span>
                </a>
            </li>
            <li class="nav-item">
                <a href='/admin/users/search_UH_LDAP.cfm' class='nav-link'>
                    <i class='bi bi-person-vcard sidebar-icon'></i><span class="sidebar-label">Search UH LDAP</span>
                </a>
            </li>
            <cfif arrayLen(alphaNavItems) AND request.isSuperAdmin()>
                <li class="nav-item sidebar-section-divider">
                    <span class="sidebar-section-label">Alpha</span>
                </li>
                <cfloop array="#alphaNavItems#" index="alphaItem">
                <li class="nav-item">
                    <a class="nav-link" href="#request.webRoot##alphaItem.href#">
                        <i class="bi #alphaItem.icon# sidebar-icon"></i>
                        <span class="sidebar-label">#encodeForHTML(alphaItem.label)#</span>
                    </a>
                </li>
                </cfloop>
            </cfif>
            
        </ul>
            <cfif request.hasPermission("settings.view")
                OR request.isSuperAdmin()
                OR request.hasAnyPermission([
                "settings.media_config.manage",
                "settings.api.manage",
                "settings.bulk_exclusions.manage",
                "settings.scheduled_tasks.manage",
                "settings.workflows.manage",
                "settings.user_permissions.manage",
                "flags.manage",
                "orgs.manage",
                "external_ids.manage"
            ])>
            <div class="sidebar-footer">
                <a href="#request.webRoot#/admin/settings/" class="settings settings-btn" title="Settings" id="settingsGear">
                    <span class="settings-icon-wrap">
                        <i class="bi bi-gear-fill sidebar-icon"></i>
                        <cfif NOT request.isProduction>
                            <span class="settings-environment-indicator" aria-hidden="true"></span>
                        </cfif>
                    </span>
                    <span class="sidebar-label">Settings</span>
                </a>
            </div>
            </cfif>
        </div>
    </nav>
    </cfoutput>
    
    

    <!-- Main Content wrapper — offset for fixed sidebar -->
        <div class="mainContainer main-content d-flex<cfif NOT showGlobalAdminToolbar> no-global-admin-toolbar</cfif>" id="mainContent">
    
    <cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
        // Sync main content offset immediately to prevent layout shift
        if (localStorage.getItem('sidebarCollapsed') === 'true') {
            document.body.classList.add('sidebar-collapsed');
            document.getElementById('mainContent').classList.add('sidebar-collapsed');
        }
    </script>
    <cfset normalizedContentWrapperClass = trim(contentWrapperClass ?: "")>

    <cfset currentAdminUser = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {}>
    <cfset currentUserDisplayName = encodeForHTML(trim(currentAdminUser.displayName ?: "Admin User"))>
    <cfset currentUserEmail = encodeForHTML(trim(currentAdminUser.email ?: ""))>
    <cfset currentUserUsername = encodeForHTML(trim(currentAdminUser.username ?: ""))>
    <cfset currentUserRoleLabel = "">
    <cfset currentUserImageSrc = "">
    <cfset impersonationState = {}>
    <cfset currentRequestUrl = cgi.script_name & (len(trim(cgi.query_string ?: "")) ? "?" & cgi.query_string : "")>
    <cfset toolbarTitle = "Admin">
    <cfset toolbarIconClass = "bi-grid-1x2-fill">

    <cfif structKeyExists(currentAdminUser, "roles") AND isArray(currentAdminUser.roles) AND arrayLen(currentAdminUser.roles)>
        <cfset currentUserRoleLabel = encodeForHTML(replace(currentAdminUser.roles[1], "_", " ", "all"))>
    </cfif>

    <cfif structKeyExists(currentAdminUser, "image")>
        <cfset currentUserImageSrc = trim(currentAdminUser.image ?: "")>
    </cfif>
    <cfif NOT len(currentUserImageSrc) AND structKeyExists(currentAdminUser, "avatar")>
        <cfset currentUserImageSrc = trim(currentAdminUser.avatar ?: "")>
    </cfif>
    <cfif NOT len(currentUserImageSrc)>
        <cfset currentUserImageSrc = request.webRoot & "/assets/images/uh.png">
    </cfif>

    <cfif structKeyExists(application, "authService") AND application.authService.isImpersonating() AND application.authService.isActualSuperAdmin()>
        <cfset impersonationState = application.authService.getImpersonationState()>
    </cfif>

    <cfif structKeyExists(variables, "pageTitle") AND len(trim(variables.pageTitle ?: ""))>
        <cfset toolbarTitle = trim(variables.pageTitle)>
    <cfelseif structKeyExists(cgi, "script_name")>
        <cfset normalizedScriptName = lcase(replace(cgi.script_name ?: "", "\", "/", "all"))>
        <cfif findNoCase("/admin/dashboard", normalizedScriptName)>
            <cfset toolbarTitle = "Dashboard">
            <cfset toolbarIconClass = "bi-speedometer2">
        <cfelseif findNoCase("/admin/statistics/", normalizedScriptName)>
            <cfset toolbarTitle = "Statistics">
            <cfset toolbarIconClass = "bi-bar-chart-fill">
        <cfelseif findNoCase("/admin/user-review/", normalizedScriptName)>
            <cfset toolbarTitle = "User Review">
            <cfset toolbarIconClass = "bi-person-lines-fill">
        <cfelseif findNoCase("/admin/migrations/", normalizedScriptName)>
            <cfset toolbarTitle = "Migrations">
            <cfset toolbarIconClass = "bi-mortarboard">
        <cfelseif findNoCase("/admin/rosters/", normalizedScriptName)>
            <cfset toolbarTitle = "Rosters">
            <cfset toolbarIconClass = "bi-card-image">
        <cfelseif findNoCase("/admin/import/", normalizedScriptName)>
            <cfset toolbarTitle = "Import Data">
            <cfset toolbarIconClass = "bi-upload">
        <cfelseif findNoCase("/admin/query-builder/", normalizedScriptName)>
            <cfset toolbarTitle = "Query Builder">
            <cfset toolbarIconClass = "bi-database">
        <cfelseif findNoCase("/admin/settings/flags/", normalizedScriptName)>
            <cfset toolbarTitle = "Manage Flags">
            <cfset toolbarIconClass = "bi-flag-fill">
        <cfelseif findNoCase("/admin/settings/orgs/", normalizedScriptName)>
            <cfset toolbarTitle = "Manage Organizations">
            <cfset toolbarIconClass = "bi-building-fill">
        <cfelseif findNoCase("/admin/settings/external/", normalizedScriptName)>
            <cfset toolbarTitle = "Manage External IDs">
            <cfset toolbarIconClass = "bi-person-bounding-box">
        <cfelseif findNoCase("/admin/settings/", normalizedScriptName)>
            <cfset toolbarTitle = "Settings">
            <cfset toolbarIconClass = "bi-gear-fill">
        <cfelseif findNoCase("/admin/user-media/", normalizedScriptName)>
            <cfset toolbarTitle = "User Media">
            <cfset toolbarIconClass = "bi-collection-fill">
        <cfelseif findNoCase("/admin/users/search_uh_api.cfm", normalizedScriptName)>
            <cfset toolbarTitle = "Search UH API">
            <cfset toolbarIconClass = "bi-search">
        <cfelseif findNoCase("/admin/users/search_uh_ldap.cfm", normalizedScriptName)>
            <cfset toolbarTitle = "Search UH LDAP">
            <cfset toolbarIconClass = "bi-person-vcard">
        <cfelseif findNoCase("/admin/reporting/", normalizedScriptName)>
            <cfset toolbarTitle = "Reporting">
            <cfset toolbarIconClass = "bi-bar-chart-line-fill">
        <cfelse>
            <cfset scriptParts = listToArray(reReplace(normalizedScriptName, "^/+|/+$", "", "all"), "/")>
            <cfif arrayLen(scriptParts) GTE 2>
                <cfset candidateTitle = scriptParts[arrayLen(scriptParts)]>
                <cfif compareNoCase(candidateTitle, "index.cfm") EQ 0 AND arrayLen(scriptParts) GTE 3>
                    <cfset candidateTitle = scriptParts[arrayLen(scriptParts) - 1]>
                <cfelse>
                    <cfset candidateTitle = listFirst(candidateTitle, ".")>
                </cfif>
                <cfset candidateTitle = reReplace(candidateTitle, "[-_]+", " ", "all")>
                <cfif len(candidateTitle)>
                    <cfset toolbarTitle = uCase(left(candidateTitle, 1)) & mid(candidateTitle, 2, len(candidateTitle))>
                </cfif>
            </cfif>
        </cfif>
    </cfif>

    <cfset toolbarTitle = encodeForHTML(toolbarTitle)>

    <main class="portal-main flex-fill <cfif isSettingsSection> admin-main-settings</cfif>" style="min-width:0;">
        <cfif showGlobalAdminToolbar>
            <cfoutput>
            <header class="portal-header border-bottom admin-global-toolbar" data-toolbar-title="#encodeForHTMLAttribute(toolbarTitle)#">
                <nav class="navbar navbar-expand-lg py-2">
                    <div class="container-fluid users-list-toolbar-shell">
                        <div class="users-list-toolbar-primary">
                            <button class="btn btn-sm btn-ui-cancel me-2 admin-sidebar-toggle" id="sidebarToggle" type="button" title="Toggle Sidebar" aria-label="Toggle Sidebar">
                                <i class="bi bi-list"></i>
                            </button>
                            <span class="users-list-toolbar-brand">UHCO_Identity</span>
                            <div class="admin-toolbar-title d-none d-md-inline-flex align-items-center gap-2">
                                <i class="bi #encodeForHTMLAttribute(toolbarIconClass)#"></i>
                                <span>#toolbarTitle#</span>
                            </div>
                        </div>
                        <ul class="navbar-nav d-flex flex-row align-items-center gap-2 ms-auto users-list-toolbar-nav">
                        <li class="nav-item dropdown ms-3 users-list-toolbar-account">
                            <a class="nav-link dropdown-toggle p-0 d-flex align-items-center gap-2 text-dark" href="##" role="button" data-bs-toggle="dropdown" aria-expanded="false" aria-label="User menu">
                                <img src="#encodeForHTMLAttribute(currentUserImageSrc)#" alt="Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#" class="rounded-circle users-list-toolbar-avatar admin-toolbar-avatar">
                                <span class="d-none d-lg-inline small">#currentUserDisplayName#</span>
                            </a>
                            <div class="dropdown-menu dropdown-menu-end p-3 users-list-toolbar-dropdown" style="min-width: 320px;">
                                <div class="d-flex align-items-center gap-3 mb-3 users-list-toolbar-account-header">
                                    <img src="#encodeForHTMLAttribute(currentUserImageSrc)#" alt="Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#" class="users-list-toolbar-avatar rounded-circle">
                                    <div class="users-list-toolbar-account-meta">
                                        <h6 class="mb-1">#currentUserDisplayName#</h6>
                                        #len(currentUserEmail) ? "<div class='small text-muted'>" & currentUserEmail & "</div>" : ""#
                                        #len(currentUserUsername) ? "<div class='small text-muted'>@" & currentUserUsername & "</div>" : ""#
                                    </div>
                                </div>
                                #len(currentUserRoleLabel) ? "<div class='bg-light p-2 rounded mb-3'><small class='d-block text-uppercase fw-bold text-muted users-list-toolbar-label'>Role</small><span class='badge text-bg-primary'>" & currentUserRoleLabel & "</span></div>" : ""#
                                #structCount(impersonationState) ? "<div class='users-list-toolbar-impersonation alert alert-warning mb-3 py-2 px-3'><div class='small fw-semibold text-uppercase mb-1'>Impersonation Active</div><div class='small mb-2'>You are currently using <strong>" & encodeForHTML(impersonationState.label ?: "") & "</strong>.</div><form method='post' action='" & request.webRoot & "/admin/settings/admin-users/save.cfm' class='mb-0'><input type='hidden' name='action' value='clearImpersonation'><input type='hidden' name='returnURL' value='" & encodeForHTMLAttribute(currentRequestUrl) & "'><button type='submit' class='btn btn-sm btn-ui-warning w-100'><i class='bi bi-x-octagon me-1'></i>Stop Impersonating</button></form></div>" : ""#
                                <div class="d-grid">
                                    <a href="#request.webRoot#/admin/logout.cfm" class="btn btn-sm btn-ui-go"><i class="bi bi-box-arrow-right me-1"></i>Logout</a>
                                </div>
                            </div>
                        </li>
                    </ul>
                    </div>
                </nav>
            </header>
            </cfoutput>
        </cfif>
        <cfif len(normalizedContentWrapperClass)>
            <cfoutput><div class="#encodeForHTMLAttribute(normalizedContentWrapperClass)# admin-toolbar-content-root">#content#</div></cfoutput>
        <cfelse>
            <cfoutput><div class="admin-toolbar-content-root">#content#</div></cfoutput>
        </cfif>
    </main>

    <cfif CGI.SCRIPT_NAME CONTAINS "/admin/users/edit.cfm">
        <div class="viewbar p-3 d-none">
            <cfoutput>
                #ViewContent#
            </cfoutput>
        </div>
    </cfif>
    </div><!--- /.main-content d-flex --->
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI" crossorigin="anonymous"></script>
<script src="/assets/js/admin/admin-ui.js"></script>

<cfif structKeyExists(variables, "pageScripts")>
    <cfoutput>#pageScripts#</cfoutput>
</cfif>

<cfif structKeyExists(variables, "wsChannel") AND len(trim(variables.wsChannel))>
<cftry>
<cfwebsocket name="#trim(structKeyExists(variables,'wsName') ? variables.wsName : 'appWS')#"
             onMessage="#trim(structKeyExists(variables,'wsOnMessage') ? variables.wsOnMessage : '')#"
             onOpen="#trim(structKeyExists(variables,'wsOnOpen') ? variables.wsOnOpen : '')#"
             onClose="#trim(structKeyExists(variables,'wsOnClose') ? variables.wsOnClose : '')#"
             onError="#trim(structKeyExists(variables,'wsOnError') ? variables.wsOnError : '')#"
             subscribeTo="#trim(variables.wsChannel)#">
<cfcatch type="any">
<cfoutput>
<script>
(function(){
    var el = document.getElementById('wsStatus');
    if (el) {
        el.className = 'badge bg-warning text-dark';
        el.textContent = 'CF WS error: #jsStringFormat(cfcatch.message)#';
    }
    console.error('cfwebsocket failed:', '#jsStringFormat(cfcatch.type)#', '#jsStringFormat(cfcatch.message)#');
})();
</script>
</cfoutput>
</cfcatch>
</cftry>
</cfif>

</body>
</html>
