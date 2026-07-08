<cfsetting requesttimeout="300">
<!---
    run_data_quality_report.cfm
    Executes the data quality audit and stores results in DataQualityRuns / DataQualityIssues.
    Can be triggered:
      - Manually via the "Run Now" button on data_quality_report.cfm
      - By the ColdFusion Scheduler (GET request, ?triggeredBy=scheduled)
      - Programmatically with ?format=json to get a JSON response instead of a redirect
--->

<cfset triggeredBy = "manual">
<cfif structKeyExists(url, "triggeredBy") AND len(trim(url.triggeredBy))>
    <cfset triggeredBy = trim(url.triggeredBy)>
<cfelseif structKeyExists(form, "triggeredBy") AND len(trim(form.triggeredBy))>
    <cfset triggeredBy = trim(form.triggeredBy)>
</cfif>

<cfinclude template="/admin/settings/scheduled-tasks/tasks/_scheduled_task_auth.cfm">

<cfset returnJson = structKeyExists(url, "format") AND trim(url.format) EQ "json">

<cfset dqDAO     = createObject("component", "dao.dataQuality_DAO").init()>
<cfset runID     = 0>
<cfset issueCount = 0>
<cfset userCount  = 0>
<cfset success   = false>
<cfset errorMsg  = "">

<cftry>
    <cfset runID      = dqDAO.createRun(triggeredBy)>
    <cfset issueCount = dqDAO.runAuditAndInsert(runID)>
    <cfset userCount  = dqDAO.getTotalUserCount()>
    <cfset dqDAO.updateRunTotals(runID, userCount, issueCount)>
    <cfset success    = true>
<cfcatch type="any">
    <cfset errorMsg = cfcatch.message & " — " & cfcatch.detail>
</cfcatch>
</cftry>

<cfif returnJson>
    <cfcontent type="application/json; charset=utf-8">
    <cfoutput>#serializeJSON({
        success     : success,
        runID       : runID,
        totalUsers  : userCount,
        totalIssues : issueCount,
        triggeredBy : triggeredBy,
        error       : errorMsg
    })#</cfoutput>
    <cfabort>
</cfif>

<cfif success>
    <cflocation url="#request.webRoot#/admin/reporting/data_quality_report.cfm?msg=ran&runID=#runID#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/reporting/data_quality_report.cfm?msg=error&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
</cfif>
