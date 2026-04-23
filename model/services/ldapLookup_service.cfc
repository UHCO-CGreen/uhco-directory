component output="false" singleton {

    public any function init() {
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.flagsService = createObject("component", "cfc.flags_service").init();

        variables.defaultServer = "cougarnet.uh.edu";
        variables.defaultStartDN = "DC=cougarnet,DC=uh,DC=edu";
        variables.defaultCandidateStartDN = "OU=Master Users,DC=cougarnet,DC=uh,DC=edu";
        variables.fallbackSearchStartDN = variables.defaultStartDN;
        variables.defaultTimeoutSeconds = 10;
        variables.defaultMaxRows = 25;
        variables.maxRowsHardCap = 100;

        return this;
    }

    public struct function searchCandidates(
        required string searchTerm,
        string userType = "",
        numeric userID = 0,
        numeric maxRows = 25
    ) {
        var normalizedTerm = trim(arguments.searchTerm ?: "");
        var resolvedMaxRows = _resolveMaxRows(arguments.maxRows);
        var lookupContext = _buildLookupContext(arguments.userType, arguments.userID);
        var ldapFilter = "";
        var qLdap = "";
        var startedAt = getTickCount();
        var elapsedMs = 0;
        var candidates = [];
        var filtered = [];
        var queryStartDN = _getCandidateStartDN();
        var queryResult = {};
        var bindPasswordLength = 0;

        try {
            bindPasswordLength = len(_getBindPassword());
        } catch (any ignored) {
            bindPasswordLength = 0;
        }

        if (len(normalizedTerm) LT 2) {
            return {
                success = false,
                message = "Enter at least 2 characters.",
                data = [],
                meta = {
                    eligible = lookupContext.eligible,
                    reason = lookupContext.reason,
                    userType = lookupContext.userType,
                    elapsedMs = 0
                }
            };
        }

        if (NOT lookupContext.eligible) {
            return {
                success = false,
                message = "Lookup is only enabled for faculty, staff, or current-student users.",
                data = [],
                meta = {
                    eligible = false,
                    reason = lookupContext.reason,
                    userType = lookupContext.userType,
                    elapsedMs = 0
                }
            };
        }

        if (arrayLen(lookupContext.allowedGroups) EQ 0) {
            return {
                success = false,
                message = "No LDAP group restrictions were resolved for this lookup context.",
                data = [],
                meta = {
                    eligible = false,
                    reason = "no_groups",
                    userType = lookupContext.userType,
                    elapsedMs = 0
                }
            };
        }

        ldapFilter = _buildFilter(normalizedTerm);

        try {
            queryResult = _runCandidateQuery(ldapFilter, queryStartDN);
            queryStartDN = queryResult.startDN;
            qLdap = queryResult.query;

            elapsedMs = getTickCount() - startedAt;

            candidates = _queryToCandidateArray(qLdap);
            filtered = _filterByGroups(candidates, lookupContext.allowedGroups, resolvedMaxRows);

            return {
                success = true,
                message = arrayLen(filtered) ? "Match(es) found." : "No matches found.",
                data = filtered,
                meta = {
                    eligible = true,
                    reason = lookupContext.reason,
                    userType = lookupContext.userType,
                    resultCount = arrayLen(filtered),
                    candidateCount = arrayLen(candidates),
                    elapsedMs = elapsedMs,
                    maxRows = resolvedMaxRows,
                    startDN = queryStartDN,
                    filter = ldapFilter,
                    allowedGroups = lookupContext.allowedGroups
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
                    ldapAttributes = "displayName,sAMAccountName,mail,memberOf,department,title,employeeid"
                },
                meta = {
                    eligible = true,
                    reason = lookupContext.reason,
                    userType = lookupContext.userType,
                    elapsedMs = elapsedMs
                }
            };
        }
    }

    private numeric function _resolveMaxRows(required numeric maxRows) {
        var n = val(arguments.maxRows);
        if (n LT 1) { n = variables.defaultMaxRows; }
        if (n GT variables.maxRowsHardCap) { n = variables.maxRowsHardCap; }
        return n;
    }

    private struct function _buildLookupContext(required string userType, required numeric userID) {
        var ctx = {
            eligible = false,
            reason = "",
            userType = arguments.userType,
            allowedGroups = []
        };
        var normalizedType = lCase(trim(arguments.userType));

        if (!len(normalizedType) AND val(arguments.userID) GT 0) {
            normalizedType = _inferUserTypeFromUserFlags(arguments.userID);
            ctx.userType = normalizedType;
            if (len(normalizedType)) {
                ctx.reason = "inferred_from_flags";
            }
        }

        if (normalizedType EQ "current student" OR normalizedType EQ "current_students" OR normalizedType EQ "current-students") {
            normalizedType = "current-student";
        }

        if (normalizedType EQ "faculty") {
            ctx.eligible = true;
            ctx.reason = "faculty";
            ctx.allowedGroups = _getFacultyGroupDNs();
        } else if (normalizedType EQ "staff") {
            ctx.eligible = true;
            ctx.reason = "staff";
            ctx.allowedGroups = _getStaffGroupDNs();
        } else if (normalizedType EQ "current-student" OR normalizedType EQ "current_student" OR normalizedType EQ "student") {
            ctx.eligible = true;
            ctx.reason = "current_student";
            ctx.allowedGroups = _getCurrentStudentGroupDNs();
        } else {
            ctx.eligible = false;
            ctx.reason = "unknown_type";
        }

        return ctx;
    }

    private string function _inferUserTypeFromUserFlags(required numeric userID) {
        var flagPayload = variables.flagsService.getUserFlags(arguments.userID);
        var flags = [];
        var f = {};
        var flagName = "";

        if (isStruct(flagPayload) AND structKeyExists(flagPayload, "data") AND isArray(flagPayload.data)) {
            flags = flagPayload.data;
        }

        for (f in flags) {
            flagName = lCase(trim((f.flagName ?: "") & ""));

            if (flagName EQ "staff") {
                return "staff";
            }
            if (flagName EQ "faculty" OR flagName EQ "faculty-adjunct" OR flagName EQ "faculty-fulltime" OR flagName EQ "joint faculty appointment") {
                return "faculty";
            }
            if (flagName EQ "current-student" OR flagName EQ "current student" OR flagName EQ "current_student") {
                return "current-student";
            }
        }

        return "";
    }

    private string function _buildFilter(required string searchTerm) {
        var escaped = _escapeLDAP(arguments.searchTerm);
        return "(&(objectClass=user)(objectCategory=person)(|(sAMAccountName=#escaped#)(displayName=#escaped#)(mail=#escaped#)(userPrincipalName=#escaped#)))";
    }

    private struct function _runCandidateQuery(required string ldapFilter, required string startDN) {
        var qResult = "";
        var ldapAttributes = "displayName,sAMAccountName,mail,memberOf,department,title,employeeid";
        var ldapServer = _getServer();
        var ldapTimeout = _getTimeoutSeconds();
        var bindUsername = _getBindUsername();
        var bindPassword = _getBindPassword();
        var ldapMaxRows = variables.maxRowsHardCap;
        var searchStartDN = arguments.startDN;

        try {
            include "../includes/ldap_run_candidate_query.cfm";

            if (qResult.recordCount GT 0 OR arguments.startDN EQ variables.fallbackSearchStartDN) {
                return {
                    query = qResult,
                    startDN = arguments.startDN
                };
            }

            // Some valid student accounts are not under the narrower candidate OU.
            // If the targeted search returns no rows, widen once to the full configured base DN.
            searchStartDN = variables.fallbackSearchStartDN;
            include "../includes/ldap_run_candidate_query.cfm";

            return {
                query = qResult,
                startDN = variables.fallbackSearchStartDN
            };
        } catch (any firstCatch) {
            if (arguments.startDN EQ variables.fallbackSearchStartDN) {
                rethrow;
            }
        }

        searchStartDN = variables.fallbackSearchStartDN;
        include "../includes/ldap_run_candidate_query.cfm";

        return {
            query = qResult,
            startDN = variables.fallbackSearchStartDN
        };
    }

    private array function _queryToCandidateArray(required query qRows) {
        var results = [];
        var i = 0;
        var row = {};
        var hasDepartment = listFindNoCase(arguments.qRows.columnList, "department") GT 0;
        var hasTitle = listFindNoCase(arguments.qRows.columnList, "title") GT 0;
        var hasEmployeeID = listFindNoCase(arguments.qRows.columnList, "employeeid") GT 0;
        var hasDistinguishedName = listFindNoCase(arguments.qRows.columnList, "distinguishedName") GT 0;
        var hasMemberOf = listFindNoCase(arguments.qRows.columnList, "memberOf") GT 0;

        for (i = 1; i <= arguments.qRows.recordCount; i++) {
            row = {
                displayName = trim(arguments.qRows.displayName[i] ?: ""),
                samAccountName = trim(arguments.qRows.sAMAccountName[i] ?: ""),
                mail = trim(arguments.qRows.mail[i] ?: ""),
                department = hasDepartment ? trim(arguments.qRows.department[i] ?: "") : "",
                title = hasTitle ? trim(arguments.qRows.title[i] ?: "") : "",
                employeeID = hasEmployeeID ? trim(arguments.qRows.employeeid[i] ?: "") : "",
                distinguishedName = hasDistinguishedName ? trim(arguments.qRows.distinguishedName[i] ?: "") : "",
                memberOf = hasMemberOf ? trim(arguments.qRows.memberOf[i] ?: "") : ""
            };
            arrayAppend(results, row);
        }

        return results;
    }

    private array function _filterByGroups(required array candidates, required array allowedGroups, required numeric maxRows) {
        if (arrayLen(arguments.allowedGroups) EQ 0) {
            return arguments.candidates;
        }

        var result = [];
        var candidate = {};
        var memberOf = "";
        var groupDN = "";
        var matched = false;

        for (candidate in arguments.candidates) {
            if (arrayLen(result) GTE arguments.maxRows) {
                break;
            }
            memberOf = lCase(candidate.memberOf ?: "");
            matched = false;
            for (groupDN in arguments.allowedGroups) {
                if (findNoCase(lCase(trim(groupDN)), memberOf)) {
                    matched = true;
                    break;
                }
            }
            if (matched) {
                arrayAppend(result, candidate);
            }
        }

        return result;
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

    private string function _getServer() {
        return trim(variables.appConfigService.getValue("ldap.cougarnet.server", variables.defaultServer));
    }

    private string function _getStartDN() {
        return trim(variables.appConfigService.getValue("ldap.cougarnet.start_dn", variables.defaultStartDN));
    }

    private string function _getCandidateStartDN() {
        var configuredStartDN = _getStartDN();
        if (!len(configuredStartDN) OR configuredStartDN EQ variables.defaultStartDN) {
            return variables.defaultCandidateStartDN;
        }
        return configuredStartDN;
    }

    private numeric function _getTimeoutSeconds() {
        var n = val(variables.appConfigService.getValue("ldap.cougarnet.timeout_seconds", toString(variables.defaultTimeoutSeconds)));
        return n GT 0 ? n : variables.defaultTimeoutSeconds;
    }

    private string function _getBindUsername() {
        var v = trim(variables.appConfigService.getValue("ldap.cougarnet.bind_username", ""));
        if (!len(v)) {
            throw(type = "LdapLookup.MissingConfig", message = "Missing AppConfig key ldap.cougarnet.bind_username.");
        }

        // Preserve explicit formats from config (DOMAIN\user, user@domain, or full DN).
        // Only coerce when the value is a bare account name.
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

    private array function _getFacultyGroupDNs() {
        var csv = trim(variables.appConfigService.getValue(
            "ldap.cougarnet.groups.faculty",
            "CN=OPT-Faculty-1,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-OPTOMETRY,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu"
        ));
        return _splitPipeList(csv);
    }

    private array function _getStaffGroupDNs() {
        var csv = trim(variables.appConfigService.getValue(
            "ldap.cougarnet.groups.staff",
            "CN=OPT-Staff,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu"
        ));
        return _splitPipeList(csv);
    }

    private array function _getCurrentStudentGroupDNs() {
        var csv = trim(variables.appConfigService.getValue(
            "ldap.cougarnet.groups.current_student",
            "CN=OPT-ClassOf2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2027,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2028,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu|CN=OPT-ClassOf2029,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu"
        ));
        return _splitPipeList(csv);
    }

    private array function _splitPipeList(required string pipeList) {
        var raw = listToArray(arguments.pipeList, "|");
        var clean = [];
        var item = "";
        for (item in raw) {
            item = trim(item);
            if (len(item)) {
                arrayAppend(clean, item);
            }
        }
        return clean;
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
