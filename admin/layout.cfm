<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>UHCO ident Admin</title>

    <!-- Bootstrap 5.3 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">

    <style>
        body { background:#f8f9fa; }
        
        .sidebar {
            width: 260px;
            flex-shrink: 0;
            background: #212529;
            color: #fff;
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            z-index: 1030;
            transition: width 0.3s ease;
            overflow-x: hidden;
            overflow-y: auto;
            display: flex;
            flex-direction: column;
        }
        
        .sidebar.collapsed {
            width: 80px;
        }

        /* Offset main content to account for fixed sidebar */
        .main-content {
            margin-left: 260px;
            transition: margin-left 0.3s ease;
        }
        .main-content.sidebar-collapsed {
            margin-left: 80px;
        }
        
        .sidebar a {
            color: #adb5bd;
            text-decoration: none;
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 15px;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        
        .sidebar a:hover {
            background-color: rgba(255, 255, 255, 0.1);
            color: #fff;
        }

        .sidebar a:focus,
        .sidebar a:focus-visible,
        .sidebar a:focus-within,
        .sidebar .nav-link:focus,
        .sidebar .nav-link:focus-visible {
            outline: none;
            box-shadow: none;
            border-color: transparent;
            background-color: rgba(255, 255, 255, 0.1);
            color: #fff;
        }
        
        .sidebar a.settings {
            color: #adb5bd;
            text-decoration: none;
            padding: 10px;
            border-radius: 5px;
            transition: all 0.3s ease;
        }

        /* Top-level active nav item — highlight the entire LI so children appear grouped */
        .sidebar > ul > .nav-item.active {
            background-color: rgba(255, 255, 255, 0.1);
            border-radius: 5px;
        }

        /* Active link text styling (top-level and sub-level) */
        .sidebar .nav-item a.active {
            background-color: transparent;
            color: #f0d878;
            font-weight: 700;
        }
        
        .sidebar.collapsed a {
            justify-content: center;
            padding: 12px;
        }
        
        .sidebar-label {
            white-space: nowrap;
            flex: 1;
        }
        
        .sidebar.collapsed .sidebar-label {
            display: none;
        }
        
        .sidebar-chevron {
            font-size: 12px;
            transition: transform 0.2s;
            margin-left: auto;
        }
        
        .sidebar.collapsed .sidebar-chevron {
            display: none;
        }

        /* Collapsed: hide user info, center settings, hide logout text */
        .sidebar.collapsed .user {
            display: none;
        }
        .sidebar.collapsed .settings {
            width: 100%;
            text-align: center;
        }
        .sidebar.collapsed .logout a {
            padding: 0.375rem;
            width: auto;
        }
        .sidebar.collapsed .logout span {
            display: none;
        }
        .sidebar.collapsed .logout .bi {
            margin-right: 0 !important;
        }
        
        .sidebar-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
            padding-right: 5px;
        }
        
        .sidebar-title {
            white-space: nowrap;
            transition: opacity 0.3s ease;
        }
        
        .sidebar.collapsed .sidebar-title {
            display: none;
        }
        
        .sidebar-toggle {
            background: none;
            border: none;
            color: #adb5bd;
            cursor: pointer;
            font-size: 20px;
            padding: 5px;
            display: flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        
        .sidebar-toggle:hover {
            background-color: rgba(255, 255, 255, 0.1);
            color: #fff;
        }
        
        .sidebar-icon {
            min-width: 24px;
            width: 24px;
            text-align: center;
        }
        
        .sidebar-nav {
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .viewbar{
            width: 460px;
            flex-shrink: 0;
            background: #efefef;
            color: #54585a;
            min-height: 100vh;
            transition: width 0.3s ease;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }

        .cfdebug {
            max-width: 100%;
            overflow: auto;
            margin-left: 280px;
        }

        .environment-toast {
            position: fixed;
            right: 1rem;
            bottom: 1rem;
            z-index: 1085;
        }
    </style>
</head>

<body>
<div>
    <!-- Sidebar -->
    <cfoutput>
    <nav class="sidebar p-3" id="sidebar">
        <script>
            // Apply collapsed state immediately to prevent flicker
            if (localStorage.getItem('sidebarCollapsed') === 'true') {
                document.getElementById('sidebar').classList.add('collapsed');
            }
        </script>
        <div class="sidebar-header">
            <h4 class="sidebar-title text-white mb-0">UHCO_<em>Ident</em></h4>
            <button class="sidebar-toggle" id="sidebarToggle" title="Toggle Sidebar">
                <i class="bi bi-chevron-left"></i>
            </button>
        </div>
        
        <ul class="nav flex-column sidebar-nav">
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/dashboard.cfm">
                    <i class="bi bi-speedometer2 sidebar-icon"></i>
                    <span class="sidebar-label">Dashboard</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="##"
                   id="usersToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleUsers(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-people-fill sidebar-icon"></i>
                        <span class="sidebar-label">Users</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-chevron" id="usersChevron"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="usersSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=problems">
                            <i class="bi bi-exclamation-triangle sidebar-icon"></i>
                            <span class="sidebar-label">Problem Records</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=faculty">
                            <i class="bi bi-people-fill sidebar-icon"></i>
                            <span class="sidebar-label">Faculty</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=staff">
                            <i class="bi bi-people-fill sidebar-icon"></i>
                            <span class="sidebar-label">Staff</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=current-students">
                            <i class="bi bi-people-fill sidebar-icon"></i>
                            <span class="sidebar-label">Current Students</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=alumni">
                            <i class="bi bi-mortarboard sidebar-icon"></i>
                            <span class="sidebar-label">Alumni</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=inactive">
                            <i class="bi bi-person-dash sidebar-icon"></i>
                            <span class="sidebar-label">Inactive Records</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=all">
                            <i class="bi bi-list sidebar-icon"></i>
                            <span class="sidebar-label">All Records</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/search_UH_API.cfm">
                            <i class="bi bi-search sidebar-icon"></i>
                            <span class="sidebar-label">Search UH API</span>
                        </a>
                    </li>
                </ul>
            </li>
            <cfif request.hasRole("USER_MEDIA_ADMIN") or request.hasRole("SUPER_ADMIN")>
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/user-media/index.cfm">
                    <i class="bi bi-collection-fill sidebar-icon"></i>
                    <span class="sidebar-label">User Media</span>
                </a>
            </li>
            </cfif>
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/flags/index.cfm">
                    <i class="bi bi-flag-fill sidebar-icon"></i>
                    <span class="sidebar-label">Flags</span>
                </a>
            </li>
            
            
            
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/orgs/index.cfm">
                    <i class="bi bi-building-fill sidebar-icon"></i>
                    <span class="sidebar-label">Organizations</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/external/index.cfm">
                    <i class="bi bi-person-bounding-box sidebar-icon"></i>
                    <span class="sidebar-label">External IDs</span>
                </a>
            </li>
            <!---<li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="#"
                   id="apiToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleAPI(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-braces sidebar-icon"></i>
                        <span class="sidebar-label">UHCO API</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-chevron" id="apiChevron"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="apiSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/settings/uhco-api/tokens/index.cfm">
                            <i class="bi bi-key sidebar-icon"></i>
                            <span class="sidebar-label">Tokens</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/settings/uhco-api/secrets/index.cfm">
                            <i class="bi bi-shield-lock sidebar-icon"></i>
                            <span class="sidebar-label">Secrets</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/api/docs.html" target="_blank">
                            <i class="bi bi-book sidebar-icon"></i>
                            <span class="sidebar-label">Documentation</span>
                        </a>
                    </li>
                </ul>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#request.webRoot#/admin/access/index.cfm">
                    <i class="bi bi-lock sidebar-icon"></i>
                    <span class="sidebar-label">Access Areas</span>
                </a>
            </li>
            
            

            <li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="#"
                   id="reportingToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleReporting(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-database-fill-gear sidebar-icon"></i>
                        <span class="sidebar-label">SQL</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-chevron" id="reportingChevron"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="reportingSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/uh_people_import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">UH Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/users/uh_people_db_not_in_api.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">DB vs API Compare</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/reporting/OLD/cs-migration.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Migration &amp; Compare</span>
                        </a>
                    </li>
                    
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/reporting/OLD/CS-bulk-import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Bulk Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/reporting/OLD/CS-alumni-bulk-import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Alumni Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#request.webRoot#/admin/reporting/OLD/OD-student-audit.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">OD Student Audit</span>
                        </a>
                    </li>
                </ul>
            </li>--->
        </ul>
            <!-- User Info & Logout at Bottom -->
            <cfif structKeyExists(session, "user") and structKeyExists(session.user, "displayName")>
            <div class="mt-auto pt-3 pb-2 border-top">
                <div class="row align-items-center text-white" style="font-size:1rem;">
                    <div class="col-9 user">
                    <i class="bi bi-person-circle me-2"></i>
                    <cfoutput>#session.user.displayName#</cfoutput>
                    </div>
                    <cfif structKeyExists(session.user, "isSuperAdmin") AND session.user.isSuperAdmin>
                    <div class="col-3 justify-content-center settings">
                        <a href="#request.webRoot#/admin/settings/" class="text-white settings" title="Settings" id="settingsGear">
                        <i class="bi bi-gear-fill"></i> 
                        </a>
                    </div>
                    </cfif>
                </div>
            </div>
            <div class="d-flex justify-content-center mb-3 logout">
                <a href="#request.webRoot#/admin/logout.cfm" class="btn btn-outline-light btn-sm w-100">
                    <i class="bi bi-box-arrow-right me-1"></i> <span>Logout</span>
                </a>
            </div>
            </cfif>
    </nav>
    </cfoutput>

    <!-- Main Content wrapper — offset for fixed sidebar -->
    <div class="main-content d-flex" id="mainContent">
    <script>
        // Sync main content offset immediately to prevent layout shift
        if (localStorage.getItem('sidebarCollapsed') === 'true') {
            document.getElementById('mainContent').classList.add('sidebar-collapsed');
        }
    </script>
    <main class="flex-fill p-4" style="min-width:0; overflow-x:hidden;">
        <cfoutput>#content#</cfoutput>
        
        <cfif isDefined('url.dump')><cfdump var="#session.user#">

        <!---filter="(&(objectClass=user)(sAMAccountName=chlorens))"--->
        <cfldap 
        action="QUERY"
        name="qFindUser"
        attributes="displayName,memberOf,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title,initials"
        start="DC=cougarnet,DC=uh,DC=edu"
        scope="SUBTREE"
        maxrows="1"
        server="cougarnet.uh.edu"
        filter="(&(objectClass=user)(sAMAccountName=mcgonz24))"
        username="COUGARNET\uhcoweb"
        password="5E9##WN!ag">
        </cfldap>
         <cfldap 
        action="QUERY"
        name="qFindUser2"
        attributes="displayName,memberOf,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title,initials"
        start="DC=cougarnet,DC=uh,DC=edu"
        scope="SUBTREE"
        maxrows="1"
        server="cougarnet.uh.edu"
        filter="(&(objectClass=user)(sAMAccountName=adezzell))"
        username="COUGARNET\svc-opt-cfserv"
        password="Xu&mLtgdtKV5bQ@M">
        </cfldap>
        
        <cfdump var="#qFindUser#" label="User found with uhcoweb account">
        <cfdump var="#qFindUser2#" label="User found with svc-opt-cfserv account">
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

<cfoutput>
<div class="toast-container environment-toast">
    <div
        id="environmentToast"
        class="toast border-0 shadow-sm"
        role="status"
        aria-live="polite"
        aria-atomic="true"
        data-bs-autohide="false"
        data-environment-name="#encodeForHTMLAttribute(request.environmentName)#"
    >
        <div class="toast-header #(request.isProduction ? "text-bg-danger" : "text-bg-success")# border-0">
            <i class="bi #(request.isProduction ? "bi-broadcast-pin" : "bi-laptop")# me-2"></i>
            <strong class="me-auto">Environment</strong>
            <small>#encodeForHTML(ucase(left(request.environmentName, 1)) & mid(request.environmentName, 2, len(request.environmentName)))#</small>
            <button type="button" class="btn-close btn-close-white ms-2 mb-1" data-bs-dismiss="toast" aria-label="Close"></button>
        </div>
        <div class="toast-body bg-white">
            Current session is running in <strong>#encodeForHTML(request.environmentName)#</strong>.
        </div>
    </div>
</div>
</cfoutput>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI" crossorigin="anonymous"></script>

<cfif structKeyExists(variables, "pageScripts")>
    <cfoutput>#pageScripts#</cfoutput>
</cfif>

<cfoutput><script>const WEBROOT='#request.webRoot#';</script></cfoutput>

<script>
    function toggleUsers(e) {
        e.preventDefault();
        const submenu = document.getElementById('usersSubmenu');
        const chevron  = document.getElementById('usersChevron');
        const open     = submenu.style.display === 'block';
        submenu.style.display = open ? 'none' : 'block';
        chevron.style.transform = open ? '' : 'rotate(180deg)';
    }

    function toggleUserMedia(e) {
        e.preventDefault();
        const submenu = document.getElementById('userMediaSubmenu');
        const chevron  = document.getElementById('userMediaChevron');
        const open     = submenu.style.display === 'block';
        submenu.style.display = open ? 'none' : 'block';
        chevron.style.transform = open ? '' : 'rotate(180deg)';
    }

    function toggleAPI(e) {
        e.preventDefault();
        const submenu = document.getElementById('apiSubmenu');
        const chevron  = document.getElementById('apiChevron');
        const open     = submenu.style.display === 'block';
        submenu.style.display = open ? 'none' : 'block';
        chevron.style.transform = open ? '' : 'rotate(180deg)';
    }

    function toggleReporting(e) {
        e.preventDefault();
        const submenu  = document.getElementById('reportingSubmenu');
        const chevron  = document.getElementById('reportingChevron');
        const open     = submenu.style.display === 'block';
        submenu.style.display = open ? 'none' : 'block';
        chevron.style.transform = open ? '' : 'rotate(180deg)';
    }

    document.addEventListener('DOMContentLoaded', function() {
        // Auto-expand Users submenu when a child page is active
        const usersPages = [
            WEBROOT+'/admin/users/index.cfm',
            WEBROOT+'/admin/users/new.cfm',
            WEBROOT+'/admin/users/edit.cfm',
            WEBROOT+'/admin/users/view.cfm',
            WEBROOT+'/admin/users/deleteconfirm.cfm',
            WEBROOT+'/admin/users/search_UH_API.cfm'
        ];
        if (usersPages.some(p => window.location.pathname.toLowerCase().startsWith(p))) {
            const usersSubmenu = document.getElementById('usersSubmenu');
            const usersChevron = document.getElementById('usersChevron');
            if (usersSubmenu) { usersSubmenu.style.display = 'block'; }
            if (usersChevron) { usersChevron.style.transform = 'rotate(180deg)'; }
        }

        // Auto-expand API submenu when a child page is active
        const apiPages = [
            WEBROOT+'/admin/settings/uhco-api/tokens/',
            WEBROOT+'/admin/settings/uhco-api/secrets/'
        ];
        if (apiPages.some(p => window.location.pathname.toLowerCase().startsWith(p))) {
            const apiSubmenu = document.getElementById('apiSubmenu');
            const apiChevron = document.getElementById('apiChevron');
            if (apiSubmenu) { apiSubmenu.style.display = 'block'; }
            if (apiChevron) { apiChevron.style.transform = 'rotate(180deg)'; }
        }

        
        // Highlight settings gear when on a settings page
        if (window.location.pathname.toLowerCase().startsWith(WEBROOT+'/admin/settings/')) {
            const gear = document.getElementById('settingsGear');
            if (gear) { gear.style.color = '#f0d878'; }
        }

        // Auto-expand Reporting submenu when a child page is active
        const reportingPages = [
            WEBROOT+'/admin/users/uh_people_import.cfm',
            WEBROOT+'/admin/users/uh_people_db_not_in_api.cfm',
            WEBROOT+'/admin/reporting/OLD/cs-migration.cfm',
            WEBROOT+'/admin/reporting/OLD/cs-bulk-import.cfm',
            WEBROOT+'/admin/reporting/OLD/cs-alumni-bulk-import.cfm',
            WEBROOT+'/admin/reporting/OLD/od-student-audit.cfm'
        ];
        if (reportingPages.some(p => window.location.pathname.startsWith(p))) {
            const submenu = document.getElementById('reportingSubmenu');
            const chevron = document.getElementById('reportingChevron');
            if (submenu) { submenu.style.display = 'block'; }
            if (chevron) { chevron.style.transform = 'rotate(180deg)'; }
        }

        const sidebar = document.getElementById('sidebar');
        const sidebarToggle = document.getElementById('sidebarToggle');
        const toggleIcon = sidebarToggle.querySelector('i');
        
        // Initialize toggle icon based on current collapsed state
        if (sidebar.classList.contains('collapsed')) {
            toggleIcon.classList.remove('bi-chevron-left');
            toggleIcon.classList.add('bi-chevron-right');
        }

        const environmentToastEl = document.getElementById('environmentToast');
        if (environmentToastEl && window.bootstrap) {
            const environmentKey = 'environmentToastDismissed:' + environmentToastEl.dataset.environmentName;
            const environmentToast = bootstrap.Toast.getOrCreateInstance(environmentToastEl);

            if (!sessionStorage.getItem(environmentKey)) {
                environmentToast.show();
            }

            environmentToastEl.addEventListener('hidden.bs.toast', function() {
                sessionStorage.setItem(environmentKey, 'true');
            });
        }
        
        // Toggle sidebar on button click
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            const nowCollapsed = sidebar.classList.contains('collapsed');
            localStorage.setItem('sidebarCollapsed', nowCollapsed);

            // Sync main content offset
            const mainContent = document.getElementById('mainContent');
            if (mainContent) {
                mainContent.classList.toggle('sidebar-collapsed', nowCollapsed);
            }
            
            // Update icon
            if (nowCollapsed) {
                toggleIcon.classList.remove('bi-chevron-left');
                toggleIcon.classList.add('bi-chevron-right');
            } else {
                toggleIcon.classList.remove('bi-chevron-right');
                toggleIcon.classList.add('bi-chevron-left');
            }
        });
        
        // Mark active link and its top-level nav-item based on current page
        const currentURL  = new URL(window.location.href);
        const currentPage = currentURL.pathname.toLowerCase();
        const currentList = (currentURL.searchParams.get('list') || '').toLowerCase();

        document.querySelectorAll('.sidebar .sidebar-nav a[href]').forEach(link => {
            const rawHref = link.getAttribute('href');
            // Skip dropdown toggles (href="#")
            if (!rawHref || rawHref === '#') return;
            const linkURL  = new URL(link.href, window.location.origin);
            const linkPath = linkURL.pathname.toLowerCase();
            const linkList = (linkURL.searchParams.get('list') || '').toLowerCase();

            // Match: same path AND same list param (or both empty)
            let isActive = false;
            if (linkPath === currentPage) {
                if (linkList && currentList) {
                    isActive = (linkList === currentList);
                } else if (!linkList && !currentList) {
                    isActive = true;
                } else if (!currentList && linkList === 'problems') {
                    // Default: no ?list in URL matches the "problems" sidebar link
                    isActive = true;
                } else if (!linkList) {
                    // Links without a list param (e.g. Search UH API) match by path only
                    isActive = true;
                }
            }

            if (isActive) {
                link.classList.add('active');
                // Walk up to the top-level nav-item LI and mark it active
                let li = link.closest('.nav-item');
                while (li) {
                    const parentUl = li.parentElement;
                    const parentLi = parentUl ? parentUl.closest('.nav-item') : null;
                    if (!parentLi) {
                        // This is the top-level LI
                        li.classList.add('active');
                        break;
                    }
                    li = parentLi;
                }
            }
        });
    });
</script>
</body>
</html>
