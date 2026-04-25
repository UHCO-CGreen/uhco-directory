<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>UHCO Identity Admin</title>

    <link rel="stylesheet" href="/assets/css/admin.css">
    
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="/assets/vendor/bootstrap-icons/bootstrap-icons.css">

    <cfif structKeyExists(variables, "pageStyles")>
        <cfoutput>#pageStyles#</cfoutput>
    </cfif>
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
            <h4 class="sidebar-title text-white mb-0">UHCO_<em>Identity</em></h4>
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
                <a class="nav-link" href="#request.webRoot#/admin/users/index.cfm?list=all" id="usersToggle">
                    <i class="bi bi-people-fill sidebar-icon"></i>
                    <span class="sidebar-label">Users</span>
                </a>
            </li>
            <cfif request.hasPermission("media.view")>
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
            <li class="nav-item">
                <a href='/admin/users/search_UH_API.cfm' class='nav-link'>
                    <i class='bi bi-search me-1'></i><span class="sidebar-label">Search UH API</span>
                </a>
            </li>
            <li class="nav-item">
                <a href='/admin/users/search_UH_LDAP.cfm' class='nav-link'>
                    <i class='bi bi-person-vcard me-1'></i><span class="sidebar-label">Search UH LDAP</span>
                </a>
            </li>
        </ul>
            <cfif request.hasPermission("settings.view") OR request.hasAnyPermission([
                "settings.app_config.manage",
                "settings.media_config.manage",
                "settings.api.manage",
                "settings.admin_users.manage",
                "settings.admin_roles.manage",
                "settings.admin_permissions.manage",
                "settings.user_review.manage",
                "users.approve_user_review",
                "settings.import.manage",
                "settings.bulk_exclusions.manage",
                "settings.migrations.manage",
                "settings.uh_sync.view",
                "settings.query_builder.use",
                "settings.scheduled_tasks.manage",
                "settings.workflows.manage"
            ])>
            <div class="mt-auto pt-3 pb-1 border-top d-flex justify-content-start">
                <a href="#request.webRoot#/admin/settings/" class="text-white settings settings-btn" title="Settings" id="settingsGear">
                    <i class="bi bi-gear-fill"></i><span class="sidebar-label">Settings</span>
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
    <cfset isSettingsSection = structKeyExists(cgi, "script_name") AND findNoCase("/admin/settings/", cgi.script_name) GT 0>
    <cfparam name="contentWrapperClass" default="py-4 px-4 pt-2">
    <cfset normalizedContentWrapperClass = trim(contentWrapperClass ?: "")>

    <main class="flex-fill <cfif isSettingsSection> admin-main-settings</cfif>" style="min-width:0; overflow-x:hidden;">
        <cfif len(normalizedContentWrapperClass)>
            <cfoutput><div class="#encodeForHTMLAttribute(normalizedContentWrapperClass)#">#content#</div></cfoutput>
        <cfelse>
            <cfoutput>#content#</cfoutput>
        </cfif>
        
        <cfif isDefined('url.dump')><cfdump var="#session.user#">

       
    <cfldap 
        action="QUERY"
        name="qFindUser2"
        attributes="displayName,sAMAccountName,mail,employeeid"
        start="OU=Master Users,DC=cougarnet,DC=uh,DC=edu"
        scope="SUBTREE"
        server="cougarnet.uh.edu"
        filter="(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=amarchi2)(displayName=amarchi2)(mail=amarchi2)(userPrincipalName=amarchi2)))"
        username="COUGARNET\svc-opt-cfserv"
        password="Xu&mLtgdtKV5bQ@M">
    </cfldap>
    <cfset searchTerm = "oaborahm">
    <cfset filter = "(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=#searchTerm#)(displayName=#searchTerm#)(mail=#searchTerm#)(userPrincipalName=#searchTerm#))(|(memberOf=CN=OPT-Class2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-Class2027,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-Class2028,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-Class2029,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)))">
    <cfset attributes = "displayName,sAMAccountName,mail,employeeid">
    <cfset user = "COUGARNET\svc-opt-cfserv">
    <cfset password = "Xu&mLtgdtKV5bQ@M">
    <cfldap 
        action="QUERY"
        name="qFindUser3"
        attributes="#attributes#"
        start="OU=Master Users,DC=cougarnet,DC=uh,DC=edu"
        scope="SUBTREE"
        server="cougarnet.uh.edu"
        filter="(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=#searchTerm#)(displayName=#searchTerm#)(mail=#searchTerm#)(userPrincipalName=#searchTerm#)))"
        username="#user#"
        password="#password#">
    </cfldap>






   <!--- CN=OPT-ClassOf2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2027,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2028,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2029,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu

        CN=OPT-OPTOMETRY,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-ClassOf2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-ClassOf2027,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-ClassOf2028,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-ClassOf2029,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-Staff,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        -OPT-Faculty,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu<Br/>
        <cfdump var="#qGetGroupDN#" label="Group DNs for Optometry distribution groups">
        <cfdump var="#qFindUser#" label="User found with uhcoweb account">--->
        <cfdump var="#qFindUser2#" label="User found with svc-opt-cfserv account">
        <cfdump var="#qFindUser3#" label="User found in class of groups">
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

        // Ensure Users parent item is active for child routes that do not have direct sidebar links.
        const usersBasePath = (WEBROOT + '/admin/users/').toLowerCase();
        if (currentPage.startsWith(usersBasePath)) {
            const usersToggle = document.getElementById('usersToggle');
            if (usersToggle) {
                usersToggle.classList.add('active');
                const usersTopNavItem = usersToggle.closest('.nav-item');
                if (usersTopNavItem) {
                    usersTopNavItem.classList.add('active');
                }
            }
        }
    });
</script>
</body>
</html>
