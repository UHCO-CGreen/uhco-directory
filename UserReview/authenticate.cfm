<cfparam name="form.username" default="">
<cfparam name="form.password" default="">
<cfparam name="form.cougarnetID" default="">
<cfparam name="form.externalAuthToken" default="">

<cfif cgi.request_method NEQ "POST">
    <cflocation url="/UserReview/login.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfif len(trim(form.externalAuthToken)) AND len(trim(form.cougarnetID))>
    <cfset authResult = application.userReviewAuthService.authenticateExternal(
        cougarnetID = form.cougarnetID,
        token = form.externalAuthToken
    )>
<cfelse>
    <cfif NOT len(trim(form.username)) OR NOT len(trim(form.password))>
        <cflocation url="/UserReview/login.cfm?error=#urlEncodedFormat('Username and password are required.')#" addtoken="false">
        <cfabort>
    </cfif>

    <cfset authResult = application.userReviewAuthService.authenticate(
        username = form.username,
        password = form.password
    )>
</cfif>

<cfif authResult.success>
    <cfset application.userReviewAuthService.createSession(authResult.user)>
    <cflocation url="/UserReview/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="/UserReview/login.cfm?error=#urlEncodedFormat(authResult.message)#" addtoken="false">
</cfif>