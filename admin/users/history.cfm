<!---
    User Change History — All change groups for a specific user.
    Requires change_log.view permission.
--->

<cfif NOT (request.hasPermission("change_log.view") OR request.hasPermission("change_log.revert"))>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="url.userID" default="0">
<cfset userID = val(url.userID)>

<cfif userID LTE 0>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<!--- Load the user record for the page header --->
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset userResult   = usersService.getUser(userID)>
<cfif NOT userResult.success>
    <cflocation url="#request.webRoot#/admin/users/index.cfm?error=User+not+found" addtoken="false">
</cfif>
<cfset user = userResult.data>

<cfset changeLogSvc = application.changeLogSvc>
<cfset groups = changeLogSvc.getGroupsByEntity("user", toString(userID), 300)>

<cfsavecontent variable="content"><cfoutput>
<div>

<div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
    <div>
        <div class="mb-1">
            <a href="/admin/users/edit.cfm?userID=#userID#" class="btn btn-sm btn-ui-cancel">
                <i class="bi bi-arrow-left me-1"></i>Back to User
            </a>
            <a href="/admin/settings/change-log/?entityType=user" class="btn btn-sm btn-ui-go ms-1">
                <i class="bi bi-journal-text me-1"></i>Global Log
            </a>
        </div>
        <h2 class="mb-0"><i class="bi bi-clock-history me-2"></i>Change History</h2>
        <p class="text-muted mb-0 mt-1">
            #encodeForHTML(trim((user.FIRSTNAME ?: "") & " " & (user.LASTNAME ?: "")))# &mdash; User #encodeForHTML(userID)#
        </p>
    </div>
</div>

<cfif structKeyExists(url, "reverted") AND url.reverted EQ "1">
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        Change reverted successfully.
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>
<cfif structKeyExists(url, "error")>
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        <strong>Error:</strong> #encodeForHTML(url.error)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>

<cfif arrayLen(groups) EQ 0>
    <div class="alert alert-light border">
        <i class="bi bi-info-circle me-2"></i>No change history found for this user.
    </div>
<cfelse>
<div class="table-responsive">
<table class="table table-bordered table-sm table-hover">
    <thead class="table-light">
        <tr>
            <th>When (UTC)</th>
            <th>Changed By</th>
            <th>Section</th>
            <th>Description</th>
            <th>Source</th>
            <th>Status</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
    <cfloop array="#groups#" index="grp">
        <cfset isReverted = len(trim(grp["REVERTEDAT"] ?: "")) GT 0>
        <tr#isReverted ? " class='text-muted'" : ""#>
            <td class="text-nowrap small">#dateTimeFormat(grp.CREATEDAT, "yyyy-mm-dd HH:nn")#</td>
            <td class="small">#encodeForHTML(grp.CHANGEDBY ?: "")#</td>
            <td class="small">#encodeForHTML(grp.CHANGESECTION ?: "")#</td>
            <td class="small">#encodeForHTML(left(grp.DESCRIPTION ?: "", 80))#</td>
            <td class="small">
                <cfif grp.SOURCE EQ "scheduled_task"><span class="badge bg-secondary">Scheduled</span>
                <cfelseif grp.SOURCE EQ "revert"><span class="badge bg-warning text-dark">Revert</span>
                <cfelse><span class="badge bg-info text-dark">Admin</span></cfif>
            </td>
            <td class="small">
                <cfif isReverted>
                    <span class="badge bg-light text-muted border" title="Reverted by #encodeForHTMLAttribute(grp["REVERTEDBY"] ?: "")#">Reverted</span>
                <cfelse>
                    <span class="badge bg-success">Active</span>
                </cfif>
            </td>
            <td>
                <a href="/admin/settings/change-log/detail.cfm?groupID=#encodeForHTMLAttribute(grp.GROUPID)#" class="btn btn-xs btn-ui-go btn-sm py-0 px-1 small">View</a>
            </td>
        </tr>
    </cfloop>
    </tbody>
</table>
</div>
</cfif>

</div>
</cfoutput></cfsavecontent>

<cfinclude template="/admin/layout.cfm">
