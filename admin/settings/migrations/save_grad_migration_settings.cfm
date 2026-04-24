<!---
    save_grad_migration_settings.cfm
    Handles POST actions for the graduation migration dashboard:
      - Save settings (auto-execute toggle, notification email)
      - Rollback a migration run
--->

<cfif NOT request.hasPermission("settings.migrations.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset migrationService = createObject("component", "cfc.gradMigration_service").init()>

<!--- ── Rollback action ── --->
<cfif structKeyExists(form, "action") AND form.action EQ "rollback">
    <cfset rollbackRunID = ( structKeyExists(form, "runID") AND isNumeric(form.runID) ) ? val(form.runID) : 0>
    <cfif rollbackRunID GT 0>
        <cfset rolledBy = ( structKeyExists(session, "user") AND structKeyExists(session.user, "displayName") )
            ? session.user.displayName : "admin">
        <cftry>
            <cfset result = migrationService.rollback( rollbackRunID, rolledBy )>
            <cfif result.success>
                <cfset rolledCount = structKeyExists(result, "totalRolledBack") ? val(result.totalRolledBack) : 0>
                <cfset errCount = structKeyExists(result, "totalErrors") ? val(result.totalErrors) : 0>
                <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=rollback&runID=#rollbackRunID#&rolled=#rolledCount#&errors=#errCount#" addtoken="false">
            <cfelse>
                <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=error&err=#urlEncodedFormat(result.message)#" addtoken="false">
            </cfif>
        <cfcatch type="any">
            <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=error&err=#urlEncodedFormat(cfcatch.message)#" addtoken="false">
        </cfcatch>
        </cftry>
    </cfif>
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm" addtoken="false">
</cfif>

<!--- ── Save settings action (default) ── --->
<cftry>
    <!--- Auto-execute toggle: checkbox only submits when checked --->
    <cfset autoExec = structKeyExists(form, "autoExecute") AND form.autoExecute EQ "true">
    <cfset migrationService.setAutoExecute( autoExec )>

    <!--- Notification email --->
    <cfif structKeyExists(form, "notifyEmail")>
        <cfset migrationService.setNotifyEmail( trim(form.notifyEmail) )>
    </cfif>

    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=settings" addtoken="false">
<cfcatch type="any">
    <cflocation url="#request.webRoot#/admin/settings/migrations/grad_migration.cfm?msg=error&err=#urlEncodedFormat(cfcatch.message)#" addtoken="false">
</cfcatch>
</cftry>
