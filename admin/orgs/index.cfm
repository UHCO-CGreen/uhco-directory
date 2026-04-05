<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset orgsResult = orgsService.getAllOrgs()>
<cfset allOrgs = orgsResult.data />

<!--- Build name lookup and parent-keyed grouping --->
<cfset orgNameLookup = {}>
<cfset orgsByParent  = {}>
<cfset rootOrgs      = []>

<cfloop from="1" to="#arrayLen(allOrgs)#" index="i">
    <cfset orgNameLookup[toString(allOrgs[i].ORGID)] = allOrgs[i].ORGNAME>
</cfloop>

<cfloop from="1" to="#arrayLen(allOrgs)#" index="i">
    <cfset o    = allOrgs[i]>
    <cfset pVal = trim((o.PARENTORGID ?: "") & "")>
    <cfset isChild = len(pVal) AND isNumeric(pVal) AND structKeyExists(orgNameLookup, pVal)>
    <cfset pKey = isChild ? pVal : "ROOT">

    <cfif NOT structKeyExists(orgsByParent, pKey)>
        <cfset orgsByParent[pKey] = []>
    </cfif>
    <cfset arrayAppend(orgsByParent[pKey], o)>

    <cfif NOT isChild>
        <cfset arrayAppend(rootOrgs, o)>
    </cfif>
</cfloop>

<!--- Recursively collect all descendants with their nesting depth --->
<cffunction name="collectDescendants" returntype="array" access="private" output="false">
    <cfargument name="parentKey" type="string" required="true">
    <cfargument name="depth"     type="numeric" required="true">
    <cfset var result = []>
    <cfset var k      = 0>
    <cfset var child  = {}>
    <cfset var nested = []>
    <cfset var n      = 0>

    <cfif NOT structKeyExists(orgsByParent, arguments.parentKey)>
        <cfreturn result>
    </cfif>

    <cfloop from="1" to="#arrayLen(orgsByParent[arguments.parentKey])#" index="k">
        <cfset child = orgsByParent[arguments.parentKey][k]>
        <cfset arrayAppend(result, { org=child, depth=arguments.depth })>
        <cfset nested = collectDescendants(toString(child.ORGID), arguments.depth + 1)>
        <cfloop from="1" to="#arrayLen(nested)#" index="n">
            <cfset arrayAppend(result, nested[n])>
        </cfloop>
    </cfloop>

    <cfreturn result>
</cffunction>

<!--- ── Render ── --->
<cfset content = "<h1>Organizations</h1>">

<cfif arrayLen(allOrgs) EQ 0>
    <cfset content &= "<p class='text-muted mt-3'>No organizations found.</p>">
