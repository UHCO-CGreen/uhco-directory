<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="form.returnTo" default="/admin/users/index.cfm">
<cfparam name="form.embedded" default="0">

<cffunction name="toProperName" access="private" returntype="string" output="false">
    <cfargument name="input" type="string" required="true">
    <cfset var raw = trim(arguments.input)>
    <cfset var words = []>
    <cfset var result = []>
    <cfset var w = "">
    <cfset var hParts = []>
    <cfset var hResult = []>
    <cfset var h = "">
    <cfset var part = "">

    <cfif NOT len(raw)>
        <cfreturn "">
    </cfif>

    <cfset words = listToArray(raw, " ")>

    <cfloop array="#words#" index="w">
        <cfset hParts = listToArray(w, "-")>
        <cfset hResult = []>

        <cfloop array="#hParts#" index="h">
            <cfset part = lCase(h)>
            <cfif len(part) GT 2 AND left(part, 2) EQ "mc">
                <cfset part = "Mc" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3)>
            <cfelseif len(part) GT 2 AND left(part, 2) EQ "o'">
                <cfset part = "O'" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3)>
            <cfelse>
                <cfset part = uCase(left(part, 1)) & mid(part, 2, len(part) - 1)>
            </cfif>
            <cfset arrayAppend(hResult, part)>
        </cfloop>

        <cfset arrayAppend(result, arrayToList(hResult, "-"))>
    </cfloop>

    <cfreturn arrayToList(result, " ")>
</cffunction>

<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset aliasesService = createObject("component", "cfc.aliases_service").init()>
<cfset userData = {
    FirstName = toProperName(structKeyExists(form, "FirstName") ? form.FirstName : ""),
    MiddleName = toProperName(structKeyExists(form, "MiddleName") ? form.MiddleName : ""),
    LastName = toProperName(structKeyExists(form, "LastName") ? form.LastName : ""),
    Pronouns = "",
    EmailPrimary = trim(structKeyExists(form, "EmailPrimary") ? form.EmailPrimary : ""),
    Phone = "",
    UH_API_ID = "",
    Active = 1
}>
<cfset isCreate = NOT (structKeyExists(form, "UserID") AND isNumeric(form.UserID) AND val(form.UserID) GT 0)>

<cfif isCreate AND NOT request.canCreateUsers()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif len(trim(userData.MiddleName)) EQ 1 AND reFind("^[A-Za-z]$", trim(userData.MiddleName))>
    <cfset userData.MiddleName = trim(userData.MiddleName) & ".">
</cfif>

<cfif NOT isCreate>
    <cfset userID = val(form.UserID)>
    <cfif NOT request.canAccessUserByID(userID)>
        <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
    </cfif>
    <cfset _suFlagsSvc = createObject("component", "cfc.flags_service").init()>
    <cfset _suFlags = _suFlagsSvc.getUserFlags(userID).data>
    <cfset _suIsAlumni = false>
    <cfset _suIsFaculty = false>
    <cfloop array="#_suFlags#" index="_suf">
        <cfif compareNoCase(trim(_suf.FLAGNAME ?: ""), "Alumni") EQ 0>
            <cfset _suIsAlumni = true>
        </cfif>
        <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", trim(_suf.FLAGNAME ?: ""))>
            <cfset _suIsFaculty = true>
        </cfif>
    </cfloop>
    <cfif _suIsAlumni AND NOT (application.authService.hasRole("ALUMNI_ADMIN") OR (_suIsFaculty AND application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])))>
        <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
        <cfabort>
    </cfif>
    <cfset result = usersService.updateUser(userID, userData)>
<cfelse>
    <cfset result = usersService.createUser(userData)>
    <cfset userID = result.success ? val(result.userID) : 0>
</cfif>

<cfif result.success AND userID GT 0>
    <cfif isCreate>
        <cfset aliasesService.replaceAliases(userID, [{
            firstName = userData.FirstName,
            middleName = userData.MiddleName,
            lastName = userData.LastName,
            aliasType = "SOURCE_VARIANT",
            sourceSystem = "QUICK_ADD",
            isActive = 1,
            isPrimary = 1
        }])>
    </cfif>

    <cfset returnTo = trim(form.returnTo)>
    <cfset editUrl = "/admin/users/edit.cfm?userID=" & urlEncodedFormat(userID) & "&returnTo=" & urlEncodedFormat(returnTo)>

    <cfif val(form.embedded) EQ 1>
        <cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>User Saved</title>
</head>
<body>
    <p>User saved. Opening edit view...</p>
    <cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
    (function () {
        var targetUrl = '#encodeForJavaScript(editUrl)#';
        try {
            if (window.parent && window.parent !== window) {
                window.parent.location.href = targetUrl;
                return;
            }
        } catch (err) {
            // Fall through to same-window redirect.
        }
        window.location.href = targetUrl;
    })();
    </script>
    <noscript>
        <p><a href="#encodeForHTMLAttribute(editUrl)#">Continue to Edit User</a></p>
    </noscript>
</body>
</html>
        </cfoutput>
        <cfabort>
    </cfif>

    <cflocation url="#editUrl#" addtoken="false">
<cfelse>
    <cfoutput><h2>Error: #encodeForHTML(result.message ?: "Unable to save user.")#</h2></cfoutput>
</cfif>
