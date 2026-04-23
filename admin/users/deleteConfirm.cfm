<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("users.delete")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset user = directoryService.getFullProfile( url.userID ).user>
<cfset aliasesSvc = createObject("component", "cfc.aliases_service").init()>
<cfset userAliases = aliasesSvc.getAliases(val(url.userID)).data>
<cfset primaryAlias = {}>
<cfset resolvedFirstName = trim(user.FIRSTNAME ?: "")>
<cfset resolvedMiddleName = trim(user.MIDDLENAME ?: "")>
<cfset resolvedLastName = trim(user.LASTNAME ?: "")>

<cfloop from="1" to="#arrayLen(userAliases)#" index="i">
    <cfif val(userAliases[i].ISPRIMARY ?: 0) EQ 1 AND val(userAliases[i].ISACTIVE ?: 0) EQ 1>
        <cfset primaryAlias = userAliases[i]>
        <cfbreak>
    </cfif>
</cfloop>

<cfif structIsEmpty(primaryAlias)>
    <cfloop from="1" to="#arrayLen(userAliases)#" index="i">
        <cfif val(userAliases[i].ISACTIVE ?: 0) EQ 1>
            <cfset primaryAlias = userAliases[i]>
            <cfbreak>
        </cfif>
    </cfloop>
</cfif>

<cfif structIsEmpty(primaryAlias) AND arrayLen(userAliases) GT 0>
    <cfset primaryAlias = userAliases[1]>
</cfif>

<cfif NOT structIsEmpty(primaryAlias)>
    <cfset resolvedFirstName = trim(primaryAlias.FIRSTNAME ?: resolvedFirstName)>
    <cfset resolvedMiddleName = trim(primaryAlias.MIDDLENAME ?: resolvedMiddleName)>
    <cfset resolvedLastName = trim(primaryAlias.LASTNAME ?: resolvedLastName)>
</cfif>

<cfif structIsEmpty(user)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset content = "
<div class='alert alert-danger' role='alert'>
    <h4 class='alert-heading'>⚠️ Permanent Deletion Warning</h4>
    <p>You are about to permanently delete the following user:</p>
    <p><strong>#resolvedFirstName# #resolvedLastName#</strong> (#user.EMAILPRIMARY#)</p>
    <hr>
    <p class='mb-0'><strong>This action CANNOT be undone.</strong> All associated records (including flag assignments and any related data) will also be deleted.</p>
</div>

<div class='card mb-4'>
    <div class='card-header bg-light'>
        <h5>User Details</h5>
    </div>
    <div class='card-body'>
        <p><strong>User ID:</strong> #user.USERID#</p>
        <p><strong>Name:</strong> #resolvedFirstName# #resolvedMiddleName# #resolvedLastName#</p>
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
