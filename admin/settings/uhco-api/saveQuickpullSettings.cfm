<cfif NOT request.hasPermission("settings.api.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="/admin/settings/uhco-api/" addtoken="false">
    <cfabort>
</cfif>

<cflocation url="/admin/settings/uhco-api/quickpulls/?msg=#urlEncodedFormat('Quickpull settings moved to the Quickpulls folder.')#" addtoken="false">