<cfsetting showdebugoutput="false" requesttimeout="600">
<!---
    run_hometown_sync.cfm
    Synchronizes blank UserStudentProfile hometown city/state values from
    Hometown addresses for users flagged as Alumni or Current-Student.

    Can be triggered:
      - Manually via the scheduled tasks admin page
      - By the ColdFusion Scheduler (?triggeredBy=scheduled)
      - Programmatically with ?format=json for a JSON response
--->

<cfset triggeredBy = "manual">
<cfif structKeyExists(url, "triggeredBy") AND len(trim(url.triggeredBy))>
    <cfset triggeredBy = trim(url.triggeredBy)>
<cfelseif structKeyExists(form, "triggeredBy") AND len(trim(form.triggeredBy))>
    <cfset triggeredBy = trim(form.triggeredBy)>
</cfif>

<cfif triggeredBy NEQ "scheduled" AND NOT request.hasPermission("settings.scheduled_tasks.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset returnJson = structKeyExists(url, "format") AND lCase(trim(url.format)) EQ "json">
<cfset studentProfileService = createObject("component", "cfc.studentProfile_service").init()>

<cfset success  = false>
<cfset errorMsg = "">
<cfset result   = {}>

<cftry>
    <cfset result  = studentProfileService.syncMissingHometownsFromAddresses()>
    <cfset success = true>
<cfcatch type="any">
    <cfset errorMsg = cfcatch.message>
    <cfif len(trim(cfcatch.detail ?: ""))>
        <cfset errorMsg &= " — " & cfcatch.detail>
    </cfif>
</cfcatch>
</cftry>

<cfif returnJson>
    <cfcontent type="application/json; charset=utf-8">
    <cfif success>
        <cfoutput>#serializeJSON({
            success         : true,
            triggeredBy     : triggeredBy,
            totalCandidates : result.totalCandidates ?: 0,
            updatedProfiles : result.updatedProfiles ?: 0,
            insertedProfiles: result.insertedProfiles ?: 0,
            totalSynced     : result.totalSynced ?: 0,
            message         : result.message ?: ""
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
    <cflocation url="#request.webRoot#/admin/settings/scheduled-tasks/?msg=ran&taskKey=UHCO_HometownProfileSync&total=#urlEncodedFormat(result.totalSynced ?: 0)#&updated=#urlEncodedFormat(result.updatedProfiles ?: 0)#&inserted=#urlEncodedFormat(result.insertedProfiles ?: 0)#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/settings/scheduled-tasks/?msg=error&taskKey=UHCO_HometownProfileSync&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
</cfif>