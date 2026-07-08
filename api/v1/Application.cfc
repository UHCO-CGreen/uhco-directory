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

        application.runtimeSecretPolicyService = createObject("component", "cfc.runtimeSecretPolicy_service").init();
        application.corsService = createObject("component", "cfc.cors_service").init();

        var uhApiCredentials = application.runtimeSecretPolicyService.getUHApiCredentials();
        application.uhApiToken = uhApiCredentials.token;
        application.uhApiSecret = uhApiCredentials.secret;

        return true;
    }

    // ── Request start ──────────────────────────────────────────────────
    public boolean function onRequestStart(required string targetPage) {

        // Reinitialize application scope if requested (admin use only)
        if (structKeyExists(url, "reinit") AND url.reinit EQ "true") {
            onApplicationStart();
        }

        // Safety: ensure onApplicationStart() has run
        if (!structKeyExists(application, "datasource") OR !structKeyExists(application, "runtimeSecretPolicyService") OR !structKeyExists(application, "corsService")) {
            onApplicationStart();
        }

        cfsetting(showDebugOutput = false);

        // ── CORS handling ──────────────────────────────────────────────
        // Decision logic (baseline *.opt.uh.edu, admin domain whitelist, and
        // the optional admin IP-range trust check) lives in cors_service.cfc.
        var headers  = getHttpRequestData().headers;
        var origin   = "";
        var remoteIP = trim(CGI.REMOTE_ADDR ?: "");

        if (structKeyExists(headers, "Origin")) {
            origin = trim(headers.Origin);
        }

        var originAllowed = application.corsService.isOriginAllowed(origin, remoteIP);

        if (originAllowed) {
            cfheader(name="Access-Control-Allow-Origin", value=origin);
            cfheader(name="Vary", value="Origin");
            cfheader(name="Access-Control-Expose-Headers", value="X-UHCO-Directory-Api-Base, X-UHCO-Directory-Authorization");
        }

        // HARD STOP for preflight
        if (cgi.request_method EQ "OPTIONS") {
            cfheader(name="Access-Control-Allow-Methods", value="GET, POST, PUT, DELETE, OPTIONS");
            cfheader(name="Access-Control-Allow-Headers", value="Content-Type, Authorization, X-API-Secret");
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
        request.runtimeSecretPolicy = application.runtimeSecretPolicyService;
        request.runtimeSecretHealth = application.runtimeSecretPolicyService.getHealthStatus(request.environmentName);
        request.runtimeSecretPolicyReady = request.runtimeSecretHealth.ready;
        request.uhApiToken  = application.uhApiToken;
        request.uhApiSecret = application.uhApiSecret;

        // ── Response identification headers ──────────────────────────
        // Echoes the base URL this request was served from, and the bearer
        // token the caller sent (unvalidated), so multi-environment/proxy
        // clients can confirm what they actually hit.
        cfheader(name="X-UHCO-Directory-Api-Base", value=request.siteBaseUrl & "/api/v1");

        var callerAuthHeader = CGI.HTTP_AUTHORIZATION ?: "";
        if (reFindNoCase("^Bearer\s+\S+", trim(callerAuthHeader))) {
            cfheader(name="X-UHCO-Directory-Authorization", value=trim(reReplaceNoCase(callerAuthHeader, "^Bearer\s+", "")));
        }

        return true;
    }

    private string function _getEnvironmentName() {
        var host = lCase(trim(cgi.http_host ?: cgi.server_name ?: ""));
        var localHosts = "127.0.0.1,localhost,uhco-identity.local";

        if (!len(host)) {
            return "local";
        }

        host = listFirst(host, ":");

        if (listFindNoCase(localHosts, host)) {
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
