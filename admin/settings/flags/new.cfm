<cfif NOT request.hasPermission("flags.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset content = "
<div class='flags-page'>
<div class='flags-form-shell'>
<h1>Add New Flag</h1>

<form method='post' action='saveFlag.cfm' class='mt-4'>
    <div class='mb-3'>
        <label class='form-label' for='flagName'>Flag Name</label>
        <input type='text' class='form-control' id='flagName' name='FlagName' required>
    </div>

    <div class='mb-3'>
        <label class='form-label' for='flagDescription'>Description</label>
        <textarea class='form-control' id='flagDescription' name='FlagDescription' rows='4'></textarea>
    </div>

    <div class='mb-3'>
        <button type='submit' class='btn btn-ui-add'>Create Flag</button>
        <a href='/admin/settings/flags/index.cfm' class='btn btn-ui-cancel'>Cancel</a>
    </div>
</form>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">
