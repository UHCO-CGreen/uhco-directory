<cfif NOT request.hasPermission("flags.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset flagsDAO = createObject("component", "dao.flags_DAO").init()>

<cfif !structKeyExists(url, "flagID") || !isNumeric(url.flagID)>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
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
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
</cfif>

<cfset content = "
<div class='flags-page'>
<div class='flags-form-shell'>
<h1>Edit Flag</h1>

<form method='post' action='saveFlag.cfm' class='mt-4'>
    <input type='hidden' name='FlagID' value='#flag.FLAGID#'>
    <input type='hidden' name='action' value='update'>
    
    <div class='mb-3'>
        <label class='form-label' for='flagName'>Flag Name</label>
        <input type='text' class='form-control' id='flagName' name='FlagName' value='#encodeForHTMLAttribute(flag.FLAGNAME)#' required>
    </div>

    <div class='mb-3'>
        <label class='form-label' for='flagDescription'>Description</label>
        <textarea class='form-control' id='flagDescription' name='FlagDescription' rows='4'>#structKeyExists(flag, "FLAGDESCRIPTION") AND NOT isNull(flag.FLAGDESCRIPTION) ? encodeForHTML(toString(flag.FLAGDESCRIPTION)) : ""#</textarea>
    </div>

    <div class='mb-3'>
        <button type='submit' class='btn btn-ui-save'>Update Flag</button>
        <a href='/admin/settings/flags/index.cfm' class='btn btn-ui-cancel'>Cancel</a>
    </div>
</form>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">
