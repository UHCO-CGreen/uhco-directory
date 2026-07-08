<!---
    Change Log — Global list of all change groups.
    Requires change_log.view permission.
--->

<cfif NOT request.isSuperAdmin()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset changeLogSvc = application.changeLogSvc>

<!--- Filter params --->
<cfparam name="url.entityType" default="">
<cfparam name="url.source"     default="">
<cfparam name="url.section"    default="">
<cfparam name="url.dateFrom"   default="">
<cfparam name="url.dateTo"     default="">
<cfparam name="url.page"       default="1">

<cfset pageSize   = 50>
<cfset pageNum    = max(1, val(url.page))>
<cfset pageOffset = (pageNum - 1) * pageSize>

<cfset result = changeLogSvc.getAllGroups(
    filterEntityType = trim(url.entityType),
    filterSource     = trim(url.source),
    filterSection    = trim(url.section),
    dateFrom         = len(trim(url.dateFrom)) ? trim(url.dateFrom) & " 00:00:00" : "",
    dateTo           = len(trim(url.dateTo))   ? trim(url.dateTo)   & " 23:59:59" : "",
    maxRows          = pageSize,
    offset           = pageOffset
)>

<cfset totalCount = val(result.totalCount)>
<cfset rows       = result.rows>
<cfset totalPages = ceiling(totalCount / pageSize)>

<cfsavecontent variable="content"><cfoutput>
<div class="settings-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active">Change Log</li>
    </ol>
</nav>
<div class="d-flex justify-content-between align-items-center mb-3">
    <div>
        <h1 class="mb-0"><i class="bi bi-journal-text me-2"></i>Change Log</h1>
        <p class="text-muted mb-0 mt-1">Audit trail of all changes made within the admin.</p>
    </div>
</div>

<!--- Filters --->
<form method="get" action="/admin/settings/change-log/" class="row g-2 mb-4 align-items-end">
    <div class="col-auto">
        <label class="form-label form-label-sm">Entity Type</label>
        <select name="entityType" class="form-select form-select-sm">
            <option value="">All</option>
            <option value="user"#url.entityType EQ "user" ? " selected" : ""#>User</option>
            <option value="flag_def"#url.entityType EQ "flag_def" ? " selected" : ""#>Flag Definition</option>
            <option value="app_config"#url.entityType EQ "app_config" ? " selected" : ""#>App Config</option>
        </select>
    </div>
    <div class="col-auto">
        <label class="form-label form-label-sm">Source</label>
        <select name="source" class="form-select form-select-sm">
            <option value="">All</option>
            <option value="admin"#url.source EQ "admin" ? " selected" : ""#>Admin</option>
            <option value="scheduled_task"#url.source EQ "scheduled_task" ? " selected" : ""#>Scheduled Task</option>
            <option value="revert"#url.source EQ "revert" ? " selected" : ""#>Revert</option>
        </select>
    </div>
    <div class="col-auto">
        <label class="form-label form-label-sm">Section</label>
        <input type="text" name="section" value="#encodeForHTMLAttribute(url.section)#" class="form-control form-control-sm" placeholder="e.g. Flags">
    </div>
    <div class="col-auto">
        <label class="form-label form-label-sm">From</label>
        <input type="date" name="dateFrom" value="#encodeForHTMLAttribute(url.dateFrom)#" class="form-control form-control-sm">
    </div>
    <div class="col-auto">
        <label class="form-label form-label-sm">To</label>
        <input type="date" name="dateTo" value="#encodeForHTMLAttribute(url.dateTo)#" class="form-control form-control-sm">
    </div>
    <div class="col-auto">
        <button type="submit" class="btn btn-sm btn-ui-filter">Filter</button>
        <a href="/admin/settings/change-log/" class="btn btn-sm btn-ui-clear ms-1">Reset</a>
    </div>
</form>

<p class="text-muted small">#totalCount# total entries</p>

