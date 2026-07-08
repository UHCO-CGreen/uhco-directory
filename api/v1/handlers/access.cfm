<!---
    GET /api/v1/access?userID={userID}

    Returns the active, non-expired module permissions for a given identity user.
    Used by MyUHCO external modules to enforce permission-based access control.
    Callers cache the response for 10 minutes (no server-side caching here).

        Auth:   Bearer token (Authorization header) — required
            API secret  (X-API-Secret header) — required
    Params: userID — positive integer, identity user key

    Responses:
        200 { "userID": N, "permissions": ["documents.view", ...] }
        400 { "error": "Invalid userID" }
        401 { "error": "Unauthorized" }
--->

<!--- ── Auth: require valid token ────────────────────────────────────────── --->
<cfset auth.requireAuth("read")>

<!--- ── Auth: require valid secret ──────────────────────────────────────── --->
<cfset unlockedFlags = auth.checkSecret()>
<cfif NOT arrayLen(unlockedFlags)>
    <cfset auth.sendError(401, "Unauthorized")>
</cfif>

<!--- ── Validate userID param ────────────────────────────────────────────── --->
<cfif NOT (structKeyExists(url, "userID") AND len(trim(url.userID)) AND isNumeric(url.userID) AND val(url.userID) GT 0)>
    <cfset auth.sendError(400, "Invalid userID")>
</cfif>

<cfset targetUserID = int(val(url.userID))>

<!--- ── Query permissions ────────────────────────────────────────────────── --->
<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset result = accessService.getPermissionsForUser(targetUserID)>

<!--- ── Respond ─────────────────────────────────────────────────────────── --->
<cfset auth.sendResponse({ userID: targetUserID, permissions: result.data })>
<cfabort>
