<cfset body = toString(getHttpRequestData().content)>
<cfif len(trim(body))>
    <cflog file="csp_violations" type="information" text="#body#">
</cfif>
<cfheader statusCode="204">
<cfabort>
