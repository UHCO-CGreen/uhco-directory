component output="false" singleton {

    public any function init() {
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.defaultServer = "cougarnet.uh.edu";
        variables.defaultStartDN = "OU=Master Users,DC=cougarnet,DC=uh,DC=edu";
        return this;
    }

    public struct function searchCandidates(
        required string searchTerm,
        string userType = "",
        numeric userID = 0,
        numeric maxRows = 25
    ) {
        var term = trim(arguments.searchTerm ?: "");
        var ldapFilter = "";
        var qLdap = "";
        var startedAt = getTickCount();
        var elapsedMs = 0;
        var rows = [];
        var queryStartDN = _getStartDN();
        var bindPasswordLength = 0;
        var ldapAttributes = _getCandidateAttributes();

        try {
            bindPasswordLength = len(_getBindPassword());
        } catch (any ignored) {
            bindPasswordLength = 0;
        }

        if (len(term) LT 2) {
            return {
                success = false,
                message = "Enter at least 2 characters.",
                data = [],
                meta = {
                    elapsedMs = 0,
                    userType = trim(arguments.userType ?: "")
                }
            };
        }

        ldapFilter = _buildFilter(term);

        try {
            qLdap = _queryLdap(
                ldapFilter = ldapFilter,
                startDN = queryStartDN,
                attributes = ldapAttributes
            );

            rows = _toRows(qLdap);
            elapsedMs = getTickCount() - startedAt;

            return {
                success = true,
                message = arrayLen(rows) ? "Match(es) found." : "No matches found.",
                data = rows,
                meta = {
                    elapsedMs = elapsedMs,
                    resultCount = arrayLen(rows),
                    startDN = queryStartDN,
                    filter = ldapFilter,
                    ldapAttributes = ldapAttributes,
                    userType = trim(arguments.userType ?: "")
                }
            };
        } catch (any cfcatch) {
            elapsedMs = getTickCount() - startedAt;
            return {
                success = false,
                message = _friendlyErrorMessage(cfcatch),
                data = [],
                _debug = {
                    message = cfcatch.message,
                    detail = cfcatch.detail,
                    type = cfcatch.type,
                    filter = ldapFilter,
                    startDN = queryStartDN,
                    server = _getServer(),
                    username = _getBindUsername(),
                    bindPasswordLength = bindPasswordLength,
                    ldapAttributes = ldapAttributes
                },
                meta = {
                    elapsedMs = elapsedMs,
                    userType = trim(arguments.userType ?: "")
                }
            };
        }
    }

    private query function _queryLdap(
        required string ldapFilter,
        required string startDN,
        required string attributes
    ) {
        var qResult = "";
        var ldapAttributes = arguments.attributes;
        var searchStartDN = arguments.startDN;
        var ldapServer = _getServer();
        var bindUsername = _getBindUsername();
        var bindPassword = _getBindPassword();

        include "../includes/ldap_run_simple_query.cfm";
        return qResult;
    }

    private array function _toRows(required query qRows) {
        var out = [];
        var i = 0;
        var limitRows = arguments.qRows.recordCount;
        var hasEmployeeID = listFindNoCase(arguments.qRows.columnList, "employeeid") GT 0;

        for (i = 1; i <= limitRows; i++) {
            arrayAppend(out, {
                displayName = trim(arguments.qRows.displayName[i] ?: ""),
                samAccountName = trim(arguments.qRows.sAMAccountName[i] ?: ""),
                mail = trim(arguments.qRows.mail[i] ?: ""),
                employeeID = hasEmployeeID ? trim(arguments.qRows.employeeid[i] ?: "") : ""
            });
        }

        return out;
    }

    private string function _buildFilter(required string searchTerm) {
        var escaped = _escapeLDAP(arguments.searchTerm);
        return "(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=#escaped#)(displayName=#escaped#)(mail=#escaped#)(userPrincipalName=#escaped#)))";
    }

    private string function _friendlyErrorMessage(required any err) {
        var m = lCase(trim(arguments.err.message ?: ""));
        if (m CONTAINS "invalid credentials" OR m CONTAINS "error code 49") {
            return "LDAP bind credentials are invalid. Update AppConfig keys ldap.cougarnet.bind_username / ldap.cougarnet.bind_password.";
        }
        if (m CONTAINS "timed out") {
            return "LDAP lookup timed out. Please try again.";
        }
        return "Directory lookup failed.";
    }

    private string function _getCandidateAttributes() {
        return trim(variables.appConfigService.getValue(
            "ldap.cougarnet.simple_attributes",
            "displayName,sAMAccountName,mail,employeeid"
        ));
    }

    private string function _getServer() {
        return trim(variables.appConfigService.getValue("ldap.cougarnet.server", variables.defaultServer));
    }

    private string function _getStartDN() {
        return trim(variables.appConfigService.getValue("ldap.cougarnet.start_dn", variables.defaultStartDN));
    }

    private string function _getBindUsername() {
        var v = trim(variables.appConfigService.getValue("ldap.cougarnet.bind_username", ""));
        if (!len(v)) {
            throw(type = "LdapLookup.MissingConfig", message = "Missing AppConfig key ldap.cougarnet.bind_username.");
        }

        if (find("@", v) GT 0 OR find(chr(92), v) GT 0 OR left(lCase(v), 3) EQ "cn=") {
            while (find(chr(92) & chr(92), v) GT 0) {
                v = replace(v, chr(92) & chr(92), chr(92), "all");
            }
            return v;
        }

        while (find(chr(92) & chr(92), v) GT 0) {
            v = replace(v, chr(92) & chr(92), chr(92), "all");
        }
        if (find("@", v) GT 0) {
            v = listFirst(v, "@");
        }
        if (find(chr(92), v) GT 0) {
            v = listLast(v, chr(92));
        }
        return "COUGARNET" & chr(92) & v;
    }

    private string function _getBindPassword() {
        var v = trim(variables.appConfigService.getValue("ldap.cougarnet.bind_password", ""));
        if (!len(v)) {
            throw(type = "LdapLookup.MissingConfig", message = "Missing AppConfig key ldap.cougarnet.bind_password.");
        }
        return v;
    }

    private string function _escapeLDAP(required string value) {
        var s = arguments.value;
        s = replace(s, "\\", "\\5c", "all");
        s = replace(s, "*", "\\2a", "all");
        s = replace(s, "(", "\\28", "all");
        s = replace(s, ")", "\\29", "all");
        s = replace(s, chr(0), "\\00", "all");
        return s;
    }
}
