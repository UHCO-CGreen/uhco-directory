<!---
    API v1 Dispatcher
    Routed here via IIS URL rewrite from /dir/api/v1/*

    URL structure:  /dir/api/v1/{resource}/{id?}/{sub?}
    e.g.  GET /dir/api/v1/people
          GET /dir/api/v1/people/42
          GET /dir/api/v1/people/42/flags
          GET /dir/api/v1/organizations
--->
<cfset auth  = createObject("component", "dir.api.v1.api_auth")>

<!--- Parse path: passed by URL rewrite as _path=/people/42/flags → ["people","42","flags"] --->
<cfset pathInfo    = trim(url._path ?: "")>
<cfset pathInfo    = reReplaceNoCase(pathInfo, "^/+", "")>
<cfset segments    = len(pathInfo) ? listToArray(pathInfo, "/") : []>
<cfset resource  = arrayLen(segments) GTE 1 ? lCase(segments[1]) : "">
<cfset resourceID = arrayLen(segments) GTE 2 ? segments[2] : "">
<cfset subResource = arrayLen(segments) GTE 3 ? lCase(segments[3]) : "">
<cfset method    = uCase(CGI.REQUEST_METHOD)>

<!--- Enforce GET-only for all current endpoints --->
<cfif method NEQ "GET">
    <cfset auth.sendError(405, "Method not allowed")>
</cfif>

<!--- Route --->
<cfswitch expression="#resource#">

    <cfcase value="people">
        <cfif len(resourceID)>
            <cfif !isNumeric(resourceID)>
                <cfset auth.sendError(400, "Invalid user ID")>
            </cfif>
            <cfswitch expression="#subResource#">
                <cfcase value="">       <cfinclude template="handlers/person.cfm"></cfcase>
                <cfcase value="flags">  <cfinclude template="handlers/person_flags.cfm"></cfcase>
                <cfcase value="organizations"> <cfinclude template="handlers/person_orgs.cfm"></cfcase>
                <cfcase value="academic">      <cfinclude template="handlers/person_academic.cfm"></cfcase>
                <cfcase value="addresses">     <cfinclude template="handlers/person_addresses.cfm"></cfcase>
                <cfcase value="externalids">   <cfinclude template="handlers/person_externalids.cfm"></cfcase>
                <cfdefaultcase> <cfset auth.sendError(404, "Unknown sub-resource")> </cfdefaultcase>
            </cfswitch>
        <cfelse>
            <cfinclude template="handlers/people.cfm">
        </cfif>
    </cfcase>

    <cfcase value="organizations">
        <cfif len(resourceID)>
            <cfif !isNumeric(resourceID)>
                <cfset auth.sendError(400, "Invalid organization ID")>
            </cfif>
            <cfinclude template="handlers/org.cfm">
        <cfelse>
            <cfinclude template="handlers/orgs.cfm">
        </cfif>
    </cfcase>

    <cfcase value="flags">
        <cfinclude template="handlers/flags.cfm">
    </cfcase>

    <cfcase value="">
        <cfset auth.sendJSON({
            api     : "UHCO Directory API",
            version : "1.0",
            docs    : "/dir/api/docs.html",
            endpoints : [
                "GET /dir/api/v1/people",
                "GET /dir/api/v1/people/{id}",
                "GET /dir/api/v1/people/{id}/flags",
                "GET /dir/api/v1/people/{id}/organizations",
                "GET /dir/api/v1/people/{id}/academic",
                "GET /dir/api/v1/people/{id}/addresses",
                "GET /dir/api/v1/people/{id}/externalids",
                "GET /dir/api/v1/organizations",
                "GET /dir/api/v1/organizations/{id}",
                "GET /dir/api/v1/flags"
            ]
        })>
        <cfabort>
    </cfcase>

    <cfdefaultcase>
        <cfset auth.sendError(404, "Unknown resource: #EncodeForHTML(resource)#")>
    </cfdefaultcase>

</cfswitch>
