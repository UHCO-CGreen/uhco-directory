<cfif structKeyExists(request, "isProduction") AND request.isProduction>
    <cfheader statusCode="404">
    <cfoutput>Not found</cfoutput>
    <cfabort>
</cfif>

<cfthrow
    type="Diagnostic.UnhandledTest"
    message="Intentional uncaught UserReview exception for Workstream 02 testing."
    detail="Local-only test endpoint: /userreview/diagnostic_unhandled_error.cfm"
>