<div class="table-responsive">
<table class="table table-bordered table-sm table-hover">
    <thead class="table-light">
        <tr>
            <th>When</th>
            <th>Changed By</th>
            <th>Entity</th>
            <th>Section</th>
            <th>Description</th>
            <th>Source</th>
            <th>Status</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
<cfif arrayLen(rows) EQ 0>
        <tr><td colspan="8" class="text-muted text-center py-3">No entries found.</td></tr>
<cfelse>
    <cfloop array="#rows#" index="row">
        <cfset isReverted = len(trim(row["REVERTEDAT"] ?: "")) GT 0>
        <cfset entityLabel = "">
        <cfif row.ENTITYTYPE EQ "user" AND len(trim(row.ENTITYID ?: ""))>
            <cfset entityLabel = "<a href='/admin/users/edit.cfm?userID=#encodeForHTMLAttribute(row.ENTITYID)#'>User #encodeForHTML(row.ENTITYID)#</a>">
        <cfelseif len(trim(row.ENTITYTYPE ?: ""))>
            <cfset entityLabel = encodeForHTML(row.ENTITYTYPE) & (len(trim(row.ENTITYID ?: "")) ? " #encodeForHTML(row.ENTITYID)#" : "")>
        </cfif>
        <tr#isReverted ? " class='text-muted'" : ""#>
            <td class="text-nowrap small">#dateTimeFormat(row.CREATEDAT, "yyyy-mm-dd HH:nn")#</td>
            <td class="small">#encodeForHTML(row.CHANGEDBY ?: "")#</td>
            <td class="small">#entityLabel#</td>
            <td class="small">#encodeForHTML(row.CHANGESECTION ?: "")#</td>
            <td class="small">#encodeForHTML(left(row.DESCRIPTION ?: "", 80))#</td>
            <td class="small">
                <cfif row.SOURCE EQ "scheduled_task">
                    <span class="badge bg-secondary">Scheduled</span>
                <cfelseif row.SOURCE EQ "revert">
                    <span class="badge bg-warning text-dark">Revert</span>
                <cfelse>
                    <span class="badge bg-info text-dark">Admin</span>
                </cfif>
            </td>
            <td class="small">
                <cfif isReverted>
                    <span class="badge bg-light text-muted border">Reverted</span>
                <cfelse>
                    <span class="badge bg-success">Active</span>
                </cfif>
            </td>
            <td class="text-nowrap">
                <a href="/admin/settings/change-log/detail.cfm?groupID=#encodeForHTMLAttribute(row.GROUPID)#" class="btn btn-xs btn-ui-go btn-sm py-0 px-1 small">View</a>
            </td>
        </tr>
    </cfloop>
</cfif>
    </tbody>
</table>
</div>

<!--- Pagination --->
<cfif totalPages GT 1>
<nav>
<ul class="pagination pagination-sm">
    <cfif pageNum GT 1>
    <li class="page-item"><a class="page-link" href="?page=#pageNum-1#&entityType=#encodeForURL(url.entityType)#&source=#encodeForURL(url.source)#&section=#encodeForURL(url.section)#&dateFrom=#encodeForURL(url.dateFrom)#&dateTo=#encodeForURL(url.dateTo)#">&laquo; Prev</a></li>
    </cfif>
    <li class="page-item disabled"><span class="page-link">Page #pageNum# of #totalPages#</span></li>
    <cfif pageNum LT totalPages>
    <li class="page-item"><a class="page-link" href="?page=#pageNum+1#&entityType=#encodeForURL(url.entityType)#&source=#encodeForURL(url.source)#&section=#encodeForURL(url.section)#&dateFrom=#encodeForURL(url.dateFrom)#&dateTo=#encodeForURL(url.dateTo)#">Next &raquo;</a></li>
    </cfif>
</ul>
</nav>
</cfif>

</div>
</cfoutput></cfsavecontent>

<cfinclude template="/admin/layout.cfm">
