<cfif NOT structKeyExists(request, "_sidebarRegistryLoaded")>
<cfset request._sidebarRegistryLoaded = true>
<cfset request._sidebarNavRegistry = [
    { label="Users",         icon="bi-people-fill",       href="/admin/users/index.cfm?list=all", permission="",                                          sectionKey="" },
    { label="User Media",    icon="bi-collection-fill",   href="/admin/user-media/",              permission="media.view",                                sectionKey="user-media" },
    { label="Statistics",    icon="bi-bar-chart-fill",    href="/admin/statistics/",              permission="stats.manage",                              sectionKey="statistics" },
    { label="User Review",   icon="bi-person-lines-fill", href="/admin/user-review/",             permission="user_review.manage|users.approve_user_review", sectionKey="user-review" },
    { label="Migrations",    icon="bi-mortarboard",       href="/admin/migrations/",              permission="migrations.manage",                         sectionKey="migrations" },
    { label="Rosters",       icon="bi-card-image",        href="/admin/rosters/",                 permission="rosters.manage",                            sectionKey="rosters" },
    { label="Import Data",   icon="bi-upload",            href="/admin/import/",                  permission="import.manage",                             sectionKey="import" },
    { label="Query Builder", icon="bi-database",          href="/admin/query-builder/",           permission="query_builder.use",                         sectionKey="query-builder" }
]>
</cfif>
