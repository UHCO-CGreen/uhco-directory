<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>
<cfset externalService = createObject("component", "dir.cfc.externalID_service").init()>
<cfset systemsResult = externalService.getSystems()>
<cfset allSystems = systemsResult.data />

<cfset content = "
<h1>External Systems</h1>

<table class='table table-striped mt-4'>
    <thead class='table-dark'>
        <tr>
            <th>System</th>
            <th>Actions</th>
        </tr>
    </thead>

    <tbody>
" />

<cfif arrayLen(allSystems) gt 0>
    <cfloop from="1" to="#arrayLen(allSystems)#" index="i">
        <cfset s = allSystems[i]>
        <cfset content &= "
            <tr>
                <td>#s.SYSTEMNAME#</td>
                <td>
                    <a href='/dir/admin/external/edit.cfm?systemID=#s.SYSTEMID#' class='btn btn-sm btn-info'>Edit</a>
                    <a href='/dir/admin/external/delete.cfm?systemID=#s.SYSTEMID#' class='btn btn-sm btn-danger'>Delete</a>
                </td>
            </tr>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<tr><td colspan='2' class='text-muted'>No external systems found</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>

<h3 class='mt-4'>Add New External System</h3>

<form class='row g-3 mt-1' method='post' action='saveExternalID.cfm'>
    <div class='col-md-6'>
        <label class='form-label'>System Name</label>
        <input class='form-control' name='SystemName'>
    </div>
    <div class='col-md-6'>
        <button class='btn btn-success mt-4'>Add System</button>
    </div>
</form>
" />

<cfinclude template="/dir/admin/layout.cfm">