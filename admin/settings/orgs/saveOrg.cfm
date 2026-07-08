<cfif NOT request.hasPermission("orgs.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset orgsService = createObject("component", "cfc.organizations_service").init()>

<cfif !structKeyExists(form, "OrgName") OR !len(trim(form.OrgName))>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm" addtoken="false">
</cfif>

<cfset orgName = trim(form.OrgName)>
<cfset orgType = structKeyExists(form, "OrgType") ? trim(form.OrgType) : "">
<cfset orgDescription = structKeyExists(form, "OrgDescription") ? trim(form.OrgDescription) : "">
<cfset parentOrgID = (structKeyExists(form, "ParentOrgID") AND isNumeric(form.ParentOrgID)) ? val(form.ParentOrgID) : "">
<cfset additionalRoles = (structKeyExists(form, "AdditionalRoles") AND form.AdditionalRoles EQ "1") ? 1 : 0>
<cfset display = (structKeyExists(form, "display") AND form.display EQ "1") ? 1 : 0>

<cfif structKeyExists(form, "action") AND form.action EQ "update">
    <cfif !structKeyExists(form, "OrgID") OR !isNumeric(form.OrgID)>
        <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm" addtoken="false">
    </cfif>
    <cfset result = orgsService.updateOrg(val(form.OrgID), orgName, orgType, parentOrgID, additionalRoles, orgDescription, display)>
<cfelse>
    <cfset result = orgsService.createOrg(orgName, orgType, parentOrgID, additionalRoles, orgDescription, display) >
</cfif>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/orgs/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>