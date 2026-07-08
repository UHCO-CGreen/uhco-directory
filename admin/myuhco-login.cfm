<cfsetting showdebugoutput="false">
<cfscript>
function trustedLaunchError(required string errorMessage) {
    cflocation(url="/admin/login.cfm?error=" & urlEncodedFormat(arguments.errorMessage), addtoken=false);
    cfabort;
}

function base64UrlDecode(required string input) {
    var b64 = replace(arguments.input, "-", "+", "all");
    b64 = replace(b64, "_", "/", "all");
    while ((len(b64) mod 4) NEQ 0) {
        b64 &= "=";
    }
    return toString(binaryDecode(b64, "base64"));
}

function generateSignature(required string input, required string secret) {
    var algorithm = "HmacSHA256";
    var mac = createObject("java", "javax.crypto.Mac").getInstance(algorithm);
    var keySpec = createObject("java", "javax.crypto.spec.SecretKeySpec").init(
        charsetDecode(arguments.secret, "utf-8"),
        algorithm
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

function verifyMyUhcoToken(required string token, required string secret) {
    var parts = listToArray(arguments.token, ".");
    var expectedSignature = "";
    var payloadJson = "";
    var payload = {};
    var nowEpoch = int(now().getTime() / 1000);

    if (arrayLen(parts) NEQ 3) {
        return { valid = false, reason = "Invalid token format" };
    }

    expectedSignature = generateSignature(parts[1] & "." & parts[2], arguments.secret);
    if (parts[3] NEQ expectedSignature) {
        return { valid = false, reason = "Invalid signature" };
    }

    try {
        payloadJson = base64UrlDecode(parts[2]);
        payload = deserializeJSON(payloadJson);
    } catch (any e) {
        return { valid = false, reason = "Invalid payload" };
    }

    if (!structKeyExists(payload, "exp") OR nowEpoch GT int(val(payload.exp))) {
        return { valid = false, reason = "Token expired" };
    }

    return { valid = true, payload = payload };
}

param name="url.token" default="";

if (!len(trim(url.token & ""))) {
    trustedLaunchError("Missing MyUHCO launch token.");
}

if (!structKeyExists(application, "runtimeSecretPolicyService") OR !isObject(application.runtimeSecretPolicyService)) {
    trustedLaunchError("Runtime secret policy service is not available.");
}

if (!structKeyExists(application, "authService") OR !isObject(application.authService)) {
    trustedLaunchError("Auth service is not available.");
}

myUhcoSecret = trim(application.runtimeSecretPolicyService.getEnvironmentSecret("MYUHCO_SECRET") & "");
if (!len(myUhcoSecret)) {
    trustedLaunchError("MYUHCO_SECRET is not configured for trusted launch.");
}

verification = verifyMyUhcoToken(trim(url.token & ""), myUhcoSecret);
if (!verification.valid) {
    trustedLaunchError("Trusted launch token is invalid.");
}

payload = verification.payload;
if (!structKeyExists(payload, "moduleID") OR lCase(trim(payload.moduleID & "")) NEQ "identity-admin") {
    trustedLaunchError("Trusted launch token is not valid for Identity Admin.");
}
if (!structKeyExists(payload, "username") OR !len(trim(payload.username & ""))) {
    trustedLaunchError("Trusted launch token is missing the required username.");
}

launchResult = application.authService.authenticateTrustedLaunch(
    username = trim(payload.username & ""),
    canonicalUserID = structKeyExists(payload, "userID") ? int(val(payload.userID)) : 0,
    displayName = structKeyExists(payload, "displayName") ? trim(payload.displayName & "") : "",
    email = structKeyExists(payload, "email") ? trim(payload.email & "") : "",
    department = structKeyExists(payload, "department") ? trim(payload.department & "") : "",
    title = structKeyExists(payload, "title") ? trim(payload.title & "") : "",
    authType = "myuhco-token"
);

if (!launchResult.success) {
    trustedLaunchError(len(trim(launchResult.message & "")) ? launchResult.message : "Trusted launch failed.");
}

application.authService.createSession(launchResult.user);
location("/admin/dashboard.cfm", false);
</cfscript>