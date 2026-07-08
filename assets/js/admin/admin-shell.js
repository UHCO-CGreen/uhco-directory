(function () {
    function getMetaContent(name) {
        var meta = document.querySelector('meta[name="' + name + '"]');
        return meta ? meta.getAttribute('content') || '' : '';
    }

    var csrfToken = getMetaContent('csrf-token');
    var webroot = getMetaContent('uhco-webroot');

    function getUrl(target) {
        try {
            return new URL(target || window.location.href, window.location.href);
        } catch (err) {
            return new URL(window.location.href);
        }
    }

    function isSameOriginTarget(target) {
        return getUrl(target).origin === window.location.origin;
    }

    function isStateChangingMethod(method) {
        var normalized = String(method || 'GET').toUpperCase();
        return normalized === 'POST' || normalized === 'PUT' || normalized === 'PATCH' || normalized === 'DELETE';
    }

    function ensureFormToken(form) {
        if (!csrfToken || !form || form.tagName !== 'FORM') {
            return;
        }

        if (!isStateChangingMethod(form.getAttribute('method') || 'GET')) {
            return;
        }

        if (!isSameOriginTarget(form.getAttribute('action') || window.location.href)) {
            return;
        }

        var existing = form.querySelector('input[name="_csrf"]');
        if (!existing) {
            existing = document.createElement('input');
            existing.type = 'hidden';
            existing.name = '_csrf';
            form.appendChild(existing);
        }

        existing.value = csrfToken;
    }

    if (csrfToken) {
        document.addEventListener('submit', function (event) {
            ensureFormToken(event.target);
        }, true);

        if (window.fetch) {
            var originalFetch = window.fetch;
            window.fetch = function (input, init) {
                var options = init ? Object.assign({}, init) : {};
                var requestUrl = (typeof input === 'string' || input instanceof URL)
                    ? input
                    : (input && input.url ? input.url : window.location.href);
                var requestMethod = options.method || (input && input.method) || 'GET';

                if (isSameOriginTarget(requestUrl)) {
                    if (typeof options.credentials === 'undefined') {
                        options.credentials = 'same-origin';
                    }

                    if (isStateChangingMethod(requestMethod)) {
                        var headers = new Headers(options.headers || (input && input.headers) || undefined);
                        if (!headers.has('X-CSRF-Token')) {
                            headers.set('X-CSRF-Token', csrfToken);
                        }
                        options.headers = headers;
                    }
                }

                return originalFetch.call(this, input, options);
            };
        }
    }

    function toggleSubmenu(event, submenuId, chevronId) {
        if (event) {
            event.preventDefault();
        }

        var submenu = document.getElementById(submenuId);
        var chevron = document.getElementById(chevronId);
        if (!submenu) {
            return;
        }

        var open = submenu.style.display === 'block';
        submenu.style.display = open ? 'none' : 'block';
        if (chevron) {
            chevron.style.transform = open ? '' : 'rotate(180deg)';
        }
    }

    window.toggleUserMedia = function (event) {
        toggleSubmenu(event, 'userMediaSubmenu', 'userMediaChevron');
    };

    window.toggleAPI = function (event) {
        toggleSubmenu(event, 'apiSubmenu', 'apiChevron');
    };

    window.toggleReporting = function (event) {
        toggleSubmenu(event, 'reportingSubmenu', 'reportingChevron');
    };

    document.addEventListener('DOMContentLoaded', function () {
        document.querySelectorAll('form').forEach(ensureFormToken);

        function syncSidebarState(collapsed) {
            document.body.classList.toggle('sidebar-collapsed', collapsed);

            var mainContent = document.getElementById('mainContent');
            if (mainContent) {
                mainContent.classList.toggle('sidebar-collapsed', collapsed);
            }
        }

        var apiPages = [
            webroot + '/admin/settings/uhco-api/tokens/',
            webroot + '/admin/settings/uhco-api/secrets/'
        ];
        if (apiPages.some(function (path) { return window.location.pathname.toLowerCase().startsWith(path.toLowerCase()); })) {
            var apiSubmenu = document.getElementById('apiSubmenu');
            var apiChevron = document.getElementById('apiChevron');
            if (apiSubmenu) { apiSubmenu.style.display = 'block'; }
            if (apiChevron) { apiChevron.style.transform = 'rotate(180deg)'; }
        }

        if (window.location.pathname.toLowerCase().startsWith((webroot + '/admin/settings/').toLowerCase())) {
            var gear = document.getElementById('settingsGear');
            if (gear) { gear.style.color = '#1f3b8a'; }
        }

        var reportingPages = [
            webroot + '/admin/reporting/OLD/cs-migration.cfm',
            webroot + '/admin/reporting/OLD/cs-bulk-import.cfm',
            webroot + '/admin/reporting/OLD/cs-alumni-bulk-import.cfm',
            webroot + '/admin/reporting/OLD/od-student-audit.cfm'
        ];
        if (reportingPages.some(function (path) { return window.location.pathname.startsWith(path); })) {
            var reportingSubmenu = document.getElementById('reportingSubmenu');
            var reportingChevron = document.getElementById('reportingChevron');
            if (reportingSubmenu) { reportingSubmenu.style.display = 'block'; }
            if (reportingChevron) { reportingChevron.style.transform = 'rotate(180deg)'; }
        }

        var sidebar = document.getElementById('sidebar');
        var sidebarToggle = document.getElementById('sidebarToggle');
        if (sidebar && sidebar.classList.contains('collapsed')) {
            syncSidebarState(true);
        }

        var globalToolbar = document.querySelector('.admin-global-toolbar[data-toolbar-title]');
        var toolbarContentRoot = document.querySelector('.admin-toolbar-content-root');
        if (globalToolbar && toolbarContentRoot) {
            var normalizeTitle = function (text) {
                return (text || '')
                    .toLowerCase()
                    .replace(/\s+/g, ' ')
                    .replace(/[^a-z0-9 ]/g, '')
                    .trim();
            };

            var toolbarTitle = normalizeTitle(globalToolbar.getAttribute('data-toolbar-title'));
            var firstHeading = toolbarContentRoot.querySelector('h1');
            var currentPath = (window.location.pathname || '').toLowerCase();
            var forceHideDuplicateTitle = currentPath.includes('/admin/settings/flags/')
                || currentPath.includes('/admin/settings/orgs/')
                || currentPath.includes('/admin/settings/external/');

            if (firstHeading) {
                var headingTitle = normalizeTitle(firstHeading.textContent);
                var fuzzyMatch = headingTitle === toolbarTitle
                    || headingTitle.startsWith(toolbarTitle)
                    || toolbarTitle.startsWith(headingTitle)
                    || (toolbarTitle === 'flags' && headingTitle.includes('flag'))
                    || (toolbarTitle === 'organizations' && headingTitle.includes('org'))
                    || (toolbarTitle === 'external ids' && headingTitle.includes('external'));

                if (forceHideDuplicateTitle || fuzzyMatch) {
                    firstHeading.classList.add('d-none');
                }
            }
        }

        if (sidebarToggle) {
            sidebarToggle.addEventListener('click', function () {
                if (window.innerWidth <= 991) {
                    document.body.classList.toggle('sidebar-open');
                    return;
                }

                if (sidebar) {
                    sidebar.classList.toggle('collapsed');
                }

                var nowCollapsed = sidebar ? sidebar.classList.contains('collapsed') : false;
                localStorage.setItem('sidebarCollapsed', nowCollapsed);
                syncSidebarState(nowCollapsed);
            });
        }

        var currentURL = new URL(window.location.href);
        var currentPage = currentURL.pathname.toLowerCase();
        var currentList = (currentURL.searchParams.get('list') || '').toLowerCase();

        document.querySelectorAll('#sidebar .sidebar-nav a[href]').forEach(function (link) {
            var rawHref = link.getAttribute('href');
            if (!rawHref || rawHref === '#') {
                return;
            }

            var linkURL = new URL(link.href, window.location.origin);
            var linkPath = linkURL.pathname.toLowerCase();
            var linkList = (linkURL.searchParams.get('list') || '').toLowerCase();
            var isActive = false;

            if (linkPath === currentPage) {
                if (linkList && currentList) {
                    isActive = linkList === currentList;
                } else if (!linkList && !currentList) {
                    isActive = true;
                } else if (!currentList && linkList === 'problems') {
                    isActive = true;
                } else if (!linkList) {
                    isActive = true;
                }
            }

            if (isActive) {
                link.classList.add('active');
                var navItem = link.closest('.nav-item');
                while (navItem) {
                    var parentList = navItem.parentElement;
                    var parentItem = parentList ? parentList.closest('.nav-item') : null;
                    if (!parentItem) {
                        navItem.classList.add('active');
                        break;
                    }
                    navItem = parentItem;
                }
            }
        });

        var usersBasePath = (webroot + '/admin/users/').toLowerCase();
        if (currentPage.startsWith(usersBasePath)) {
            var usersToggle = document.getElementById('usersToggle');
            if (usersToggle) {
                usersToggle.classList.add('active');
                var usersTopNavItem = usersToggle.closest('.nav-item');
                if (usersTopNavItem) {
                    usersTopNavItem.classList.add('active');
                }
            }
        }
    });

    // ── Delegated security handlers (Phase 2 — removes need for unsafe-inline) ──

    // data-confirm on <form> — intercept submit in capture phase
    document.addEventListener('submit', function (e) {
        var msg = e.target.dataset.confirm;
        if (msg && !confirm(msg)) { e.preventDefault(); }
    }, true);

    document.addEventListener('click', function (e) {
        // data-confirm on buttons / links (not forms — forms handled by submit listener)
        var confirmEl = e.target.closest('[data-confirm]');
        if (confirmEl && confirmEl.tagName !== 'FORM') {
            if (!confirm(confirmEl.dataset.confirm)) {
                e.preventDefault();
                e.stopPropagation();
                return;
            }
        }

        // data-clipboard-source — copy value from an element identified by ID
        var clipSrcEl = e.target.closest('[data-clipboard-source]');
        if (clipSrcEl && navigator.clipboard) {
            var src = document.getElementById(clipSrcEl.dataset.clipboardSource);
            if (src) {
                var text = (src.value !== undefined) ? src.value : src.textContent;
                var origHtml = clipSrcEl.innerHTML;
                navigator.clipboard.writeText(text).then(function () {
                    clipSrcEl.textContent = 'Copied!';
                    setTimeout(function () { clipSrcEl.innerHTML = origHtml; }, 2000);
                }).catch(function () {});
            }
            return;
        }

        // data-clipboard-text — copy the literal attribute value
        var clipTxtEl = e.target.closest('[data-clipboard-text]');
        if (clipTxtEl && navigator.clipboard) {
            var origHtml2 = clipTxtEl.innerHTML;
            navigator.clipboard.writeText(clipTxtEl.dataset.clipboardText).then(function () {
                clipTxtEl.textContent = 'Copied!';
                setTimeout(function () { clipTxtEl.innerHTML = origHtml2; }, 2000);
            }).catch(function () {});
            return;
        }

        // data-stop-propagation — replaces onclick="event.stopPropagation()"
        if (e.target.closest('[data-stop-propagation]')) {
            e.stopPropagation();
        }

        // data-require-review-note — validate review note textarea before form submits
        var reviewEl = e.target.closest('[data-require-review-note]');
        if (reviewEl) {
            var rnForm = reviewEl.form || reviewEl.closest('form');
            var note = rnForm ? rnForm.querySelector('[name="reviewNote"]') : null;
            if (note && !String(note.value || '').trim().length) {
                e.preventDefault();
                alert('A reason for rejection is required.');
                note.focus();
            }
        }

        // data-confirm-delete-id + data-confirm-delete-pattern — Bootstrap modal delete trigger
        var delEl = e.target.closest('[data-confirm-delete-id]');
        if (delEl) {
            var idInput = document.getElementById('deleteID');
            var nameEl  = document.getElementById('deletePatternName');
            if (idInput) { idInput.value = delEl.dataset.confirmDeleteId; }
            if (nameEl)  { nameEl.textContent = delEl.dataset.confirmDeletePattern || ''; }
            var modalEl = document.getElementById('deleteModal');
            if (modalEl && window.bootstrap) { new bootstrap.Modal(modalEl).show(); }
        }
    });

    document.addEventListener('change', function (e) {
        // data-navigate-on-change — select navigates to a URL when value changes
        var navEl = e.target.closest('[data-navigate-on-change]');
        if (navEl) {
            var base  = navEl.dataset.navigateBase  || window.location.pathname;
            var param = navEl.dataset.navigateParam || '';
            var val   = navEl.value;
            window.location.href = val
                ? base + '?' + encodeURIComponent(param) + '=' + encodeURIComponent(val)
                : base;
            return;
        }

        // data-toggle-panel — checkbox shows/hides a panel div by ID
        var toggleEl = e.target.closest('[data-toggle-panel]');
        if (toggleEl) {
            var panel = document.getElementById(toggleEl.dataset.togglePanel);
            if (panel) { panel.style.display = toggleEl.checked ? 'block' : 'none'; }
        }
    });
})();