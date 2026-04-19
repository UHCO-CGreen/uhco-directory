component output="false" {

    this.name              = "UHCOidentity";
    this.sessionManagement = true;
    this.sessionTimeout    = createTimeSpan(0, 8, 0, 0);
    this.setClientCookies  = true;
    this.showDebugOutput   = false;
    this.postParametersLimit = 10000;

    // ── Component & template mappings ──────────────────────────────────
    // These let existing createObject("component","cfc.*") / "dao.*" and
    // cfinclude template="/includes/*" calls work without any code changes.
    this.mappings["/cfc"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "model/services";
    this.mappings["/dao"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "model/dao";
    this.mappings["/includes"] = getDirectoryFromPath(getCurrentTemplatePath()) & "model/includes";

    // ── Application start ──────────────────────────────────────────────
    public boolean function onApplicationStart() {

        // Per-context datasources — selected in onRequestStart()
        application.datasources = {
            api   : "UHCO_Identity_API",
            admin : "UHCO_Identity_Admin"
        };

        application.webRoot = "";

        // UH API credentials
        application.uhApiToken  = "";
        application.uhApiSecret = "";
        if (
            structKeyExists(server, "system")
            AND structKeyExists(server.system, "environment")
        ) {
            if (structKeyExists(server.system.environment, "UH_API_TOKEN")) {
                application.uhApiToken = trim(server.system.environment["UH_API_TOKEN"]);
            }
            if (structKeyExists(server.system.environment, "UH_API_SECRET")) {
                application.uhApiSecret = trim(server.system.environment["UH_API_SECRET"]);
            }
        }

        // Admin auth service (singleton)
        application.authService = new admin.AuthService();
        application.userReviewAuthService = createObject("component", "cfc.UserReviewAuthService").init();

        return true;
    }

    // ── Request start ──────────────────────────────────────────────────
    public boolean function onRequestStart(required string targetPage) {

        // Reinitialize application if requested
        if (structKeyExists(url, "reinit") AND url.reinit EQ "true") {
            onApplicationStart();
        }

        // Safety: ensure onApplicationStart() has run
        if (!structKeyExists(application, "datasources")) {
            onApplicationStart();
        }

        var path = lCase(arguments.targetPage);

        // ── Determine request context ──────────────────────────────────
        if (findNoCase("/api/", path) EQ 1) {
            request.context    = "api";
            request.datasource = application.datasources.api;

            // API: no debug output, no session cookies
            cfsetting(showDebugOutput = false);
        } else if (findNoCase("/userreview/", path) EQ 1) {
            request.context    = "userreview";
            request.datasource = application.datasources.admin;
            request.userReviewAuth = application.userReviewAuthService;

            var publicUserReviewPages = [
                "/userreview/login.cfm",
                "/userreview/authenticate.cfm",
                "/userreview/logout.cfm"
            ];

            var isUserReviewPublicPage = arrayFind(publicUserReviewPages, path);

            if (NOT isUserReviewPublicPage AND NOT application.userReviewAuthService.isLoggedIn()) {
                location(application.webRoot & "/UserReview/login.cfm", false);
            }

            if (application.userReviewAuthService.isLoggedIn()) {
                request.userReviewUser = application.userReviewAuthService.getSessionUser();
            }
        } else {
            request.context    = "admin";
            request.datasource = application.datasources.admin;

            // Expose role-check helpers on every admin request
            request.hasRole    = application.authService.hasRole;
            request.hasAnyRole = application.authService.hasAnyRole;
            request.hasPermission = application.authService.hasPermission;
            request.hasAnyPermission = application.authService.hasAnyPermission;
            request.isActualSuperAdmin = application.authService.isActualSuperAdmin;
            request.isImpersonating = application.authService.isImpersonating;

            // ── Admin authentication ───────────────────────────────────
            var publicPages = [
                "/admin/login.cfm",
                "/admin/authenticate.cfm",
                "/admin/logout.cfm"
            ];

            var isAdminPage  = (path CONTAINS "/admin/");
            var isPublicPage = arrayFind(publicPages, path);

            if (isAdminPage AND NOT isPublicPage) {
                if (!application.authService.isLoggedIn()) {
                    location(application.webRoot & "/admin/login.cfm", false);
                }
            }
        }

        // Always available on every request
        request.webRoot = application.webRoot;
        request.environmentName = _getEnvironmentName();
        request.siteBaseUrl = _getRequestBaseUrl();
        request.isProduction = (request.environmentName EQ "production");

        return true;
    }

    private string function _getEnvironmentName() {
        var host = lCase(trim(cgi.http_host ?: cgi.server_name ?: ""));

        if ( !len(host) ) {
            return "local";
        }

        host = listFirst(host, ":");

        if ( listFindNoCase("127.0.0.1,localhost", host) ) {
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

    // ── Error handling ─────────────────────────────────────────────────
    public void function onError(required any exception, required string eventName) {
        // API: return JSON error
        if (structKeyExists(request, "context") AND request.context EQ "api") {
            cfheader(statusCode = "500");
            cfheader(name = "Content-Type", value = "application/json; charset=utf-8");
            writeOutput(serializeJSON({ "error": "Internal server error" }));
            abort;
        }

        // Admin: display the error (re-throwing from onError produces a bare 500)
        cfheader(statusCode = "500");
        writeOutput("<h2>Error: " & encodeForHTML(arguments.exception.message) & "</h2>");
        writeOutput("<p><strong>Detail:</strong> " & encodeForHTML(arguments.exception.detail ?: "") & "</p>");
        writeOutput("<p><strong>Type:</strong> " & encodeForHTML(arguments.exception.type ?: "") & "</p>");
        if (structKeyExists(arguments.exception, "tagContext") AND isArray(arguments.exception.tagContext) AND arrayLen(arguments.exception.tagContext)) {
            writeOutput("<p><strong>File:</strong> " & encodeForHTML(arguments.exception.tagContext[1].template) & " line " & arguments.exception.tagContext[1].line & "</p>");
        }
        writeDump(var = arguments.exception, label = "Exception Detail");
    }

}