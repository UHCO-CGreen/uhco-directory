<!---
    saveDQExclusions.cfm
    Saves data quality report exclusions for a single user.
    Expects POST: UserID, returnTo, dqInclude (multi-value checkbox list)
--->
<cfif NOT request.hasPermission("users.edit")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="form.UserID"      type="integer">
<cfparam name="form.returnTo"    default="/admin/users/index.cfm">
<cfparam name="form.dqInclude"   default="">

<cfif NOT request.canAccessUserByID(val(form.UserID))>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset allCodes = [
    "missing_uh_api_id",
    "missing_primary_alias",
    "missing_email_primary",
    "missing_email_secondary",
    "missing_title1",
    "missing_room",
    "missing_building",
    "missing_phone",
    "missing_degrees",
    "no_flags",
    "no_orgs",
    "no_images",
    "missing_cougarnet",
    "missing_peoplesoft",
    "missing_legacy_id",
    "missing_grad_year"
]>

<!--- Build set of checked (included) codes from submitted form --->
<cfset includedSet = {}>
<cfif len(trim(form.dqInclude))>
    <cfloop list="#form.dqInclude#" item="code">
        <cfset includedSet[trim(code)] = true>
    </cfloop>
</cfif>

<!--- Codes NOT checked = excluded --->
<cfset exclusionCodes = []>
<cfloop array="#allCodes#" item="code">
    <cfif NOT structKeyExists(includedSet, code)>
        <cfset arrayAppend(exclusionCodes, code)>
    </cfif>
</cfloop>

<cfset dqDAO = createObject("component", "dao.dataQuality_DAO").init()>
<cfset dqDAO.saveExclusionsForUser(form.UserID, exclusionCodes)>

<cflocation url="#form.returnTo#" addtoken="false">
