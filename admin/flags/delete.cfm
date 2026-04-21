<cfset flagsDAO = createObject("component", "dao.flags_DAO").init()>

<cfif !structKeyExists(url, "flagID") || !isNumeric(url.flagID)>
    <cflocation url="#request.webRoot#/admin/flags/index.cfm">
</cfif>

<cfset allFlags = flagsDAO.getAllFlags()>
<cfset flag = {}>

<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfif allFlags[i].FLAGID == url.flagID>
        <cfset flag = allFlags[i]>
        <cfbreak>
    </cfif>
</cfloop>

<cfif structIsEmpty(flag)>
    <cflocation url="#request.webRoot#/admin/flags/index.cfm">
</cfif>

<cfset content = "
<div class='flags-page'>
<div class='flags-delete-shell'>
<h1 class='mb-4'>Delete Flag</h1>

<div class='alert alert-danger flags-delete-alert' role='alert'>
    <h4 class='alert-heading'>Delete Flag</h4>
    <p>Are you sure you want to delete this flag?</p>
</div>

<div class='flags-delete-card'>
        <p><strong>Flag ID:</strong> #flag.FLAGID#</p>
        <p><strong>Flag Name:</strong> #EncodeForHTML(flag.FLAGNAME)#</p>
</div>

<div class='mt-4'>
    <form method='post' action='confirmDelete.cfm' class='admin-inline-form'>
        <input type='hidden' name='FlagID' value='#flag.FLAGID#'>
        <button type='submit' class='btn btn-danger'>Delete Flag</button>
    </form>
    <a href='/admin/flags/index.cfm' class='btn btn-secondary'>Cancel</a>
</div>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">
