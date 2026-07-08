<cfif structKeyExists(request, "isProduction") AND request.isProduction>
    <cfheader statusCode="404">
    <cfheader name="Content-Type" value="application/json; charset=utf-8">
    <cfoutput>{"error":"Not found"}</cfoutput>
    <cfabort>
</cfif>

<cfthrow
    type="Diagnostic.UnhandledTest"
    message="Intentional uncaught API exception for Workstream 02 testing."
    detail="Local-only test endpoint: /api/v1/diagnostic_unhandled_error.cfm"
>