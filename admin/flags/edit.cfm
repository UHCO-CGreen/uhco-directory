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
<h1>Edit Flag</h1>

<form method='post' action='saveFlag.cfm' class='mt-4'>
    <input type='hidden' name='FlagID' value='#flag.FLAGID#'>
    <input type='hidden' name='action' value='update'>
    
    <div class='mb-3'>
        <label class='form-label' for='flagName'>Flag Name</label>
        <input type='text' class='form-control' id='flagName' name='FlagName' value='#flag.FLAGNAME#' required>
    </div>

    <div class='mb-3'>
        <button type='submit' class='btn btn-success'>Update Flag</button>
        <a href='/dir/admin/flags/index.cfm' class='btn btn-secondary'>Cancel</a>
    </div>
</form>
" />

<cfinclude template="/dir/admin/layout.cfm">
