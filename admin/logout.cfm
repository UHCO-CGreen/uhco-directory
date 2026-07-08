<cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
  <cfset application.authAuditService.log(
    source      = "admin",
    eventType   = "LOGOUT",
    adminUserID = session.user.adminUserID,
    username    = session.user.username ?: "",
    ipAddress   = left(trim(cgi.remote_addr & ""), 50)
  )>
</cfif>
<cfset application.authService.logout()>
<cflocation url="#request.webRoot#/admin/login.cfm" addtoken="false">