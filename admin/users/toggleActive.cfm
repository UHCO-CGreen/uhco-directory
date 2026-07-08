<!---
    toggleActive.cfm

    Accepts POST:
        userID  — required numeric
        active  — required, 0 or 1

    Returns JSON:
        { "success": true/false, "active": 0|1, "message": "..." }
--->
<cfsetting showdebugoutput="false">
<cfheader name="Content-Type" value="application/json; charset=utf-8">

<!--- Only allow POST --->
<cfif cgi.REQUEST_METHOD NEQ "POST">
    <cfoutput>{"success":false,"message":"Method not allowed."}</cfoutput>
    <cfabort>
</cfif>

<!--- Permission check --->
<cfif NOT request.hasPermission("users.edit")>
    <cfoutput>{"success":false,"message":"Unauthorized: users.edit permission required."}</cfoutput>
    <cfabort>
</cfif>

<cfparam name="form.userID" default="0">
<cfparam name="form.active" default="">

<!--- Validate userID --->
<cfif NOT (isNumeric(form.userID) AND val(form.userID) GT 0)>
    <cfoutput>{"success":false,"message":"Invalid user ID."}</cfoutput>
    <cfabort>
</cfif>

<!--- Validate active value: must be 0 or 1 --->
<cfif NOT (isNumeric(form.active) AND listFind("0,1", val(form.active)))>
    <cfoutput>{"success":false,"message":"Invalid active value."}</cfoutput>
    <cfabort>
</cfif>

<cfset targetUserID = val(form.userID)>
<cfset newActive    = val(form.active)>
<cfif NOT request.canAccessUserByID(targetUserID)>
    <cfoutput>{"success":false,"message":"Unauthorized."}</cfoutput>
    <cfabort>
</cfif>
<cfset _taFlagsSvc = createObject("component", "cfc.flags_service").init()>
<cfset _taFlags = _taFlagsSvc.getUserFlags(targetUserID).data>
<cfset _taIsAlumni = false>
<cfset _taIsFaculty = false>
<cfloop array="#_taFlags#" index="_taf">
    <cfif compareNoCase(trim(_taf.FLAGNAME ?: ""), "Alumni") EQ 0>
        <cfset _taIsAlumni = true>
    </cfif>
    <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", trim(_taf.FLAGNAME ?: ""))>
        <cfset _taIsFaculty = true>
    </cfif>
</cfloop>
<cfif _taIsAlumni AND NOT (application.authService.hasRole("ALUMNI_ADMIN") OR (_taIsFaculty AND application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])))>
    <cfheader statuscode="403" statustext="Forbidden">
    <cfoutput>{"success":false,"message":"Access denied."}</cfoutput>
    <cfabort>
</cfif>

<cftry>
    <cfset usersDAO = createObject("component", "dao.users_DAO").init()>

    <!--- Verify the user exists --->
    <cfset existingUser = usersDAO.getUserByID(targetUserID)>
    <cfif structIsEmpty(existingUser)>
        <cfoutput>{"success":false,"message":"User not found."}</cfoutput>
        <cfabort>
    </cfif>

    <!--- Update only the Active field --->
    <cfquery datasource="#request.datasource#">
        UPDATE Users
        SET    Active    = <cfqueryparam value="#newActive#" cfsqltype="cf_sql_integer">,
               UpdatedAt = GETDATE()
        WHERE  UserID   = <cfqueryparam value="#targetUserID#" cfsqltype="cf_sql_integer">
    </cfquery>

    <cfoutput>{"success":true,"active":#newActive#,"message":"Status updated."}</cfoutput>

<cfcatch>
    <cfoutput>{"success":false,"message":"An error occurred: #jsStringFormat(cfcatch.message)#"}</cfoutput>
</cfcatch>
</cftry>
