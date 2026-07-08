<cfif NOT request.hasPermission("external_ids.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset externalService = createObject("component", "cfc.externalID_service").init()>

<cfif !structKeyExists(form, "SystemName") OR !len(trim(form.SystemName))>
    <cflocation url="#request.webRoot#/admin/settings/external/index.cfm" addtoken="false">
</cfif>

<cfset systemName = trim(form.SystemName)>

<cfif structKeyExists(form, "action") AND form.action EQ "update">
    <cfif !structKeyExists(form, "SystemID") OR !isNumeric(form.SystemID)>
        <cflocation url="#request.webRoot#/admin/settings/external/index.cfm" addtoken="false">
    </cfif>
    <cfset result = externalService.updateSystem(val(form.SystemID), systemName)>
<cfelse>
    <cfquery datasource="#request.datasource#">
        INSERT INTO ExternalSystems (SystemName)
        VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#systemName#">)
    </cfquery>
    <cfset result = { success=true }>
</cfif>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/settings/external/index.cfm" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/external/index.cfm?error=#urlEncodedFormat(result.message)#" addtoken="false">
</cfif>