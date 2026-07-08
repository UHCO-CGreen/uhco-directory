component output="false" singleton {

    // Hardcoded, non-removable baseline — any subdomain of opt.uh.edu, http or https.
    variables.baselinePattern = "^https?://([a-z0-9-]+\.)*opt\.uh\.edu$";
    variables.ipRangeCheckConfigKey = "cors.ip_range_check_enabled";

    variables.cacheTTLSeconds        = 60;
    variables.cacheOrigins           = [];
    variables.cacheIPRanges          = [];
    variables.cacheIPRangeCheckOn    = false;
    variables.cacheLoadedAt          = 0;

    public any function init() {
        variables.dao        = createObject("component", "dao.cors_DAO").init();
        variables.ipMatch    = createObject("component", "cfc.ipMatch_service").init();
        variables.appConfig  = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    // ── Decision API (called from api/v1/Application.cfc on every request) ──

    /**
     * NOTE: CGI.REMOTE_ADDR is trusted directly — this codebase has no
     * X-Forwarded-For handling anywhere. If this app is ever placed behind a
     * reverse proxy/load balancer that doesn't preserve the real client IP,
     * the IP-range check below will silently stop matching real clients (or
     * over-match on the proxy's own IP).
     */
    public boolean function isOriginAllowed( required string origin, required string remoteIP ) {
        if (!len(trim(arguments.origin))) return false;

        if (reFindNoCase(variables.baselinePattern, arguments.origin)) return true;

        _ensureFreshCache();

        for (var o in variables.cacheOrigins) {
            if (o.MATCHTYPE EQ "exact") {
                if (compareNoCase(trim(o.ORIGINPATTERN), arguments.origin) EQ 0) return true;
            } else {
                var escapedDomain = replace(trim(o.ORIGINPATTERN), ".", "\.", "all");
                var pattern = "^https?://([a-z0-9-]+\.)*" & escapedDomain & "$";
                if (reFindNoCase(pattern, arguments.origin)) return true;
            }
        }

        if (variables.cacheIPRangeCheckOn && len(trim(arguments.remoteIP))) {
            for (var r in variables.cacheIPRanges) {
                if (variables.ipMatch.ipMatchesCIDR(trim(arguments.remoteIP), trim(r.CIDR))) return true;
            }
        }

        return false;
    }

    public void function forceRefresh() {
        variables.cacheLoadedAt = 0;
        _ensureFreshCache();
    }

    private void function _ensureFreshCache() {
        if (getTickCount() - variables.cacheLoadedAt LT (variables.cacheTTLSeconds * 1000)) return;
        variables.cacheOrigins        = variables.dao.getActiveOrigins();
        variables.cacheIPRanges       = variables.dao.getActiveIPRanges();
        variables.cacheIPRangeCheckOn = isIPRangeCheckEnabled();
        variables.cacheLoadedAt       = getTickCount();
    }

    // ── IP range check toggle ────────────────────────────────────────────

    public boolean function isIPRangeCheckEnabled() {
        return variables.appConfig.getValue(variables.ipRangeCheckConfigKey, "false") EQ "true";
    }

    public struct function setIPRangeCheckEnabled( required boolean enabled ) {
        if (arguments.enabled) {
            var activeRanges = variables.dao.getActiveIPRanges();
            if (arrayLen(activeRanges) EQ 0) {
                return { success=false, message="Add at least one active IP range before enabling this check." };
            }
        }

        variables.appConfig.setValue(
            variables.ipRangeCheckConfigKey,
            arguments.enabled ? "true" : "false",
            "Whether the CORS IP/CIDR-range trust check is active for the API.",
            "cors"
        );
        forceRefresh();

        return { success=true, message="IP range check " & (arguments.enabled ? "enabled." : "disabled.") };
    }

    // ── Origins CRUD (called from admin screens) ─────────────────────────

    public struct function getAllOrigins() {
        return { success=true, data=variables.dao.getAllOrigins() };
    }

    public struct function getOriginByID( required numeric originID ) {
        var origin = variables.dao.getOriginByID(arguments.originID);
        return {
            success = !structIsEmpty(origin),
            data = origin,
            message = structIsEmpty(origin) ? "Origin not found." : ""
        };
    }

    public struct function createOrigin( required string originPattern, required string matchType, string description="" ) {
        var normalizedType = lCase(trim(arguments.matchType));
        var normalizedPattern = trim(arguments.originPattern);
        var validation = _validateOriginPattern(normalizedPattern, normalizedType);

        if (!validation.success) return validation;

        var originID = variables.dao.createOrigin(normalizedPattern, normalizedType, trim(arguments.description));
        forceRefresh();

        return {
            success = originID GT 0,
            originID = originID,
            message = originID GT 0 ? "Origin added." : "Unable to add origin."
        };
    }

    public struct function updateOrigin( required numeric originID, required string originPattern, required string matchType, string description="", required boolean isActive ) {
        var normalizedType = lCase(trim(arguments.matchType));
        var normalizedPattern = trim(arguments.originPattern);
        var existing = variables.dao.getOriginByID(arguments.originID);

        if (structIsEmpty(existing)) {
            return { success=false, message="Origin not found." };
        }

        var validation = _validateOriginPattern(normalizedPattern, normalizedType);
        if (!validation.success) return validation;

        variables.dao.updateOrigin(arguments.originID, normalizedPattern, normalizedType, trim(arguments.description), arguments.isActive);
        forceRefresh();

        return { success=true, message="Origin updated." };
    }

    public struct function deleteOrigin( required numeric originID ) {
        var existing = variables.dao.getOriginByID(arguments.originID);
        if (structIsEmpty(existing)) {
            return { success=false, message="Origin not found." };
        }

        variables.dao.deleteOrigin(arguments.originID);
        forceRefresh();

        return { success=true, message="Origin deleted." };
    }

    // ── IP Ranges CRUD (called from admin screens) ───────────────────────

    public struct function getAllIPRanges() {
        return { success=true, data=variables.dao.getAllIPRanges() };
    }

    public struct function getIPRangeByID( required numeric rangeID ) {
        var range = variables.dao.getIPRangeByID(arguments.rangeID);
        return {
            success = !structIsEmpty(range),
            data = range,
            message = structIsEmpty(range) ? "IP range not found." : ""
        };
    }

    public struct function createIPRange( required string cidr, string description="" ) {
        var normalizedCIDR = trim(arguments.cidr);
        var validation = _validateCIDR(normalizedCIDR);

        if (!validation.success) return validation;

        var rangeID = variables.dao.createIPRange(normalizedCIDR, trim(arguments.description));
        forceRefresh();

        return {
            success = rangeID GT 0,
            rangeID = rangeID,
            message = rangeID GT 0 ? "IP range added." : "Unable to add IP range."
        };
    }

    public struct function updateIPRange( required numeric rangeID, required string cidr, string description="", required boolean isActive ) {
        var normalizedCIDR = trim(arguments.cidr);
        var existing = variables.dao.getIPRangeByID(arguments.rangeID);

        if (structIsEmpty(existing)) {
            return { success=false, message="IP range not found." };
        }

        var validation = _validateCIDR(normalizedCIDR);
        if (!validation.success) return validation;

        variables.dao.updateIPRange(arguments.rangeID, normalizedCIDR, trim(arguments.description), arguments.isActive);
        forceRefresh();

        return { success=true, message="IP range updated." };
    }

    public struct function deleteIPRange( required numeric rangeID ) {
        var existing = variables.dao.getIPRangeByID(arguments.rangeID);
        if (structIsEmpty(existing)) {
            return { success=false, message="IP range not found." };
        }

        variables.dao.deleteIPRange(arguments.rangeID);
        forceRefresh();

        return { success=true, message="IP range deleted." };
    }

    // ── Private validation helpers ───────────────────────────────────────

    private struct function _validateOriginPattern( required string pattern, required string matchType ) {
        if (!len(arguments.pattern)) {
            return { success=false, message="Origin pattern is required." };
        }
        if (!listFindNoCase("exact,wildcard", arguments.matchType)) {
            return { success=false, message="Match type must be 'exact' or 'wildcard'." };
        }
        if (arguments.matchType EQ "exact") {
            if (!reFindNoCase("^https?://[a-z0-9.-]+(:\d+)?$", arguments.pattern)) {
                return { success=false, message="Exact origins must look like https://host.example.edu or https://host.example.edu:port." };
            }
        } else {
            if (!reFindNoCase("^[a-z0-9-]+(\.[a-z0-9-]+)+$", arguments.pattern)) {
                return { success=false, message="Wildcard entries must be a bare domain, e.g. partner.example.edu (no scheme, no port)." };
            }
        }
        return { success=true };
    }

    private struct function _validateCIDR( required string cidr ) {
        if (!len(arguments.cidr)) {
            return { success=false, message="IP/CIDR value is required." };
        }
        if (find(":", arguments.cidr)) {
            return { success=false, message="IPv6 is not supported — enter an IPv4 address or CIDR range." };
        }
        if (!reFind("^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(/\d{1,2})?$", arguments.cidr)) {
            return { success=false, message="Enter an IPv4 address (e.g. 10.0.0.5) or CIDR range (e.g. 129.7.0.0/16)." };
        }

        var networkPart = listFirst(arguments.cidr, "/");
        for (var octet in listToArray(networkPart, ".")) {
            if (val(octet) GT 255) {
                return { success=false, message="Each IP octet must be between 0 and 255." };
            }
        }

        if (find("/", arguments.cidr)) {
            var prefix = val(listLast(arguments.cidr, "/"));
            if (prefix LT 0 OR prefix GT 32) {
                return { success=false, message="CIDR prefix must be between 0 and 32." };
            }
        }

        return { success=true };
    }

}
