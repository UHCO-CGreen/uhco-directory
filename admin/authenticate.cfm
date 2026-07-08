<cfparam name="form.username" default="">
<cfparam name="form.password" default="">

<cfif !len(form.username) OR !len(form.password)>
  <cflocation url="login.cfm?error=missing" addtoken="false">
</cfif>

<cfset authResult = application.authService.authenticate(
  username = form.username,
  password = form.password
)>

<!--- 
Debugging: dump the authentication result and auth service state - uncomment for troubleshooting.
<cfdump var="#authResult#" label="Authentication Result">
<cfif authResult.success>
  <cfset application.authService.createSession(authResult.user)>

  <cfdump var="#application.authService#" label="Auth Service">
  <cfdump var="#request.webRoot#" label="Web Root">
</cfif>
<cfabort>--->


<cfif authResult.success>
  <cfset application.authService.createSession(authResult.user)>
  <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
    <cfset application.authAuditService.log(
      source      = "admin",
      eventType   = "LOGIN",
      adminUserID = session.user.adminUserID,
      username    = session.user.username ?: "",
      ipAddress   = left(trim(cgi.remote_addr & ""), 50),
      userAgent   = left(trim(cgi.http_user_agent & ""), 500)
    )>
  </cfif>
  <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
<cfelse>
  <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService)>
    <cfset application.authAuditService.log(
      source    = "admin",
      eventType = "LOGIN_FAILED",
      username  = left(trim(form.username & ""), 50),
      ipAddress = left(trim(cgi.remote_addr & ""), 50),
      details   = left(trim(authResult.message & ""), 500)
    )>
  </cfif>
  <cflocation url="login.cfm?error=#urlEncodedFormat(authResult.message)#" addtoken="false">
</cfif>