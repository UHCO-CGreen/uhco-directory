<cfif !structKeyExists(url, "orgID") OR !isNumeric(url.orgID)>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset orgResult = orgsService.getOrg(val(url.orgID))>

<cfif NOT orgResult.success>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset org = orgResult.data>
<cfset orgTypeDisplay = EncodeForHTML(len(trim(org.ORGTYPE ?: '')) ? org.ORGTYPE : 'N/A')>

<cfset content = "
<h1>Delete Organization</h1>

<div class='alert alert-danger' role='alert'>
    <h4 class='alert-heading'>Are you sure?</h4>
    <p>You are about to permanently delete this organization. All user assignments to this organization will also be removed, and any child organizations will be un-parented.</p>
</div>

<div class='card mb-4'>
    <div class='card-body'>
        <p><strong>ID:</strong> #org.ORGID#</p>
        <p><strong>Name:</strong> #EncodeForHTML(org.ORGNAME)#</p>
        <p><strong>Type:</strong> #orgTypeDisplay#</p>
    </div>
</div>

<form method='post' action='confirmDelete.cfm' style='display:inline;'>
    <input type='hidden' name='OrgID' value='#org.ORGID#'>
    <button type='submit' class='btn btn-danger'>Delete Organization</button>
</form>
<a href='/dir/admin/orgs/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
">

<cfinclude template="/dir/admin/layout.cfm">
