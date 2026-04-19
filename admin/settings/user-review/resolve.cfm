<cfif NOT request.hasPermission("users.approve_user_review")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="/admin/settings/user-review/" addtoken="false">
    <cfabort>
</cfif>

<cfparam name="form.action" default="">
<cfparam name="form.submissionID" default="0">
<cfparam name="form.submissionFieldID" default="0">
<cfparam name="form.reviewNote" default="">

<cfif structKeyExists(application, "authService")>
    <cfset application.authService.reloadAuthorization(cougarnet = trim(session.user.username ?: ""))>
</cfif>

<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset result = { success = false, message = "Unsupported action." }>
<cfset adminUserID = val(session.user.adminUserID ?: 0)>
<cfset reviewerCougarnetID = trim(session.user.username ?: "")>

<cfif adminUserID LTE 0>
    <cflocation url="/admin/settings/user-review/review.cfm?submissionID=#val(form.submissionID)#&error=#urlEncodedFormat('Your admin session could not be mapped to an AdminUsers record. Please sign out and sign back in.')#" addtoken="false">
    <cfabort>
</cfif>

<cfswitch expression="#trim(form.action)#">
    <cfcase value="approveField">
        <cfset result = userReviewService.approveField(val(form.submissionFieldID), adminUserID, reviewerCougarnetID, trim(form.reviewNote))>
    </cfcase>
    <cfcase value="discardField">
        <cfset result = userReviewService.discardField(val(form.submissionFieldID), adminUserID, reviewerCougarnetID, trim(form.reviewNote))>
    </cfcase>
    <cfcase value="approveAll">
        <cfset result = userReviewService.approveSubmission(val(form.submissionID), adminUserID, reviewerCougarnetID, trim(form.reviewNote))>
    </cfcase>
    <cfcase value="discardAll">
        <cfset result = userReviewService.discardSubmission(val(form.submissionID), adminUserID, reviewerCougarnetID, trim(form.reviewNote))>
    </cfcase>
</cfswitch>

<cfif result.success>
    <cflocation url="/admin/settings/user-review/review.cfm?submissionID=#val(result.submissionID ?: form.submissionID)#&msg=#urlEncodedFormat(result.message)#" addtoken="false">
<cfelse>
    <cflocation url="/admin/settings/user-review/review.cfm?submissionID=#val(form.submissionID)#&error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>