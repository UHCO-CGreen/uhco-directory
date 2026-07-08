<!---
    API v1 Dispatcher
    Routed here via IIS URL rewrite from /api/v1/*

    URL structure:  /api/v1/{resource}/{id?}/{sub?}
    e.g.  GET /api/v1/people
          GET /api/v1/people/42
          GET /api/v1/people/42/flags
          GET /api/v1/organizations
--->
<cfset auth  = createObject("component", "api.v1.api_auth")>

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
            <!--- Guard: inactive records are treated as not found for all person endpoints --->
            <cfset _activeChk = createObject("component", "cfc.users_service").init().getUser(val(resourceID))>
            <cfif structIsEmpty(_activeChk.data) OR NOT val(_activeChk.data.ACTIVE ?: 1)>
                <cfset auth.sendError(404, "User not found")>
            </cfif>
            <cfswitch expression="#subResource#">
                <cfcase value="">       <cfinclude template="handlers/person.cfm"></cfcase>
                <cfcase value="flags">  <cfinclude template="handlers/person_flags.cfm"></cfcase>
                <cfcase value="organizations"> <cfinclude template="handlers/person_orgs.cfm"></cfcase>
                <cfcase value="academic">      <cfinclude template="handlers/person_academic.cfm"></cfcase>
                <cfcase value="addresses">     <cfinclude template="handlers/person_addresses.cfm"></cfcase>
                <cfcase value="externalids">   <cfinclude template="handlers/person_externalids.cfm"></cfcase>
                <cfcase value="images">        <cfinclude template="handlers/person_images.cfm"></cfcase>
                <cfcase value="emails">        <cfinclude template="handlers/person_emails.cfm"></cfcase>
                <cfcase value="degrees">       <cfinclude template="handlers/person_degrees.cfm"></cfcase>
                <cfcase value="studentprofile"><cfinclude template="handlers/person_studentprofile.cfm"></cfcase>
                <cfcase value="awards">        <cfinclude template="handlers/person_awards.cfm"></cfcase>
                <cfcase value="bio">           <cfinclude template="handlers/person_bio.cfm"></cfcase>
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

    <cfcase value="quickpulls">
        <cfif NOT len(resourceID)>
            <cfset auth.sendError(400, "Quickpull type is required (e.g. /quickpulls/attending)")>
        </cfif>
        <cfinclude template="handlers/quickpulls.cfm">
    </cfcase>

    <cfcase value="access">
        <cfinclude template="handlers/access.cfm">
    </cfcase>

    <cfcase value="permission-roster">
        <cfinclude template="handlers/permission_roster.cfm">
    </cfcase>

    <cfcase value="">
        <cfset auth.sendJSON({
            api     : "UHCO Directory API",
            version : "1.0",
            docs    : "/api/docs.html",
            endpoints : [
                "GET /api/v1/people",
                "GET /api/v1/people/{id}",
                "GET /api/v1/people/{id}/flags",
                "GET /api/v1/people/{id}/organizations",
                "GET /api/v1/people/{id}/academic",
                "GET /api/v1/people/{id}/addresses",
                "GET /api/v1/people/{id}/externalids",
                "GET /api/v1/people/{id}/images",
                "GET /api/v1/people/{id}/emails",
                "GET /api/v1/people/{id}/degrees",
                "GET /api/v1/people/{id}/studentprofile",
                "GET /api/v1/people/{id}/awards",
                "GET /api/v1/people/{id}/bio",
                "GET /api/v1/organizations",
                "GET /api/v1/organizations/{id}",
                "GET /api/v1/flags",
                "GET /api/v1/quickpulls/attending",
                "GET /api/v1/quickpulls/gradclass?year={year}",
                "GET /api/v1/quickpulls/graduate?id={userID}",
                "GET /api/v1/quickpulls/deans",
                "GET /api/v1/quickpulls/myuhco?id={externalID}",
                "GET /api/v1/quickpulls/myuhco-rosters?publishedOnly={true|false}",
                "GET /api/v1/access?userID={userID}",
                "GET /api/v1/permission-roster?permission={name}"
            ]
        })>
        <cfabort>
    </cfcase>

    <cfdefaultcase>
        <cfset auth.sendError(404, "Unknown resource: #EncodeForHTML(resource)#")>
    </cfdefaultcase>

</cfswitch>
