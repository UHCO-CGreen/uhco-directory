<cfif NOT request.hasPermission("flags.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset flagsResult = flagsService.getAllFlags()>
<cfset allFlags = flagsResult.data />

<cfset content = "
<div class='flags-page'>
<div class='d-flex justify-content-between align-items-center mb-4 flags-header'>
    <h1>User Flags</h1>
    <a href='/admin/flags/new.cfm' class='btn btn-ui-add'><i class='bi bi-plus-circle me-1'></i>New Flag</a>
</div>
" />

<cfif structKeyExists(url, "error")>
    <cfset content &= "<div class='alert alert-danger alert-dismissible fade show' role='alert'>
        #url.error#
        <button type='button' class='btn-close' data-bs-dismiss='alert' aria-label='Close'></button>
    </div>
    ">
</cfif>

<cfset content &= "
<div class='flags-table-shell mt-4 overflow-hidden'>
<table class='table table-bordered table-striped flags-table'>
    <thead>
        <tr><th>Flag Name</th><th>Actions</th></tr>
    </thead>
    <tbody>
" />

<cfif arrayLen(allFlags) gt 0>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset f = allFlags[i]>
        <cfset content &= "
            <tr>
                <td class='flags-name'>#EncodeForHTML(f.FLAGNAME)#</td>
                <td>
                    <div class='d-flex flex-wrap gap-1 align-items-start users-list-actions flags-actions'>
                        <a href='/admin/flags/edit.cfm?flagID=#f.FLAGID#' class='btn btn-sm btn-edit users-list-action-button users-list-action-button-edit' title='Edit Flag' data-bs-toggle='tooltip' data-bs-title='Edit Flag' aria-label='Edit Flag'><i class='bi bi-pencil-square'></i></a>
                        <a href='/admin/flags/delete.cfm?flagID=#f.FLAGID#' class='btn btn-sm btn-remove users-list-action-button users-list-action-button-delete' title='Delete Flag' data-bs-toggle='tooltip' data-bs-title='Delete Flag' aria-label='Delete Flag'><i class='bi bi-trash'></i></a>
                    </div>
                </td>
            </tr>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<tr><td colspan='2' class='text-muted flags-empty-state'>No flags found</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
</div>
</div>
" />

<cfinclude template="/admin/layout.cfm">