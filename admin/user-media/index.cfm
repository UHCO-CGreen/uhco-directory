<cfif NOT request.hasPermission("media.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService     = createObject("component", "cfc.flags_service").init()>

<cfset searchTerm    = structKeyExists(url, "search") ? trim(url.search) : "">
<cfset searched      = len(searchTerm) GT 0>
<cfset allUserFlagMap = flagsService.getAllUserFlagMap()>

<cftry>
    <cfset allUsers = directoryService.listUsers()>
    <cfcatch type="any">
        <cfset allUsers = []>
    </cfcatch>
</cftry>

<!--- Apply advanced search filter using shared helper --->
<cfinclude template="/admin/users/_search_helper.cfm">
<cfset filteredUsers = allUsers>
<cfif searched>
    <cfset filteredUsers = []>
    <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
        <cfif userMatchesSearch(allUsers[i], searchTerm)>
            <cfset arrayAppend(filteredUsers, allUsers[i])>
        </cfif>
    </cfloop>
</cfif>

<cfset content = "
<div class='d-flex justify-content-between align-items-center mb-2'>
    <h1>User Media</h1>
    <div class='d-flex gap-2'>
">

<cfif request.hasPermission("media.publish")>
    <cfset content &= "
        <a href='#request.webRoot#/admin/user-media/bulk-transfer.cfm' class='btn btn-outline-secondary'>
            <i class='bi bi-arrow-left-right me-1'></i> Bulk Transfer
        </a>
    ">
</cfif>

<cfif request.hasPermission("settings.media_config.manage")>
    <cfset content &= "
        <a href='/admin/settings/media-config/filename-patterns.cfm' class='btn btn-outline-secondary'>
            <i class='bi bi-file-earmark-text me-1'></i> Filename Patterns
        </a>
        <a href='/admin/settings/media-config/variant-types.cfm' class='btn btn-outline-secondary'>
            <i class='bi bi-sliders me-1'></i> Manage Variant Types
        </a>
    ">
</cfif>

<cfset content &= "
    </div>
</div>
<p class='text-muted'>Manage images and media variants for individual users.</p>

<div class='card mb-4 users-list-filter-card'>
    <div class='card-body users-list-filter-card-body'>
        <form method='get' class='d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form'>
            <div class='input-group users-list-toolbar-search'>
                <button type='button' class='btn btn-sm btn-outline-secondary users-list-help-button' data-bs-toggle='modal' data-bs-target='##searchHelpModal' title='Search help'><i class='bi bi-question-circle'></i></button>
                <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#encodeForHTMLAttribute(searchTerm)#'>
            </div>
            <button type='submit' class='btn btn-sm btn-secondary users-list-apply-button'>
                <i class='bi bi-search'></i> Search
            </button>
">

<cfif searched>
    <cfset content &= "<a href='/admin/user-media/' class='btn btn-sm btn-warning users-list-clear-button'>Clear</a>">
</cfif>

<cfset content &= "
        </form>
    </div>
</div>
">

<cfif searched>
    <cfset resultUsers = filteredUsers>
    <cfset resultCount = arrayLen(filteredUsers)>
    <cfset pluralS = resultCount NEQ 1 ? "s" : "">
    <cfset content &= "<p class='text-muted mb-3'>#resultCount# result#pluralS# for &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo;</p>">

    <cfif arrayLen(resultUsers) GT 0>
        <cfset content &= "<div class='row row-cols-1 row-cols-md-4 row-cols-xl-5 g-4'>">

        <cfloop from="1" to="#arrayLen(resultUsers)#" index="i">
            <cfset u = resultUsers[i]>
            <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
            <cfset displayEmail = u.EMAILPRIMARY ?: "">

            <cfset content &= "
            <div class='col'>
                <div class='card h-100 shadow-sm'>
                    <div class='card-body d-flex flex-column'>
                        <h5 class='card-title mb-1'>#encodeForHTML(u.FIRSTNAME ?: "")# #encodeForHTML(u.LASTNAME ?: "")#</h5>
            ">

            <cfif len(displayEmail)>
                <cfset content &= "<p class='card-text text-muted small mb-2'><i class='bi bi-envelope'></i> #encodeForHTML(displayEmail)#</p>">
            <cfelse>
                <cfset content &= "<p class='card-text text-muted small mb-2'><span class='fst-italic'>No email on record</span></p>">
            </cfif>

            <cfif arrayLen(userFlags) GT 0>
                <cfset content &= "<div class='mb-3 d-flex flex-wrap gap-1'>">
                <cfloop from="1" to="#arrayLen(userFlags)#" index="f">
                    <cfset content &= "<span class='badge bg-secondary'>#encodeForHTML(userFlags[f].FLAGNAME)#</span>">
                </cfloop>
                <cfset content &= "</div>">
            <cfelse>
                <cfset content &= "<p class='text-muted small fst-italic mb-3'>No flags</p>">
            </cfif>

            <cfset content &= "
                        <div class='mt-auto'>
                            <a href='/admin/user-media/sources.cfm?userid=#u.USERID#' class='btn btn-sm btn-primary w-100'>
                                <i class='bi bi-images'></i> Manage Media
                            </a>
                        </div>
                    </div>
                </div>
            </div>
            ">
        </cfloop>

        <cfset content &= "</div>">
    <cfelse>
        <cfset content &= "<div class='alert alert-info'>No users found matching &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo;.</div>">
    </cfif>
<cfelse>
    <cfset content &= "
    <div class='text-center text-muted py-5'>
        <i class='bi bi-search fs-1 d-block mb-3 opacity-25'></i>
        <p>Enter a name or email above to find a user.</p>
    </div>
    ">
</cfif>


<cfinclude template="/admin/layout.cfm">