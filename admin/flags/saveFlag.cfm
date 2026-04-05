<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>

<cfif !structKeyExists(form, "FlagName") || !len(trim(form.FlagName))>
    <cflocation url="/dir/admin/flags/index.cfm">
</cfif>

<cfif structKeyExists(form, "action") && form.action == "update">
    <!--- Update existing flag --->
    <cfif !structKeyExists(form, "FlagID") || !isNumeric(form.FlagID)>
        <cflocation url="/dir/admin/flags/index.cfm">
    </cfif>
    
    <cfset result = flagsService.updateFlag(form.FlagID, form.FlagName)>
<cfelse>
    <!--- Create new flag --->
    <cfset result = flagsService.createFlag(form.FlagName)>
</cfif>

<cfif result.success>
    <cflocation url="/dir/admin/flags/index.cfm">
<cfelse>
    <cflocation url="/dir/admin/flags/index.cfm?error=#urlEncodedFormat(result.message)#">
</cfif>