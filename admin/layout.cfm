<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>UHCO Directory Admin</title>

    <!-- Bootstrap 5.3 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">

    <style>
        body { background:#f8f9fa; }
        
        .sidebar {
            width: 260px;
            background: #212529;
            color: #fff;
            min-height: 100vh;
            transition: width 0.3s ease;
            overflow: hidden;
        }
        
        .sidebar.collapsed {
            width: 80px;
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
        
        .sidebar a.active {
            background-color: #0d6efd;
            color: #fff;
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
    </style>
</head>

<body>
<div class="d-flex">
    <!-- Sidebar -->
    <nav class="sidebar p-3" id="sidebar">
        <script>
            // Apply collapsed state immediately to prevent flicker
            if (localStorage.getItem('sidebarCollapsed') === 'true') {
                document.getElementById('sidebar').classList.add('collapsed');
            }
        </script>
        <div class="sidebar-header">
            <h4 class="sidebar-title text-white mb-0">UHCO Admin</h4>
            <button class="sidebar-toggle" id="sidebarToggle" title="Toggle Sidebar">
                <i class="bi bi-chevron-left"></i>
            </button>
        </div>

        <ul class="nav flex-column sidebar-nav">
            <li class="nav-item">
                <a class="nav-link" href="/dir/admin/dashboard.cfm">
                    <i class="bi bi-speedometer2 sidebar-icon"></i>
                    <span class="sidebar-label">Dashboard</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="#"
                   id="usersToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleUsers(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-people sidebar-icon"></i>
                        <span class="sidebar-label">Users</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-label" id="usersChevron" style="font-size:12px;transition:transform 0.2s;"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="usersSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/index.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">All Users</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/faculty.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">Faculty</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/staff.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">Staff</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/current_students.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">Current Students</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/alumni.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">Alumni</span>
                        </a>
                    </li>
                </ul>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="/dir/admin/flags/index.cfm">
                    <i class="bi bi-flag sidebar-icon"></i>
                    <span class="sidebar-label">Flags</span>
                </a>
            </li>
            
            
            
            <li class="nav-item">
                <a class="nav-link" href="/dir/admin/orgs/index.cfm">
                    <i class="bi bi-building sidebar-icon"></i>
                    <span class="sidebar-label">Organizations</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="/dir/admin/external/index.cfm">
                    <i class="bi bi-gear sidebar-icon"></i>
                    <span class="sidebar-label">External IDs</span>
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="#"
                   id="apiToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleAPI(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-braces sidebar-icon"></i>
                        <span class="sidebar-label">API</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-label" id="apiChevron" style="font-size:12px;transition:transform 0.2s;"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="apiSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/tokens/index.cfm">
                            <i class="bi bi-key sidebar-icon"></i>
                            <span class="sidebar-label">Tokens</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/secrets/index.cfm">
                            <i class="bi bi-shield-lock sidebar-icon"></i>
                            <span class="sidebar-label">Secrets</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/api/docs.html" target="_blank">
                            <i class="bi bi-book sidebar-icon"></i>
                            <span class="sidebar-label">Documentation</span>
                        </a>
                    </li>
                </ul>
            </li>
           <!--- <li class="nav-item">
                <a class="nav-link" href="/dir/admin/access/index.cfm">
                    <i class="bi bi-lock sidebar-icon"></i>
                    <span class="sidebar-label">Access Areas</span>
                </a>
            </li>
            
            --->

            <li class="nav-item">
                <a class="nav-link d-flex align-items-center justify-content-between" href="#"
                   id="reportingToggle"
                   role="button"
                   aria-expanded="false"
                   onclick="toggleReporting(event)">
                    <span class="d-flex align-items-center gap-3">
                        <i class="bi bi-graph-up sidebar-icon"></i>
                        <span class="sidebar-label">Development</span>
                    </span>
                    <i class="bi bi-chevron-down sidebar-label" id="reportingChevron" style="font-size:12px;transition:transform 0.2s;"></i>
                </a>
                <ul class="nav flex-column ms-1 mt-1 sidebar-nav" id="reportingSubmenu" style="display:none;">
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/uh_people_import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">UH Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/users/uh_people_db_not_in_api.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">DB vs API Compare</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/reporting/cs-migration.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Migration &amp; Compare</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/reporting/pull_API_students.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">Pull API Students</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/reporting/CS-bulk-import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Bulk Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/reporting/CS-alumni-bulk-import.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">CS Alumni Import</span>
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/dir/admin/reporting/OD-student-audit.cfm">
                            <i class="bi bi-arrow-right-short sidebar-icon"></i>
                            <span class="sidebar-label">OD Student Audit</span>
                        </a>
                    </li>
                </ul>
            </li>
        </ul>
    </nav>

    <!-- Main Content -->
    <main class="flex-fill p-4">
        <cfoutput>#content#</cfoutput>
    </main>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI" crossorigin="anonymous"></script>

<script>
    function toggleUsers(e) {
        e.preventDefault();
        const submenu = document.getElementById('usersSubmenu');
        const chevron  = document.getElementById('usersChevron');
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
            '/dir/admin/users/index.cfm',
            '/dir/admin/users/faculty.cfm',
            '/dir/admin/users/staff.cfm',
            '/dir/admin/users/current_students.cfm',
            '/dir/admin/users/alumni.cfm',
            '/dir/admin/users/students.cfm',
            '/dir/admin/users/new.cfm',
            '/dir/admin/users/edit.cfm',
            '/dir/admin/users/view.cfm',
            '/dir/admin/users/deleteconfirm.cfm'
        ];
        if (usersPages.some(p => window.location.pathname.toLowerCase().startsWith(p))) {
            const usersSubmenu = document.getElementById('usersSubmenu');
            const usersChevron = document.getElementById('usersChevron');
            if (usersSubmenu) { usersSubmenu.style.display = 'block'; }
            if (usersChevron) { usersChevron.style.transform = 'rotate(180deg)'; }
        }

        // Auto-expand API submenu when a child page is active
        const apiPages = [
            '/dir/admin/tokens/',
            '/dir/admin/secrets/'
        ];
        if (apiPages.some(p => window.location.pathname.toLowerCase().startsWith(p))) {
            const apiSubmenu = document.getElementById('apiSubmenu');
            const apiChevron = document.getElementById('apiChevron');
            if (apiSubmenu) { apiSubmenu.style.display = 'block'; }
            if (apiChevron) { apiChevron.style.transform = 'rotate(180deg)'; }
        }

        // Auto-expand Reporting submenu when a child page is active
        const reportingPages = [
            '/dir/admin/users/uh_people_import.cfm',
            '/dir/admin/users/uh_people_db_not_in_api.cfm',
            '/dir/admin/reporting/cs-migration.cfm',
            '/dir/admin/reporting/pull_api_students.cfm',
            '/dir/admin/reporting/cs-bulk-import.cfm',
            '/dir/admin/reporting/cs-alumni-bulk-import.cfm',
            '/dir/admin/reporting/od-student-audit.cfm'
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
        
        // Toggle sidebar on button click
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('collapsed');
            const nowCollapsed = sidebar.classList.contains('collapsed');
            localStorage.setItem('sidebarCollapsed', nowCollapsed);
            
            // Update icon
            if (nowCollapsed) {
                toggleIcon.classList.remove('bi-chevron-left');
                toggleIcon.classList.add('bi-chevron-right');
            } else {
                toggleIcon.classList.remove('bi-chevron-right');
                toggleIcon.classList.add('bi-chevron-left');
            }
        });
        
        // Mark active link based on current page
        const currentPage = window.location.pathname;
        const navLinks = document.querySelectorAll('.sidebar a');
        navLinks.forEach(link => {
            if (link.href.includes(currentPage)) {
                link.classList.add('active');
            }
        });
    });
</script>
</body>
</html>
