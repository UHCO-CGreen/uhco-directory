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

        // Web root prefix: empty for local dev, "/UHCOidentity" for IIS sub-app
        //application.webRoot = "";
        //application.webRoot = "/UHCOidentity";
        if (CGI.HTTP_HOST == "127.0.0.1" || CGI.HTTP_HOST == "localhost") {
            application.webRoot = "";
        } else {
            application.webRoot = "";
        }

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
        } else {
            request.context    = "admin";
            request.datasource = application.datasources.admin;

            // Expose role-check helpers on every admin request
            request.hasRole    = application.authService.hasRole;
            request.hasAnyRole = application.authService.hasAnyRole;

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

        return true;
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