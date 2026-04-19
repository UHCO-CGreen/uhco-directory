component output="false" singleton {

    public any function init() {
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.userReviewService = createObject("component", "cfc.userReview_service").init();
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    public struct function authenticate(required string username, required string password) {
        var result = { success = false, message = "", user = {} };
        var ldapUser = "";
        var userResult = {};
        var eligibility = {};

        try {
            cfldap(
                action = "QUERY",
                name = "UserReviewLdapUser",
                attributes = "displayName,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title",
                start = "DC=cougarnet,DC=uh,DC=edu",
                scope = "SUBTREE",
                filter = "(&(objectClass=User)(objectCategory=Person)(sAMAccountName=#trim(arguments.username)#))",
                maxrows = 1,
                server = "cougarnet.uh.edu",
                username = "COUGARNET\#trim(arguments.username)#",
                password = arguments.password
            );

            if (UserReviewLdapUser.recordCount EQ 0) {
                result.message = "User not found.";
                return result;
            }

            if (bitAnd(UserReviewLdapUser.userAccountControl, 2)) {
                result.message = "Account disabled.";
                return result;
            }

            if (
                UserReviewLdapUser.accountExpires NEQ 0
                AND UserReviewLdapUser.accountExpires LT dateDiff("s", createDate(1601, 1, 1), now())
            ) {
                result.message = "Account expired.";
                return result;
            }

            ldapUser = lCase(trim(UserReviewLdapUser.sAMAccountName & ""));
            userResult = variables.usersService.getUserByCougarnet(ldapUser);
            if (NOT userResult.success) {
                result.message = "Your directory profile was not found in this system.";
                return result;
            }

            eligibility = variables.userReviewService.getEligibilityResult(val(userResult.data.USERID));
            if (NOT eligibility.success) {
                result.message = eligibility.message;
                return result;
            }

            result.success = true;
            result.user = {
                userID = val(userResult.data.USERID),
                username = ldapUser,
                cougarnetID = ldapUser,
                displayName = trim(UserReviewLdapUser.displayName ?: ""),
                email = trim(UserReviewLdapUser.mail ?: ""),
                phone = trim(UserReviewLdapUser.telephoneNumber ?: ""),
                department = trim(UserReviewLdapUser.department ?: ""),
                title = trim(UserReviewLdapUser.title ?: ""),
                authType = "ldap",
                loginAt = now()
            };
            return result;
        } catch (any cfcatch) {
            if (cfcatch.message CONTAINS "error code 49") {
                if (cfcatch.message CONTAINS "52e") {
                    result.message = "Invalid credentials.";
                } else {
                    result.message = "Login failed.";
                }
            } else {
                result.message = "Authentication error. " & cfcatch.message;
            }
            return result;
        }
    }

    public struct function authenticateExternal(required string cougarnetID, required string token) {
        var result = { success = false, message = "", user = {} };
        var expectedToken = trim(variables.appConfigService.getValue("user_review.external_auth_token", ""));
        var userResult = {};
        var eligibility = {};
        var normalizedCougarnet = lCase(trim(arguments.cougarnetID));

        if (NOT len(expectedToken)) {
            result.message = "External UserReview authentication is not configured.";
            return result;
        }

        if (arguments.token NEQ expectedToken) {
            result.message = "External UserReview authentication failed.";
            return result;
        }

        userResult = variables.usersService.getUserByCougarnet(normalizedCougarnet);
        if (NOT userResult.success) {
            result.message = "Your directory profile was not found in this system.";
            return result;
        }

        eligibility = variables.userReviewService.getEligibilityResult(val(userResult.data.USERID));
        if (NOT eligibility.success) {
            result.message = eligibility.message;
            return result;
        }

        result.success = true;
        result.user = {
            userID = val(userResult.data.USERID),
            username = normalizedCougarnet,
            cougarnetID = normalizedCougarnet,
            displayName = trim((userResult.data.FIRSTNAME ?: "") & " " & (userResult.data.LASTNAME ?: "")),
            email = trim(userResult.data.EMAILPRIMARY ?: ""),
            authType = "external-post",
            loginAt = now()
        };

        return result;
    }

    public void function createSession(required struct user) {
        session.userReviewUser = duplicate(arguments.user);
    }

    public boolean function isLoggedIn() {
        return structKeyExists(session, "userReviewUser");
    }

    public struct function getSessionUser() {
        return isLoggedIn() ? duplicate(session.userReviewUser) : {};
    }

    public void function logout() {
        if (structKeyExists(session, "userReviewUser")) {
            structDelete(session, "userReviewUser", false);
        }
    }
}