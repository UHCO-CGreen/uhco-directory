<!---
    Change Log — Detail view for a single ChangeGroup with before/after diff.
    Requires change_log.view. Revert button requires change_log.revert.
--->

<cfif NOT (request.hasPermission("change_log.view") OR request.hasPermission("change_log.revert"))>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="url.groupID" default="">

<cfif NOT len(trim(url.groupID))>
    <cflocation url="#request.webRoot#/admin/settings/change-log/" addtoken="false">
</cfif>

<cfset changeLogSvc = application.changeLogSvc>
<cfset group = changeLogSvc.getGroupByID(trim(url.groupID))>

<cfif NOT structCount(group)>
    <cflocation url="#request.webRoot#/admin/settings/change-log/?error=Group+not+found" addtoken="false">
</cfif>

<cfset isReverted    = len(trim(group["REVERTEDAT"] ?: "")) GT 0>
<cfset canRevert     = request.hasPermission("change_log.revert") AND NOT isReverted AND group.SOURCE NEQ "revert">
<cfset changes       = group.CHANGES ?: []>

<cfset csrfToken = request.adminCsrfToken ?: "">

<cfsavecontent variable="content"><cfoutput>
<div class="settings-page">

<div class="mb-3">
    <a href="/admin/settings/change-log/" class="btn btn-sm btn-ui-cancel"><i class="bi bi-arrow-left me-1"></i>Back to Change Log</a>
    <cfif group.ENTITYTYPE EQ "user" AND len(trim(group.ENTITYID ?: ""))>
        <a href="/admin/users/history.cfm?userID=#encodeForHTMLAttribute(group.ENTITYID)#" class="btn btn-sm btn-ui-go ms-1"><i class="bi bi-clock-history me-1"></i>User History</a>
        <a href="/admin/users/edit.cfm?userID=#encodeForHTMLAttribute(group.ENTITYID)#" class="btn btn-sm btn-ui-go ms-1"><i class="bi bi-person me-1"></i>View User</a>
    </cfif>
</div>

<h1 class="mb-1"><i class="bi bi-journal-text me-2"></i>Change Detail</h1>


<!--- Group metadata --->
<div class="card mb-4 border-0 shadow-sm">
    <div class="card-body">
        <div class="row g-3">
            <div class="col-sm-4">
                <p class="text-muted small mb-1">When</p>
                <p class="mb-0">#dateTimeFormat(group.CREATEDAT, "yyyy-mm-dd HH:nn:ss")# UTC</p>
            </div>
            <div class="col-sm-4">
                <p class="text-muted small mb-1">Changed By</p>
                <p class="mb-0">#encodeForHTML(group.CHANGEDBY ?: "(unknown)")#</p>
            </div>
            <div class="col-sm-4">
                <p class="text-muted small mb-1">Source</p>
                <p class="mb-0">
                    <cfif group.SOURCE EQ "scheduled_task"><span class="badge bg-secondary">Scheduled Task</span>
                    <cfelseif group.SOURCE EQ "revert"><span class="badge bg-warning text-dark">Revert</span>
                    <cfelse><span class="badge bg-info text-dark">Admin</span></cfif>
                </p>
            </div>
            <div class="col-sm-4">
                <p class="text-muted small mb-1">Entity</p>
                <p class="mb-0">
                    <cfif group.ENTITYTYPE EQ "user" AND len(trim(group.ENTITYID ?: ""))>
                        User <a href="/admin/users/edit.cfm?userID=#encodeForHTMLAttribute(group.ENTITYID)#">#encodeForHTML(group.ENTITYID)#</a>
                    <cfelse>
                        #encodeForHTML(group.ENTITYTYPE)# #encodeForHTML(group.ENTITYID ?: "")#
                    </cfif>
                </p>
            </div>
            <div class="col-sm-4">
                <p class="text-muted small mb-1">Section</p>
                <p class="mb-0">#encodeForHTML(group.CHANGESECTION ?: "")#</p>
            </div>
            <div class="col-sm-4">
                <p class="text-muted small mb-1">Status</p>
                <p class="mb-0">
                    <cfif isReverted>
                        <span class="badge bg-light text-muted border">Reverted #dateTimeFormat(group["REVERTEDAT"], "yyyy-mm-dd HH:nn")# by #encodeForHTML(group["REVERTEDBY"] ?: "")#</span>
                    <cfelse>
                        <span class="badge bg-success">Active</span>
                    </cfif>
                </p>
            </div>
            <div class="col-12">
                <p class="text-muted small mb-1">Description</p>
                <p class="mb-0">#encodeForHTML(group.DESCRIPTION ?: "")#</p>
            </div>
        </div>
    </div>
</div>

<!--- Revert action --->
<cfif canRevert>
<div class="alert alert-warning d-flex align-items-center justify-content-between mb-4">
    <div>
        <i class="bi bi-arrow-counterclockwise me-2"></i>
        <strong>Revert this change?</strong>
        All #arrayLen(changes)# table change(s) below will be undone in a single transaction.
        This action itself will be logged and cannot be un-reverted.
    </div>
    <form method="post" action="/admin/settings/change-log/revert.cfm" class="ms-3 flex-shrink-0"
          onsubmit="return confirm('Revert this change? This cannot be undone.');">
        <input type="hidden" name="groupID"    value="#encodeForHTMLAttribute(group.GROUPID)#">
        <input type="hidden" name="_csrf_token" value="#encodeForHTMLAttribute(csrfToken)#">
        <button type="submit" class="btn btn-ui-warning btn-sm">
            <i class="bi bi-arrow-counterclockwise me-1"></i>Revert
        </button>
    </form>
