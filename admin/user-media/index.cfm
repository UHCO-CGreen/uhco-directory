<cfif NOT request.hasPermission("media.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset canManageMedia = request.hasPermission("media.edit")>
<cfset requestedMode = structKeyExists(url, "mode") ? lCase(trim(url.mode)) : "">
<cfset legacyNeedsPublishingOnly = structKeyExists(url, "needsPublishingOnly") AND val(url.needsPublishingOnly) EQ 1>
<cfif legacyNeedsPublishingOnly AND NOT len(requestedMode)>
    <cfset requestedMode = "needs">
</cfif>
<cfif NOT listFindNoCase("view,manage,needs", requestedMode)>
    <cfset requestedMode = canManageMedia ? "manage" : "view">
</cfif>
<cfif requestedMode EQ "view" OR NOT canManageMedia>
    <cfset activeMode = "view">
<cfelse>
    <cfset activeMode = requestedMode>
</cfif>

<cfset searchTerm = structKeyExists(url, "search") ? trim(url.search) : "">
<cfset variantFilter = structKeyExists(url, "variant") ? trim(url.variant) : "">
<cfset searched = len(searchTerm) GT 0>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset imagesService = createObject("component", "cfc.images_service").init()>
<cfset allUserFlagMap = {}>
<cfset allUsers = []>
<cfset usersByID = {}>
<cfset loadUsersForMode = activeMode EQ "manage" AND searched>

<cfif loadUsersForMode>
    <cftry>
        <cfset allUsers = directoryService.listUsersForAdminIndex()>
        <cfcatch type="any">
            <cfset allUsers = []>
        </cfcatch>
    </cftry>

    <cfloop array="#allUsers#" index="directoryUserRow">
        <cfif structKeyExists(directoryUserRow, "USERID") AND isNumeric(directoryUserRow.USERID)>
            <cfset usersByID[toString(val(directoryUserRow.USERID))] = directoryUserRow>
        </cfif>
    </cfloop>
</cfif>

<cfset publishedImageTotalCountResult = imagesService.getPublishedImageTotalCount()>
<cfset totalPublishedImageCount = publishedImageTotalCountResult.success ? val(publishedImageTotalCountResult.data) : 0>
<cfset needsPublishingCountResult = imagesService.getNeedsPublishingUserCount()>
<cfset needsPublishingUserCount = needsPublishingCountResult.success ? val(needsPublishingCountResult.data) : 0>
<cfset needsPublishingUserRows = []>
<cfset filteredNeedsPublishingRows = []>

<!--- Shared search function + helper modal --->
<cfinclude template="/admin/users/_search_helper.cfm">

<cfset filteredUsers = allUsers>

<cfset availableVariantList = []>
<cfset pagedPublishedUsers = []>
<cfset pageSize = 25>
<cfset requestedPage = structKeyExists(url, "page") AND isNumeric(url.page) ? val(url.page) : 1>
<cfset currentPage = requestedPage GT 0 ? requestedPage : 1>
<cfset totalPages = 1>
<cfset totalFilteredUsers = 0>

<cfif activeMode EQ "needs">
    <cfset needsPublishingQueueResult = imagesService.getNeedsPublishingQueue()>
    <cfset needsPublishingUserRows = needsPublishingQueueResult.success ? needsPublishingQueueResult.data : []>
</cfif>

<cfif activeMode EQ "manage">
    <cfset filteredUsers = allUsers>
    <cfif searched>
        <cfset filteredUsers = []>
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfif userMatchesSearch(allUsers[i], searchTerm)>
                <cfset arrayAppend(filteredUsers, allUsers[i])>
            </cfif>
        </cfloop>

        <cfif arrayLen(filteredUsers) GT 0>
            <cfset allUserFlagMap = flagsService.getAllUserFlagMap()>
        </cfif>
    </cfif>
</cfif>

<cfif activeMode EQ "needs">
    <cfset filteredNeedsPublishingRows = needsPublishingUserRows>
    <cfif searched>
        <cfset filteredNeedsPublishingRows = []>
        <cfloop array="#needsPublishingUserRows#" index="queueCandidateRow">
            <cfset queueUserKey = toString(val(queueCandidateRow.USERID ?: 0))>
            <cfif userMatchesSearch(queueCandidateRow, searchTerm) OR findNoCase(searchTerm, queueUserKey) GT 0>
                <cfset arrayAppend(filteredNeedsPublishingRows, queueCandidateRow)>
            </cfif>
        </cfloop>
    </cfif>
</cfif>

<cfif activeMode EQ "view">
    <cfset publishedVariantListResult = imagesService.getPublishedVariantList()>
    <cfset availableVariantList = publishedVariantListResult.success ? publishedVariantListResult.data : []>
    <cfset publishedSummaryCountResult = imagesService.getPublishedUserSummaryCount(searchTerm = searchTerm, variantFilter = variantFilter)>
    <cfset totalFilteredUsers = publishedSummaryCountResult.success ? val(publishedSummaryCountResult.data) : 0>

    <cfif totalFilteredUsers GT 0>
        <cfset totalPages = ceiling(totalFilteredUsers / pageSize)>
        <cfif currentPage GT totalPages>
            <cfset currentPage = totalPages>
        </cfif>
        <cfset publishedSummaryPageResult = imagesService.getPublishedUserSummaryPage(
            pageSize = pageSize,
            pageNumber = currentPage,
            searchTerm = searchTerm,
            variantFilter = variantFilter
        )>
        <cfset pagedPublishedUsers = publishedSummaryPageResult.success ? publishedSummaryPageResult.data : []>
    </cfif>
</cfif>

<cfset pageTitle = "User Media">

<cfsavecontent variable="content">
<cfoutput>
<div class="users-page-secondary-toolbar mb-4">
    <div class="users-page-secondary-toolbar-heading">
        <span class="users-page-secondary-toolbar-eyebrow">Media Administration</span>
        <h1 class="users-page-secondary-toolbar-title">User Media</h1>
        <div class="users-page-secondary-toolbar-meta">Browse published images and manage publication workflows for user media.</div>
    </div>
    <div class="users-page-secondary-toolbar-actions">
        <cfif request.hasPermission("media.publish")>
            <a href="#request.webRoot#/admin/user-media/bulk-transfer.cfm" class="btn btn-sm btn-ui-go">
                <i class="bi bi-arrow-left-right me-1"></i>Bulk Transfer
            </a>
        </cfif>
        <cfif request.hasPermission("settings.media_config.manage")>
            <a href="/admin/settings/media-config/filename-patterns.cfm" class="btn btn-sm btn-ui-go">
                <i class="bi bi-file-earmark-text me-1"></i>Filename Patterns
            </a>
            <a href="/admin/settings/media-config/variant-types.cfm" class="btn btn-sm btn-ui-go">
                <i class="bi bi-sliders me-1"></i>Variant Types
            </a>
        </cfif>
    </div>
</div>

<ul class="nav nav-pills mb-4 users-edit-tabs" role="tablist" aria-label="User media modes">
    <li class="nav-item" role="presentation">
        <a class="nav-link <cfif activeMode EQ 'view'>active</cfif>" href="#request.webRoot#/admin/user-media/index.cfm?mode=view">
            <i class="bi bi-eye me-1"></i>View Published
            <span class="badge ms-1 <cfif activeMode EQ 'view'>text-bg-light<cfelse>text-bg-secondary</cfif>">#totalPublishedImageCount#</span>
        </a>
    </li>
    <cfif canManageMedia>
        <li class="nav-item" role="presentation">
            <a class="nav-link <cfif activeMode EQ 'manage'>active</cfif>" href="#request.webRoot#/admin/user-media/index.cfm?mode=manage">
                <i class="bi bi-gear me-1"></i>Manage Published Media
            </a>
        </li>
        <li class="nav-item" role="presentation">
            <a class="nav-link <cfif activeMode EQ 'needs'>active</cfif>" href="#request.webRoot#/admin/user-media/index.cfm?mode=needs">
                <cfif needsPublishingUserCount GT 0><i class="bi bi-exclamation-circle-fill text-warning me-1"></i></cfif>Needs Publishing
            </a>
        </li>
    </cfif>
</ul>

<cfif activeMode EQ "view">
    <p class="text-muted">Browse published images across all users. Filter by user details, variant code, or user ID.</p>

    <div class="card mb-4 users-list-filter-card">
        <div class="card-body users-list-filter-card-body">
            <form method="get" class="d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form">
                <input type="hidden" name="mode" value="view">
                <div class="input-group users-list-toolbar-search">
                    <button type="button" class="btn btn-sm btn-ui-help users-list-help-button" data-bs-toggle="modal" data-bs-target="##searchHelpModal" title="Search help"><i class="bi bi-question-circle"></i></button>
                    <input type="text" name="search" class="form-control" placeholder="Search user name/email, userID, or variant" value="#encodeForHTMLAttribute(searchTerm)#">
                </div>
                <select name="variant" class="form-select form-select-sm" style="max-width:220px;">
                    <option value="">All variants</option>
                    <cfloop array="#availableVariantList#" index="variantOption">
                        <option value="#encodeForHTMLAttribute(variantOption)#" <cfif compareNoCase(variantOption, variantFilter) EQ 0>selected</cfif>>#encodeForHTML(variantOption)#</option>
                    </cfloop>
                </select>
                <button type="submit" class="btn btn-sm btn-ui-filter users-list-apply-button">
                    <i class="bi bi-search"></i> Filter
                </button>
                <cfif searched OR len(variantFilter)>
                    <a href="#request.webRoot#/admin/user-media/index.cfm?mode=view" class="btn btn-sm btn-warning users-list-clear-button">Clear</a>
                </cfif>
            </form>
        </div>
    </div>

    <p class="text-muted mb-3">#totalFilteredUsers# user<cfif totalFilteredUsers NEQ 1>s</cfif> found with published media (#totalPublishedImageCount# images total).</p>

    <cfif totalFilteredUsers>
        <div class="row row-cols-1 row-cols-lg-3 g-3">
            <cfloop array="#pagedPublishedUsers#" index="userStatRow">
                <cfset rowUserID = val(userStatRow.userID)>
                <cfset displayName = trim((userStatRow.FIRSTNAME ?: "") & " " & (userStatRow.LASTNAME ?: ""))>
                <cfif NOT len(displayName)>
                    <cfset displayName = "User ID " & rowUserID>
                </cfif>
                <cfset thumbURL = len(trim(userStatRow.webThumbURL ?: ""))
                    ? trim(userStatRow.webThumbURL)
                    : (len(trim(userStatRow.legacyAlumniURL ?: "")) ? trim(userStatRow.legacyAlumniURL) : "")>
                <cfset thumbVariantLabel = len(trim(userStatRow.webThumbURL ?: "")) ? "WEB_THUMB" : "legacy_alumni">

                <div class="col">
                    <div class="card h-100 shadow-sm">
                        <div class="card-body d-flex flex-column gap-3">
                            <div class="d-flex align-items-start gap-3">
                                <div class="flex-shrink-0">
                                    <cfif len(thumbURL)>
                                        <img src="#encodeForHTMLAttribute(thumbURL)#" alt="#encodeForHTMLAttribute(thumbVariantLabel)# for #encodeForHTMLAttribute(displayName)#" style="width:96px; height:96px; object-fit:cover; border-radius:.5rem;">
                                    <cfelse>
                                        <div class="d-flex align-items-center justify-content-center bg-light border rounded" style="width:96px; height:96px;">
                                            <i class="bi bi-image text-muted"></i>
                                        </div>
                                    </cfif>
                                </div>
                                <div class="min-w-0 flex-grow-1">
                                    <h5 class="mb-1">#encodeForHTML(displayName)#</h5>
                                    <div class="d-flex flex-wrap gap-2 mb-1">
                                        <span class="badge text-bg-secondary">User ID #rowUserID#</span>
                                        <span class="badge text-bg-primary">#userStatRow.totalPublished# published image<cfif userStatRow.totalPublished NEQ 1>s</cfif></span>
                                    </div>
                                    <cfif len(trim(userStatRow.EMAILPRIMARY ?: ""))>
                                        <div class="small text-muted"><i class="bi bi-envelope"></i> #encodeForHTML(userStatRow.EMAILPRIMARY)#</div>
                                    </cfif>
                                    <cfif structKeyExists(userStatRow, "latestPublishedAt") AND len(userStatRow.latestPublishedAt)>
                                        <div class="small text-muted">Last published: #dateTimeFormat(userStatRow.latestPublishedAt, "mm/dd/yyyy h:nn tt")#</div>
                                    </cfif>
                                </div>
                            </div>

                            <div class="mt-auto d-flex flex-column gap-2">
                                <div class="btn-group w-100" role="group">
                                    <a href="/admin/users/view.cfm?userID=#rowUserID#" class="btn btn-ui-go" title="View user details and media activity for this user">
                                        <i class="bi bi-eye me-1"></i>Open User Profile
                                    </a>
                                    <cfif canManageMedia>
                                        <a href="/admin/user-media/sources.cfm?userid=#rowUserID#" class="btn btn-ui-go" title="Manage media sources and published images for this user">
                                            <i class="bi bi-images me-1"></i>Manage Media
                                        </a>
                                        <a href="/admin/user-media/variants.cfm?userid=#rowUserID#" class="btn btn-ui-go" title="Manage image variants for this user">
                                            <i class="bi bi-sliders me-1"></i>Manage Variants
                                        </a>
                                    </cfif>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </cfloop>
        </div>

        <cfif totalPages GT 1>
            <cfset pageBaseUrl = request.webRoot & "/admin/user-media/index.cfm?mode=view" & (searched ? "&search=" & urlEncodedFormat(searchTerm) : "") & (len(variantFilter) ? "&variant=" & urlEncodedFormat(variantFilter) : "")>
            <nav class="mt-4" aria-label="Published user media pages">
                <ul class="pagination pagination-sm flex-wrap mb-0">
                    <li class="page-item <cfif currentPage EQ 1>disabled</cfif>">
                        <a class="page-link" href="#pageBaseUrl#&page=#currentPage - 1#">Previous</a>
                    </li>
                    <cfloop from="1" to="#totalPages#" index="pageNum">
                        <li class="page-item <cfif pageNum EQ currentPage>active</cfif>">
                            <a class="page-link" href="#pageBaseUrl#&page=#pageNum#">#pageNum#</a>
                        </li>
                    </cfloop>
                    <li class="page-item <cfif currentPage EQ totalPages>disabled</cfif>">
                        <a class="page-link" href="#pageBaseUrl#&page=#currentPage + 1#">Next</a>
                    </li>
                </ul>
            </nav>
        </cfif>
    <cfelse>
        <div class="alert alert-info">No published media matches the current filters.</div>
    </cfif>
<cfelse>
    <p class="text-muted"><cfif activeMode EQ "needs">Review users who still need media publication follow-up.<cfelse>Search for a user to manage published media, sources, and variants.</cfif></p>

    <div class="card mb-4 users-list-filter-card">
        <div class="card-body users-list-filter-card-body">
            <form method="get" class="d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form">
                <input type="hidden" name="mode" value="#activeMode#">
                <div class="input-group users-list-toolbar-search">
                    <button type="button" class="btn btn-sm btn-ui-help users-list-help-button" data-bs-toggle="modal" data-bs-target="##searchHelpModal" title="Search help"><i class="bi bi-question-circle"></i></button>
                    <input type="text" name="search" class="form-control" placeholder="Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)" value="#encodeForHTMLAttribute(searchTerm)#">
                </div>
                <button type="submit" class="btn btn-sm btn-ui-filter users-list-apply-button">
                    <i class="bi bi-search"></i> Search
                </button>
                <cfif searched>
                    <a href="#request.webRoot#/admin/user-media/index.cfm?mode=#activeMode#" class="btn btn-sm btn-warning users-list-clear-button">Clear</a>
                </cfif>
            </form>
        </div>
    </div>

    <cfif activeMode EQ "needs">
        <cfset resultRows = filteredNeedsPublishingRows>
        <cfset resultCount = arrayLen(filteredNeedsPublishingRows)>
        <p class="text-muted mb-3"><cfif searched>#resultCount# result<cfif resultCount NEQ 1>s</cfif> for &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo; in the needs publishing queue.<cfelse>#resultCount# user<cfif resultCount NEQ 1>s</cfif> currently need publishing follow-up.</cfif></p>

        <cfif resultCount GT 0>
            <div class="row row-cols-1 row-cols-lg-2 g-3">
                <cfloop array="#resultRows#" index="queueRow">
                    <div class="col">
                        <div class="card h-100 shadow-sm border-warning-subtle">
                            <div class="card-body d-flex flex-column gap-3">
                                <div class="d-flex justify-content-between align-items-start gap-3">
                                    <div>
                                        <h5 class="mb-1">#encodeForHTML(trim((queueRow.FIRSTNAME ?: "") & " " & (queueRow.LASTNAME ?: "")))#</h5>
                                        <div class="small text-muted">User ID #queueRow.USERID#</div>
                                        <cfif len(trim(queueRow.EMAILPRIMARY ?: ""))>
                                            <div class="small text-muted"><i class="bi bi-envelope"></i> #encodeForHTML(queueRow.EMAILPRIMARY)#</div>
                                        </cfif>
                                    </div>
                                    <div class="text-end small">
                                        <div><span class="badge text-bg-secondary">Sources #queueRow.ActiveSourceCount#</span></div>
                                        <div class="mt-1"><span class="badge text-bg-primary">Published #queueRow.PublishedImageCount#</span></div>
                                        <cfif queueRow.GeneratedUnpublishedCount GT 0>
                                            <div class="mt-1"><span class="badge text-bg-warning">Generated/Unpublished #queueRow.GeneratedUnpublishedCount#</span></div>
                                        </cfif>
                                    </div>
                                </div>
                                <p class="small text-muted mb-0">Queue includes users with active sources but no published images, plus users with generated variants that are not yet published.</p>
                                <div class="mt-auto">
                                    <a href="/admin/user-media/sources.cfm?userid=#queueRow.USERID#" class="btn btn-sm btn-ui-go w-100">
                                        <i class="bi bi-images me-1"></i>Manage Media
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </cfloop>
            </div>
        <cfelse>
            <div class="alert alert-success">No users currently need publishing follow-up.</div>
        </cfif>
    <cfelseif searched>
        <cfset resultUsers = filteredUsers>
        <cfset resultCount = arrayLen(filteredUsers)>
        <p class="text-muted mb-3">#resultCount# result<cfif resultCount NEQ 1>s</cfif> for &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo;.</p>

        <cfif arrayLen(resultUsers) GT 0>
            <div class="row row-cols-1 row-cols-md-4 row-cols-xl-5 g-4">
                <cfloop array="#resultUsers#" index="u">
                    <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
                    <cfset displayEmail = u.EMAILPRIMARY ?: "">
                    <div class="col">
                        <div class="card h-100 shadow-sm">
                            <div class="card-body d-flex flex-column">
                                <cfset cardDisplayName = trim((u.FIRSTNAME ?: "") & " " & (u.LASTNAME ?: ""))>
                                <h5 class="card-title mb-1">#encodeForHTML(cardDisplayName)#</h5>

                                <cfif len(displayEmail)>
                                    <p class="card-text text-muted small mb-2"><i class="bi bi-envelope"></i> #encodeForHTML(displayEmail)#</p>
                                <cfelse>
                                    <p class="card-text text-muted small mb-2"><span class="fst-italic">No email on record</span></p>
                                </cfif>

                                <cfif arrayLen(userFlags) GT 0>
                                    <div class="mb-3 d-flex flex-wrap gap-1">
                                        <cfloop array="#userFlags#" index="userFlag">
                                            <span class="badge bg-secondary text-dark">#encodeForHTML(userFlag.FLAGNAME)#</span>
                                        </cfloop>
                                    </div>
                                <cfelse>
                                    <p class="text-muted small fst-italic mb-3">No flags</p>
                                </cfif>

                                <div class="mt-auto">
                                    <a href="/admin/user-media/sources.cfm?userid=#u.USERID#" class="btn btn-sm btn-ui-go w-100">
                                        <i class="bi bi-images"></i> Manage Media
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </cfloop>
            </div>
        <cfelse>
            <div class="alert alert-info">No users found matching &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo;.</div>
        </cfif>
    <cfelse>
        <div class="text-center text-muted py-5">
            <i class="bi bi-search fs-1 d-block mb-3 opacity-25"></i>
            <p>Enter a name or email above to find a user.</p>
        </div>
    </cfif>
</cfif>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">