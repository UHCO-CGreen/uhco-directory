component output="false" {

    /**
     * Authenticate the current request.
     * Aborts with 401/403 JSON if auth fails.
     * Returns the validated token struct on success.
     *
     * @requiredScope  'read' or 'write'
     */
    public struct function requireAuth( required string requiredScope = "read" ) {

        var tokenService = createObject("component", "dir.cfc.token_service").init();

        // Extract Bearer token from Authorization header or ?token= query param
        var authHeader = CGI.HTTP_AUTHORIZATION ?: "";
        var rawToken   = "";
        if (reFindNoCase("^Bearer\s+\S+", trim(authHeader))) {
            rawToken = trim(reReplaceNoCase(authHeader, "^Bearer\s+", ""));
        } else if (len(trim(url.token ?: ""))) {
            rawToken = trim(url.token);
        } else {
            sendError(401, "Missing or malformed Authorization header. Expected: Bearer <token>");
        }
        var remoteIP = CGI.REMOTE_ADDR;

        var result = tokenService.validateToken(
            rawToken      = rawToken,
            remoteIP      = remoteIP,
            requiredScope = arguments.requiredScope
        );

        if (!result.valid) {
            // Always return 401 — never reveal the specific reason to the caller
            sendError(401, "Unauthorized");
        }

        return result.token;
    }

    /**
     * Write a JSON error response and abort.
     */
    public void function sendError( required numeric statusCode, required string message ) {
        var statusText = {
            400: "Bad Request",
            401: "Unauthorized",
            403: "Forbidden",
            404: "Not Found",
            405: "Method Not Allowed",
            500: "Internal Server Error"
        };
        var text = structKeyExists(statusText, arguments.statusCode)
            ? statusText[arguments.statusCode]
            : "Error";

        cfheader(statusCode=arguments.statusCode);
        cfheader(name="Content-Type", value="application/json; charset=utf-8");
        writeOutput(serializeJSON({ error: arguments.message }));
        abort;
    }

    /**
     * Check for an optional secret and return which protected flags it unlocks.
     * Never aborts — callers use the returned array to decide what to include/exclude.
     * Returns an empty array if no secret supplied or secret is invalid.
     */
    public array function checkSecret() {
        var raw = "";
        // Accept X-API-Secret header (preferred) or ?secret= query param
        if (len(trim(CGI.HTTP_X_API_SECRET ?: ""))) {
            raw = trim(CGI.HTTP_X_API_SECRET);
        } else if (len(trim(url.secret ?: ""))) {
            raw = trim(url.secret);
        }
        if (!len(raw)) return [];

        var secretService = createObject("component", "dir.cfc.secret_service").init();
        var result = secretService.validateSecret(
            rawSecret = raw,
            remoteIP  = CGI.REMOTE_ADDR
        );
        return result.valid ? result.protectedFlags : [];
    }

    /**
     * Write a successful JSON response.
     * Caller should abort after this.
     */
    public void function sendJSON( required any data, numeric statusCode = 200 ) {
        cfheader(statusCode=arguments.statusCode);
        cfheader(name="Content-Type", value="application/json; charset=utf-8");
        cfheader(name="Cache-Control", value="no-store");
        writeOutput(serializeJSON(arguments.data));
    }

    /**
     * Write a successful XML response.
     */
    public void function sendXML( required any data, numeric statusCode = 200 ) {
        cfheader(statusCode=arguments.statusCode);
        cfheader(name="Content-Type", value="application/xml; charset=utf-8");
        cfheader(name="Cache-Control", value="no-store");
        writeOutput('<?xml version="1.0" encoding="UTF-8"?><response>' & _toXML(arguments.data) & '</response>');
    }

    /**
     * Write a response in the format requested by the caller (?return=json|xml).
     * Defaults to JSON.
     */
    public void function sendResponse( required any data, numeric statusCode = 200 ) {
        var fmt = lCase(trim(url["return"] ?: "json"));
        if (fmt EQ "xml") {
            sendXML(arguments.data, arguments.statusCode);
        } else {
            sendJSON(arguments.data, arguments.statusCode);
        }
    }

    /**
     * Recursively convert a CF struct/array/scalar to an XML string.
     */
    private string function _toXML( required any data ) {
        var out = "";
        if (isNull(arguments.data)) {
            return "";
        } else if (isArray(arguments.data)) {
            for (var item in arguments.data) {
                out &= "<item>" & _toXML(item) & "</item>";
            }
        } else if (isStruct(arguments.data)) {
            for (var key in arguments.data) {
                // Sanitize key to a valid XML element name
                var safeName = reReplace(key, "[^a-zA-Z0-9_\-]", "_", "all");
                if (!reFindNoCase("^[a-zA-Z_]", safeName)) safeName = "_" & safeName;
                out &= "<#safeName#>" & _toXML(arguments.data[key]) & "</#safeName#>";
            }
        } else {
            out = xmlFormat(toString(arguments.data));
        }
        return out;
    }
}