</div>
</cfif>

<!--- Per-table diffs --->
<h4 class="mb-3">Changed Data</h4>

<cfif arrayLen(changes) EQ 0>
    <p class="text-muted">No individual row changes were recorded for this group.</p>
<cfelse>
    <cfloop array="#changes#" index="ch">
        <cfset beforeStruct = {}>
        <cfset afterStruct  = {}>
        <cfset beforeArr    = []>
        <cfset afterArr     = []>
        <cfset isReplace    = (uCase(ch.ACTION) EQ "REPLACE")>

        <cftry>
            <cfif len(trim(ch.BEFOREJSON ?: ""))>
                <cfif isReplace>
                    <cfset beforeArr = deserializeJSON(ch.BEFOREJSON)>
                    <cfif NOT isArray(beforeArr)><cfset beforeArr = [beforeArr]></cfif>
                <cfelse>
                    <cfset beforeStruct = deserializeJSON(ch.BEFOREJSON)>
                </cfif>
            </cfif>
            <cfif len(trim(ch.AFTERJSON ?: ""))>
                <cfif isReplace>
                    <cfset afterArr = deserializeJSON(ch.AFTERJSON)>
                    <cfif NOT isArray(afterArr)><cfset afterArr = [afterArr]></cfif>
                <cfelse>
                    <cfset afterStruct = deserializeJSON(ch.AFTERJSON)>
                </cfif>
            </cfif>
        <cfcatch><cfset beforeStruct = {}><cfset afterStruct = {}></cfcatch>
        </cftry>

        <div class="card mb-3 border-0 shadow-sm">
            <div class="card-header d-flex justify-content-between align-items-center bg-light">
                <strong>#encodeForHTML(ch.TABLENAME)#</strong>
                <span class="badge
                    #uCase(ch.ACTION) EQ "INSERT" ? "bg-success" :
                     uCase(ch.ACTION) EQ "DELETE" ? "bg-danger"  :
                     uCase(ch.ACTION) EQ "UPDATE" ? "bg-primary" : "bg-secondary"#">
                    #encodeForHTML(ch.ACTION)#
                </span>
            </div>
            <div class="card-body p-0">

            <cfif isReplace>
                <!--- REPLACE: show count summary and collapsible before/after arrays --->
                <div class="p-3">
                    <p class="mb-1 small text-muted">
                        Before: #arrayLen(beforeArr)# row(s) &rarr; After: #arrayLen(afterArr)# row(s)
                    </p>
                    <cfif arrayLen(beforeArr) GT 0>
                        <details class="mt-2">
                            <summary class="text-muted small" style="cursor:pointer">Before rows</summary>
                            <pre class="mt-2 p-2 bg-light rounded small" style="max-height:200px;overflow:auto;">#encodeForHTML(serializeJSON(beforeArr))#</pre>
                        </details>
                    </cfif>
                    <cfif arrayLen(afterArr) GT 0>
                        <details class="mt-2">
                            <summary class="text-muted small" style="cursor:pointer">After rows</summary>
                            <pre class="mt-2 p-2 bg-light rounded small" style="max-height:200px;overflow:auto;">#encodeForHTML(serializeJSON(afterArr))#</pre>
                        </details>
                    </cfif>
                </div>
            <cfelse>
                <!--- UPDATE / INSERT / DELETE: show field-level diff --->
                <cfset allCols = []>
                <cfif structCount(beforeStruct) GT 0>
                    <cfloop collection="#beforeStruct#" item="k"><cfset arrayAppend(allCols, k)></cfloop>
                <cfelseif structCount(afterStruct) GT 0>
                    <cfloop collection="#afterStruct#" item="k"><cfset arrayAppend(allCols, k)></cfloop>
                </cfif>
                <cfset arraySort(allCols, "textNoCase")>

                <cfif arrayLen(allCols) GT 0>
                <table class="table table-sm table-bordered mb-0 small">
                    <thead class="table-light">
                        <tr><th>Field</th><th class="text-danger">Before</th><th class="text-success">After</th></tr>
                    </thead>
                    <tbody>
                    <cfloop array="#allCols#" index="col">
                        <cfset bVal = structKeyExists(beforeStruct, col) ? toString(beforeStruct[col] ?: "") : "(none)">
                        <cfset aVal = structKeyExists(afterStruct,  col) ? toString(afterStruct[col]  ?: "") : "(none)">
                        <cfset isDiff = (bVal NEQ aVal)>
                        <tr#isDiff ? " class='table-warning'" : ""#>
                            <td><code>#encodeForHTML(col)#</code></td>
                            <td class="text-danger">#encodeForHTML(bVal)#</td>
                            <td class="text-success">#encodeForHTML(aVal)#</td>
                        </tr>
                    </cfloop>
                    </tbody>
                </table>
                </cfif>
            </cfif>

            </div>
        </div>
    </cfloop>
</cfif>

</div>
</cfoutput></cfsavecontent>

<cfsavecontent variable="pageScripts">
<cfoutput>
<script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#">
<cfif structKeyExists(url, "reverted") AND url.reverted EQ "1">
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("Change reverted successfully.", { tone: 'success' });
}
</cfif>
<cfif structKeyExists(url, "error")>
if (window.AdminUI && typeof window.AdminUI.showToast === 'function') {
    window.AdminUI.showToast("Revert failed: #encodeForJavaScript(url.error)#", { tone: 'danger' });
}
</cfif>
</script>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
