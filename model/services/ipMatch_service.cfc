component output="false" singleton {

    public any function init() {
        return this;
    }

    /**
     * Basic IP / CIDR matcher supporting exact IPs and /prefix notation.
     * Handles IPv4 only (sufficient for internal university use).
     */
    public boolean function ipMatchesCIDR( required string ip, required string cidr ) {
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

    /**
     * Matches ip against a comma-separated list of exact IPs / CIDR ranges.
     */
    public boolean function ipMatchesAny( required string ip, required string cidrList ) {
        for (var cidr in listToArray(arguments.cidrList, ",")) {
            if (ipMatchesCIDR(arguments.ip, trim(cidr))) return true;
        }
        return false;
    }

    private numeric function ipToLong( required string ip ) {
        var octets = listToArray(arguments.ip, ".");
        return (val(octets[1]) * 16777216)
             + (val(octets[2]) * 65536)
             + (val(octets[3]) * 256)
             +  val(octets[4]);
    }
}
