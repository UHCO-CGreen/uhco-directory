<cfif !structKeyExists(url, "orgID") OR !isNumeric(url.orgID)>
    <cflocation url="#request.webRoot#/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "cfc.organizations_service").init()>
<cfset orgResult = orgsService.getOrg(val(url.orgID))>

<cfif NOT orgResult.success>
    <cflocation url="#request.webRoot#/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset org = orgResult.data>
<cfset allOrgsResult = orgsService.getAllOrgs()>
<cfset allOrgs = allOrgsResult.data>

<cfset orgName    = EncodeForHTML(org.ORGNAME)>
<cfset orgType    = EncodeForHTML(len(trim(org.ORGTYPE ?: '')) ? org.ORGTYPE : '')>
<cfset orgDesc    = EncodeForHTML(len(trim(org.ORGDESCRIPTION ?: '')) ? org.ORGDESCRIPTION : '')>
<cfset orgParentID = isNumeric(org.PARENTORGID ?: '') ? val(org.PARENTORGID) : ''>
<cfset orgAdditionalRoles = (isNumeric(org.ADDITIONALROLES ?: '') AND val(org.ADDITIONALROLES) EQ 1) ? 1 : 0>
<cfset orgDisplay = (isNumeric(org.DISPLAY ?: '') AND val(org.DISPLAY) EQ 1) ? 1 : 0>

<cfset content = "
<div class='orgs-page'>
<div class='orgs-form-shell'>
<h1>Edit Organizational Unit</h1>

<form class='mt-4' method='post' action='saveOrg.cfm'>
    <input type='hidden' name='action' value='update'>
    <input type='hidden' name='OrgID' value='#org.ORGID#'>

    <div class='mb-3'>
        <label class='form-label'>Organizational Unit Name</label>
        <input class='form-control' name='OrgName' value='#orgName#' required>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Organizational Unit Type</label>
        <input class='form-control' name='OrgType' value='#orgType#'>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Description</label>
        <textarea class='form-control' name='OrgDescription' rows='3' placeholder='Optional description shown on user edit/new pages for parent organizations.'>#orgDesc#</textarea>
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
        <div class='form-text mt-1'>When enabled, a role title and display order can be set when assigning users to this organizational unit.</div>
    </div>

    <div class='mb-4'>
        <div class='form-check'>
            <input class='form-check-input' type='checkbox' name='display' value='1' id='display' #(orgDisplay ? 'checked' : '')#>
            <label class='form-check-label fw-semibold' for='display'>Displayable</label>
        </div>
        <div class='form-text mt-1'>When checked, the organizational unit will be available to be output in UI</div>
    </div>

    <button type='submit' class='btn btn-primary'>Update Organizational Unit</button>
    <a href='/admin/orgs/index.cfm' class='btn btn-secondary ms-2'>Cancel</a>
</form>

</div>
</div>
">

<cfinclude template="/admin/layout.cfm">
