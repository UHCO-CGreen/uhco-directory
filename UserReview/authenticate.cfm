<cfparam name="form.username" default="">
<cfparam name="form.password" default="">
<cfparam name="form.cougarnetID" default="">
<cfparam name="form.externalAuthToken" default="">
<cfparam name="form.launchContextToken" default="">
<cfset userReviewAuth = structKeyExists(request, "userReviewAuth") ? request.userReviewAuth : createObject("component", "cfc.UserReviewAuthService").init()>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="/UserReview/login.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfif len(trim(form.externalAuthToken)) AND len(trim(form.cougarnetID))>
    <cfset authResult = userReviewAuth.authenticateExternal(
        cougarnetID = form.cougarnetID,
        token = form.externalAuthToken,
        launchContextToken = form.launchContextToken
    )>
<cfelse>
    <cfif NOT len(trim(form.username)) OR NOT len(trim(form.password))>
        <cflocation url="/UserReview/login.cfm?error=#urlEncodedFormat('Username and password are required.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset authResult = userReviewAuth.authenticate(
        username = form.username,
        password = form.password
    )>
</cfif>

<cfif authResult.success>
    <cfset userReviewAuth.createSession(authResult.user)>
    <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService)>
        <cfset application.authAuditService.log(
            source    = "userreview",
            eventType = len(trim(form.externalAuthToken)) ? "UR_EXTERNAL_AUTH" : "UR_LOGIN",
            username  = authResult.user.username ?: "",
            ipAddress = left(trim(cgi.remote_addr & ""), 50),
            userAgent = left(trim(cgi.http_user_agent & ""), 500)
        )>
    </cfif>
    <cflocation url="/UserReview/index.cfm" addtoken="false">
<cfelse>
    <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService)>
        <cfset application.authAuditService.log(
            source    = "userreview",
            eventType = len(trim(form.externalAuthToken)) ? "UR_EXTERNAL_AUTH_FAILED" : "UR_LOGIN_FAILED",
            username  = len(trim(form.cougarnetID)) ? left(trim(form.cougarnetID), 50) : left(trim(form.username & ""), 50),
            ipAddress = left(trim(cgi.remote_addr & ""), 50),
            details   = left(trim(authResult.message & ""), 500)
        )>
    </cfif>
    <cflocation url="/UserReview/login.cfm?error=#urlEncodedFormat(authResult.message)#" addtoken="false">
</cfif>