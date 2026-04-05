<cfset content = "
<h1>Add New Flag</h1>

<form method='post' action='saveFlag.cfm' class='mt-4'>
    <div class='mb-3'>
        <label class='form-label' for='flagName'>Flag Name</label>
        <input type='text' class='form-control' id='flagName' name='FlagName' required>
    </div>

    <div class='mb-3'>
        <button type='submit' class='btn btn-success'>Create Flag</button>
        <a href='/dir/admin/flags/index.cfm' class='btn btn-secondary'>Cancel</a>
    </div>
</form>
" />

<cfinclude template="/dir/admin/layout.cfm">
