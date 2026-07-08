<!---
    Statistics Settings
    Permission: stats.manage
--->

<cfif NOT request.hasPermission("stats.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/feature-gates.cfm">
<cfinclude template="/admin/settings/section-status-config.cfm">

<cfset statsDAO      = createObject("component", "dao.stats_DAO").init()>
<cfset configService = createObject("component", "cfc.appConfig_service").init()>

<!--- Stat definitions. fieldKey uses underscores (no dots) for safe form field names. --->
<cfset statDefs = [
    {
        key        = "stats.dashboard.total_users",
        fieldKey   = "toggle_stats_dashboard_total_users",
        label      = "Total Users",
        description= "All users in the system",
        flags      = [],
        icon       = "bi-people-fill",
        colorClass = "stat-panel-icon--primary",
        queryType  = "users"
    },
    {
        key        = "stats.dashboard.total_faculty",
        fieldKey   = "toggle_stats_dashboard_total_faculty",
        label      = "Total Faculty",
        description= "Faculty-Fulltime, Faculty-Adjunct, Professor-Emeritus",
        flags      = ["Faculty-Fulltime","Faculty-Adjunct","Professor-Emeritus"],
        icon       = "bi-mortarboard-fill",
        colorClass = "stat-panel-icon--purple",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_faculty_fulltime",
        fieldKey   = "toggle_stats_dashboard_total_faculty_fulltime",
        label      = "Total Fulltime Faculty",
        description= "Faculty-Fulltime",
        flags      = ["Faculty-Fulltime"],
        icon       = "bi-person-workspace",
        colorClass = "stat-panel-icon--info",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_faculty_adjunct",
        fieldKey   = "toggle_stats_dashboard_total_faculty_adjunct",
        label      = "Total Adjunct Faculty",
        description= "Faculty-Adjunct",
        flags      = ["Faculty-Adjunct"],
        icon       = "bi-person-workspace",
        colorClass = "stat-panel-icon--teal",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_staff",
        fieldKey   = "toggle_stats_dashboard_total_staff",
        label      = "Total Staff",
        description= "Staff",
        flags      = ["Staff"],
        icon       = "bi-briefcase-fill",
        colorClass = "stat-panel-icon--secondary",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_residents",
        fieldKey   = "toggle_stats_dashboard_total_residents",
        label      = "Total Residents",
        description= "Resident",
        flags      = ["Resident"],
        icon       = "bi-hospital-fill",
        colorClass = "stat-panel-icon--danger",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_alumni",
        fieldKey   = "toggle_stats_dashboard_total_alumni",
        label      = "Total Alumni",
        description= "Alumni",
        flags      = ["Alumni"],
        icon       = "bi-award-fill",
        colorClass = "stat-panel-icon--warning",
        queryType  = "flags"
    },
    {
        key        = "stats.dashboard.total_published_images",
        fieldKey   = "toggle_stats_dashboard_total_published_images",
        label      = "Total Published Images",
        description= "All published images across all users",
        flags      = [],
        icon       = "bi-images",
        colorClass = "stat-panel-icon--success",
        queryType  = "images"
    },
    {
        key        = "stats.dashboard.total_publications",
        fieldKey   = "toggle_stats_dashboard_total_publications",
        label      = "Total Publications",
        description= "All publications in the system",
        flags      = [],
        icon       = "bi-journal-text",
        colorClass = "stat-panel-icon--orange",
        queryType  = "publications"
    }
]>

<cfset actionMessage = "">
<cfset actionType    = "">

<!--- POST: save toggles --->
<cfif cgi.request_method EQ "POST" AND trim(form.formAction ?: "") EQ "saveToggles">
    <cftry>
        <cfloop array="#statDefs#" index="def">
            <cfset rawVal = structKeyExists(form, def.fieldKey) ? toString(form[def.fieldKey]) : "0">
            <cfset isOn   = listFind(rawVal, "1") GT 0>
            <cfset configService.setValue(
                configKey   = def.key,
                configValue = isOn ? "1" : "0",
                description = "Dashboard visibility for: " & def.label,
                category    = "statistics"
            )>
        </cfloop>
        <cfset actionMessage = "Dashboard statistics settings saved.">
        <cfset actionType    = "success">
    <cfcatch>
        <cfset actionMessage = "Error saving settings: " & cfcatch.message>
        <cfset actionType    = "danger">
    </cfcatch>
    </cftry>
</cfif>

<!--- Load current toggle states and live counts --->
<cfset statsWithData = []>
<cfloop array="#statDefs#" index="def">
    <cfset toggleVal = configService.getValue(def.key, "0")>
    <cfset liveCount = 0>
    <cftry>
        <cfswitch expression="#def.queryType#">
            <cfcase value="users">
                <cfset liveCount = statsDAO.getTotalUsers()>
            </cfcase>
            <cfcase value="flags">
                <cfset liveCount = statsDAO.getTotalUsersByFlags(def.flags)>
            </cfcase>
            <cfcase value="images">
                <cfset liveCount = statsDAO.getTotalPublishedImages()>
            </cfcase>
            <cfcase value="publications">
                <cfset liveCount = statsDAO.getTotalPublications()>
            </cfcase>
        </cfswitch>
    <cfcatch>
        <cfset liveCount = -1>
    </cfcatch>
    </cftry>
    <cfset arrayAppend(statsWithData, {
        key        = def.key,
        fieldKey   = def.fieldKey,
        label      = def.label,
        description= def.description,
        icon       = def.icon,
        colorClass = def.colorClass,
        showOnDash = (trim(toggleVal) EQ "1"),
        liveCount  = liveCount
    })>
</cfloop>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-statistics-page">
<nav aria-label="breadcrumb">
    <ol class="breadcrumb">
        <li class="breadcrumb-item active">Statistics</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-bar-chart-fill me-2"></i>Statistics</h1>
        <p class="text-muted mb-0">Live counts shown below. Toggle which stats appear as panels on the admin dashboard.</p>
    </div>
</div>

<cfif len(actionMessage)>
    <div class="alert alert-#encodeForHTMLAttribute(actionType)# alert-dismissible fade show" role="alert">
        <i class="bi bi-#(actionType EQ 'success' ? 'check-circle' : 'exclamation-triangle')# me-2"></i>#encodeForHTML(actionMessage)#
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
</cfif>

<div class="card shadow-sm settings-shell">
    <div class="card-body">
        <form method="post">
            <input type="hidden" name="formAction" value="saveToggles">

            <table class="table settings-table align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th style="width:36px"></th>
                        <th>Statistic</th>
                        <th>Description / Flags</th>
                        <th class="text-end">Current Count</th>
                        <th class="text-center" style="width:160px">Show on Dashboard</th>
                    </tr>
                </thead>
                <tbody>
                    <cfloop array="#statsWithData#" index="stat">
                        <tr>
                            <td>
                                <div class="stat-panel-icon #encodeForHTMLAttribute(stat.colorClass)#" style="width:32px;height:32px;font-size:1rem;">
                                    <i class="bi #encodeForHTMLAttribute(stat.icon)#"></i>
                                </div>
                            </td>
                            <td class="fw-semibold">#encodeForHTML(stat.label)#</td>
                            <td class="text-muted small">#encodeForHTML(stat.description)#</td>
                            <td class="text-end">
                                <cfif stat.liveCount EQ -1>
                                    <span class="text-muted small">Error</span>
                                <cfelse>
                                    <span class="fw-bold">#numberFormat(stat.liveCount)#</span>
                                </cfif>
                            </td>
                            <td class="text-center">
                                <input type="hidden" name="#encodeForHTMLAttribute(stat.fieldKey)#" value="0">
                                <div class="form-check form-switch d-inline-block mb-0">
                                    <input class="form-check-input" type="checkbox"
                                        id="#encodeForHTMLAttribute(stat.fieldKey)#"
                                        name="#encodeForHTMLAttribute(stat.fieldKey)#"
                                        value="1"
                                        #(stat.showOnDash ? "checked" : "")#>
                                </div>
                            </td>
                        </tr>
                    </cfloop>
                </tbody>
            </table>

            <div class="mt-3 pt-3 border-top">
                <button type="submit" class="btn btn-ui-save">
                    <i class="bi bi-floppy me-1"></i>Save Dashboard Settings
                </button>
            </div>
        </form>
    </div>
</div>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
