component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dir.dao.tokens_DAO").init();
        return this;
    }

    public array function getAllTokens() {
        return variables.dao.getAllTokens();
    }

    /**
     * Validate an incoming raw Bearer token.
     * Returns a struct: { valid: bool, token: struct|{}, reason: string }
     *
     * Validation steps:
     *  1. Hash the raw value
     *  2. Look up hash in DB (must be active)
     *  3. Check expiry
     *  4. Check IP allowlist (if set)
     *  5. Touch LastUsedAt on success
     */
    public struct function validateToken(
        required string rawToken,
        required string remoteIP,
        required string requiredScope
    ) {
        var result = { valid: false, token: {}, reason: "" };

        // 1. Hash
        var hash = hashToken(arguments.rawToken);

        // 2. DB lookup
        var rows = variables.dao.getTokenByHash(hash);
        if (arrayIsEmpty(rows)) {
            result.reason = "Invalid token";
            return result;
        }
        var tok = rows[1];

        // 3. Expiry
        if (!isNull(tok.EXPIRESAT) && len(trim(tok.EXPIRESAT & ""))) {
            if (now() GT parseDateTime(tok.EXPIRESAT)) {
                result.reason = "Token expired";
                return result;
            }
        }

        // 4. IP allowlist
        var ips = trim(tok.ALLOWEDIPS ?: "");
        if (len(ips)) {
            var allowed = false;
            for (var cidr in listToArray(ips, ",")) {
                if (ipMatchesCIDR(trim(arguments.remoteIP), trim(cidr))) {
                    allowed = true;
                    break;
                }
            }
            if (!allowed) {
                result.reason = "IP not permitted";
                return result;
            }
        }

        // 5. Scope check
        var tokenScopes = listToArray(lCase(tok.SCOPES ?: ""), " ");
        if (!arrayFindNoCase(tokenScopes, lCase(arguments.requiredScope))
            && !arrayFindNoCase(tokenScopes, "admin")) {
            result.reason = "Insufficient scope";
            return result;
        }

        // 6. Touch LastUsedAt (fire-and-forget; ignore errors)
        try { variables.dao.touchLastUsed(tok.TOKENID); } catch (any e) {}

        result.valid = true;
        result.token = tok;
        return result;
    }

    /**
     * Generate a new token, persist the hash, return the raw token string (shown once).
     * Format: uhcs_ + 40 lowercase hex chars
     */
    public struct function createToken(
        required string tokenName,
        required string appName,
        required string scopes,
                 string allowedIPs = "",
                 string expiresAt  = ""
    ) {
        var raw  = "uhcs_" & lCase(createUUID()) & lCase(left(hash(now() & createUUID(), "SHA-256"), 8));
        var h    = hashToken(raw);

        var newID = variables.dao.createToken(
            tokenName = arguments.tokenName,
            appName   = arguments.appName,
            tokenHash = h,
            scopes    = arguments.scopes,
            allowedIPs = arguments.allowedIPs,
            expiresAt  = arguments.expiresAt
        );

        return { tokenID: newID, rawToken: raw };
    }

    public void function revokeToken( required numeric tokenID ) {
        variables.dao.revokeToken( arguments.tokenID );
    }

    public void function deleteToken( required numeric tokenID ) {
        variables.dao.deleteToken( arguments.tokenID );
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private string function hashToken( required string raw ) {
        return lCase(hash(arguments.raw, "SHA-256"));
    }

    /**
     * Basic IP / CIDR matcher supporting exact IPs and /prefix notation.
     * Handles IPv4 only (sufficient for internal university use).
     */
    private boolean function ipMatchesCIDR( required string ip, required string cidr ) {
        // Exact match shortcut
        if (arguments.ip == arguments.cidr) return true;

        if (!find("/", arguments.cidr)) return false;

        var parts      = listToArray(arguments.cidr, "/");
        var networkIP  = parts[1];
        var prefixLen  = val(parts[2]);

        var ipLong  = ipToLong(arguments.ip);
        var netLong = ipToLong(networkIP);
        var mask    = bitSHLN(javaCast("long", -1), javaCast("long", 32 - prefixLen));

        return bitAnd(ipLong, mask) == bitAnd(netLong, mask);
    }

    private numeric function ipToLong( required string ip ) {
        var octets = listToArray(arguments.ip, ".");
        return (val(octets[1]) * 16777216)
             + (val(octets[2]) * 65536)
             + (val(octets[3]) * 256)
             +  val(octets[4]);
    }
}
