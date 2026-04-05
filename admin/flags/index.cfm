<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>
<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>
<cfset flagsResult = flagsService.getAllFlags()>
<cfset allFlags = flagsResult.data />

<cfset content = "
<div class='d-flex justify-content-between align-items-center mb-4'>
    <h1>User Flags</h1>
    <a href='/dir/admin/flags/new.cfm' class='btn btn-primary'>New Flag</a>
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
<table class='table table-bordered table-striped mt-4'>
    <thead class='table-dark'>
        <tr><th>Flag Name</th><th>Actions</th></tr>
    </thead>
    <tbody>
" />

<cfif arrayLen(allFlags) gt 0>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset f = allFlags[i]>
        <cfset content &= "
            <tr>
                <td>#f.FLAGNAME#</td>
                <td>
                    <a href='/dir/admin/flags/edit.cfm?flagID=#f.FLAGID#' class='btn btn-sm btn-info'>Edit</a>
                    <a href='/dir/admin/flags/delete.cfm?flagID=#f.FLAGID#' class='btn btn-sm btn-danger'>Delete</a>
                </td>
            </tr>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<tr><td colspan='2' class='text-muted'>No flags found</td></tr>">
</cfif>

<cfset content &= "
    </tbody>
</table>
" />

<cfinclude template="/dir/admin/layout.cfm">