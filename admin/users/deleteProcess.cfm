<cfif !structKeyExists(form, "userID") OR !isNumeric(form.userID)>
    <cflocation url="/dir/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset usersService = createObject("component", "dir.cfc.users_service").init()>

<!--- Perform the deletion --->
<cfset result = usersService.deleteUser( form.userID )>

<cfif result.success>
    <cfset content = "
    <div class='alert alert-success alert-dismissible fade show' role='alert'>
        <h4 class='alert-heading'>✓ User Deleted</h4>
        <p>#result.message#</p>
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>

    <p><a href='/dir/admin/users/index.cfm' class='btn btn-primary'>Back to Users</a></p>
    " />
<cfelse>
    <cfset content = "
    <div class='alert alert-danger alert-dismissible fade show' role='alert'>
        <h4 class='alert-heading'>✗ Error Deleting User</h4>
        <p>#result.message#</p>
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>

    <p><a href='/dir/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a></p>
    " />
</cfif>

<cfinclude template="/dir/admin/layout.cfm">
