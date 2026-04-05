<cfif !structKeyExists(url, "orgID") OR !isNumeric(url.orgID)>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>
<cfset orgResult = orgsService.getOrg(val(url.orgID))>

<cfif NOT orgResult.success>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset org = orgResult.data>
<cfset allOrgsResult = orgsService.getAllOrgs()>
<cfset allOrgs = allOrgsResult.data>

<cfset orgName    = EncodeForHTML(org.ORGNAME)>
<cfset orgType    = EncodeForHTML(len(trim(org.ORGTYPE ?: '')) ? org.ORGTYPE : '')>
<cfset orgParentID = isNumeric(org.PARENTORGID ?: '') ? val(org.PARENTORGID) : ''>
<cfset orgAdditionalRoles = (isNumeric(org.ADDITIONALROLES ?: '') AND val(org.ADDITIONALROLES) EQ 1) ? 1 : 0>

<cfset content = "
<h1>Edit Organization</h1>

<form class='mt-4' method='post' action='saveOrg.cfm'>
    <input type='hidden' name='action' value='update'>
    <input type='hidden' name='OrgID' value='#org.ORGID#'>

    <div class='mb-3'>
        <label class='form-label'>Organization Name</label>
        <input class='form-control' name='OrgName' value='#orgName#' required>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Organization Type</label>
        <input class='form-control' name='OrgType' value='#orgType#'>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Parent Organization</label>
        <select class='form-select' name='ParentOrgID'>
            <option value=''>-- None --</option>
">

<cfloop from="1" to="#arrayLen(allOrgs)#" index="i">
    <cfset o = allOrgs[i]>
    <cfif o.ORGID NEQ org.ORGID>
        <cfset isSelected = (orgParentID NEQ '' AND val(orgParentID) EQ val(o.ORGID))>
        <cfset content &= "<option value='#o.ORGID#'" & (isSelected ? " selected" : "") & ">#EncodeForHTML(o.ORGNAME)#</option>">
    </cfif>
</cfloop>

<cfset content &= "
        </select>
    </div>

    <div class='mb-4'>
        <div class='form-check'>
            <input class='form-check-input' type='checkbox' name='AdditionalRoles' value='1' id='additionalRoles' #(orgAdditionalRoles ? 'checked' : '')#>
            <label class='form-check-label fw-semibold' for='additionalRoles'>Additional Roles</label>
        </div>
        <div class='form-text mt-1'>When enabled, a role title and display order can be set when assigning users to this organization.</div>
    </div>

    <button type='submit' class='btn btn-primary'>Update Organization</button>
    <a href='/dir/admin/orgs/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</form>
">

<cfinclude template="/dir/admin/layout.cfm">
