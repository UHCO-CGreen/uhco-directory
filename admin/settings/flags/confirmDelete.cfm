<cfif NOT request.hasPermission("flags.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset flagsService = createObject("component", "cfc.flags_service").init()>

<cfif !structKeyExists(form, "FlagID") || !isNumeric(form.FlagID)>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
</cfif>

<cfset result = flagsService.deleteFlag(form.FlagID)>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm?error=#urlEncodedFormat(result.message)#">
</cfif>
