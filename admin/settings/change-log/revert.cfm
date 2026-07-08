<!---
    Change Log — Revert POST handler.
    Requires change_log.revert permission and a valid CSRF token.
--->

<cfif NOT request.hasPermission("change_log.revert")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="#request.webRoot#/admin/settings/change-log/" addtoken="false">
</cfif>

<cfparam name="form.groupID"     default="">
<cfparam name="form._csrf_token" default="">

<!--- CSRF validation --->
<cfif NOT len(trim(form._csrf_token)) OR form._csrf_token NEQ (request.adminCsrfToken ?: "")>
    <cfset redirectURL = request.webRoot & "/admin/settings/change-log/detail.cfm?groupID=" & urlEncodedFormat(trim(form.groupID)) & "&error=" & urlEncodedFormat("Invalid security token. Please try again.")>
    <cflocation url="#redirectURL#" addtoken="false">
</cfif>

<cfset groupID = trim(form.groupID)>

<cfif NOT len(groupID)>
    <cflocation url="#request.webRoot#/admin/settings/change-log/" addtoken="false">
</cfif>

<cfset adminUserID = val(session.user.adminUserID ?: 0)>

<cftry>
    <cfset application.changeLogSvc.revertGroup(groupID, adminUserID)>
    <cflocation url="#request.webRoot#/admin/settings/change-log/detail.cfm?groupID=#urlEncodedFormat(groupID)#&reverted=1" addtoken="false">
<cfcatch>
    <cfset errMsg = len(trim(cfcatch.message ?: "")) ? cfcatch.message : "An unexpected error occurred during revert.">
    <cflocation url="#request.webRoot#/admin/settings/change-log/detail.cfm?groupID=#urlEncodedFormat(groupID)#&error=#urlEncodedFormat(errMsg)#" addtoken="false">
</cfcatch>
</cftry>
