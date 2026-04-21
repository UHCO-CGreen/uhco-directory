<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset user = directoryService.getFullProfile( url.userID ).user>

<cfif structIsEmpty(user)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset content = "
<div class='alert alert-danger' role='alert'>
    <h4 class='alert-heading'>⚠️ Permanent Deletion Warning</h4>
    <p>You are about to permanently delete the following user:</p>
    <p><strong>#user.FIRSTNAME# #user.LASTNAME#</strong> (#user.EMAILPRIMARY#)</p>
    <hr>
    <p class='mb-0'><strong>This action CANNOT be undone.</strong> All associated records (including flag assignments and any related data) will also be deleted.</p>
</div>

<div class='card mb-4'>
    <div class='card-header bg-light'>
        <h5>User Details</h5>
    </div>
    <div class='card-body'>
        <p><strong>User ID:</strong> #user.USERID#</p>
        <p><strong>Name:</strong> #user.FIRSTNAME# #user.MIDDLENAME# #user.LASTNAME#</p>
        <p><strong>Primary Email:</strong> #user.EMAILPRIMARY#</p>
        <p><strong>Phone:</strong> #user.PHONE#</p>
    </div>
</div>

<div class='d-flex gap-2'>
    <form method='POST' action='/admin/users/deleteProcess.cfm' class='admin-inline-form'>
        <input type='hidden' name='userID' value='#user.USERID#'>
        <button type='submit' class='btn btn-danger btn-lg admin-delete-action' onclick='return confirm('Are you absolutely sure? This cannot be undone.');'>
            Yes, Delete Permanently
        </button>
    </form>
    <a href='/admin/users/index.cfm' class='btn btn-secondary btn-lg'>Cancel</a>
</div>
" />

<cfinclude template="/admin/layout.cfm">
