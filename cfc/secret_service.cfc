component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dir.dao.secrets_DAO").init();
        return this;
    }

    public array function getAllSecrets() {
        return variables.dao.getAllSecrets();
    }

    /**
     * Validate an incoming raw secret value.
     * Returns { valid: bool, protectedFlags: array, reason: string }
     *
     * ProtectedFlags is a comma-separated list of flag names this secret unlocks,
     * e.g. "OD Student,Current Student"
     */
    public struct function validateSecret(
        required string rawSecret,
        required string remoteIP
    ) {
        var result = { valid: false, protectedFlags: [], reason: "" };

        var h    = hashSecret(arguments.rawSecret);
        var rows = variables.dao.getSecretByHash(h);

        if (arrayIsEmpty(rows)) {
            result.reason = "Invalid secret";
            return result;
        }
        var sec = rows[1];

        // Expiry check
        if (!isNull(sec.EXPIRESAT) && len(trim(sec.EXPIRESAT & ""))) {
            if (now() GT parseDateTime(sec.EXPIRESAT)) {
                result.reason = "Secret expired";
                return result;
            }
        }

        // IP allowlist
        var ips = trim(sec.ALLOWEDIPS ?: "");
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

        try { variables.dao.touchLastUsed(sec.SECRETID); } catch (any e) {}

        result.valid          = true;
        result.protectedFlags = listToArray(sec.PROTECTEDFLAGS, ",");
        return result;
    }

    /**
     * Generate a new secret, persist the hash, return the raw value (shown once).
     * Format: uhcs_sec_ + UUID + 8 hex chars
     */
    public struct function createSecret(
        required string secretName,
        required string appName,
        required string protectedFlags,
                 string allowedIPs = "",
                 string expiresAt  = ""
    ) {
        var raw = "uhcs_sec_" & lCase(createUUID()) & lCase(left(hash(now() & createUUID(), "SHA-256"), 8));
        var h   = hashSecret(raw);

        var newID = variables.dao.createSecret(
            secretName     = arguments.secretName,
            appName        = arguments.appName,
            secretHash     = h,
            protectedFlags = arguments.protectedFlags,
            allowedIPs     = arguments.allowedIPs,
            expiresAt      = arguments.expiresAt
        );

        return { secretID: newID, rawSecret: raw };
    }

    public void function revokeSecret( required numeric secretID ) {
        variables.dao.revokeSecret( arguments.secretID );
    }

    public void function deleteSecret( required numeric secretID ) {
        variables.dao.deleteSecret( arguments.secretID );
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private string function hashSecret( required string raw ) {
        return lCase(hash(arguments.raw, "SHA-256"));
    }

    private boolean function ipMatchesCIDR( required string ip, required string cidr ) {
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
        var parts = listToArray(arguments.ip, ".");
        return (val(parts[1]) * 16777216)
             + (val(parts[2]) * 65536)
             + (val(parts[3]) * 256)
             +  val(parts[4]);
    }

}
