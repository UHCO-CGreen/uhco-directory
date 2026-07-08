component output="false" singleton {

    variables.algorithm = "HmacSHA256";

    public any function init() {
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.userReviewService = createObject("component", "cfc.userReview_service").init();
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.ldapAuthGateway = createObject("component", "cfc.ldapAuthGateway_service").init();
        return this;
    }

    public struct function authenticate(required string username, required string password) {
        var result = { success = false, message = "", user = {} };
        var ldapUser = "";
        var userResult = {};
        var eligibility = {};
        var UserReviewLdapUser = "";

        try {
            UserReviewLdapUser = variables.ldapAuthGateway.queryUserByCredentials(
                username = trim(arguments.username),
                password = arguments.password,
                attributes = "displayName,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title"
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
            _logAuthError("authenticate", cfcatch, trim(arguments.username));
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

    public struct function authenticateExternal(required string cougarnetID, required string token, string launchContextToken = "") {
        var result = { success = false, message = "", user = {} };
        var expectedToken = trim(variables.appConfigService.getValue("user_review.external_auth_token", ""));
        var userResult = {};
        var eligibility = {};
        var normalizedCougarnet = lCase(trim(arguments.cougarnetID));
        var launchContext = {};
        var launchContextResult = { success = true, payload = {} };

        if (NOT len(expectedToken)) {
            result.message = "External UserReview authentication is not configured.";
            return result;
        }

        if (arguments.token NEQ expectedToken) {
            result.message = "External UserReview authentication failed.";
            return result;
        }

        if (len(trim(arguments.launchContextToken))) {
            launchContextResult = _verifyLaunchContextToken(
                token = trim(arguments.launchContextToken),
                sharedSecret = expectedToken,
                cougarnetID = normalizedCougarnet
            );
            if (NOT launchContextResult.success) {
                result.message = launchContextResult.message;
                return result;
            }
            launchContext = launchContextResult.payload;
        }

        userResult = variables.usersService.getUserByCougarnet(normalizedCougarnet);
        if (NOT userResult.success) {
            result.message = "Your directory profile was not found in this system.";
            return result;
        }

        if (structCount(launchContext)) {
            eligibility = variables.userReviewService.getEligibilityResult(val(launchContext.targetUserId ?: 0));
            if (NOT eligibility.success) {
                result.message = eligibility.message;
                return result;
            }
        } else {
            eligibility = variables.userReviewService.getEligibilityResult(val(userResult.data.USERID));
            if (NOT eligibility.success) {
                result.message = eligibility.message;
                return result;
            }
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
        if (structCount(launchContext)) {
            result.user.launchContext = launchContext;
        }

        return result;
    }

    private struct function _verifyLaunchContextToken(required string token, required string sharedSecret, required string cougarnetID) {
        var parts = listToArray(arguments.token, ".");
        var expectedSignature = "";
        var payloadJson = "";
        var payload = {};
        var normalizedCougarnet = lCase(trim(arguments.cougarnetID));

        if (arrayLen(parts) NEQ 3) {
            return { success = false, message = "Delegated launch token format is invalid." };
        }

        expectedSignature = _generateSignature(parts[1] & "." & parts[2], arguments.sharedSecret);
        if (parts[3] NEQ expectedSignature) {
            return { success = false, message = "Delegated launch token signature failed validation." };
        }

        try {
            payloadJson = _base64UrlDecode(parts[2]);
            payload = deserializeJSON(payloadJson);
        } catch (any e) {
            return { success = false, message = "Delegated launch token payload is invalid." };
        }

        if (trim(payload.kind ?: "") NEQ "delegated-user-review-launch") {
            return { success = false, message = "Delegated launch token kind is invalid." };
        }
        if (!structKeyExists(payload, "exp") OR _dateToEpoch(now()) GT val(payload.exp ?: 0)) {
            return { success = false, message = "Delegated launch token has expired." };
        }
        if (lCase(trim(payload.actorCougarnetId ?: "")) NEQ normalizedCougarnet) {
            return { success = false, message = "Delegated launch token actor does not match the authenticated user." };
        }
        if (trim(payload.requestType ?: "") NEQ "profile_edit") {
            return { success = false, message = "Only delegated profile edit launches are currently supported." };
        }
        if (!isNumeric(payload.targetUserId ?: "") OR val(payload.targetUserId ?: 0) LTE 0) {
            return { success = false, message = "Delegated launch target user is invalid." };
        }
        if (!structKeyExists(payload, "sections") OR !isArray(payload.sections) OR !arrayLen(payload.sections)) {
            return { success = false, message = "Delegated launch sections are missing." };
        }

        return { success = true, payload = payload };
    }

    private string function _generateSignature(required string input, required string secret) {
        var mac = createObject("java", "javax.crypto.Mac").getInstance(variables.algorithm);
        var keySpec = createObject("java", "javax.crypto.spec.SecretKeySpec").init(
            charsetDecode(arguments.secret, "utf-8"),
            variables.algorithm
        );
        var rawHmac = "";
        var b64 = "";

        mac.init(keySpec);
        rawHmac = mac.doFinal(charsetDecode(arguments.input, "utf-8"));
        b64 = binaryEncode(rawHmac, "base64");
        b64 = replace(b64, "+", "-", "all");
        b64 = replace(b64, "/", "_", "all");
        b64 = replace(b64, "=", "", "all");
        return b64;
    }

    private string function _base64UrlDecode(required string input) {
        var b64 = replace(arguments.input, "-", "+", "all");
        b64 = replace(b64, "_", "/", "all");
        while ((len(b64) mod 4) NEQ 0) {
            b64 &= "=";
        }
        return toString(binaryDecode(b64, "base64"));
    }

    private numeric function _dateToEpoch(required date dt) {
        return int(arguments.dt.getTime() / 1000);
    }

    private void function _logAuthError(
        required string context,
        required any err,
        string username = ""
    ) {
        var parts = [];
        var lineInfo = "";

        arrayAppend(parts, "UserReviewAuthService error");
        arrayAppend(parts, "context=" & arguments.context);
        if (len(trim(arguments.username ?: ""))) {
            arrayAppend(parts, "username=" & trim(arguments.username));
        }

        if (isStruct(arguments.err)) {
            if (structKeyExists(arguments.err, "type")) {
                arrayAppend(parts, "type=" & toString(arguments.err.type));
            }
            if (structKeyExists(arguments.err, "message")) {
                arrayAppend(parts, "message=" & toString(arguments.err.message));
            }
            if (structKeyExists(arguments.err, "detail") AND len(trim(arguments.err.detail ?: ""))) {
                arrayAppend(parts, "detail=" & trim(arguments.err.detail));
            }
            if (structKeyExists(arguments.err, "sqlstate") AND len(trim(arguments.err.sqlstate ?: ""))) {
                arrayAppend(parts, "sqlstate=" & trim(arguments.err.sqlstate));
            }
            if (structKeyExists(arguments.err, "tagContext") AND isArray(arguments.err.tagContext) AND arrayLen(arguments.err.tagContext)) {
                lineInfo = (arguments.err.tagContext[1].template ?: "") & ":" & (arguments.err.tagContext[1].line ?: "");
                arrayAppend(parts, "tag=" & lineInfo);
            }
        }

        cflog(
            file = "uhco_ident_userreview_auth",
            type = "error",
            text = arrayToList(parts, " | ")
        );
    }

    public void function createSession(required struct user) {
        sessionRotate();
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