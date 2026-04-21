<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset externalService = createObject("component", "cfc.externalID_service").init()>
<cfset systemsResult = externalService.getSystems()>
<cfset allSystems = systemsResult.data />

<cfset content = "
<div class='external-page'>
<h1>External Systems</h1>

<div class='external-table-shell mt-4 overflow-hidden'>
<table class='table table-striped external-table'>
    <thead>
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
                <td class='external-system-name'>#EncodeForHTML(s.SYSTEMNAME)#</td>
                <td>
                    <div class='d-flex flex-wrap gap-1 align-items-start users-list-actions external-actions'>
                        <a href='/admin/external/edit.cfm?systemID=#s.SYSTEMID#' class='btn btn-sm btn-info users-list-action-button users-list-action-button-edit' title='Edit External System' data-bs-toggle='tooltip' data-bs-title='Edit External System' aria-label='Edit External System'><i class='bi bi-pencil-square'></i></a>
                        <a href='/admin/external/delete.cfm?systemID=#s.SYSTEMID#' class='btn btn-sm btn-danger users-list-action-button users-list-action-button-delete' title='Delete External System' data-bs-toggle='tooltip' data-bs-title='Delete External System' aria-label='Delete External System'><i class='bi bi-trash'></i></a>
                    </div>
                </td>
            </tr>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<tr><td colspan='2' class='text-muted external-empty-state'>No external systems found</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
</div>

<div class='card mt-5 external-add-card'>
    <div class='card-header fw-semibold'>Add New External System</div>
    <div class='card-body'>
        <form class='row g-3' method='post' action='saveExternalID.cfm'>
            <div class='col-md-6'>
                <label class='form-label'>System Name</label>
                <input class='form-control' name='SystemName'>
            </div>
            <div class='col-md-6'>
                <button class='btn btn-success mt-4'>Add System</button>
            </div>
        </form>
    </div>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">