<cfparam name="form.username" default="">
<cfparam name="form.password" default="">

<cfif !len(form.username) OR !len(form.password)>
  <cflocation url="login.cfm?error=missing" addtoken="false">
</cfif>

<cfset authResult = application.authService.authenticate(
  username = form.username,
  password = form.password
)>

<!--- Debugging: dump the authentication result and auth service state 
<cfdump var="#authResult#" label="Authentication Result">
<cfif authResult.success>
  <cfset application.authService.createSession(authResult.user)>

  <cfdump var="#application.authService#" label="Auth Service">
  <cfdump var="#request.webRoot#" label="Web Root">
</cfif>
<cfabort>--->


<cfif authResult.success>
  <cfset application.authService.createSession(authResult.user)>
  <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
<cfelse>
  <cflocation url="login.cfm?error=#urlEncodedFormat(authResult.message)#" addtoken="false">
</cfif>