<cfelse>
    <cfset content &= "<div class='accordion mt-4' id='orgAccordion'>">

    <cfloop from="1" to="#arrayLen(rootOrgs)#" index="i">
        <cfset ro          = rootOrgs[i]>
        <cfset collapseID  = "collapseOrg" & ro.ORGID>
        <cfset headingID   = "headingOrg"  & ro.ORGID>
        <cfset descendants = collectDescendants(toString(ro.ORGID), 1)>
        <cfset hasChildren = arrayLen(descendants) GT 0>

        <!--- Pre-compute fragments to avoid nested quotes in the string --->
        <cfset ariaExpanded = (i EQ 1 AND hasChildren) ? "true" : "false">
        <cfset showClass    = (i EQ 1 AND hasChildren) ? " show" : "">
        <cfset typeHtml  = len(trim(ro.ORGTYPE ?: "")) ? " <span class='badge bg-secondary fw-normal'>" & EncodeForHTML(trim(ro.ORGTYPE)) & "</span>" : "">
        <cfset countBadge = hasChildren ? " <span class='badge bg-white text-muted border fw-normal ms-1'>" & arrayLen(descendants) & "</span>" : "">

        <cfset content &= "
        <div class='accordion-item mb-2 border rounded shadow-sm'>
            <div class='d-flex align-items-center pe-3 rounded-top' style='background:##f8f9fa;' id='#headingID#'>
                <button class='btn btn-link text-dark text-start text-decoration-none flex-grow-1 px-3 py-2 fw-semibold'
                        type='button'
                        data-bs-toggle='collapse'
                        data-bs-target='###collapseID#'
                        aria-expanded='#ariaExpanded#'
                        aria-controls='#collapseID#'>
                    #EncodeForHTML(ro.ORGNAME)##typeHtml##countBadge#
                </button>
                <div class='d-flex gap-1 flex-shrink-0'>
                    <a href='/dir/admin/orgs/edit.cfm?orgID=#ro.ORGID#'   class='btn btn-sm btn-outline-primary'>Edit</a>
                    <a href='/dir/admin/orgs/delete.cfm?orgID=#ro.ORGID#' class='btn btn-sm btn-outline-danger'>Delete</a>
                </div>
            </div>
            <div id='#collapseID#' class='accordion-collapse collapse#showClass#'>
        ">

        <cfif hasChildren>
            <cfset content &= "
                <table class='table table-sm table-hover mb-0'>
                    <thead class='table-light'>
                        <tr>
                            <th class='ps-3'>Name</th>
                            <th>Type</th>
                            <th class='text-end pe-3'>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
            ">

            <cfloop from="1" to="#arrayLen(descendants)#" index="d">
                <cfset desc   = descendants[d]>
                <cfset indent = repeatString("&nbsp;&nbsp;&nbsp;&nbsp;", desc.depth - 1)>
                <cfset prefix = desc.depth GT 1 ? indent & "&##x2514;&nbsp;" : "">
                <cfset dType  = EncodeForHTML(trim(desc.org.ORGTYPE ?: ""))>

                <cfset content &= "
                        <tr>
                            <td class='ps-3'>#prefix##EncodeForHTML(desc.org.ORGNAME)#</td>
                            <td>#dType#</td>
                            <td class='text-end pe-3'>
                                <a href='/dir/admin/orgs/edit.cfm?orgID=#desc.org.ORGID#'   class='btn btn-sm btn-outline-primary'>Edit</a>
                                <a href='/dir/admin/orgs/delete.cfm?orgID=#desc.org.ORGID#' class='btn btn-sm btn-outline-danger'>Delete</a>
                            </td>
                        </tr>
                ">
            </cfloop>

            <cfset content &= "
                    </tbody>
                </table>
            ">
        <cfelse>
            <cfset content &= "<p class='text-muted small ps-3 py-2 mb-0'>No sub-organizations.</p>">
        </cfif>

        <cfset content &= "
            </div>
        </div>
        ">
    </cfloop>

    <cfset content &= "</div>">
</cfif>

<cfset content &= "
<div class='card mt-5'>
    <div class='card-header fw-semibold'>Add New Organization</div>
    <div class='card-body'>
        <form class='row g-3' method='post' action='saveOrg.cfm'>
            <div class='col-md-4'>
                <label class='form-label'>Organization Name</label>
                <input class='form-control' name='OrgName' required>
            </div>
            <div class='col-md-4'>
                <label class='form-label'>Organization Type</label>
                <input class='form-control' name='OrgType'>
            </div>
            <div class='col-md-4'>
                <label class='form-label'>Parent Organization</label>
                <select class='form-select' name='ParentOrgID'>
                    <option value=''>-- None --</option>
">

<cfloop from="1" to="#arrayLen(rootOrgs)#" index="i">
    <cfset ro = rootOrgs[i]>
    <cfset content &= "<option value='#ro.ORGID#'>#EncodeForHTML(ro.ORGNAME)#</option>">
    <cfset descendants = collectDescendants(toString(ro.ORGID), 1)>
    <cfloop from="1" to="#arrayLen(descendants)#" index="d">
        <cfset desc   = descendants[d]>
        <cfset indent = repeatString("&nbsp;&nbsp;", desc.depth)>
        <cfset content &= "<option value='#desc.org.ORGID#'>#indent##EncodeForHTML(desc.org.ORGNAME)#</option>">
    </cfloop>
</cfloop>

<cfset content &= "
                </select>
            </div>
            <div class='col-md-4'>
                <div class='form-check mt-4 pt-2'>
                    <input class='form-check-input' type='checkbox' name='AdditionalRoles' value='1' id='newAdditionalRoles'>
                    <label class='form-check-label' for='newAdditionalRoles'>Additional Roles</label>
                </div>
                <div class='form-text'>Allow role title &amp; order when assigning users.</div>
            </div>
            <div class='col-12'>
                <button class='btn btn-success'>Add Organization</button>
            </div>
        </form>
    </div>
</div>
" />

<cfinclude template="/dir/admin/layout.cfm">