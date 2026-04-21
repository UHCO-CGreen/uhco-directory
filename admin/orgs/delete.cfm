<cfif !structKeyExists(url, "orgID") OR !isNumeric(url.orgID)>
    <cflocation url="#request.webRoot#/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "cfc.organizations_service").init()>
<cfset orgResult = orgsService.getOrg(val(url.orgID))>

<cfif NOT orgResult.success>
    <cflocation url="#request.webRoot#/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset org = orgResult.data>
<cfset orgTypeDisplay = EncodeForHTML(len(trim(org.ORGTYPE ?: '')) ? org.ORGTYPE : 'N/A')>

<cfset content = "
<div class='orgs-page'>
<div class='orgs-delete-shell'>
<h1>Delete Organization</h1>

<div class='alert alert-danger orgs-delete-alert mt-4' role='alert'>
    <h4 class='alert-heading'>Are you sure?</h4>
    <p>You are about to permanently delete this organization. All user assignments to this organization will also be removed, and any child organizations will be un-parented.</p>
</div>

<div class='orgs-delete-card mb-4'>
        <p><strong>ID:</strong> #org.ORGID#</p>
        <p><strong>Name:</strong> #EncodeForHTML(org.ORGNAME)#</p>
        <p><strong>Type:</strong> #orgTypeDisplay#</p>
</div>

<form method='post' action='confirmDelete.cfm' class='admin-inline-form'>
    <input type='hidden' name='OrgID' value='#org.ORGID#'>
    <button type='submit' class='btn btn-danger'>Delete Organization</button>
</form>
<a href='/admin/orgs/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</div>
</div>
">

<cfinclude template="/admin/layout.cfm">
