<cfif !structKeyExists(url, "systemID") OR !isNumeric(url.systemID)>
    <cflocation url="#request.webRoot#/admin/external/index.cfm" addtoken="false">
</cfif>

<cfset externalService = createObject("component", "cfc.externalID_service").init()>
<cfset systemResult = externalService.getSystem(val(url.systemID))>

<cfif NOT systemResult.success>
    <cflocation url="#request.webRoot#/admin/external/index.cfm" addtoken="false">
</cfif>

<cfset system = systemResult.data>
<cfset systemName = EncodeForHTML(system.SYSTEMNAME)>

<cfset content = "
<div class='external-page'>
<div class='external-form-shell'>
<h1>Edit External System</h1>

<form class='mt-4' method='post' action='saveExternalID.cfm'>
    <input type='hidden' name='action' value='update'>
    <input type='hidden' name='SystemID' value='#system.SYSTEMID#'>

    <div class='mb-3'>
        <label class='form-label'>System Name</label>
        <input class='form-control' name='SystemName' value='#systemName#' required>
    </div>

    <button type='submit' class='btn btn-primary'>Update System</button>
    <a href='/admin/external/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</form>

</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">
