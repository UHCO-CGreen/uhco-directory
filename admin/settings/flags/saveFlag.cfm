<cfif NOT request.hasPermission("flags.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfparam name="form.FlagDescription" default="">

<cfif !structKeyExists(form, "FlagName") || !len(trim(form.FlagName))>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
</cfif>

<cfif structKeyExists(form, "action") && form.action == "update">
    <!--- Update existing flag --->
    <cfif !structKeyExists(form, "FlagID") || !isNumeric(form.FlagID)>
        <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
    </cfif>
    
    <cfset result = flagsService.updateFlag(form.FlagID, form.FlagName, form.FlagDescription)>
<cfelse>
    <!--- Create new flag --->
    <cfset result = flagsService.createFlag(form.FlagName, form.FlagDescription)>
</cfif>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/flags/index.cfm?error=#urlEncodedFormat(result.message)#">
</cfif>