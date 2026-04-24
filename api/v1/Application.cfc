component output="false" {

    this.name              = "UHCOidentity_API";
    this.sessionManagement = false;   // stateless — no session cookies
    this.setClientCookies  = false;
    this.showDebugOutput   = false;

    // ── Component & template mappings ──────────────────────────────────
    this.mappings["/cfc"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "..\..\model\services";
    this.mappings["/dao"]      = getDirectoryFromPath(getCurrentTemplatePath()) & "..\..\model\dao";
    this.mappings["/includes"] = getDirectoryFromPath(getCurrentTemplatePath()) & "..\..\model\includes";

    // ── Application start ──────────────────────────────────────────────
    public boolean function onApplicationStart() {

        application.datasource = "UHCO_Identity_API";

        // BaseDAO.init() references application.datasources.admin as a fallback;
        // populate it here so DAO instantiation doesn't error in the API app scope.
        application.datasources = {
            api   : "UHCO_Identity_API",
            admin : "UHCO_Identity_API"
        };

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

        return true;
    }

    // ── Request start ──────────────────────────────────────────────────
    public boolean function onRequestStart(required string targetPage) {

        // Reinitialize application scope if requested (admin use only)
        if (structKeyExists(url, "reinit") AND url.reinit EQ "true") {
            onApplicationStart();
        }

        // Safety: ensure onApplicationStart() has run
        if (!structKeyExists(application, "datasource")) {
            onApplicationStart();
        }

        cfsetting(showDebugOutput = false);

        // ── CORS handling ──────────────────────────────────────────────
        var headers = getHttpRequestData().headers;
        var origin  = "";

        if (structKeyExists(headers, "Origin")) {
            origin = trim(headers.Origin);
        }

        // Allowed origins: any subdomain of opt.uh.edu (https or http).
        // Add explicit entries below for hosts outside this pattern.
        var allowedPattern  = "^https?://([a-z0-9-]+\.)*opt\.uh\.edu$";
        var explicitAllowed = [
            "https://www.opt.uh.edu",
            "https://www2.opt.uh.edu",
            "http://www.opt.uh.edu",
            "http://www2.opt.uh.edu"
        ];

        var originAllowed = len(origin)
            && ( reFindNoCase(allowedPattern, origin) || arrayFindNoCase(explicitAllowed, origin) );

        if (originAllowed) {
            cfheader(name="Access-Control-Allow-Origin", value=origin);
            cfheader(name="Vary", value="Origin");
        }

        // HARD STOP for preflight
        if (cgi.request_method EQ "OPTIONS") {
            cfheader(name="Access-Control-Allow-Methods", value="GET, POST, PUT, DELETE, OPTIONS");
            cfheader(name="Access-Control-Allow-Headers", value="Content-Type, Authorization");
            cfheader(name="Access-Control-Max-Age", value="86400");
            cfabort;
        }

        // Always available on every API request
        request.context    = "api";
        request.datasource = application.datasource;
        request.webRoot    = "";
        request.siteBaseUrl = _getRequestBaseUrl();
        request.environmentName = _getEnvironmentName();
        request.isProduction = (request.environmentName EQ "production");
        request.uhApiToken  = application.uhApiToken;
        request.uhApiSecret = application.uhApiSecret;

        return true;
    }

    private string function _getEnvironmentName() {
        var host = lCase(trim(cgi.http_host ?: cgi.server_name ?: ""));

        if (!len(host)) {
            return "local";
        }

        host = listFirst(host, ":");

        if (listFindNoCase("127.0.0.1,localhost", host)) {
            return "local";
        }

        return "production";
    }

    private string function _getRequestBaseUrl() {
        var scheme = "http";
        var host   = trim(cgi.http_host ?: cgi.server_name ?: "127.0.0.1");

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
        cfheader(statusCode = "500");
        cfheader(name = "Content-Type", value = "application/json; charset=utf-8");
        writeOutput(serializeJSON({ "error": "Internal server error" }));
        abort;
    }

}
