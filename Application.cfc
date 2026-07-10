component output="false" {

    this.name              = "UHCOidentity";
    this.sessionManagement = true;
    this.sessionTimeout    = createTimeSpan(0, 8, 0, 0);
    this.setClientCookies  = true;
    this.sessionCookie.disableUpdate = false;
    this.sessionCookie.httpOnly = true;
    this.sessionCookie.sameSite = "Lax";
    this.showDebugOutput   = false;
    this.postParametersLimit = 10000;

    // ── Custom Java dependencies ─────────────────────────────────────────
    // libphonenumber (international phone parsing/validation/formatting) —
    // self-contained jar in this app's own /lib, not the shared CF server lib.
    this.javaSettings = {
        loadPaths               : [ getDirectoryFromPath(getCurrentTemplatePath()) & "lib" ],
        loadColdFusionClassPath : false,
        reloadOnChange          : false
    };

    // ── Component & template mappings ──────────────────────────────────
    // These let existing createObject("component","cfc.*") / "dao.*" and
    // cfinclude template="/includes/*" calls work without any code changes.
    this.mappings["/cfc"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "model/services";
    this.mappings["/dao"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "model/dao";
    this.mappings["/includes"] = getDirectoryFromPath(getCurrentTemplatePath()) & "model/includes";

    // ── WebSocket channels ─────────────────────────────────────────────
    // authEvents: real-time auth event feed for the admin observability dashboard.
    // Browser connects directly to ws://hostname:8585 (Use Proxy: NOT checked).
    this.wschannels = [
        { name: "authEvents" }
    ];

    // ── Application start ──────────────────────────────────────────────
    public boolean function onApplicationStart() {

        // Per-context datasources — selected in onRequestStart()
        application.datasources = {
            admin : "UHCO_Identity_Admin"
        };

        application.webRoot = "";

        // Temporary feature flag: keep Windows SSO code in place but disabled
        // until production Windows Authentication installation is complete.
        application.flags = {
            windowsSSOEnabled : false
        };

        // Admin auth service (singleton)
        application.authService = new admin.AuthService();
        application.userReviewAuthService = createObject("component", "cfc.UserReviewAuthService").init();
        application.adminAuthorizationPolicyService = createObject("component", "cfc.adminAuthorizationPolicy_service").init();
        application.runtimeSecretPolicyService = createObject("component", "cfc.runtimeSecretPolicy_service").init();
        application.authAuditService    = createObject("component", "cfc.authAudit_service").init();
        application.adminSessionsDAO    = createObject("component", "dao.adminSessions_DAO").init();
        application.adminSectionsDAO    = createObject("component", "dao.adminSections_DAO").init();

        // Change log service — initialized separately so any failure here never blocks app startup
        try {
            application.changeLogSvc = createObject("component", "cfc.changeLog_service").init();
        } catch (any e) {
            application.changeLogSvc = "";  // signals "unavailable" without crashing
            cflog(
                file = "uhco_ident_errors",
                type = "error",
                text = "changeLog_service init FAILED: #e.message# | #e.detail# | type=#e.type#"
            );
        }

        // Backward-compatible UH API credentials now sourced through the runtime secret boundary.
        var uhApiCredentials = application.runtimeSecretPolicyService.getUHApiCredentials();
        application.uhApiToken = uhApiCredentials.token;
        application.uhApiSecret = uhApiCredentials.secret;
        application.runtimeSecretPolicyWarningLogged = false;

        return true;
    }

    // ── Request start ──────────────────────────────────────────────────
    public boolean function onRequestStart(required string targetPage) {

        // Reinitialize application if requested.
        // ?reinit=true  — re-runs onApplicationStart() (services, config)
        // ?reinit=full  — full application stop; next request re-reads this.wschannels
        //                 and re-registers WebSocket channels (required after adding wschannels)
        if (structKeyExists(url, "reinit") AND url.reinit EQ "true") {
            onApplicationStart();
        } else if (structKeyExists(url, "reinit") AND url.reinit EQ "full") {
            applicationStop();
            location(listFirst(cgi.script_name, "?"), false);
            return false;
        }

        // Safety: ensure onApplicationStart() has run (and services are available)
        if (
            !structKeyExists(application, "datasources")
            OR !isStruct(application.datasources)
            OR !structKeyExists(application.datasources, "admin")
            OR !structKeyExists(application, "authService")
            OR !isObject(application.authService)
            OR !structKeyExists(application, "userReviewAuthService")
            OR !isObject(application.userReviewAuthService)
            OR !structKeyExists(application, "adminAuthorizationPolicyService")
            OR !isObject(application.adminAuthorizationPolicyService)
            OR !structKeyExists(application, "runtimeSecretPolicyService")
            OR !isObject(application.runtimeSecretPolicyService)
            OR !structKeyExists(application, "authAuditService")
            OR !isObject(application.authAuditService)
            OR !structKeyExists(application, "adminSessionsDAO")
            OR !isObject(application.adminSessionsDAO)
            OR !structKeyExists(application, "adminSectionsDAO")
            OR !isObject(application.adminSectionsDAO)
        ) {
            onApplicationStart();
        }

        if (
            !structKeyExists(application, "adminAuthorizationPolicyService")
            OR !isObject(application.adminAuthorizationPolicyService)
            OR !structKeyExists(application.adminAuthorizationPolicyService, "filterAccessibleUsers")
            OR !structKeyExists(application.adminAuthorizationPolicyService, "canCurrentAdminManageTestUsers")
        ) {
            application.adminAuthorizationPolicyService = createObject("component", "cfc.adminAuthorizationPolicy_service").init();
        }

        request.webRoot = application.webRoot;
        request.environmentName = _getEnvironmentName();
        request.siteBaseUrl = _getRequestBaseUrl();
        request.isProduction = (request.environmentName EQ "production");
        request.runtimeSecretPolicy = application.runtimeSecretPolicyService;
        request.runtimeSecretHealth = application.runtimeSecretPolicyService.getHealthStatus(request.environmentName);
        request.runtimeSecretPolicyReady = request.runtimeSecretHealth.ready;
        _logRuntimeSecretPolicyHealth(request.runtimeSecretHealth);
        _applySessionCookiePolicy();
        _setSecurityHeaders();

        var path = lCase(arguments.targetPage);

        // ── Determine request context ──────────────────────────────────
        if (findNoCase("/userreview/", path) EQ 1) {
            request.context    = "userreview";
            request.datasource = application.datasources.admin;
            request.userReviewAuth = application.userReviewAuthService;

            var publicUserReviewPages = [
                "/userreview/login.cfm",
                "/userreview/authenticate.cfm",
                "/userreview/logout.cfm"
            ];

            var isUserReviewPublicPage = arrayFind(publicUserReviewPages, path);

            if (NOT isUserReviewPublicPage AND NOT request.userReviewAuth.isLoggedIn()) {
                location(application.webRoot & "/UserReview/login.cfm", false);
            }

            if (request.userReviewAuth.isLoggedIn()) {
                request.userReviewUser = request.userReviewAuth.getSessionUser();
            }
        } else {
            request.context    = "admin";
            request.datasource = application.datasources.admin;
            request.windowsSSOEnabled = structKeyExists(application, "flags")
                AND structKeyExists(application.flags, "windowsSSOEnabled")
                AND application.flags.windowsSSOEnabled;

            // Expose role-check helpers on every admin request
            request.hasRole = function(required string roleName) {
                return application.authService.hasRole(arguments.roleName);
            };
            request.hasAnyRole = function(required array roleNames) {
                return application.authService.hasAnyRole(arguments.roleNames);
            };
            request.hasPermission = function(required string permissionKey) {
                return application.authService.hasPermission(arguments.permissionKey);
            };
            request.hasAnyPermission = function(required array permissionKeys) {
                return application.authService.hasAnyPermission(arguments.permissionKeys);
            };
            request.isActualSuperAdmin = function() {
                return application.authService.isActualSuperAdmin();
            };
            request.isImpersonating = function() {
                return application.authService.isImpersonating();
            };
            // True only when the real identity is super admin AND not currently impersonating.
            // Use this for sections that should be invisible/inaccessible during impersonation.
            request.isSuperAdmin = function() {
                return application.authService.isActualSuperAdmin() AND NOT application.authService.isImpersonating();
            };
            request.canManageTestUsers = function() {
                return application.adminAuthorizationPolicyService.canCurrentAdminManageTestUsers();
            };
            request.canCreateUsers = function() {
                return application.adminAuthorizationPolicyService.canCurrentAdminCreateUsers();
            };
            request.shouldExcludeTestUsers = function() {
                return application.adminAuthorizationPolicyService.shouldExcludeTestUsers();
            };
            request.canAccessUserFlags = function(required array userFlags) {
                return application.adminAuthorizationPolicyService.canCurrentAdminAccessUserFlags(arguments.userFlags);
            };
            request.canAccessUser = function(required array userFlags, array userOrganizations=[]) {
                return application.adminAuthorizationPolicyService.canCurrentAdminAccessUser(arguments.userFlags, arguments.userOrganizations);
            };
            request.canAccessUserProfile = function(required struct profile) {
                return application.adminAuthorizationPolicyService.canCurrentAdminAccessUserProfile(arguments.profile);
            };
            request.canAccessUserByID = function(required numeric userID) {
                return application.adminAuthorizationPolicyService.canCurrentAdminAccessUserID(arguments.userID);
            };

            var publicPages = [
                "/admin/login.cfm",
                "/admin/authenticate.cfm",
                "/admin/logout.cfm",
                "/admin/myuhco-login.cfm"
            ];
            var isAsyncRequest = _isAsyncErrorRequest();
            var isAdminPage = (path CONTAINS "/admin/");
            var isPublicPage = arrayFind(publicPages, path);
            var adminViewBypassPages = [
                "/admin/unauthorized.cfm",
                "/admin/settings/admin-users/save.cfm"
            ];
            var scheduledRunnerBypassPages = [
                "/admin/reporting/run_data_quality_report.cfm",
                "/admin/reporting/run_duplicate_users_report.cfm",
                "/admin/reporting/run_uh_sync_report.cfm",
                "/admin/migrations/run_grad_migration.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_bulk_exclusions_task.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_dashboard_stale_media_snapshot.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_dashboard_stale_users_snapshot.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_dashboard_unpublished_variants_snapshot.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_data_quality_report_task.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_duplicate_users_report_task.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_grad_migration_task.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_hometown_sync.cfm",
                "/admin/settings/scheduled-tasks/tasks/run_uh_sync_report_task.cfm"
            ];
            var windowsAuthPages = [];
            var bypassAdminViewGate = false;
            var asyncFailurePayload = structNew("ordered");
            var isScheduledRunnerRequest = false;

            if (request.windowsSSOEnabled) {
                arrayAppend(publicPages, "/admin/auth_windows_probe.cfm");
                arrayAppend(publicPages, "/admin/auth_windows_start.cfm");
                arrayAppend(publicPages, "/admin/auth_windows_callback.cfm");

                windowsAuthPages = [
                    "/admin/auth_windows_probe.cfm",
                    "/admin/auth_windows_start.cfm",
                    "/admin/auth_windows_callback.cfm"
                ];
            }

            isPublicPage = arrayFind(publicPages, path);
            isScheduledRunnerRequest = (
                (structKeyExists(url, "triggeredBy") AND lCase(trim(url.triggeredBy ?: "")) EQ "scheduled")
                OR (structKeyExists(form, "triggeredBy") AND lCase(trim(form.triggeredBy ?: "")) EQ "scheduled")
            ) AND arrayFind(scheduledRunnerBypassPages, path) GT 0;

            // Expose change log source context so changeLog_service can detect scheduled tasks
            request.changeLogSource   = isScheduledRunnerRequest ? "scheduled_task" : "admin";
            request.changeLogTaskName = isScheduledRunnerRequest ? listLast(path, "/") : "";

            bypassAdminViewGate = arrayFind(adminViewBypassPages, path) GT 0
                OR arrayFind(windowsAuthPages, path) GT 0
                OR isScheduledRunnerRequest;

            if (isAdminPage AND NOT isPublicPage) {
                if (!application.authService.isLoggedIn() AND !isScheduledRunnerRequest) {
                    if (isAsyncRequest) {
                        asyncFailurePayload["success"] = false;
                        asyncFailurePayload["message"] = "Your admin session has expired. Sign in again.";
                        asyncFailurePayload["reason"] = "session_expired";
                        asyncFailurePayload["redirectURL"] = application.webRoot & "/admin/login.cfm";

                        cfsetting(showDebugOutput = "false");
                        cfheader(statusCode = "401");
                        cfcontent(type = "application/json; charset=utf-8", reset = "true");
                        writeOutput(serializeJSON(asyncFailurePayload));
                        return false;
                    }

                    location(application.webRoot & "/admin/login.cfm", false);
                }

                // ── Force-logout check + throttled last-activity update ──────
                // Runs only when the user IS logged in (redirect above didn't fire).
                if (application.authService.isLoggedIn()
                    AND structKeyExists(session, "user")
                    AND val(session.user.adminUserID ?: 0)
                    AND !isScheduledRunnerRequest
                ) {
                    try {
                        if (application.adminSessionsDAO.checkForceLogout(val(session.user.adminUserID))) {
                            // Close DB rows, clear the in-memory session, redirect.
                            application.adminSessionsDAO.closeSessionsForUser(val(session.user.adminUserID));
                            structDelete(session, "user");
                            sessionInvalidate();
                            location(application.webRoot & "/admin/login.cfm?error=force_logout", false);
                            return false;
                        }
                        // Throttled LastActivity update — at most once per 60 seconds per session.
                        if (NOT structKeyExists(session, "_lastActTs")
                            OR dateDiff("s", session._lastActTs, now()) GT 60
                        ) {
                            application.adminSessionsDAO.updateLastActivity(
                                val(session.user.adminUserID),
                                left(trim(cgi.script_name & ""), 500)
                            );
                            session._lastActTs = now();
                        }
                    } catch (any ignore) {}
                }

                if (!request.hasPermission("admin.view") AND !bypassAdminViewGate) {
                    if (isAsyncRequest) {
                        asyncFailurePayload["success"] = false;
                        asyncFailurePayload["message"] = "You are not authorized for this action.";
                        asyncFailurePayload["reason"] = "unauthorized";
                        asyncFailurePayload["redirectURL"] = application.webRoot & "/admin/unauthorized.cfm";

                        cfsetting(showDebugOutput = "false");
                        cfheader(statusCode = "403");
                        cfcontent(type = "application/json; charset=utf-8", reset = "true");
                        writeOutput(serializeJSON(asyncFailurePayload));
                        return false;
                    }

                    location(application.webRoot & "/admin/unauthorized.cfm", false);
                }

                request.adminCsrfToken = _ensureAdminCsrfToken();

                if (_isAdminStateChangingRequest(path, isPublicPage, isScheduledRunnerRequest) AND NOT _isValidAdminCsrfToken()) {
                    if (isAsyncRequest) {
                        asyncFailurePayload["success"] = false;
                        asyncFailurePayload["message"] = "Security validation failed. Refresh the page and try again.";
                        asyncFailurePayload["reason"] = "csrf_invalid";

                        cfsetting(showDebugOutput = "false");
                        cfheader(statusCode = "403");
                        cfcontent(type = "application/json; charset=utf-8", reset = "true");
                        writeOutput(serializeJSON(asyncFailurePayload));
                    } else {
                        cfheader(statusCode = "403");
                        writeOutput("<h2>Security Validation Failed</h2><p>" & encodeForHTML("Security validation failed. Refresh the page and try again.") & "</p>");
                    }

                    return false;
                }
            }
        }

        return true;
    }

    private void function _applySessionCookiePolicy() {
        this.sessionCookie.secure = request.isProduction;
    }

    private void function _setSecurityHeaders() {
        var isHTTPS = (
            (structKeyExists(cgi, "https") AND lCase(trim(cgi.https)) EQ "on")
            OR (structKeyExists(cgi, "server_port_secure") AND val(cgi.server_port_secure) EQ 1)
            OR (structKeyExists(cgi, "http_x_forwarded_proto") AND listFirst(cgi.http_x_forwarded_proto, ",") EQ "https")
        );

        if (request.isProduction AND isHTTPS) {
            cfheader(name="Strict-Transport-Security", value="max-age=31536000; includeSubDomains");
        }

        // Set X-Frame-Options for all paths except /modules/, which must be embeddable
        // by external signage/wallboard systems. CSP frame-ancestors handles modern browsers;
        // this header covers legacy fallback.
        if (findNoCase("/modules/", cgi.script_name) EQ 0) {
            cfheader(name="X-Frame-Options", value="DENY");
        }

        // The observability dashboard uses cfwebsocket, which generates un-nonced inline
        // scripts and connects to ws://hostname:8585 (a different port from 'self').
        // Relax script-src and connect-src for that page only.
        local.isWsPage = findNoCase("/admin/settings/observability/", cgi.script_name) GT 0;

        if (local.isWsPage) {
            request.cspNonce  = "";
            local.scriptSrc  = "'self' 'unsafe-inline' https://cdn.jsdelivr.net";
            local.connectSrc = "'self' ws: wss: https://cdn.jsdelivr.net";
        } else {
            request.cspNonce  = toBase64(generateSecretKey("AES", 128));
            local.scriptSrc  = "'self' 'nonce-" & request.cspNonce & "' https://cdn.jsdelivr.net";
            local.connectSrc = "'self' https://cdn.jsdelivr.net";
        }

        local.frameAncestors = (findNoCase("/modules/", cgi.script_name) GT 0) ? "frame-ancestors https: file:" : "frame-ancestors 'self'";
        local.imgSrc         = "img-src 'self' data: https:" & (request.isProduction ? "" : " http:");

        local.directives = [
            "default-src 'self'",
            "script-src "  & local.scriptSrc,
            "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net",
            local.imgSrc,
            "font-src 'self'",
            "connect-src " & local.connectSrc,
            local.frameAncestors,
            "form-action 'self'",
            "base-uri 'self'",
            "object-src 'none'"
        ];

        if (request.isProduction) {
            arrayAppend(local.directives, "upgrade-insecure-requests");
        }

        cfheader(name="Content-Security-Policy", value=arrayToList(local.directives, "; "));
    }

    private void function _logRuntimeSecretPolicyHealth(required struct healthStatus) {
        if (
            arguments.healthStatus.ready
            OR (structKeyExists(application, "runtimeSecretPolicyWarningLogged") AND application.runtimeSecretPolicyWarningLogged)
        ) {
            return;
        }

        cflog(
            file = "uhco_ident",
            type = "warning",
            text = "Runtime secret policy is not ready for #arguments.healthStatus.environmentName#: #arrayToList(arguments.healthStatus.missing)#"
        );
        application.runtimeSecretPolicyWarningLogged = true;
    }

    private string function _getEnvironmentName() {
        var rawHttpHost = trim(cgi.http_host ?: "");
        var rawServerName = trim(cgi.server_name ?: "");
        var localHosts = "127.0.0.1,localhost,uhco-identity.local";

        var httpHost = lCase(listFirst(rawHttpHost, ":"));
        var serverName = lCase(listFirst(rawServerName, ":"));

        // IIS host header and server name can differ; treat either local alias as local.
        if (
            !len(httpHost)
            AND !len(serverName)
        ) {
            return "local";
        }

        if ( listFindNoCase(localHosts, httpHost) OR listFindNoCase(localHosts, serverName) ) {
            return "local";
        }

        return "production";
    }

    private string function _getRequestBaseUrl() {
        var scheme = "http";
        var host = trim(cgi.http_host ?: cgi.server_name ?: "127.0.0.1");

        if (
            (structKeyExists(cgi, "https") AND lCase(trim(cgi.https)) EQ "on")
            OR (structKeyExists(cgi, "server_port_secure") AND val(cgi.server_port_secure) EQ 1)
            OR (structKeyExists(cgi, "http_x_forwarded_proto") AND listFirst(cgi.http_x_forwarded_proto, ",") EQ "https")
        ) {
            scheme = "https";
        }

        return scheme & "://" & host;
    }

    private boolean function _isAsyncErrorRequest() {
        var requestedWith = lCase(trim(cgi.http_x_requested_with ?: ""));
        var acceptHeader = lCase(trim(cgi.http_accept ?: ""));

        if (requestedWith EQ "xmlhttprequest") {
            return true;
        }

        if (findNoCase("application/json", acceptHeader) GT 0) {
            return true;
        }

        if (
            (structKeyExists(url, "format") AND lCase(trim(url.format ?: "")) EQ "json")
            OR (structKeyExists(form, "format") AND lCase(trim(form.format ?: "")) EQ "json")
            OR structKeyExists(url, "ajax")
            OR structKeyExists(form, "ajax")
        ) {
            return true;
        }

        return false;
    }

    private string function _ensureAdminCsrfToken() {
        if (
            NOT structKeyExists(session, "adminCsrfToken")
            OR NOT len(trim(session.adminCsrfToken ?: ""))
        ) {
            session.adminCsrfToken = lCase(hash(createUUID() & now() & randRange(100000, 999999) & getTickCount(), "SHA-256"));
        }

        return session.adminCsrfToken;
    }

    private boolean function _isAdminStateChangingRequest(
        required string path,
        boolean isPublicPage = false,
        boolean isScheduledRunnerRequest = false
    ) {
        var requestMethod = lCase(trim(cgi.request_method ?: "get"));

        if (arguments.isPublicPage OR arguments.isScheduledRunnerRequest) {
            return false;
        }

        if (findNoCase("/admin/", arguments.path) NEQ 1) {
            return false;
        }

        return listFindNoCase("post,put,patch,delete", requestMethod) GT 0;
    }

    private boolean function _isValidAdminCsrfToken() {
        var expectedToken = _ensureAdminCsrfToken();
        var providedToken = trim(cgi.http_x_csrf_token ?: "");

        if (NOT len(providedToken) AND structKeyExists(form, "_csrf")) {
            providedToken = trim(form._csrf ?: "");
        }
        if (NOT len(providedToken) AND structKeyExists(form, "csrfToken")) {
            providedToken = trim(form.csrfToken ?: "");
        }

        return len(providedToken) AND providedToken EQ expectedToken;
    }

    private void function _logUnhandledException(required any exception, required string eventName) {
        var parts = [
            "Unhandled application error",
            "event=" & trim(arguments.eventName ?: "")
        ];

        if (structKeyExists(request, "context") AND len(trim(request.context ?: ""))) {
            arrayAppend(parts, "context=" & trim(request.context));
        }
        if (structKeyExists(cgi, "script_name") AND len(trim(cgi.script_name ?: ""))) {
            arrayAppend(parts, "path=" & trim(cgi.script_name));
        }
        if (structKeyExists(arguments.exception, "message") AND len(trim(arguments.exception.message ?: ""))) {
            arrayAppend(parts, "message=" & trim(arguments.exception.message));
        }
        if (structKeyExists(arguments.exception, "detail") AND len(trim(arguments.exception.detail ?: ""))) {
            arrayAppend(parts, "detail=" & trim(arguments.exception.detail));
        }
        if (structKeyExists(arguments.exception, "type") AND len(trim(arguments.exception.type ?: ""))) {
            arrayAppend(parts, "type=" & trim(arguments.exception.type));
        }
        if (structKeyExists(arguments.exception, "tagContext") AND isArray(arguments.exception.tagContext) AND arrayLen(arguments.exception.tagContext)) {
            arrayAppend(parts, "tag=" & (arguments.exception.tagContext[1].template ?: "") & ":" & (arguments.exception.tagContext[1].line ?: ""));
        }

        cflog(
            file = "uhco_ident_errors",
            type = "error",
            text = arrayToList(parts, " | ")
        );
    }

    // ── Error handling ─────────────────────────────────────────────────
    public void function onError(required any exception, required string eventName) {
        var isProduction = structKeyExists(request, "isProduction") AND request.isProduction;
        var isAsyncRequest = _isAsyncErrorRequest();
        var genericMessage = "An unexpected error occurred. Please try again or contact support if the problem continues.";
        var payload = structNew("ordered");

        payload["success"] = false;
        payload["message"] = genericMessage;

        _logUnhandledException(arguments.exception, arguments.eventName);

        cfheader(statusCode = "500");

        if (isAsyncRequest) {
            cfsetting(showDebugOutput = "false");
            cfheader(name = "Content-Type", value = "application/json; charset=utf-8");
            if (NOT isProduction) {
                payload["detail"] = trim(arguments.exception.detail ?: "");
                payload["type"] = trim(arguments.exception.type ?: "");
                payload["error"] = trim(arguments.exception.message ?: "Unknown error");
                if (structKeyExists(arguments.exception, "tagContext") AND isArray(arguments.exception.tagContext) AND arrayLen(arguments.exception.tagContext)) {
                    payload["file"] = trim(arguments.exception.tagContext[1].template ?: "");
                    payload["line"] = val(arguments.exception.tagContext[1].line ?: 0);
                }
            }
            writeOutput(serializeJSON(payload));
            abort;
        }

        if (isProduction) {
            writeOutput("<h2>Application Error</h2>");
            writeOutput("<p>" & encodeForHTML(genericMessage) & "</p>");
            abort;
        }

        writeOutput("<h2>Error: " & encodeForHTML(arguments.exception.message) & "</h2>");
        writeOutput("<p><strong>Detail:</strong> " & encodeForHTML(arguments.exception.detail ?: "") & "</p>");
        writeOutput("<p><strong>Type:</strong> " & encodeForHTML(arguments.exception.type ?: "") & "</p>");
        if (structKeyExists(arguments.exception, "tagContext") AND isArray(arguments.exception.tagContext) AND arrayLen(arguments.exception.tagContext)) {
            writeOutput("<p><strong>File:</strong> " & encodeForHTML(arguments.exception.tagContext[1].template) & " line " & arguments.exception.tagContext[1].line & "</p>");
        }
        writeDump(var = arguments.exception, label = "Exception Detail");
    }

}