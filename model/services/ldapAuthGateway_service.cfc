component output="false" singleton {

    public any function init() {
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    public any function queryUserByCredentials(
        required string username,
        required string password,
        string attributes = "displayName,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title",
        array allowedGroupDNs = []
    ) {
        var ldapQuery = "";

        cfldap(
            action = "QUERY",
            name = "ldapQuery",
            attributes = arguments.attributes,
            start = getBaseDN(),
            scope = "SUBTREE",
            filter = _buildUserFilter(trim(arguments.username), arguments.allowedGroupDNs),
            maxrows = 1,
            server = getServer(),
            username = getDomainPrefix() & chr(92) & trim(arguments.username),
            password = arguments.password
        );

        return ldapQuery;
    }

    public array function getAdminAllowedGroupDNs() {
        return _getConfiguredGroupDNs(
            "auth.admin.allowed_group_dns",
            _getDefaultAdminAllowedGroupDNs()
        );
    }

    public string function getServer() {
        return trim(variables.appConfigService.getValue("auth.ldap.server", "cougarnet.uh.edu"));
    }

    public string function getBaseDN() {
        return trim(variables.appConfigService.getValue("auth.ldap.base_dn", "DC=cougarnet,DC=uh,DC=edu"));
    }

    public string function getDomainPrefix() {
        return trim(variables.appConfigService.getValue("auth.ldap.domain_prefix", "COUGARNET"));
    }

    private array function _getConfiguredGroupDNs(required string configKey, required array defaultGroupDNs) {
        var rawValue = trim(variables.appConfigService.getValue(arguments.configKey, ""));
        var parsed = [];

        if (!len(rawValue)) {
            return duplicate(arguments.defaultGroupDNs);
        }

        if (left(rawValue, 1) EQ "[") {
            try {
                parsed = deserializeJSON(rawValue);
                if (isArray(parsed)) {
                    return parsed;
                }
            } catch (any ignore) {
            }
        }

        rawValue = replace(rawValue, chr(13) & chr(10), chr(10), "all");
        rawValue = replace(rawValue, chr(13), chr(10), "all");
        for (var groupDN in listToArray(rawValue, chr(10) & "|")) {
            groupDN = trim(groupDN ?: "");
            if (len(groupDN)) {
                arrayAppend(parsed, groupDN);
            }
        }

        return arrayLen(parsed) ? parsed : duplicate(arguments.defaultGroupDNs);
    }

    private string function _buildUserFilter(required string username, array allowedGroupDNs = []) {
        var filter = "(&(objectClass=User)(objectCategory=Person)(sAMAccountName=" & _escapeFilterValue(arguments.username) & ")";

        if (arrayLen(arguments.allowedGroupDNs)) {
            filter &= _buildGroupMembershipFilter(arguments.allowedGroupDNs);
        }

        filter &= ")";
        return filter;
    }

    private string function _buildGroupMembershipFilter(required array allowedGroupDNs) {
        var filter = "(|";

        for (var groupDN in arguments.allowedGroupDNs) {
            filter &= "(memberOf=" & _escapeFilterValue(trim(groupDN ?: "")) & ")";
        }

        filter &= ")";
        return filter;
    }

    private string function _escapeFilterValue(required string rawValue) {
        var safeValue = arguments.rawValue;
        safeValue = replace(safeValue, chr(92), "\5c", "all");
        safeValue = replace(safeValue, "*", "\2a", "all");
        safeValue = replace(safeValue, "(", "\28", "all");
        safeValue = replace(safeValue, ")", "\29", "all");
        safeValue = replace(safeValue, chr(0), "\00", "all");
        return safeValue;
    }

    private array function _getDefaultAdminAllowedGroupDNs() {
        return [
            "CN=%OPTOMETRY,OU=Master Users,DC=cougarnet,DC=uh,DC=edu"
        ];
        // TESTING: original group list commented out below
        // return [
        //     "CN=OPT-ASC,OU=ASC USERS,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-STAFF,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-OPTOMETRY,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-FACULTY-1,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-CLASS2022,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-CLASS2023,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-CLASS2024,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-CLASS2025,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu",
        //     "CN=OPT-CLASS2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu"
        // ];
    }
}