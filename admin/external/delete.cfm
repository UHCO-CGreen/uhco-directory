<cfif !structKeyExists(url, "systemID") OR !isNumeric(url.systemID)>
    <cflocation url="#request.webRoot#/admin/external/index.cfm" addtoken="false">
</cfif>

<cfset externalService = createObject("component", "cfc.externalID_service").init()>
<cfset systemResult = externalService.getSystem(val(url.systemID))>

<cfif NOT systemResult.success>
    <cflocation url="#request.webRoot#/admin/external/index.cfm" addtoken="false">
</cfif>

<cfset system = systemResult.data>

<cfset content = "
<div class='external-page'>
<div class='external-delete-shell'>
<h1>Delete External System</h1>

<div class='alert alert-danger external-delete-alert mt-4' role='alert'>
    <h4 class='alert-heading'>Are you sure?</h4>
    <p>You are about to permanently delete this external system. All external IDs associated with this system will also be removed.</p>
</div>

<div class='external-delete-card mb-4'>
        <p><strong>ID:</strong> #system.SYSTEMID#</p>
        <p><strong>System Name:</strong> #EncodeForHTML(system.SYSTEMNAME)#</p>
</div>

<form method='post' action='confirmDelete.cfm' class='admin-inline-form'>
    <input type='hidden' name='SystemID' value='#system.SYSTEMID#'>
    <button type='submit' class='btn btn-danger'>Delete System</button>
</form>
<a href='/admin/external/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">
