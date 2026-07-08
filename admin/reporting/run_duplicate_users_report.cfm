<cfsetting requesttimeout="1800" showdebugoutput="false">
<!---
    run_duplicate_users_report.cfm
    Executes duplicate-user detection scan and persists candidate pairs.
--->

<cfset triggeredBy = "manual">
<cfif structKeyExists(url, "triggeredBy") AND len(trim(url.triggeredBy ?: ""))>
    <cfset triggeredBy = trim(url.triggeredBy)>
<cfelseif structKeyExists(form, "triggeredBy") AND len(trim(form.triggeredBy ?: ""))>
    <cfset triggeredBy = trim(form.triggeredBy)>
</cfif>

<cfinclude template="/admin/settings/scheduled-tasks/tasks/_scheduled_task_auth.cfm">

<cfset returnJson = structKeyExists(url, "format") AND lCase(trim(url.format ?: "")) EQ "json">
<cfset scanMode = lCase(trim(url.scan ?: form.scan ?: ""))>
<cfset stageMode = lCase(trim(url.stage ?: form.stage ?: ""))>
<cfset includeDeepSignals = false>
<cfif scanMode EQ "full">
    <cfset stageMode = "all">
</cfif>
<cfset ruleMode = lCase(trim(url.mode ?: form.mode ?: ""))>

<cfif lCase(triggeredBy) NEQ "scheduled" AND NOT application.authService.hasRole("SUPER_ADMIN") AND NOT request.hasPermission("reporting.duplicate_users.manage")>
    <cfif returnJson>
        <cfheader statuscode="403">
        <cfcontent type="application/json; charset=utf-8" reset="true"><cfoutput>#serializeJSON({ success=false, error="Super admin access is required." })#</cfoutput>
        <cfabort>
    </cfif>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset duplicateSvc = createObject("component", "cfc.duplicateUsers_service").init()>
<cfset result = duplicateSvc.runScan(
    triggeredBy=triggeredBy,
    includeDeepSignals=includeDeepSignals,
    ruleMode=ruleMode,
    scanStage=stageMode
)>

<cfif returnJson>
    <cfcontent type="application/json; charset=utf-8">
    <cfoutput>#serializeJSON(result)#</cfoutput>
    <cfabort>
</cfif>

<cfif result.success>
    <cflocation url="#request.webRoot#/admin/reporting/duplicate_users_report.cfm?msg=ran&runID=#urlEncodedFormat(result.runID)#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/reporting/duplicate_users_report.cfm?msg=error&err=#urlEncodedFormat(result.message ?: 'Unknown error')#" addtoken="false">
</cfif>
