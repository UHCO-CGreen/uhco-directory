<cfset orgsService = createObject("component", "dir.cfc.organizations_service").init()>

<cfif !structKeyExists(form, "OrgName") OR !len(trim(form.OrgName))>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgName = trim(form.OrgName)>
<cfset orgType = structKeyExists(form, "OrgType") ? trim(form.OrgType) : "">
<cfset parentOrgID = (structKeyExists(form, "ParentOrgID") AND isNumeric(form.ParentOrgID)) ? val(form.ParentOrgID) : "">
<cfset additionalRoles = (structKeyExists(form, "AdditionalRoles") AND form.AdditionalRoles EQ "1") ? 1 : 0>

<cfif structKeyExists(form, "action") AND form.action EQ "update">
    <cfif !structKeyExists(form, "OrgID") OR !isNumeric(form.OrgID)>
        <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
    </cfif>
    <cfset result = orgsService.updateOrg(val(form.OrgID), orgName, orgType, parentOrgID, additionalRoles)>
<cfelse>
    <cfset result = orgsService.createOrg(orgName, orgType, parentOrgID, additionalRoles)>
</cfif>

<cfif result.success>
    <cflocation url="/dir/admin/orgs/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="/dir/admin/orgs/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>