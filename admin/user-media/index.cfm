<cfif NOT request.hasPermission("media.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset canManageMedia = request.hasPermission("media.edit")>
<cfset requestedMode = structKeyExists(url, "mode") ? lCase(trim(url.mode)) : "">
<cfif NOT listFindNoCase("view,manage", requestedMode)>
    <cfset requestedMode = canManageMedia ? "manage" : "view">
</cfif>
<cfset activeMode = (requestedMode EQ "manage" AND canManageMedia) ? "manage" : "view">

<cfset searchTerm = structKeyExists(url, "search") ? trim(url.search) : "">
<cfset variantFilter = structKeyExists(url, "variant") ? trim(url.variant) : "">
<cfset searched = len(searchTerm) GT 0>
<cfset showNeedsPublishingOnly = structKeyExists(url, "needsPublishingOnly") AND val(url.needsPublishingOnly) EQ 1>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset imagesService = createObject("component", "cfc.images_service").init()>
<cfset sourceService = createObject("component", "cfc.UserImageSourceService").init()>
<cfset variantService = createObject("component", "cfc.UserImageVariantService").init()>
<cfset allUserFlagMap = flagsService.getAllUserFlagMap()>

<cftry>
    <cfset allUsers = directoryService.listUsers()>
    <cfcatch type="any">
        <cfset allUsers = []>
    </cfcatch>
</cftry>

<cfset usersByID = {}>
<cfloop array="#allUsers#" index="directoryUserRow">
    <cfif structKeyExists(directoryUserRow, "USERID") AND isNumeric(directoryUserRow.USERID)>
        <cfset usersByID[toString(val(directoryUserRow.USERID))] = directoryUserRow>
    </cfif>
</cfloop>

<cfset activeSourceCountMap = sourceService.getActiveSourceCountMapByUser()>
<cfset publishedCountMapResult = imagesService.getPublishedImageCountMapByUser()>
<cfset publishedCountMap = publishedCountMapResult.success ? publishedCountMapResult.data : {}>
<cfset generatedUnpublishedCountMap = variantService.getGeneratedUnpublishedCountMapByUser()>
<cfset needsPublishingUserRows = []>
<cfset needsPublishingLookup = {}>

<cfset totalPublishedImageCount = 0>
<cfloop collection="#publishedCountMap#" item="publishedCountKey">
    <cfset totalPublishedImageCount = totalPublishedImageCount + val(publishedCountMap[publishedCountKey])>
</cfloop>

<!--- Shared search function + helper modal --->
<cfinclude template="/admin/users/_search_helper.cfm">

<cfset filteredUsers = allUsers>

<cfset publishedImages = []>
<cfset filteredPublishedImages = []>
<cfset availableVariantList = []>
<cfset availableVariantLookup = {}>
<cfset publishedByUserID = {}>
<cfset publishedUserOrder = []>
<cfset filteredPublishedUsers = []>
<cfset pagedPublishedUsers = []>
<cfset totalPublishedUserCount = 0>
<cfset pageSize = 25>
<cfset requestedPage = structKeyExists(url, "page") AND isNumeric(url.page) ? val(url.page) : 1>
<cfset currentPage = requestedPage GT 0 ? requestedPage : 1>
<cfset totalPages = 1>
<cfset totalFilteredUsers = 0>

<cfloop array="#allUsers#" index="manageUserRow">
    <cfset manageUserKey = toString(val(manageUserRow.USERID ?: 0))>
    <cfset activeSourceCount = structKeyExists(activeSourceCountMap, manageUserKey) ? val(activeSourceCountMap[manageUserKey]) : 0>
    <cfset publishedImageCount = structKeyExists(publishedCountMap, manageUserKey) ? val(publishedCountMap[manageUserKey]) : 0>
    <cfset generatedUnpublishedCount = structKeyExists(generatedUnpublishedCountMap, manageUserKey) ? val(generatedUnpublishedCountMap[manageUserKey]) : 0>
    <cfset isNoPublishedWithSources = activeSourceCount GT 0 AND publishedImageCount EQ 0>
    <cfset hasGeneratedUnpublished = generatedUnpublishedCount GT 0>

    <cfif isNoPublishedWithSources OR hasGeneratedUnpublished>
        <cfset needsPublishingLookup[manageUserKey] = true>
        <cfset arrayAppend(needsPublishingUserRows, {
            USERID = val(manageUserRow.USERID ?: 0),
            FIRSTNAME = manageUserRow.FIRSTNAME ?: "",
            LASTNAME = manageUserRow.LASTNAME ?: "",
            EMAILPRIMARY = manageUserRow.EMAILPRIMARY ?: "",
            ActiveSourceCount = activeSourceCount,
            PublishedImageCount = publishedImageCount,
            GeneratedUnpublishedCount = generatedUnpublishedCount,
            NoPublishedWithSources = isNoPublishedWithSources,
            HasGeneratedUnpublished = hasGeneratedUnpublished
        })>
    </cfif>
</cfloop>

<cfif activeMode EQ "manage">
    <cfset filteredUsers = allUsers>
    <cfif searched>
        <cfset filteredUsers = []>
        <cfloop from="1" to="#arrayLen(allUsers)#" index="i">
            <cfif userMatchesSearch(allUsers[i], searchTerm)>
                <cfset arrayAppend(filteredUsers, allUsers[i])>
            </cfif>
        </cfloop>
    </cfif>

    <cfif showNeedsPublishingOnly>
        <cfset queueFilteredUsers = []>
        <cfloop array="#filteredUsers#" index="candidateUserRow">
            <cfif structKeyExists(needsPublishingLookup, toString(val(candidateUserRow.USERID ?: 0)))>
                <cfset arrayAppend(queueFilteredUsers, candidateUserRow)>
            </cfif>
        </cfloop>
        <cfset filteredUsers = queueFilteredUsers>
    </cfif>
</cfif>

<cfif activeMode EQ "view">
    <cfset publishedResult = imagesService.getPublishedImages()>
    <cfset publishedImages = publishedResult.success ? publishedResult.data : []>

    <cfloop array="#publishedImages#" index="publishedRow">
        <cfset rowUserID = val(publishedRow.USERID ?: 0)>
        <cfset rowUserKey = toString(rowUserID)>
        <cfset variantCode = trim(publishedRow.IMAGEVARIANT ?: "")>
        <cfif len(variantCode) AND NOT structKeyExists(availableVariantLookup, lCase(variantCode))>
            <cfset availableVariantLookup[lCase(variantCode)] = true>
            <cfset arrayAppend(availableVariantList, variantCode)>
        </cfif>

        <cfif rowUserID GT 0>
            <cfif NOT structKeyExists(publishedByUserID, rowUserKey)>
                <cfset publishedByUserID[rowUserKey] = {
                    userID = rowUserID,
                    totalPublished = 0,
                    variantCountByKey = {},
                        webThumbURL = "",
                    webProfileURL = "",
                    legacyAlumniURL = "",
                    latestPublishedAt = ""
                }>
                <cfset arrayAppend(publishedUserOrder, rowUserID)>
            </cfif>

            <cfset publishedByUserID[rowUserKey].totalPublished = publishedByUserID[rowUserKey].totalPublished + 1>
            <cfset variantKey = lCase(variantCode)>
            <cfset publishedByUserID[rowUserKey].variantCountByKey[variantKey] = (structKeyExists(publishedByUserID[rowUserKey].variantCountByKey, variantKey) ? publishedByUserID[rowUserKey].variantCountByKey[variantKey] : 0) + 1>

            <cfif NOT len(publishedByUserID[rowUserKey].webThumbURL) AND compareNoCase(variantCode, "WEB_THUMB") EQ 0>
                <cfset publishedByUserID[rowUserKey].webThumbURL = trim(publishedRow.IMAGEURL ?: "")>
            </cfif>
            <cfif NOT len(publishedByUserID[rowUserKey].webProfileURL) AND compareNoCase(variantCode, "WEB_PROFILE") EQ 0>
                <cfset publishedByUserID[rowUserKey].webProfileURL = trim(publishedRow.IMAGEURL ?: "")>
            </cfif>
            <cfif NOT len(publishedByUserID[rowUserKey].legacyAlumniURL) AND compareNoCase(variantCode, "legacy_alumni") EQ 0>
                <cfset publishedByUserID[rowUserKey].legacyAlumniURL = trim(publishedRow.IMAGEURL ?: "")>
            </cfif>
            <cfif NOT len(publishedByUserID[rowUserKey].latestPublishedAt) AND structKeyExists(publishedRow, "PUBLISHEDAT")>
                <cfset publishedByUserID[rowUserKey].latestPublishedAt = publishedRow.PUBLISHEDAT>
            </cfif>
        </cfif>

        <cfset rowUser = structKeyExists(usersByID, toString(val(publishedRow.USERID ?: 0))) ? usersByID[toString(val(publishedRow.USERID ?: 0))] : {}>
        <cfset variantMatches = NOT len(variantFilter) OR compareNoCase(variantCode, variantFilter) EQ 0>
        <cfset searchMatches = true>
        <cfif searched>
            <cfset searchMatches = userMatchesSearch(rowUser, searchTerm) OR findNoCase(searchTerm, variantCode) GT 0 OR findNoCase(searchTerm, toString(publishedRow.USERID ?: "")) GT 0>
        </cfif>

        <cfif variantMatches AND searchMatches>
            <cfset arrayAppend(filteredPublishedImages, publishedRow)>
        </cfif>
    </cfloop>

    <cfset arraySort(availableVariantList, "textNoCase", "asc")>

    <cfloop array="#publishedUserOrder#" index="orderedUserID">
        <cfset userKey = toString(orderedUserID)>
        <cfif structKeyExists(publishedByUserID, userKey)>
            <cfset userStat = publishedByUserID[userKey]>
            <cfset rowUser = structKeyExists(usersByID, userKey) ? usersByID[userKey] : {}>
            <cfset userVariantMatches = NOT len(variantFilter) OR structKeyExists(userStat.variantCountByKey, lCase(variantFilter))>
            <cfset userSearchMatches = true>
            <cfif searched>
                <cfset userSearchMatches = userMatchesSearch(rowUser, searchTerm) OR findNoCase(searchTerm, userKey) GT 0>
            </cfif>
            <cfif userVariantMatches AND userSearchMatches>
                <cfset arrayAppend(filteredPublishedUsers, userStat)>
            </cfif>
        </cfif>
    </cfloop>

    <cfset totalPublishedUserCount = arrayLen(publishedUserOrder)>
    <cfset totalFilteredUsers = arrayLen(filteredPublishedUsers)>
    <cfif totalFilteredUsers GT 0>
        <cfset totalPages = ceiling(totalFilteredUsers / pageSize)>
        <cfif currentPage GT totalPages>
            <cfset currentPage = totalPages>
        </cfif>
        <cfset startIndex = ((currentPage - 1) * pageSize) + 1>
        <cfset endIndex = startIndex + pageSize - 1>
        <cfif endIndex GT totalFilteredUsers>
            <cfset endIndex = totalFilteredUsers>
        </cfif>
        <cfloop from="#startIndex#" to="#endIndex#" index="pageIndex">
            <cfset arrayAppend(pagedPublishedUsers, filteredPublishedUsers[pageIndex])>
        </cfloop>
    </cfif>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-2">
    <h1 class="mb-0">User Media</h1>
    <div class="d-flex gap-2 flex-wrap">
        <a href="#request.webRoot#/admin/user-media/index.cfm?mode=view" class="btn <cfif activeMode EQ 'view'>btn-primary<cfelse>btn-outline-primary</cfif>">
            <i class="bi bi-eye me-1"></i>View Published
            <span class="badge ms-1 <cfif activeMode EQ 'view'>text-bg-light<cfelse>text-bg-secondary</cfif>">#totalPublishedImageCount#</span>
        </a>
        <cfif canManageMedia>
            <a href="#request.webRoot#/admin/user-media/index.cfm?mode=manage" class="btn <cfif activeMode EQ 'manage'>btn-primary<cfelse>btn-outline-primary</cfif>">
                <i class="bi bi-gear me-1"></i>Manage Published Media
            </a>
        </cfif>
    </div>
</div>

<cfif activeMode EQ "view">
    <p class="text-muted">Browse published images across all users. Filter by user details, variant code, or user ID.</p>

    <div class="card mb-4 users-list-filter-card">
        <div class="card-body users-list-filter-card-body">
            <form method="get" class="d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form">
                <input type="hidden" name="mode" value="view">
                <div class="input-group users-list-toolbar-search">
                    <button type="button" class="btn btn-sm btn-outline-secondary users-list-help-button" data-bs-toggle="modal" data-bs-target="##searchHelpModal" title="Search help"><i class="bi bi-question-circle"></i></button>
                    <input type="text" name="search" class="form-control" placeholder="Search user name/email, userID, or variant" value="#encodeForHTMLAttribute(searchTerm)#">
                </div>
                <select name="variant" class="form-select form-select-sm" style="max-width:220px;">
                    <option value="">All variants</option>
                    <cfloop array="#availableVariantList#" index="variantOption">
                        <option value="#encodeForHTMLAttribute(variantOption)#" <cfif compareNoCase(variantOption, variantFilter) EQ 0>selected</cfif>>#encodeForHTML(variantOption)#</option>
                    </cfloop>
                </select>
                <button type="submit" class="btn btn-sm btn-secondary users-list-apply-button">
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
                <cfset rowUser = structKeyExists(usersByID, toString(rowUserID)) ? usersByID[toString(rowUserID)] : {}>
                <cfset displayName = trim((rowUser.FIRSTNAME ?: "") & " " & (rowUser.LASTNAME ?: ""))>
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
                                    <cfif len(trim(rowUser.EMAILPRIMARY ?: ""))>
                                        <div class="small text-muted"><i class="bi bi-envelope"></i> #encodeForHTML(rowUser.EMAILPRIMARY)#</div>
                                    </cfif>
                                    <cfif structKeyExists(userStatRow, "latestPublishedAt") AND len(userStatRow.latestPublishedAt)>
                                        <div class="small text-muted">Last published: #dateTimeFormat(userStatRow.latestPublishedAt, "mm/dd/yyyy h:nn tt")#</div>
                                    </cfif>
                                </div>
                            </div>

                            <div class="mt-auto d-flex flex-column gap-2">
                                <div class="btn-group w-100" role="group">
                                    <a href="/admin/users/view.cfm?userID=#rowUserID#" class="btn btn-secondary" title="View user details and media activity for this user">
                                        <i class="bi bi-eye me-1"></i>Open User Profile
                                    </a>
                                    <cfif canManageMedia>
                                        <a href="/admin/user-media/sources.cfm?userid=#rowUserID#" class="btn btn-secondary" title="Manage media sources and published images for this user">
                                            <i class="bi bi-images me-1"></i>Manage Media
                                        </a>
                                        <a href="/admin/user-media/variants.cfm?userid=#rowUserID#" class="btn btn-secondary" title="Manage image variants for this user">
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
    <div class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-3">
        <p class="text-muted mb-0">Manage images and media variants for individual users.</p>
        <div class="d-flex gap-2 flex-wrap">
            <cfif request.hasPermission("media.publish")>
                <a href="#request.webRoot#/admin/user-media/bulk-transfer.cfm" class="btn btn-secondary text-dark">
                    <i class="bi bi-arrow-left-right me-1"></i> Bulk Transfer
                </a>
            </cfif>
            <cfif request.hasPermission("settings.media_config.manage")>
                <a href="/admin/settings/media-config/filename-patterns.cfm" class="btn btn-secondary text-dark">
                    <i class="bi bi-file-earmark-text me-1"></i> Filename Patterns
                </a>
                <a href="/admin/settings/media-config/variant-types.cfm" class="btn btn-secondary text-dark">
                    <i class="bi bi-sliders me-1"></i> Manage Variant Types
                </a>
            </cfif>
        </div>
    </div>

    <div class="card mb-4 border-warning-subtle">
        <div class="card-body">
            <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2">
                <h5 class="mb-0"><i class="bi bi-exclamation-triangle me-2 text-warning"></i>Needs Publishing</h5>
                <span class="badge text-bg-warning">#arrayLen(needsPublishingUserRows)# users</span>
            </div>
            <p class="text-muted small mb-3">Queue includes users with active sources but no published images, plus users with generated variants that are not yet published.</p>

            <cfif arrayLen(needsPublishingUserRows)>
                <div class="row row-cols-1 row-cols-lg-2 g-2">
                    <cfloop array="#needsPublishingUserRows#" index="queueRow">
                        <div class="col">
                            <div class="border rounded p-2 h-100 bg-light-subtle">
                                <div class="d-flex justify-content-between align-items-start gap-2">
                                    <div>
                                        <div class="fw-semibold">#encodeForHTML(trim((queueRow.FIRSTNAME ?: "") & " " & (queueRow.LASTNAME ?: "")))#</div>
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
                                <div class="mt-2">
                                    <a href="/admin/user-media/sources.cfm?userid=#queueRow.USERID#" class="btn btn-sm btn-outline-primary w-100">
                                        <i class="bi bi-images me-1"></i>Manage Media
                                    </a>
                                </div>
                            </div>
                        </div>
                    </cfloop>
                </div>
            <cfelse>
                <div class="alert alert-success mb-0">No users currently need publishing follow-up.</div>
            </cfif>
        </div>
    </div>

    <div class="card mb-4 users-list-filter-card">
        <div class="card-body users-list-filter-card-body">
            <form method="get" class="d-flex flex-wrap align-items-center gap-2 my-0 users-list-filter-form">
                <input type="hidden" name="mode" value="manage">
                <div class="input-group users-list-toolbar-search">
                    <button type="button" class="btn btn-sm btn-outline-secondary users-list-help-button" data-bs-toggle="modal" data-bs-target="##searchHelpModal" title="Search help"><i class="bi bi-question-circle"></i></button>
                    <input type="text" name="search" class="form-control" placeholder="Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)" value="#encodeForHTMLAttribute(searchTerm)#">
                </div>
                <button type="submit" class="btn btn-sm btn-secondary users-list-apply-button">
                    <i class="bi bi-search"></i> Search
                </button>
                <div class="form-check ms-1">
                    <input class="form-check-input" type="checkbox" name="needsPublishingOnly" value="1" id="needsPublishingOnly" <cfif showNeedsPublishingOnly>checked</cfif>>
                    <label class="form-check-label small" for="needsPublishingOnly">Needs publishing only</label>
                </div>
                <cfif searched OR showNeedsPublishingOnly>
                    <a href="#request.webRoot#/admin/user-media/index.cfm?mode=manage" class="btn btn-sm btn-warning users-list-clear-button">Clear</a>
                </cfif>
            </form>
        </div>
    </div>

    <cfif searched>
        <cfset resultUsers = filteredUsers>
        <cfset resultCount = arrayLen(filteredUsers)>
        <p class="text-muted mb-3">#resultCount# result<cfif resultCount NEQ 1>s</cfif> for &ldquo;<strong>#encodeForHTML(searchTerm)#</strong>&rdquo;<cfif showNeedsPublishingOnly> (needs publishing only)</cfif>.</p>

        <cfif arrayLen(resultUsers) GT 0>
            <div class="row row-cols-1 row-cols-md-4 row-cols-xl-5 g-4">
                <cfloop array="#resultUsers#" index="u">
                    <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
                    <cfset displayEmail = u.EMAILPRIMARY ?: "">
                    <div class="col">
                        <div class="card h-100 shadow-sm">
                            <div class="card-body d-flex flex-column">
                                <h5 class="card-title mb-1">#encodeForHTML(u.FIRSTNAME ?: "")# #encodeForHTML(u.LASTNAME ?: "")#</h5>

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
                                    <a href="/admin/user-media/sources.cfm?userid=#u.USERID#" class="btn btn-sm btn-primary w-100">
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
    <cfelseif showNeedsPublishingOnly>
        <cfset resultUsers = filteredUsers>
        <cfset resultCount = arrayLen(filteredUsers)>
        <p class="text-muted mb-3">#resultCount# user<cfif resultCount NEQ 1>s</cfif> in needs publishing queue.</p>

        <cfif arrayLen(resultUsers) GT 0>
            <div class="row row-cols-1 row-cols-md-4 row-cols-xl-5 g-4">
                <cfloop array="#resultUsers#" index="u">
                    <cfset userFlags = structKeyExists(allUserFlagMap, toString(u.USERID)) ? allUserFlagMap[toString(u.USERID)] : []>
                    <cfset displayEmail = u.EMAILPRIMARY ?: "">
                    <div class="col">
                        <div class="card h-100 shadow-sm border-warning-subtle">
                            <div class="card-body d-flex flex-column">
                                <h5 class="card-title mb-1">#encodeForHTML(u.FIRSTNAME ?: "")# #encodeForHTML(u.LASTNAME ?: "")#</h5>

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
                                    <a href="/admin/user-media/sources.cfm?userid=#u.USERID#" class="btn btn-sm btn-primary w-100">
                                        <i class="bi bi-images"></i> Manage Media
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </cfloop>
            </div>
        <cfelse>
            <div class="alert alert-info">No users currently match the needs publishing filter.</div>
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