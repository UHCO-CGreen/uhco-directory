<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>
<cfset accessService = createObject("component", "dir.cfc.access_service").init()>
<cfset areasResult = accessService.getAccessAreas()>
<cfset allAreas = areasResult.data />

<cfset content = "
<h1>Access Areas</h1>

<table class='table table-striped mt-4'>
    <thead class='table-dark'>
        <tr>
            <th>Access Area</th>
            <th>Actions</th>
        </tr>
    </thead>

    <tbody>
" />

<cfif arrayLen(allAreas) gt 0>
    <cfloop from="1" to="#arrayLen(allAreas)#" index="i">
        <cfset a = allAreas[i]>
        <cfset content &= "
            <tr>
                <td>#a.ACCESSNAME#</td>
                <td>
                    <a href='/dir/admin/access/edit.cfm?areaID=#a.ACCESSAREAID#' class='btn btn-sm btn-info'>Edit</a>
                    <a href='/dir/admin/access/delete.cfm?areaID=#a.ACCESSAREAID#' class='btn btn-sm btn-danger'>Delete</a>
                </td>
            </tr>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<tr><td colspan='2' class='text-muted'>No access areas found</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>

<h3 class='mt-4'>Add New Access Area</h3>

<form class='row g-3 mt-1' method='post' action='saveAccess.cfm'>
    <div class='col-md-6'>
        <label class='form-label'>Access Name</label>
        <input class='form-control' name='AccessName'>
    </div>
    <div class='col-md-6'>
        <button class='btn btn-success mt-4'>Add Access</button>
    </div>
</form>
" />

<cfinclude template="/dir/admin/layout.cfm">