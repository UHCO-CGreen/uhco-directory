<cfsetting requesttimeout="600">
<!---
    run_grad_migration.cfm
    Executes the student-to-alumni graduation migration.
    Can be triggered:
      - Manually via the admin UI (POST or GET with force=true)
      - By the ColdFusion Scheduler (?triggeredBy=scheduled)
      - Programmatically with ?format=json for JSON response

    Date guard: Only executes during Memorial Day weekend window
    (Saturday before through Tuesday after) unless force=true.
    Duplicate guard: Skips if a completed run exists for the target grad year.
    Auto-execute guard: If triggeredBy=scheduled and auto-execute is off, skips.
--->

<cfset triggeredBy = "manual">
<cfif structKeyExists(url, "triggeredBy") AND len(trim(url.triggeredBy))>
    <cfset triggeredBy = trim(url.triggeredBy)>
<cfelseif structKeyExists(form, "triggeredBy") AND len(trim(form.triggeredBy))>
    <cfset triggeredBy = trim(form.triggeredBy)>
</cfif>

<cfif triggeredBy NEQ "scheduled" AND NOT request.hasPermission("settings.migrations.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset returnJson = structKeyExists(url, "format") AND lCase(trim(url.format)) EQ "json">
<cfset forceRun   = structKeyExists(url, "force")  AND url.force EQ "true">

<cfset migrationService = createObject("component", "cfc.gradMigration_service").init()>

<cfset success  = false>
<cfset errorMsg = "">
<cfset result   = {}>

<cftry>
    <!--- Determine the graduating year --->
    <cfset gradWindow = migrationService.getGradYearWindow()>
    <cfset gradYear   = gradWindow.graduatingYear>
    <cfset memDay     = gradWindow.memorialDay>

    <!--- Auto-execute guard --->
    <cfif triggeredBy EQ "scheduled" AND NOT migrationService.isAutoExecuteEnabled()>
        <cfset errorMsg = "Scheduled run skipped: auto-execute is disabled.">
        <cfif returnJson>
            <cfcontent type="application/json; charset=utf-8">
            <cfoutput>#serializeJSON({ success:false, skipped:true, message:errorMsg })#</cfoutput>
            <cfabort>
        </cfif>
        <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=skipped&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
    </cfif>

    <!--- Date guard: only run during Memorial Day weekend window unless forced --->
    <cfif NOT forceRun>
        <!--- Window: Saturday before Memorial Day through Tuesday after --->
        <cfset windowStart = dateAdd("d", -2, memDay)><!--- Saturday --->
        <cfset windowEnd   = dateAdd("d",  2, memDay)><!--- Wednesday (exclusive) --->
        <cfset today = now()>
        <cfif today LT windowStart OR today GTE windowEnd>
            <cfset errorMsg = "Outside Memorial Day window (#dateFormat(windowStart,'MM/DD')# – #dateFormat(dateAdd('d',-1,windowEnd),'MM/DD')#). Use force=true to override.">
            <cfif returnJson>
                <cfcontent type="application/json; charset=utf-8">
                <cfoutput>#serializeJSON({ success:false, skipped:true, message:errorMsg })#</cfoutput>
                <cfabort>
            </cfif>
            <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=skipped&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
        </cfif>
    </cfif>

    <!--- Execute the migration --->
    <cfset result  = migrationService.execute( gradYear, triggeredBy )>
    <cfset success = result.success>
    <cfif NOT success>
        <cfset errorMsg = result.message ?: "Unknown error">
    </cfif>

<cfcatch type="any">
    <cfset errorMsg = cfcatch.message & " — " & cfcatch.detail>
</cfcatch>
</cftry>

<!--- Return JSON or redirect --->
<cfif returnJson>
    <cfcontent type="application/json; charset=utf-8">
    <cfif success>
        <cfoutput>#serializeJSON({
            success       : true,
            runID         : result.runID,
            gradYear      : result.gradYear,
            status        : result.status,
            totalTargeted : result.totalTargeted,
            totalMigrated : result.totalMigrated,
            totalErrors   : result.totalErrors,
            triggeredBy   : triggeredBy
        })#</cfoutput>
    <cfelse>
        <cfoutput>#serializeJSON({
            success : false,
            error   : errorMsg
        })#</cfoutput>
    </cfif>
    <cfabort>
</cfif>

<cfif success>
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=ran&runID=#result.runID#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=error&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
</cfif>
