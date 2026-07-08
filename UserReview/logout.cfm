<cfset userReviewAuth = structKeyExists(request, "userReviewAuth") ? request.userReviewAuth : createObject("component", "cfc.UserReviewAuthService").init()>
<cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "userReviewUser") AND isStruct(session.userReviewUser)>
    <cfset application.authAuditService.log(
        source    = "userreview",
        eventType = "UR_LOGOUT",
        username  = session.userReviewUser.username ?: "",
        ipAddress = left(trim(cgi.remote_addr & ""), 50)
    )>
</cfif>
<cfset userReviewAuth.logout()>
<cflocation url="/UserReview/login.cfm?msg=#urlEncodedFormat('You have been signed out.')#" addtoken="false">