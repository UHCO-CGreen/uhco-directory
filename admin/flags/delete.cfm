<cfset flagsDAO = createObject("component", "dir.dao.flags_DAO").init()>

<cfif !structKeyExists(url, "flagID") || !isNumeric(url.flagID)>
    <cflocation url="/dir/admin/flags/index.cfm">
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
    <cflocation url="/dir/admin/flags/index.cfm">
</cfif>

<cfset content = "
<div class='alert alert-danger' role='alert'>
    <h4 class='alert-heading'>Delete Flag</h4>
    <p>Are you sure you want to delete this flag?</p>
</div>

<div class='card'>
    <div class='card-body'>
        <p><strong>Flag ID:</strong> #flag.FLAGID#</p>
        <p><strong>Flag Name:</strong> #flag.FLAGNAME#</p>
    </div>
</div>

<div class='mt-4'>
    <form method='post' action='confirmDelete.cfm' style='display:inline;'>
        <input type='hidden' name='FlagID' value='#flag.FLAGID#'>
        <button type='submit' class='btn btn-danger'>Delete Flag</button>
    </form>
    <a href='/dir/admin/flags/index.cfm' class='btn btn-secondary'>Cancel</a>
</div>
" />

<cfinclude template="/dir/admin/layout.cfm">
