<cfif cgi.request_method NEQ "POST">
    <cflocation url="/UserReview/index.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfif NOT application.userReviewAuthService.isLoggedIn()>
    <cflocation url="/UserReview/login.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset result = userReviewService.saveSubmission(
    actor = application.userReviewAuthService.getSessionUser(),
    formScope = form
)>

<cfif result.success>
    <cflocation url="/UserReview/index.cfm?msg=#urlEncodedFormat(result.message)#" addtoken="false">
<cfelse>
    <cflocation url="/UserReview/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>