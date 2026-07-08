<cfif !structKeyExists(form, "userID") OR !isNumeric(form.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("users.delete")>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset profile = directoryService.getFullProfile(form.userID)>
<cfif NOT request.canAccessUserProfile(profile)>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>
<cfset _dpIsAlumni = false>
<cfset _dpIsFaculty = false>
<cfloop from="1" to="#arrayLen(profile.flags)#" index="_dpf">
    <cfif compareNoCase(trim(profile.flags[_dpf].FLAGNAME ?: ""), "Alumni") EQ 0>
        <cfset _dpIsAlumni = true>
    </cfif>
    <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", trim(profile.flags[_dpf].FLAGNAME ?: ""))>
        <cfset _dpIsFaculty = true>
    </cfif>
</cfloop>
<cfif _dpIsAlumni AND NOT (application.authService.hasRole("ALUMNI_ADMIN") OR (_dpIsFaculty AND application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])))>
    <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
    <cfabort>
</cfif>

<!--- Perform the deletion --->
<cfset result = usersService.deleteUser(
    userID = form.userID,
    forceDeleteRelatedDuplicatePairs = application.authService.hasRole("SUPER_ADMIN")
)>

<cfif result.success>
    <cfset content = "
    <div class='alert alert-success alert-dismissible fade show' role='alert'>
        <h4 class='alert-heading'>User Deleted</h4>
        <p>#result.message#</p>
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>

    <p><a href='/admin/users/index.cfm' class='btn btn-ui-cancel'>Back to Users</a></p>
    " />
<cfelse>
    <cfset content = "
    <div class='alert alert-danger alert-dismissible fade show' role='alert'>
        <h4 class='alert-heading'>Error Deleting User</h4>
        <p>#result.message#</p>
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>

    <p><a href='/admin/users/index.cfm' class='btn btn-ui-cancel'>Back to Users</a></p>
    " />
</cfif>

<cfinclude template="/admin/layout.cfm">
