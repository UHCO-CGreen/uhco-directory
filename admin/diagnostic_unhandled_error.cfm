<cfif structKeyExists(request, "isProduction") AND request.isProduction>
    <cfheader statusCode="404">
    <cfoutput>Not found</cfoutput>
    <cfabort>
</cfif>

<cfif NOT request.hasPermission("admin.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfthrow
    type="Diagnostic.UnhandledTest"
    message="Intentional uncaught admin exception for Workstream 02 testing."
    detail="Local-only test endpoint: /admin/diagnostic_unhandled_error.cfm"
>