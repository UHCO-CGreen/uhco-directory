component output="false" singleton {

    public any function init() {
        variables.flagsService = createObject("component", "cfc.flags_service").init();
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.organizationsService = createObject("component", "cfc.organizations_service").init();
        return this;
    }

    variables.unrestrictedUserAdminRoles = [
        "SUPER_ADMIN",
        "USER_ADMIN"
    ];

    variables.scopedUserAdminRules = [
        {
            roleName = "OD_STUDENT_ADMIN",
            requiredFlags = [ "Current-Student" ],
            requiredOrgs = [ "OD Program" ]
        },
        {
            roleName = "PHD_MS_STUDENT_ADMIN",
            requiredFlags = [ "Current-Student" ],
            requiredOrgs = [ "PhD Program", "MS Program" ]
        },
        {
            roleName = "ALUMNI_ADMIN",
            requiredFlags = [ "Alumni" ],
            requiredOrgs = []
        },
        {
            roleName = "CLINICAL_FACULTY_ADMIN",
            requiredFlags = [ "Faculty-Adjunct", "Faculty-Fulltime", "Joint Faculty Appointment" ],
            requiredOrgs = [ "Clinical Sciences" ]
        },
        {
            roleName = "CLINICAL_STAFF_ADMIN",
            requiredFlags = [ "Staff" ],
            requiredOrgs = [ "Optometry Clinic" ]
        },
        {
            roleName = "COLLEGE_STAFF_ADMIN",
            requiredFlags = [ "Staff" ],
            requiredOrgs = []
        },
        {
            roleName = "RESEARCH_FACULTY_ADMIN",
            requiredFlags = [ "Faculty-Adjunct", "Faculty-Fulltime", "Joint Faculty Appointment" ],
            requiredOrgs = [ "Vision Science" ]
        }
    ];

    public boolean function canCurrentAdminManageTestUsers() {
        return getCurrentAdminAccessContext().canManageTestUsers;
    }

    public boolean function shouldExcludeTestUsers() {
        return !canCurrentAdminManageTestUsers();
    }

    public boolean function canCurrentAdminCreateUsers() {
        return getCurrentAdminAccessContext().hasUnrestrictedRole;
    }

    public boolean function canCurrentAdminAccessUserFlags(required array userFlags) {
        return canCurrentAdminAccessUser(arguments.userFlags, []);
    }

    public boolean function canCurrentAdminAccessUser(required array userFlags, array userOrganizations=[]) {
        var accessContext = getCurrentAdminAccessContext();
        var userFlagLookup = getUserFlagNameLookup(arguments.userFlags);
        var userOrganizationLookup = getUserOrganizationNameLookup(arguments.userOrganizations);

        return canCurrentAdminAccessUserWithContext(accessContext, userFlagLookup, userOrganizationLookup);
    }

    public struct function filterAccessibleUsers(required array users, required struct userFlagMap, struct userOrgMap={}) {
        var accessContext = getCurrentAdminAccessContext();
        var visibleUsers = [];
        var userRow = {};
        var userIDKey = "";
        var userFlags = [];
        var userOrganizations = [];
        var hasVisibleTestUsers = false;

        for (userRow in arguments.users) {
            userIDKey = toString(val(userRow.USERID ?: 0));
            userFlags = structKeyExists(arguments.userFlagMap, userIDKey) ? arguments.userFlagMap[userIDKey] : [];
            userOrganizations = structKeyExists(arguments.userOrgMap, userIDKey) ? arguments.userOrgMap[userIDKey] : [];

            if (canCurrentAdminAccessUserWithContext(
                accessContext,
                getUserFlagNameLookup(userFlags),
                getUserOrganizationNameLookup(userOrganizations)
            )) {
                arrayAppend(visibleUsers, userRow);

                if (!hasVisibleTestUsers AND structKeyExists(getUserFlagNameLookup(userFlags), "test_user")) {
                    hasVisibleTestUsers = true;
                }
            }
        }

        return {
            users = visibleUsers,
            hasVisibleTestUsers = hasVisibleTestUsers
        };
    }

    private boolean function canCurrentAdminAccessUserWithContext(
        required struct accessContext,
        required struct userFlagLookup,
        required struct userOrganizationLookup
    ) {

        if (structKeyExists(arguments.userFlagLookup, "test_user") AND !arguments.accessContext.canManageTestUsers) {
            return false;
        }

        if (!arguments.accessContext.hasAuthService) {
            return false;
        }

        if (arguments.accessContext.hasUnrestrictedRole) {
            return true;
        }

        return matchesAnyScopedRule(arguments.accessContext.scopedRules, arguments.userFlagLookup, arguments.userOrganizationLookup);
    }

    public boolean function canCurrentAdminAccessUserProfile(required struct profile) {
        var userFlags = [];
        var userOrganizations = [];

        if (structKeyExists(arguments.profile, "flags") AND isArray(arguments.profile.flags)) {
            userFlags = arguments.profile.flags;
        }

        if (structKeyExists(arguments.profile, "organizations") AND isArray(arguments.profile.organizations)) {
            userOrganizations = arguments.profile.organizations;
        }

        return canCurrentAdminAccessUser(userFlags, userOrganizations);
    }

    public boolean function canCurrentAdminAccessUserID(required numeric userID) {
        var flagsResult = variables.flagsService.getUserFlags(arguments.userID);
        var orgsResult = variables.organizationsService.getUserOrgs(arguments.userID);
        var userFlags = [];
        var userOrganizations = [];

        if (structKeyExists(flagsResult, "data") AND isArray(flagsResult.data)) {
            userFlags = flagsResult.data;
        }

        if (structKeyExists(orgsResult, "data") AND isArray(orgsResult.data)) {
            userOrganizations = orgsResult.data;
        }

        return canCurrentAdminAccessUser(userFlags, userOrganizations);
    }

    public boolean function isTestUserFlags(required array userFlags) {
        var userFlag = {};

        for (userFlag in arguments.userFlags) {
            if (compareNoCase(trim(userFlag.FLAGNAME ?: ""), "TEST_USER") EQ 0) {
                return true;
            }
        }

        return false;
    }

    private any function getAuthService() {
        if (structKeyExists(application, "authService") AND isObject(application.authService)) {
            return application.authService;
        }

        return javacast("null", 0);
    }

    private boolean function hasUnrestrictedUserAdminRole(required any authService) {
        return arguments.authService.hasAnyRole(variables.unrestrictedUserAdminRoles);
    }

    private struct function getCurrentAdminAccessContext() {
        var cacheKey = "adminAuthorizationPolicyCurrentAccessContext";
        var authService = getAuthService();
        var scopedRules = [];
        var scopedRule = {};
        var context = {
            hasAuthService = isObject(authService),
            hasUnrestrictedRole = false,
            canManageTestUsers = false,
            scopedRules = []
        };

        if (structKeyExists(request, cacheKey) AND isStruct(request[cacheKey] ?: {})) {
            return request[cacheKey];
        }

        if (!context.hasAuthService) {
            request[cacheKey] = context;
            return request[cacheKey];
        }

        context.hasUnrestrictedRole = hasUnrestrictedUserAdminRole(authService);
        context.canManageTestUsers = authService.hasRole("SUPER_ADMIN")
            OR variables.usersService.isTestModeEnabled()
            OR (authService.isImpersonating() AND authService.isActualSuperAdmin());

        if (!context.hasUnrestrictedRole) {
            for (scopedRule in variables.scopedUserAdminRules) {
                if (authService.hasRole(scopedRule.roleName)) {
                    arrayAppend(scopedRules, scopedRule);
                }
            }
        }

        context.scopedRules = scopedRules;
        request[cacheKey] = context;
        return request[cacheKey];
    }

    private boolean function matchesAnyScopedRule(required array scopedRules, required struct userFlagLookup, required struct userOrganizationLookup) {
        var scopedRule = {};

        for (scopedRule in arguments.scopedRules) {
            if (matchesScopedRule(scopedRule, arguments.userFlagLookup, arguments.userOrganizationLookup)) {
                return true;
            }
        }

        return false;
    }

    private boolean function matchesScopedRule(required struct scopedRule, required struct userFlagLookup, required struct userOrganizationLookup) {
        if (arrayLen(arguments.scopedRule.requiredFlags) AND !hasAnyMatchingFlag(arguments.userFlagLookup, arguments.scopedRule.requiredFlags)) {
            return false;
        }

        if (arrayLen(arguments.scopedRule.requiredOrgs) AND !hasAnyMatchingOrganization(arguments.userOrganizationLookup, arguments.scopedRule.requiredOrgs)) {
            return false;
        }

        return true;
    }

    private struct function getUserFlagNameLookup(required array userFlags) {
        var lookup = {};
        var userFlag = {};

        for (userFlag in arguments.userFlags) {
            if (len(trim(userFlag.FLAGNAME ?: ""))) {
                lookup[lCase(trim(userFlag.FLAGNAME ?: ""))] = true;
            }
        }

        return lookup;
    }

    private struct function getUserOrganizationNameLookup(required array userOrganizations) {
        var lookup = {};
        var userOrganization = {};

        for (userOrganization in arguments.userOrganizations) {
            if (len(trim(userOrganization.ORGNAME ?: ""))) {
                lookup[lCase(trim(userOrganization.ORGNAME ?: ""))] = true;
            }
        }

        return lookup;
    }

    private boolean function hasAnyMatchingFlag(required struct userFlagLookup, required array requiredFlagNames) {
        var requiredFlagName = "";

        for (requiredFlagName in arguments.requiredFlagNames) {
            if (structKeyExists(arguments.userFlagLookup, lCase(trim(requiredFlagName)))) {
                return true;
            }
        }

        return false;
    }

    private boolean function hasAnyMatchingOrganization(required struct userOrganizationLookup, required array requiredOrgNames) {
        var allowedOrgNames = getAllowedOrganizationNameLookup(arguments.requiredOrgNames);
        var allowedOrgName = "";

        for (allowedOrgName in allowedOrgNames) {
            if (structKeyExists(arguments.userOrganizationLookup, allowedOrgName)) {
                return true;
            }
        }

        return false;
    }

    private struct function getAllowedOrganizationNameLookup(required array requiredOrgNames) {
        var lookupCacheKey = "adminAuthorizationPolicyAllowedOrgLookup";
        var hierarchyCacheKey = "adminAuthorizationPolicyOrgHierarchy";
        var normalizedRequiredOrgNames = [];
        var requiredOrgName = "";
        var cacheKey = "";
        var allowedNames = {};
        var rootOrgID = 0;
        var descendantOrgIDs = [];
        var descendantOrgID = 0;
        var hierarchy = {};

        for (requiredOrgName in arguments.requiredOrgNames) {
            if (len(trim(requiredOrgName))) {
                arrayAppend(normalizedRequiredOrgNames, lCase(trim(requiredOrgName)));
            }
        }

        arraySort(normalizedRequiredOrgNames, "textnocase", "asc");
        cacheKey = arrayToList(normalizedRequiredOrgNames, "|");

        if (!len(cacheKey)) {
            return allowedNames;
        }

        if (!structKeyExists(request, lookupCacheKey) OR !isStruct(request[lookupCacheKey] ?: {})) {
            request[lookupCacheKey] = {};
        }

        if (structKeyExists(request[lookupCacheKey], cacheKey)) {
            return request[lookupCacheKey][cacheKey];
        }

        if (!structKeyExists(request, hierarchyCacheKey) OR !isStruct(request[hierarchyCacheKey] ?: {})) {
            var allOrgsResult = variables.organizationsService.getAllOrgs();
            var allOrgs = [];
            var orgByID = {};
            var childrenByParent = {};
            var orgRow = {};
            var normalizedParentID = "";

            if (structKeyExists(allOrgsResult, "data") AND isArray(allOrgsResult.data)) {
                allOrgs = allOrgsResult.data;
            }

            for (orgRow in allOrgs) {
                orgByID[toString(orgRow.ORGID)] = orgRow;
            }

            for (orgRow in allOrgs) {
                normalizedParentID = isNumeric(orgRow.PARENTORGID ?: "") ? toString(val(orgRow.PARENTORGID)) : "ROOT";
                if (!structKeyExists(childrenByParent, normalizedParentID)) {
                    childrenByParent[normalizedParentID] = [];
                }
                arrayAppend(childrenByParent[normalizedParentID], val(orgRow.ORGID));
            }

            request[hierarchyCacheKey] = {
                allOrgs = allOrgs,
                orgByID = orgByID,
                childrenByParent = childrenByParent
            };
        }

        hierarchy = request[hierarchyCacheKey];

        for (requiredOrgName in normalizedRequiredOrgNames) {
            rootOrgID = findOrganizationIDByName(hierarchy.allOrgs, requiredOrgName);
            if (rootOrgID LTE 0) {
                continue;
            }

            descendantOrgIDs = [ rootOrgID ];
            appendDescendantOrgIDs(descendantOrgIDs, hierarchy.childrenByParent, rootOrgID);

            for (descendantOrgID in descendantOrgIDs) {
                if (structKeyExists(hierarchy.orgByID, toString(descendantOrgID))) {
                    allowedNames[lCase(trim(hierarchy.orgByID[toString(descendantOrgID)].ORGNAME ?: ""))] = true;
                }
            }
        }

        request[lookupCacheKey][cacheKey] = allowedNames;
        return allowedNames;
    }

    private numeric function findOrganizationIDByName(required array allOrgs, required string orgName) {
        var orgRow = {};

        for (orgRow in arguments.allOrgs) {
            if (compareNoCase(trim(orgRow.ORGNAME ?: ""), arguments.orgName) EQ 0) {
                return val(orgRow.ORGID);
            }
        }

        return 0;
    }

    private void function appendDescendantOrgIDs(required array orgIDCollector, required struct childrenByParent, required numeric parentOrgID) {
        var childOrgIDs = structKeyExists(arguments.childrenByParent, toString(arguments.parentOrgID))
            ? arguments.childrenByParent[toString(arguments.parentOrgID)]
            : [];
        var childOrgID = 0;

        for (childOrgID in childOrgIDs) {
            if (arrayFind(arguments.orgIDCollector, childOrgID) EQ 0) {
                arrayAppend(arguments.orgIDCollector, childOrgID);
                appendDescendantOrgIDs(arguments.orgIDCollector, arguments.childrenByParent, childOrgID);
            }
        }
    }
}
