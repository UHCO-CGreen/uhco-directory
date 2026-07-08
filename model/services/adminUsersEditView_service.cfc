<cfcomponent output="false" displayname="AdminUsersEditViewService" hint="Render helpers for admin users edit page">

    <cffunction name="init" access="public" returntype="any" output="false">
        <cfreturn this>
    </cffunction>

    <cffunction name="renderTabActionButtonGroup" access="public" returntype="string" output="false">
        <cfargument name="refreshButtonId" type="string" required="true">

        <cfreturn "<button type='button' class='btn btn-sm btn-ui-outline' id='" & EncodeForHTMLAttribute(arguments.refreshButtonId) & "'><i class='bi bi-arrow-clockwise me-1'></i>Refresh Data</button>">
    </cffunction>

    <cffunction name="renderOrgPanels" access="public" returntype="string" output="false">
        <cfargument name="selectedOrgIDs" type="array" required="true">
        <cfargument name="orgChildrenByParent" type="struct" required="true">
        <cfargument name="orgRoleMap" type="struct" required="true">

        <cfset var html = "">
        <cfset var rootOrgs = []>
        <cfset var ro = {}>
        <cfset var children = []>
        <cfset var child = {}>
        <cfset var grandchildren = []>
        <cfset var gc = {}>
        <cfset var i = 0>
        <cfset var j = 0>
        <cfset var k = 0>
        <cfset var isRootChecked = false>
        <cfset var isChildChecked = false>
        <cfset var isGcChecked = false>
        <cfset var collapseID = "">
        <cfset var childKey = "">
        <cfset var roRoleTitle = "">
        <cfset var roRoleOrder = 0>
        <cfset var childRoleTitle = "">
        <cfset var childRoleOrder = 0>
        <cfset var childAdditionalRoles = 0>
        <cfset var gcRoleTitle = "">
        <cfset var gcRoleOrder = 0>
        <cfset var gcAdditionalRoles = 0>
        <cfset var roDesc = "">

        <cfif NOT structKeyExists(arguments.orgChildrenByParent, "ROOT") OR arrayLen(arguments.orgChildrenByParent["ROOT"]) EQ 0>
            <cfreturn "<p class='text-muted'>No organizations available</p>">
        </cfif>

        <cfset rootOrgs = arguments.orgChildrenByParent["ROOT"]>
        <cfset html = "<div class='row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3'>">

        <cfloop from="1" to="#arrayLen(rootOrgs)#" index="i">
            <cfset ro = rootOrgs[i]>
            <cfset collapseID = "orgPanel#ro.ORGID#">
            <cfset isRootChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(ro.ORGID)) GT 0>
            <cfset children = structKeyExists(arguments.orgChildrenByParent, toString(ro.ORGID)) ? arguments.orgChildrenByParent[toString(ro.ORGID)] : []>
            <cfset roRoleTitle = structKeyExists(arguments.orgRoleMap, toString(ro.ORGID)) ? arguments.orgRoleMap[toString(ro.ORGID)].roleTitle : "">
            <cfset roRoleOrder = structKeyExists(arguments.orgRoleMap, toString(ro.ORGID)) ? val(arguments.orgRoleMap[toString(ro.ORGID)].roleOrder) : 0>
            <cfset roDesc = trim(ro.ORGDESCRIPTION ?: "")>

            <cfset html &= "<div class='col'><div class='card shadow-sm h-100 users-edit-org-card card-surface'>">
            <cfset html &= "<div class='card-header d-flex align-items-center gap-2 py-2 px-3 users-edit-org-card-header'>">
            <cfset html &= "<div class='form-check mb-0 flex-grow-1 d-flex align-items-center gap-1'>">
            <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#ro.ORGID#' id='org#ro.ORGID#' data-orgid='#ro.ORGID#' data-orgname='#EncodeForHTMLAttribute(ro.ORGNAME)#' data-parentorgid='' data-panelid='#collapseID#' data-isparent='1' #(isRootChecked ? 'checked' : '')#>">
            <cfset html &= "<label class='form-check-label fw-semibold user-select-none' for='org#ro.ORGID#'>#EncodeForHTML(ro.ORGNAME)#</label>">
            <cfset html &= "</div>">
            <cfif arrayLen(children) GT 0>
                <cfset html &= "<button class='btn btn-sm border-0 text-muted p-0 ms-1 org-chevron users-edit-org-chevron' type='button' data-bs-toggle='collapse' data-bs-target='###collapseID#' aria-expanded='true'><i class='bi bi-chevron-down'></i></button>">
            </cfif>
            <cfset html &= "</div>">

            <cfif len(roDesc)>
                <cfset html &= "<div class='px-3 pt-2 pb-1 text-muted small border-bottom users-edit-org-description'>#EncodeForHTML(roDesc)#</div>">
            </cfif>

            <cfif arrayLen(children) GT 0>
                <cfset html &= "<div id='#collapseID#' class='collapse show'><div class='card-body py-2 px-3 users-edit-org-card-body'>">

                <cfloop from="1" to="#arrayLen(children)#" index="j">
                    <cfset child = children[j]>
                    <cfset isChildChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(child.ORGID)) GT 0>
                    <cfset childKey = toString(child.ORGID)>
                    <cfset grandchildren = structKeyExists(arguments.orgChildrenByParent, childKey) ? arguments.orgChildrenByParent[childKey] : []>
                    <cfset childRoleTitle = structKeyExists(arguments.orgRoleMap, childKey) ? arguments.orgRoleMap[childKey].roleTitle : "">
                    <cfset childRoleOrder = structKeyExists(arguments.orgRoleMap, childKey) ? val(arguments.orgRoleMap[childKey].roleOrder) : 0>
                    <cfset childAdditionalRoles = (isNumeric(child.ADDITIONALROLES ?: "") AND val(child.ADDITIONALROLES) EQ 1) ? 1 : 0>

                    <cfset html &= "<div class='mb-2'>">
                    <cfset html &= "<div class='form-check mb-1 d-flex align-items-center gap-1'>">
                    <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#child.ORGID#' id='org#child.ORGID#' data-orgid='#child.ORGID#' data-orgname='#EncodeForHTMLAttribute(child.ORGNAME)#' data-parentorgid='#ro.ORGID#' data-additionalroles='#childAdditionalRoles#' #(isChildChecked ? 'checked' : '')#>">
                    <cfset html &= "<label class='form-check-label user-select-none' for='org#child.ORGID#'>#EncodeForHTML(child.ORGNAME)#</label>">
                    <cfif childAdditionalRoles>
                        <cfset html &= "<button type='button' class='org-role-edit users-edit-org-role-button btn btn-sm btn-edit ms-1#(isChildChecked ? ' is-visible' : '')#' data-orgid='#child.ORGID#' data-orgname='#EncodeForHTMLAttribute(child.ORGNAME)#' title='Edit role'><i class='bi bi-pencil-square'></i></button>">
                    </cfif>
                    <cfif isChildChecked>
                        <cfset html &= "<input type='hidden' name='roleTitle_#child.ORGID#' id='roleTitle_#child.ORGID#' value='#EncodeForHTMLAttribute(childRoleTitle)#'><input type='hidden' name='roleOrder_#child.ORGID#' id='roleOrder_#child.ORGID#' value='#childRoleOrder#'>">
                    </cfif>
                    <cfset html &= "</div>">

                    <cfif arrayLen(grandchildren) GT 0>
                        <cfset html &= "<div class='ms-3'>">
                        <cfloop from="1" to="#arrayLen(grandchildren)#" index="k">
                            <cfset gc = grandchildren[k]>
                            <cfset isGcChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(gc.ORGID)) GT 0>
                            <cfset gcRoleTitle = structKeyExists(arguments.orgRoleMap, toString(gc.ORGID)) ? arguments.orgRoleMap[toString(gc.ORGID)].roleTitle : "">
                            <cfset gcRoleOrder = structKeyExists(arguments.orgRoleMap, toString(gc.ORGID)) ? val(arguments.orgRoleMap[toString(gc.ORGID)].roleOrder) : 0>
                            <cfset gcAdditionalRoles = (isNumeric(gc.ADDITIONALROLES ?: "") AND val(gc.ADDITIONALROLES) EQ 1) ? 1 : 0>
                            <cfset html &= "<div class='form-check mb-1 ms-3 d-flex align-items-center gap-1'>">
                            <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#gc.ORGID#' id='org#gc.ORGID#' data-orgid='#gc.ORGID#' data-orgname='#EncodeForHTMLAttribute(gc.ORGNAME)#' data-parentorgid='#child.ORGID#' data-additionalroles='#gcAdditionalRoles#' #(isGcChecked ? 'checked' : '')#>">
                            <cfset html &= "<label class='form-check-label user-select-none small text-muted' for='org#gc.ORGID#'>#EncodeForHTML(gc.ORGNAME)#</label>">
                            <cfif gcAdditionalRoles>
                                <cfset html &= "<button type='button' class='org-role-edit users-edit-org-role-button btn btn-sm btn-edit ms-1#(isGcChecked ? ' is-visible' : '')#' data-orgid='#gc.ORGID#' data-orgname='#EncodeForHTMLAttribute(gc.ORGNAME)#' title='Edit role'><i class='bi bi-pencil-square'></i></button>">
                            </cfif>
                            <cfif isGcChecked>
                                <cfset html &= "<input type='hidden' name='roleTitle_#gc.ORGID#' id='roleTitle_#gc.ORGID#' value='#EncodeForHTMLAttribute(gcRoleTitle)#'><input type='hidden' name='roleOrder_#gc.ORGID#' id='roleOrder_#gc.ORGID#' value='#gcRoleOrder#'>">
                            </cfif>
                            <cfset html &= "</div>">
                        </cfloop>
                        <cfset html &= "</div>">
                    </cfif>

                    <cfset html &= "</div>">
                </cfloop>

                <cfset html &= "</div></div>">
            </cfif>

            <cfset html &= "</div></div>">
        </cfloop>

        <cfset html &= "</div>">
        <cfreturn html>
    </cffunction>

</cfcomponent>