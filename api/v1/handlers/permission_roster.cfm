<!---
    GET /api/v1/permission-roster?permission={name}

    Returns the active, non-expired users who hold the given permission.
    Intended for MyUHCO modules that need to resolve role membership by
    permission key (e.g. "MyUHCO.health-screening.screener").

        Auth:   Bearer token (Authorization header) — required
                API secret  (X-API-Secret header)  — required
    Params: permission — dot-notation access area name (required)

    Responses:
        200 { "permission": "...", "total": N, "users": [...] }
        400 { "error": "Missing or invalid permission" }
        401 { "error": "Unauthorized" }
--->

<!--- ── Auth: require valid token ────────────────────────────────────────── --->
<cfset auth.requireAuth("read")>

<!--- ── Auth: require valid secret ──────────────────────────────────────── --->
<cfset unlockedFlags = auth.checkSecret()>
<cfif NOT arrayLen(unlockedFlags)>
    <cfset auth.sendError(401, "Unauthorized")>
</cfif>

<!--- ── Validate permission param ───────────────────────────────────────── --->
<cfset targetPermission = trim(url.permission ?: "")>
<cfif NOT len(targetPermission)>
    <cfset auth.sendError(400, "Missing or invalid permission")>
</cfif>

<!--- ── Query users ─────────────────────────────────────────────────────── --->
<cfset accessService = createObject("component", "cfc.access_service").init()>
<cfset result = accessService.getUsersForPermission(targetPermission)>

<!--- ── Respond ─────────────────────────────────────────────────────────── --->
<cfset auth.sendResponse({
    permission : targetPermission,
    total      : arrayLen(result.data),
    users      : result.data
})>
<cfabort>
