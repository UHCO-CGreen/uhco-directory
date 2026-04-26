<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("users.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset canViewTestUsers = application.authService.hasRole("SUPER_ADMIN")>
<cfset testModeEnabledValue = trim(appConfigService.getValue("test_mode.enabled", "0"))>
<cfset testModeEnabled = usersService.isTestModeEnabled() OR (listFindNoCase("1,true,yes,on", testModeEnabledValue) GT 0)>
<cfset isSuperAdminImpersonation = structKeyExists(request, "isImpersonating") AND request.isImpersonating() AND structKeyExists(request, "isActualSuperAdmin") AND request.isActualSuperAdmin()>
<cfset showTestUsersForAdmin = canViewTestUsers OR testModeEnabled OR isSuperAdminImpersonation>
<cfset hideTestUsersForAdmin = NOT showTestUsersForAdmin>
<cfset profile = directoryService.getFullProfile(url.userID)>
<cfset isTestUser = false>
<cfloop from="1" to="#arrayLen(profile.flags ?: [])#" index="flagIndex">
    <cfif compareNoCase(trim(profile.flags[flagIndex].FLAGNAME ?: ""), "TEST_USER") EQ 0>
        <cfset isTestUser = true>
        <cfbreak>
    </cfif>
</cfloop>
<cfif hideTestUsersForAdmin AND isTestUser>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>
<cfset returnTo = structKeyExists(url, "returnTo") AND len(trim(url.returnTo)) ? trim(url.returnTo) : (len(trim(cgi.HTTP_REFERER)) ? trim(cgi.HTTP_REFERER) : "/admin/users/index.cfm")>
<cfparam name="form.quickApiMatch" default="0">
<cfparam name="form.saveMatchedApiId" default="0">
<cfparam name="form.matchedApiId" default="">
<cfset contentWrapperClass = "">
<cfset toolbarListType = "all">
<cfset toolbarSearchTerm = structKeyExists(url, "search") ? trim(url.search) : "">
<cfset currentAdminUser = structKeyExists(session, "user") AND isStruct(session.user) ? session.user : {}>
<cfset currentUserDisplayName = encodeForHTML(trim(currentAdminUser.displayName ?: "Admin User"))>
<cfset currentUserEmail = encodeForHTML(trim(currentAdminUser.email ?: ""))>
<cfset currentUserUsername = encodeForHTML(trim(currentAdminUser.username ?: ""))>
<cfset currentUserRoleLabel = "">
<cfset currentUserImageSrc = "">
<cfset impersonationState = {}>
<cfset currentRequestUrl = cgi.script_name & (len(trim(cgi.query_string ?: "")) ? "?" & cgi.query_string : "")>
<cfset toolbarReturnToMatch = reFindNoCase("(?:\?|&)list=([^&]+)", returnTo, 1, true)>

<cfif isStruct(toolbarReturnToMatch) AND arrayLen(toolbarReturnToMatch.len) GTE 2 AND toolbarReturnToMatch.len[2] GT 0>
    <cfset toolbarListType = lCase(urlDecode(mid(returnTo, toolbarReturnToMatch.pos[2], toolbarReturnToMatch.len[2])))>
</cfif>
<cfif NOT listFindNoCase("problems,all,alumni,current-students,faculty,staff,inactive", toolbarListType)>
    <cfset toolbarListType = "all">
</cfif>
<cfif structKeyExists(currentAdminUser, "roles") AND isArray(currentAdminUser.roles) AND arrayLen(currentAdminUser.roles)>
    <cfset currentUserRoleLabel = encodeForHTML(replace(currentAdminUser.roles[1], "_", " ", "all"))>
</cfif>
<cfif NOT len(currentUserImageSrc) AND structKeyExists(currentAdminUser, "image")>
    <cfset currentUserImageSrc = trim(currentAdminUser.image ?: "")>
</cfif>
<cfif NOT len(currentUserImageSrc) AND structKeyExists(currentAdminUser, "avatar")>
    <cfset currentUserImageSrc = trim(currentAdminUser.avatar ?: "")>
</cfif>
<cfif NOT len(currentUserImageSrc)>
    <cfset currentUserImageSrc = request.webRoot & "/assets/images/uh.png">
</cfif>
<cfif application.authService.isImpersonating() AND application.authService.isActualSuperAdmin()>
    <cfset impersonationState = application.authService.getImpersonationState()>
</cfif>

<cfswitch expression="#toolbarListType#">
    <cfcase value="problems"><cfset toolbarListLabel = "Problem Records"></cfcase>
    <cfcase value="faculty"><cfset toolbarListLabel = "Faculty"></cfcase>
    <cfcase value="staff"><cfset toolbarListLabel = "Staff"></cfcase>
    <cfcase value="current-students"><cfset toolbarListLabel = "Current Students"></cfcase>
    <cfcase value="alumni"><cfset toolbarListLabel = "Alumni"></cfcase>
    <cfcase value="inactive"><cfset toolbarListLabel = "Inactive Records"></cfcase>
    <cfdefaultcase><cfset toolbarListLabel = "All Records"></cfdefaultcase>
</cfswitch>

<cfset usersListMenuHTML = "
            <div class='dropdown users-list-view-selector'>
                <button class='btn btn-link navbar-brand text-white users-list-toolbar-brand users-list-view-selector-toggle dropdown-toggle' type='button' data-bs-toggle='dropdown' aria-expanded='false'>
                    <i class='bi bi-people-fill me-2'></i>Users: #toolbarListLabel#
                </button>
                <ul class='dropdown-menu dropdown-menu-end'>
                    <li><a class='dropdown-item#(toolbarListType EQ "problems" ? " active" : "")#' href='/admin/users/index.cfm?list=problems'><i class='bi bi-exclamation-triangle me-2'></i>Problem Records</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "faculty" ? " active" : "")#' href='/admin/users/index.cfm?list=faculty'><i class='bi bi-people-fill me-2'></i>Faculty</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "staff" ? " active" : "")#' href='/admin/users/index.cfm?list=staff'><i class='bi bi-people-fill me-2'></i>Staff</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "current-students" ? " active" : "")#' href='/admin/users/index.cfm?list=current-students'><i class='bi bi-people-fill me-2'></i>Current Students</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "alumni" ? " active" : "")#' href='/admin/users/index.cfm?list=alumni'><i class='bi bi-mortarboard me-2'></i>Alumni</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "inactive" ? " active" : "")#' href='/admin/users/index.cfm?list=inactive'><i class='bi bi-person-dash me-2'></i>Inactive Records</a></li>
                    <li><a class='dropdown-item#(toolbarListType EQ "all" ? " active" : "")#' href='/admin/users/index.cfm?list=all'><i class='bi bi-list me-2'></i>All Records</a></li>
                </ul>
            </div>
">

<cfset usersTopToolBar = "
    <nav class='navbar sticky-top bg-slate text-white users-list-toolbar'>
        <div class='container-fluid users-list-toolbar-shell'>
            <div class='users-list-toolbar-primary'>
                #usersListMenuHTML#
                <div class='users-list-toolbar-controls'>
                    <form method='get' action='/admin/users/index.cfm' class='users-list-toolbar-search-form'>
                        <input type='hidden' name='list' value='#toolbarListType#'>
                        <input type='hidden' name='page' value='1'>
                        <div class='input-group users-list-toolbar-search users-list-toolbar-input-group'>
                            <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#encodeForHTMLAttribute(toolbarSearchTerm)#'>
                            <button class='btn btn-secondary' type='submit'><i class='bi bi-search me-1'></i>Search</button>
                        </div>
                    </form>
                </div>
            </div>
        
            <ul class='navbar-nav d-flex flex-row align-items-center gap-2 ms-auto users-list-toolbar-nav'>
                <li class='nav-item dropdown ms-3 users-list-toolbar-account'>
                    <a class='nav-link dropdown-toggle d-flex align-items-center text-white' href='##' role='button' data-bs-toggle='dropdown' aria-expanded='false'>
                        <i class='bi bi-person-circle me-2'></i>
                        #currentUserDisplayName#
                    </a>
                    <div class='dropdown-menu dropdown-menu-end p-3 users-list-toolbar-dropdown' style='min-width: 320px;'>
                        <div class='d-flex align-items-center gap-3 mb-3 users-list-toolbar-account-header'>
                            <img src='#encodeForHTMLAttribute(currentUserImageSrc)#' alt='Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#' class='users-list-toolbar-avatar rounded-circle'>
                            <div class='users-list-toolbar-account-meta'>
                                <h6 class='mb-1'>#currentUserDisplayName#</h6>
                                #(len(currentUserEmail) ? "<div class='small text-muted'>" & currentUserEmail & "</div>" : "")#
                                #(len(currentUserUsername) ? "<div class='small text-muted'>@" & currentUserUsername & "</div>" : "")#
                            </div>
                        </div>
                        #(len(currentUserRoleLabel) ? "<div class='bg-light p-2 rounded mb-3'><small class='d-block text-uppercase fw-bold text-muted users-list-toolbar-label'>Role</small><span class='badge badge-dark'>" & currentUserRoleLabel & "</span></div>" : "")#
                        #(structCount(impersonationState) ? "<div class='users-list-toolbar-impersonation alert alert-warning mb-3 py-2 px-3'><div class='small fw-semibold text-uppercase mb-1'>Impersonation Active</div><div class='small mb-2'>You are currently using <strong>" & encodeForHTML(impersonationState.label ?: "") & "</strong>.</div><form method='post' action='" & request.webRoot & "/admin/settings/admin-users/save.cfm' class='mb-0'><input type='hidden' name='action' value='clearImpersonation'><input type='hidden' name='returnURL' value='" & encodeForHTMLAttribute(currentRequestUrl) & "'><button type='submit' class='btn btn-sm btn-outline-dark w-100'><i class='bi bi-x-octagon me-1'></i>Stop Impersonating</button></form></div>" : "")#
                        <div class='d-grid'>
                            <a href='#request.webRoot#/admin/logout.cfm' class='btn btn-outline-primary btn-sm'><i class='bi bi-box-arrow-right me-1'></i>Logout</a>
                        </div>
                    </div>
                </li>
            </ul>
        </div>
    </nav>
">

<!--- Assign variables outside the content string --->
<cfset prefix      = profile.user.PREFIX       ?: "">
<cfset suffix      = profile.user.SUFFIX       ?: "">
<cfset degrees     = profile.user.DEGREES      ?: "">
<cfset pronouns    = profile.user.PRONOUNS     ?: "">
<cfset maidenName  = profile.user.MAIDENNAME   ?: "">
<cfset preferredName = profile.user.PREFERREDNAME ?: "">
<cfset emailPrimary = profile.user.EMAILPRIMARY ?: "">
<cfset phone       = profile.user.PHONE        ?: "">

<!--- ── Aliases ── --->
<cfset aliasesSvc    = createObject("component", "cfc.aliases_service").init()>
<cfset userAliases   = aliasesSvc.getAliases(val(url.userID)).data>
<cfset primaryAlias = {}>
<cfset resolvedFirstName = trim(profile.user.FIRSTNAME ?: "")>
<cfset resolvedMiddleName = trim(profile.user.MIDDLENAME ?: "")>
<cfset resolvedLastName = trim(profile.user.LASTNAME ?: "")>

<cfloop from="1" to="#arrayLen(userAliases)#" index="i">
    <cfif val(userAliases[i].ISPRIMARY ?: 0) EQ 1 AND val(userAliases[i].ISACTIVE ?: 0) EQ 1>
        <cfset primaryAlias = userAliases[i]>
        <cfbreak>
    </cfif>
</cfloop>

<cfif structIsEmpty(primaryAlias)>
    <cfloop from="1" to="#arrayLen(userAliases)#" index="i">
        <cfif val(userAliases[i].ISACTIVE ?: 0) EQ 1>
            <cfset primaryAlias = userAliases[i]>
            <cfbreak>
        </cfif>
    </cfloop>
</cfif>

<cfif structIsEmpty(primaryAlias) AND arrayLen(userAliases) GT 0>
    <cfset primaryAlias = userAliases[1]>
</cfif>

<cfif NOT structIsEmpty(primaryAlias)>
    <cfset resolvedFirstName = trim(primaryAlias.FIRSTNAME ?: resolvedFirstName)>
    <cfset resolvedMiddleName = trim(primaryAlias.MIDDLENAME ?: resolvedMiddleName)>
    <cfset resolvedLastName = trim(primaryAlias.LASTNAME ?: resolvedLastName)>
</cfif>

<!--- ── Contact + profile detail datasets ── --->
<cfset emailsSvc   = createObject("component", "cfc.emails_service").init()>
<cfset userEmails  = emailsSvc.getEmails(val(url.userID)).data>

<cfset phoneSvc    = createObject("component", "cfc.phone_service").init()>
<cfset userPhones  = phoneSvc.getPhones(val(url.userID)).data>

<cfset degreesSvc  = createObject("component", "cfc.degrees_service").init()>
<cfset userDegrees = degreesSvc.getDegrees(val(url.userID)).data>

<cfset bioSvc      = createObject("component", "cfc.bio_service").init()>
<cfset bioData     = bioSvc.getBio(val(url.userID)).data>
<cfset bioContent  = structIsEmpty(bioData) ? "" : (bioData.BIOCONTENT ?: "")>

<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset allSystems        = externalIDService.getSystems().data>
<cfset userExternalIDs   = externalIDService.getExternalIDs(val(url.userID)).data>
<cfset externalBySystem  = {}>
<cfloop from="1" to="#arrayLen(userExternalIDs)#" index="i">
    <cfset externalBySystem[toString(userExternalIDs[i].SYSTEMID)] = userExternalIDs[i].EXTERNALVALUE>
</cfloop>

<!--- ── Addresses ── --->
<cfset addressesSvc  = createObject("component", "cfc.addresses_service").init()>
<cfset userAddresses = addressesSvc.getAddresses(val(url.userID)).data>

<!--- ── DOB / Gender from Users table ── --->
<cfset userDOB    = profile.user.DOB    ?: "">
<cfset userGender = profile.user.GENDER ?: "">
<cfset room        = profile.user.ROOM         ?: "">
<cfset building    = profile.user.BUILDING     ?: "">
<cfset campus      = profile.user.CAMPUS       ?: "">
<cfset division       = profile.user.DIVISION      ?: "">
<cfset divisionName   = profile.user.DIVISIONNAME  ?: "">
<cfset department     = profile.user.DEPARTMENT    ?: "">
<cfset departmentName = profile.user.DEPARTMENTNAME ?: "">
<cfset officeMailAddr = profile.user.OFFICE_MAILING_ADDRESS ?: "">
<cfset mailcode    = profile.user.MAILCODE     ?: "">
<cfset cougarnetid = profile.user.COUGARNETID  ?: "">
<cfset title1      = profile.user.TITLE1       ?: "">
<cfset title2      = profile.user.TITLE2       ?: "">
<cfset title3      = profile.user.TITLE3       ?: "">
<cfset uhApiId     = trim(profile.user.UH_API_ID ?: "")>
<cfset showAcademicInfo   = false>
<cfset showStudentProfile = false>
<cfset quickMatchAttempted = (cgi.request_method EQ "POST" AND form.quickApiMatch EQ "1")>
<cfset hasAddress =
    len(room) ||
    len(building) ||
    len(campus) ||
    len(division) ||
    len(divisionName) ||
    len(department) ||
    len(departmentName) ||
    len(officeMailAddr) ||
    len(mailcode)
>

<cfset quickMatchFound = false>
<cfset quickMatchApiId = "">
<cfset quickMatchApiFirstName = "">
<cfset quickMatchApiLastName = "">
<cfset quickMatchMessage = "">
<cfset quickMatchMessageClass = "alert-info">

<cfif arrayLen(profile.flags) gt 0>
    <cfloop from="1" to="#arrayLen(profile.flags)#" index="f">
        <cfset flagName = trim(profile.flags[f].FLAGNAME ?: "")>
        <cfif compareNoCase(flagName, "Current Student") eq 0 OR compareNoCase(flagName, "Alumni") eq 0>
            <cfset showAcademicInfo = true>
        </cfif>
        <cfif compareNoCase(flagName, "Current Student") eq 0>
            <cfset showStudentProfile = true>
        </cfif>
    </cfloop>
</cfif>

<!--- Load student profile data if applicable --->
<cfif showStudentProfile>
    <cfset studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
    <cfset spProfile   = studentProfileSvc.getProfile(url.userID).data>
    <cfset spAwards    = studentProfileSvc.getAwards(url.userID).data>
    <cfset spFirstExt      = structIsEmpty(spProfile) ? "" : (spProfile.FIRSTEXTERNSHIP   ?: "")>
    <cfset spSecondExt     = structIsEmpty(spProfile) ? "" : (spProfile.SECONDEXTERNSHIP  ?: "")>
    <cfset spCommAge       = structIsEmpty(spProfile) ? "" : (spProfile.COMMENCEMENTAGE   ?: "")>
<cfelse>
    <cfset spAwards        = []>
    <cfset spFirstExt      = "">
    <cfset spSecondExt     = "">
    <cfset spCommAge       = "">
</cfif>

<cfif quickMatchAttempted>
    <cfset uhApiToken = structKeyExists(application, "uhApiToken") ? trim(application.uhApiToken ?: "") : "">
    <cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">

    <cfif (uhApiToken EQ "" OR uhApiSecret EQ "") AND structKeyExists(server, "system") AND structKeyExists(server.system, "environment")>
        <cfif structKeyExists(server.system.environment, "UH_API_TOKEN")>
            <cfset uhApiToken = trim(server.system.environment["UH_API_TOKEN"] )>
        </cfif>
        <cfif structKeyExists(server.system.environment, "UH_API_SECRET")>
            <cfset uhApiSecret = trim(server.system.environment["UH_API_SECRET"] )>
        </cfif>
    </cfif>

    <cfif uhApiToken EQ "">
        <cfset uhApiToken = "my5Tu[{[VH%,dT{wR3SEigeWc%2w,ZyFT6=5!2Rv$f0g,_z!UpDduLxhgjSm$P6">
    </cfif>
    <cfif uhApiSecret EQ "">
        <cfset uhApiSecret = "degxqhYPX2Vk@LFevunxX}:kTkX3fBXR">
    </cfif>

    <cfsilent>
        <cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
        <cfset peopleResponse = uhApi.getPeople(student=true, staff=true, faculty=true)>
    </cfsilent>

    <cfset statusCode = peopleResponse.statusCode ?: "Unknown">
    <cfset responseData = peopleResponse.data ?: {}>
    <cfset peopleArray = []>

    <cfif left(statusCode, 3) EQ "200">
        <cfif isStruct(responseData) AND structKeyExists(responseData, "data") AND isArray(responseData.data)>
            <cfset peopleArray = responseData.data>
        <cfelseif isArray(responseData)>
            <cfset peopleArray = responseData>
        </cfif>

        <cfset localFirstName = lCase(trim(resolvedFirstName ?: ""))>
        <cfset localLastName = lCase(trim(resolvedLastName ?: ""))>

        <cfloop from="1" to="#arrayLen(peopleArray)#" index="i">
            <cfset person = peopleArray[i]>
            <cfif NOT isStruct(person)>
                <cfcontinue>
            </cfif>

            <cfset apiFirstName = lCase(trim(person.first_name ?: person.firstName ?: ""))>
            <cfset apiLastName = lCase(trim(person.last_name ?: person.lastName ?: ""))>
            <cfset apiId = trim(person.id ?: "")>

            <cfif apiId NEQ "" AND apiFirstName EQ localFirstName AND apiLastName EQ localLastName>
                <cfset quickMatchFound = true>
                <cfset quickMatchApiId = apiId>
                <cfset quickMatchApiFirstName = trim(person.first_name ?: person.firstName ?: "")>
                <cfset quickMatchApiLastName = trim(person.last_name ?: person.lastName ?: "")>
                <cfbreak>
            </cfif>
        </cfloop>

        <cfif quickMatchFound>
            <cfset quickMatchMessage = "API match found by first/last name.">
            <cfset quickMatchMessageClass = "alert-success">
        <cfelse>
            <cfset quickMatchMessage = "No API match found by first/last name.">
            <cfset quickMatchMessageClass = "alert-warning">
        </cfif>
    <cfelse>
        <cfset quickMatchMessage = "Quick match failed: UH API returned status #EncodeForHTML(statusCode)#.">
        <cfset quickMatchMessageClass = "alert-danger">
    </cfif>
</cfif>

<cfif cgi.request_method EQ "POST" AND form.saveMatchedApiId EQ "1">
    <cfset saveApiId = trim(form.matchedApiId ?: "")>
    <cfif saveApiId EQ "">
        <cfset quickMatchMessage = "Save failed: matched API ID is missing.">
        <cfset quickMatchMessageClass = "alert-danger">
    <cfelse>
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset userData = {
            FirstName = profile.user.FIRSTNAME ?: "",
            MiddleName = profile.user.MIDDLENAME ?: "",
            LastName = profile.user.LASTNAME ?: "",
            Pronouns = profile.user.PRONOUNS ?: "",
            EmailPrimary = profile.user.EMAILPRIMARY ?: "",
            Phone = profile.user.PHONE ?: "",
            Room = profile.user.ROOM ?: "",
            Building = profile.user.BUILDING ?: "",
            CougarNetID = profile.user.COUGARNETID ?: "",
            Title1 = profile.user.TITLE1 ?: "",
            Title2 = profile.user.TITLE2 ?: "",
            Title3 = profile.user.TITLE3 ?: "",
            UH_API_ID = saveApiId
        }>

        <cfset saveResult = usersService.updateUser(val(url.userID), userData)>
        <cfif structKeyExists(saveResult, "success") AND saveResult.success>
            <cfset profile.user.UH_API_ID = saveApiId>
            <cfset uhApiId = saveApiId>
            <cfset quickMatchMessage = "Saved UH API ID to user record.">
            <cfset quickMatchMessageClass = "alert-success">
        <cfelse>
            <cfset quickMatchMessage = "Save failed: " & (saveResult.message ?: "Unknown error")>
            <cfset quickMatchMessageClass = "alert-danger">
        </cfif>
    </cfif>
</cfif>

<cfset userAliasesHtml = "">
<cfif arrayLen(userAliases)>
    <cfset userAliasesHtml = "<div class='mb-3'><strong>Aliases:</strong><div class='table-responsive mt-2'><table class='table table-sm table-striped mb-0'><thead><tr><th>First</th><th>Middle</th><th>Last</th><th>Type / System</th><th>Status</th></tr></thead><tbody>">
    <cfloop from="1" to="#arrayLen(userAliases)#" index="aliasIndex">
        <cfset aliasItem = userAliases[aliasIndex]>
        <cfset aliasFirst = trim(aliasItem.FIRSTNAME ?: "")>
        <cfset aliasMiddle = trim(aliasItem.MIDDLENAME ?: "")>
        <cfset aliasLast = trim(aliasItem.LASTNAME ?: "")>
        <cfset aliasType = trim(aliasItem.ALIASTYPE ?: "")>
        <cfset aliasSystem = trim(aliasItem.SOURCESYSTEM ?: "")>
        <cfset aliasTypeSystem = len(aliasType) AND len(aliasSystem) ? aliasType & " / " & aliasSystem : (len(aliasType) ? aliasType : aliasSystem)>
        <cfset aliasIsActive = val(aliasItem.ISACTIVE ?: 0) EQ 1>
        <cfset aliasIsPrimary = val(aliasItem.ISPRIMARY ?: 0) EQ 1>
        <cfset aliasStatusHtml = (aliasIsActive ? "<span class='badge badge-success users-view-badge'>Active</span>" : "<span class='badge badge-danger users-view-badge'>Inactive</span>") & (aliasIsPrimary ? " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>" : "")>
        <cfset userAliasesHtml &= "<tr><td>" & (len(aliasFirst) ? EncodeForHTML(aliasFirst) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasMiddle) ? EncodeForHTML(aliasMiddle) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasLast) ? EncodeForHTML(aliasLast) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasTypeSystem) ? EncodeForHTML(aliasTypeSystem) : "<span class='text-muted'>-</span>") & "</td><td>" & aliasStatusHtml & "</td></tr>">
    </cfloop>
    <cfset userAliasesHtml &= "</tbody></table></div></div>">
</cfif>

<!---
<cfset quickMatchHtml = "
<div class='card card-body mb-3 mt-4 users-view-quickmatch'>
    <h5 class='mb-2'>Quick API Match</h5>
    <p class='text-muted mb-2'>Compare this user by primary alias first/last name against UH API.</p>
    <form method='post' action='/admin/users/view.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='d-inline'>
        <input type='hidden' name='quickApiMatch' value='1'>
        <button type='submit' class='btn btn-sm btn-outline-primary'>Run Quick API Match</button>
    </form>
">

<cfif quickMatchAttempted>
    <cfset quickMatchHtml &= "<div class='alert #quickMatchMessageClass# mt-3 mb-2'>#EncodeForHTML(quickMatchMessage)#</div>">

    <cfif quickMatchFound>
        <cfset quickMatchHtml &= "
        <p class='mb-2'><strong>Matched API ID:</strong> #EncodeForHTML(quickMatchApiId)#</p>
        <p class='mb-2'><strong>Matched API Name:</strong> #EncodeForHTML(quickMatchApiFirstName)# #EncodeForHTML(quickMatchApiLastName)#</p>
        <form method='post' action='/admin/users/view.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='d-inline me-2'>
            <input type='hidden' name='quickApiMatch' value='1'>
            <input type='hidden' name='saveMatchedApiId' value='1'>
            <input type='hidden' name='matchedApiId' value='#EncodeForHTMLAttribute(quickMatchApiId)#'>
            <button type='submit' class='btn btn-sm btn-outline-success'>Save API ID to User</button>
        </form>
        <a href='/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(quickMatchApiId)#&sourceUserID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-sm btn-success'>Sync from API</a>
        ">
    </cfif>
</cfif>

<cfset quickMatchHtml &= "</div>">
--->

<cfset profileThumbnail = "/assets/images/uh.png">

<cfif arrayLen(profile.images) GT 0>
    <cfset profileImageFallback = "">
    <cfloop from="1" to="#arrayLen(profile.images)#" index="i">
        <cfset img = profile.images[i]>
        <cfif NOT len(profileImageFallback) AND lCase(trim(img.IMAGEVARIANT ?: "")) EQ "web_profile">
            <cfset profileImageFallback = img.IMAGEURL>
        </cfif>
        <cfif lCase(trim(img.IMAGEVARIANT ?: "")) EQ "web_thumb">
            <cfset profileThumbnail = img.IMAGEURL>
            <cfbreak>
        </cfif>
    </cfloop>
    <cfif profileThumbnail EQ "/assets/images/uh.png" AND len(profileImageFallback)>
        <cfset profileThumbnail = profileImageFallback>
    </cfif>
</cfif>

<cfset SubTitle = "">
<cfif arrayLen(profile.flags) gt 0>
    <cfloop from="1" to="#arrayLen(profile.flags)#" index="f">
        <cfset flag = lCase(trim(profile.flags[f].FLAGNAME ?: ""))>
        <cfif listFindNoCase("current-student,alumni,resident", flag)>
            <cfset SubTitle = len(title1) ? "<p class='text-muted fs-5'>#title1#</p>" : "">
            <cfbreak>
        <cfelseif listFindNoCase("faculty-fulltime,faculty-adjunct,professor-emeritus", flag)>
            <cfset SubTitle = len(title1) ? "<p class='text-muted fs-5'>#title1#</p>" : "">
            <cfbreak>
        </cfif>
    </cfloop>
</cfif>
<cfif SubTitle EQ "">
    <cfset SubTitle = "<p class='text-muted fs-5'>&nbsp;</p>">
</cfif>

<cfset flagsRowHtml = "">
<cfif arrayLen(profile.flags) GT 0>
    <cfset flagsRowHtml = "<div class='users-view-pill-stack align-items-center mt-1 mb-2'>">
    <cfset flagsRowHtml &= "<span class='users-view-badge-flags-header fw-bold'>Flags:</span>">
    <cfloop from="1" to="#arrayLen(profile.flags)#" index="f">
        <cfset flag = profile.flags[f]>
        <cfset flagsRowHtml &= "<span class='badge rounded-pill users-view-badge badge-flags'>" & EncodeForHTML(flag.FLAGNAME) & "</span>">
    </cfloop>
    <cfset flagsRowHtml &= "</div>">
<cfelse>
    <cfset flagsRowHtml = "">
</cfif>

<!---#quickMatchHtml#--->

<cfif len(trim(profile.user.UH_API_ID ?: ""))>
        <cfset uhSyncUrl = "/admin/users/uh_sync.cfm?userID=" & urlEncodedFormat(profile.user.USERID) & "&uhApiId=" & urlEncodedFormat(profile.user.UH_API_ID)>
        <cfset uhSyncButtonHtml = "<a href='" & uhSyncUrl & "' class='btn btn-sm btn-ui-neutral'><i class='bi bi-cloud-download me-1'></i>UH Sync</a>">
    <cfelse>
        <cfset uhSyncButtonHtml = "<button type='button' class='btn btn-sm btn-ui-neutral disabled' disabled><i class='bi bi-cloud-download me-1'></i>UH Sync</button>">
    </cfif>

<cfset generalInfoHtml = "">
<cfset contactInfoHtml = "">
<cfset bioInfoHtml = "">
<cfset flagsHtml = "">
<cfset organizationsHtml = "">
<cfset externalHtml = "">
<cfset imagesHtml = "">
<cfset hasPrimaryAdditionalEmail = false>
<cfloop from="1" to="#arrayLen(userEmails)#" index="emailPrimaryIdx">
    <cfif val(userEmails[emailPrimaryIdx].ISPRIMARY ?: 0) EQ 1>
        <cfset hasPrimaryAdditionalEmail = true>
        <cfbreak>
    </cfif>
</cfloop>
<cfset hasGeneralInfo = len(trim(preferredName)) OR len(trim(maidenName)) OR arrayLen(userAliases) GT 0 OR len(trim(pronouns)) OR len(trim(cougarnetid)) OR len(trim(title1)) OR len(trim(title2)) OR len(trim(title3))>
<cfset hasContactInfo = arrayLen(userEmails) GT 0 OR arrayLen(userPhones) GT 0 OR arrayLen(userAddresses) GT 0>
<cfset hasBioInfo = isDate(userDOB) OR len(trim(userGender)) OR arrayLen(userDegrees) GT 0 OR arrayLen(spAwards) GT 0 OR len(trim(bioContent))>
<cfset hasFlags = arrayLen(profile.flags) GT 0>
<cfset hasOrganizations = arrayLen(profile.organizations) GT 0>
<cfset hasExternal = arrayLen(allSystems) GT 0>
<cfset hasImages = arrayLen(profile.images) GT 0>
<cfset generalSectionClass = hasGeneralInfo ? "" : " d-none">
<cfset contactSectionClass = hasContactInfo ? "" : " d-none">
<cfset bioSectionClass = hasBioInfo ? "" : " d-none">
<cfset orgSectionClass = hasOrganizations ? "" : " d-none">
<cfset flagsSectionClass = " d-none">
<cfset externalSectionClass = hasExternal ? "" : " d-none">
<cfset imagesSectionClass = hasImages ? "" : " d-none">

<cfset generalInfoHtml &= "<div class='users-view-panel-grid'>">
<cfif len(preferredName)>
    <cfset generalInfoHtml &= "<p><strong>Preferred Name:</strong> " & EncodeForHTML(preferredName) & " <span class='text-muted small'>(legacy)</span></p>">
</cfif>
<cfif len(maidenName)>
    <cfset generalInfoHtml &= "<p><strong>Maiden Name:</strong> " & EncodeForHTML(maidenName) & " <span class='text-muted small'>(legacy)</span></p>">
</cfif>
<cfset generalInfoHtml &= userAliasesHtml>
<cfif len(pronouns)>
    <cfset generalInfoHtml &= "<p><strong>Pronouns:</strong> " & EncodeForHTML(pronouns) & "</p>">
</cfif>
<cfif len(cougarnetid)>
    <cfset generalInfoHtml &= "<p><strong>CougarNet ID:</strong> " & EncodeForHTML(cougarnetid) & "</p>">
</cfif>
<cfif len(title1)>
    <cfset generalInfoHtml &= "<p><strong>Title 1:</strong> " & EncodeForHTML(title1) & "</p>">
</cfif>
<cfif len(title2)>
    <cfset generalInfoHtml &= "<p><strong>Title 2:</strong> " & EncodeForHTML(title2) & "</p>">
</cfif>
<cfif len(title3)>
    <cfset generalInfoHtml &= "<p><strong>Title 3:</strong> " & EncodeForHTML(title3) & "</p>">
</cfif>
<cfset generalInfoHtml &= "</div>">

<cfset contactInfoHtml &= "<div class='users-view-panel-grid'><div class='mb-3'><h6 class='mb-2'>Emails</h6>">
<cfif len(trim(emailPrimary ?: ""))>
    <cfset contactInfoHtml &= "<ul class='mb-2 users-view-org-list'>">
    <cfset contactInfoHtml &= "<li>" & EncodeForHTML(emailPrimary) & " <span class='badge badge-uh users-view-badge'>@UH</span>" & (NOT hasPrimaryAdditionalEmail ? " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>" : "") & "</li>">
    <cfset contactInfoHtml &= "</ul>">
</cfif>
<cfif arrayLen(userEmails) GT 0>
    <cfset contactInfoHtml &= "<ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userEmails)#" index="emIdx">
        <cfset em = userEmails[emIdx]>
        <cfset emType = len(trim(em.EMAILTYPE ?: "")) ? " <span class='badge badge-secondary users-view-badge'>" & EncodeForHTML(em.EMAILTYPE) & "</span>" : "">
        <cfset emPrimary = val(em.ISPRIMARY ?: 0) EQ 1 ? " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>" : "">
        <cfset contactInfoHtml &= "<li>" & EncodeForHTML(em.EMAILADDRESS ?: "") & emType & emPrimary & "</li>">
    </cfloop>
    <cfset contactInfoHtml &= "</ul>">
<cfelse>
    <cfset contactInfoHtml &= "<p class='text-muted mb-0'>No email records.</p>">
</cfif>
<cfset contactInfoHtml &= "</div><div class='mb-3'><h6 class='mb-2'>Phones</h6>">
<cfif arrayLen(userPhones) GT 0>
    <cfset contactInfoHtml &= "<ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userPhones)#" index="phIdx">
        <cfset ph = userPhones[phIdx]>
        <cfset phType = len(trim(ph.PHONETYPE ?: "")) ? " <span class='badge badge-secondary users-view-badge'>" & EncodeForHTML(ph.PHONETYPE) & "</span>" : "">
        <cfset phPrimary = val(ph.ISPRIMARY ?: 0) EQ 1 ? " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>" : "">
        <cfset contactInfoHtml &= "<li>" & EncodeForHTML(ph.PHONENUMBER ?: "") & phType & phPrimary & "</li>">
    </cfloop>
    <cfset contactInfoHtml &= "</ul>">
<cfelse>
    <cfset contactInfoHtml &= "<p class='text-muted mb-0'>No phone records.</p>">
</cfif>
<cfset contactInfoHtml &= "</div><div><h6 class='mb-2'>Addresses</h6>">
<cfif arrayLen(userAddresses) GT 0>
    <cfset contactInfoHtml &= "<ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userAddresses)#" index="adI">
        <cfset addrItem = userAddresses[adI]>
        <cfset addrLine = "<strong>" & EncodeForHTML(addrItem.ADDRESSTYPE ?: "Address") & "</strong>">
        <cfif val(addrItem.ISPRIMARY ?: 0)>
            <cfset addrLine &= " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>">
        </cfif>
        <cfset addrLine &= "<br><small class='text-muted'>">
        <cfif len(trim(addrItem.ADDRESS1 ?: ""))>
            <cfset addrLine &= EncodeForHTML(addrItem.ADDRESS1)>
        </cfif>
        <cfif len(trim(addrItem.ADDRESS2 ?: ""))>
            <cfset addrLine &= ", " & EncodeForHTML(addrItem.ADDRESS2)>
        </cfif>
        <cfif len(trim(addrItem.CITY ?: "")) OR len(trim(addrItem.STATE ?: "")) OR len(trim(addrItem.ZIPCODE ?: ""))>
            <cfset addrLine &= "<br>" & EncodeForHTML(addrItem.CITY ?: "")>
            <cfif len(trim(addrItem.STATE ?: ""))>
                <cfset addrLine &= ", " & EncodeForHTML(addrItem.STATE)>
            </cfif>
            <cfset addrLine &= " " & EncodeForHTML(addrItem.ZIPCODE ?: "")>
        </cfif>
        <cfset addrLine &= "</small>">
        <cfset contactInfoHtml &= "<li>" & addrLine & "</li>">
    </cfloop>
    <cfset contactInfoHtml &= "</ul>">
<cfelse>
    <cfset contactInfoHtml &= "<p class='text-muted mb-0'>No address records.</p>">
</cfif>
<cfset contactInfoHtml &= "</div></div>">

<cfset bioInfoHtml &= "<div class='users-view-panel-grid'>">
<cfif isDate(userDOB)>
    <cfset bioInfoHtml &= "<p><strong>Date of Birth:</strong> " & dateFormat(userDOB, "mmmm d, yyyy") & "</p>">
</cfif>
<cfif len(userGender)>
    <cfset bioInfoHtml &= "<p><strong>Gender:</strong> " & EncodeForHTML(userGender) & "</p>">
</cfif>
<cfif arrayLen(userDegrees) GT 0>
    <cfset bioInfoHtml &= "<div class='mb-3'><strong>Degrees:</strong><div class='table-responsive mt-2'><table class='table table-sm table-striped mb-0'><thead><tr><th>Degree</th><th>University</th><th>Year</th></tr></thead><tbody>">
    <cfloop from="1" to="#arrayLen(userDegrees)#" index="degIdx">
        <cfset deg = userDegrees[degIdx]>
        <cfset degName = trim((deg.DEGREENAME ?: deg.DEGREE ?: deg.DEGREEDESCRIPTION ?: "Degree") & "")>
        <cfset degUniversity = trim((deg.UNIVERSITY ?: "") & "")>
        <cfset degYear = trim((deg.DEGREEYEAR ?: "") & "")>
        <cfset bioInfoHtml &= "<tr><td>" & EncodeForHTML(degName) & "</td><td>" & (len(degUniversity) ? EncodeForHTML(degUniversity) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(degYear) ? EncodeForHTML(degYear) : "<span class='text-muted'>-</span>") & "</td></tr>">
    </cfloop>
    <cfset bioInfoHtml &= "</tbody></table></div></div>">
</cfif>
<cfif arrayLen(spAwards) GT 0>
    <cfset bioInfoHtml &= "<div class='mb-2'><strong>Awards:</strong><ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(spAwards)#" index="awIdx">
        <cfset award = spAwards[awIdx]>
        <cfset bioInfoHtml &= "<li>" & EncodeForHTML(award.AWARDNAME ?: "") & (len(trim(award.AWARDTYPE ?: "")) ? " <span class='badge badge-secondary users-view-badge'>" & EncodeForHTML(award.AWARDTYPE) & "</span>" : "") & "</li>">
    </cfloop>
    <cfset bioInfoHtml &= "</ul></div>">
</cfif>
<cfset bioInfoHtml &= "<div><strong>Bio / About Me:</strong>" & (len(trim(bioContent)) ? "<div class='mt-2'>" & bioContent & "</div>" : "<p class='text-muted mb-0 mt-2'>No bio content.</p>") & "</div></div>">

<cfset flagsHtml = "<div class='users-view-pill-stack'>">
<cfif arrayLen(profile.flags) GT 0>
    <cfloop from="1" to="#arrayLen(profile.flags)#" index="f">
        <cfset flagsHtml &= "<span class='badge rounded-pill users-view-badge badge-flags'>" & EncodeForHTML(profile.flags[f].FLAGNAME ?: "") & "</span>">
    </cfloop>
<cfelse>
    <cfset flagsHtml &= "<p class='text-muted mb-0'>No flags assigned.</p>">
</cfif>
<cfset flagsHtml &= "</div>">

<cfset organizationsHtml = "<ul class='mb-0 users-view-org-list'>">
<cfif arrayLen(profile.organizations) GT 0>
    <cfloop from="1" to="#arrayLen(profile.organizations)#" index="o">
        <cfset org = profile.organizations[o]>
        <cfset orgBadgeClass = findNoCase("clinic", org.ORGNAME ?: "") ? "badge-orgs-clinic" : "badge-orgs-college">
        <cfset orgLine = "<span class='badge rounded-pill users-view-badge " & orgBadgeClass & "'>" & EncodeForHTML(org.ORGNAME ?: "") & "</span>">
        <cfif len(trim(org.ROLETITLE ?: ""))>
            <cfset orgLine &= "<span class='text-muted small users-view-org-role'>(&nbsp;" & EncodeForHTML(org.ROLETITLE) & "&nbsp;)</span>">
        </cfif>
        <cfset organizationsHtml &= "<li>" & orgLine & "</li>">
    </cfloop>
<cfelse>
    <cfset organizationsHtml &= "<li class='text-muted'>No organizations assigned.</li>">
</cfif>
<cfset organizationsHtml &= "</ul>">

<cfset externalHtml = "<ul class='mb-0 users-view-org-list'>">
<cfif arrayLen(allSystems) GT 0>
    <cfloop from="1" to="#arrayLen(allSystems)#" index="sysIdx">
        <cfset sys = allSystems[sysIdx]>
        <cfset sysVal = structKeyExists(externalBySystem, toString(sys.SYSTEMID)) ? externalBySystem[toString(sys.SYSTEMID)] : "">
        <cfset externalHtml &= "<li><strong>" & EncodeForHTML(sys.SYSTEMNAME ?: "System") & ":</strong> " & (len(trim(sysVal)) ? EncodeForHTML(sysVal) : "<span class='text-muted'>Not set</span>") & "</li>">
    </cfloop>
<cfelse>
    <cfset externalHtml &= "<li class='text-muted'>No external systems configured.</li>">
</cfif>
<cfset externalHtml &= "</ul>">

<cfif arrayLen(profile.images) GT 0>
    <cfset variantGroups = {}>
    <cfset variantOrder = []>
    <cfloop from="1" to="#arrayLen(profile.images)#" index="i">
        <cfset img = profile.images[i]>
        <cfset vKey = lCase(trim(img.IMAGEVARIANT ?: "unknown"))>
        <cfif NOT structKeyExists(variantGroups, vKey)>
            <cfset variantGroups[vKey] = []>
            <cfset arrayAppend(variantOrder, vKey)>
        </cfif>
        <cfset arrayAppend(variantGroups[vKey], img)>
    </cfloop>

    <cfset imagesHtml &= "<div class='accordion users-view-images-accordion accordion-flat' id='imagesAccordion'>">
    <cfloop from="1" to="#arrayLen(variantOrder)#" index="gi">
        <cfset gKey = variantOrder[gi]>
        <cfset gItems = variantGroups[gKey]>
        <cfset gLabel = encodeForHTML(uCase(gKey))>
        <cfset gCount = arrayLen(gItems)>
        <cfset gDim = "">
        <cfif len(gItems[1].IMAGEDIMENSIONS ?: "")>
            <cfset gDim = encodeForHTML(gItems[1].IMAGEDIMENSIONS)>
        </cfif>
        <cfset collapseID = "imgGroup_#gi#">
        <cfset imagesHtml &= "
        <div class='accordion-item'>
            <h2 class='accordion-header' id='heading_#collapseID#'>
                <button class='accordion-button #gi GT 1 ? "collapsed" : ""#' type='button' data-bs-toggle='collapse' data-bs-target='###collapseID#' aria-expanded='#gi EQ 1 ? "true" : "false"#' aria-controls='#collapseID#'>
                    <span class='fw-semibold'>#gLabel#</span>
                    <span class='badge badge-info users-view-image-count-badge ms-2'>#gCount#</span>
                    #len(gDim) ? "<span class='users-view-image-dimension small ms-2'>" & gDim & "</span>" : ""#
                </button>
            </h2>
            <div id='#collapseID#' class='accordion-collapse collapse #gi EQ 1 ? "show" : ""#' aria-labelledby='heading_#collapseID#' data-bs-parent='##imagesAccordion'>
                <div class='accordion-body'>
                    <div class='row'>">

        <cfloop from="1" to="#arrayLen(gItems)#" index="j">
            <cfset img = gItems[j]>
            <cfset imagesHtml &= "
                    <div class='col-md-3 mb-3'>
                        <img class='img-fluid rounded shadow-sm' src='#img.IMAGEURL#' alt='#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#' title='#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#'>
                        <p class='mt-2 mb-0'>#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#</p>
                        <cfif len(img.IMAGEDIMENSIONS ?: "")>
                            <p class='text-muted small mb-0'>#encodeForHTML(img.IMAGEDIMENSIONS)#</p>
                        </cfif>
                    </div>">
        </cfloop>

        <cfset imagesHtml &= "
                    </div>
                </div>
            </div>
        </div>">
    </cfloop>
    <cfset imagesHtml &= "</div>">
<cfelse>
    <cfset imagesHtml = "<p class='text-muted mb-0'>No images available.</p>">
</cfif>

<cfset content = "
#usersTopToolBar#
<div class='py-4 px-4 pt-2'>
<div class='d-flex flex-wrap align-items-center gap-2 mb-4'>
    <a href='/admin/users/edit.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-sm btn-ui-neutral'>
        <i class='bi bi-pencil me-1'></i>Edit This User
    </a>
    #uhSyncButtonHtml#
    <a href='/admin/users/search_UH_API.cfm' class='btn btn-sm btn-ui-neutral'>
        <i class='bi bi-search me-1'></i>Search The UH API
    </a>
    <a href='/admin/users/search_UH_LDAP.cfm' class='btn btn-sm btn-ui-neutral'>
        <i class='bi bi-person-vcard me-1'></i>Search The UH LDAP
    </a>
</div>

<div class='users-view-page'>
    <div class='users-view-header clearfix'>
        <img src='#profileThumbnail#' alt='Profile Thumbnail' class='rounded float-start me-3 mb-2 admin-object-cover users-view-profile-thumb'>
        <h1 class='users-view-title'>#(len(prefix) ? prefix & ' ' : '')##resolvedFirstName# #resolvedLastName##(len(suffix) ? ', ' & suffix : '')##(len(trim(degrees)) ? ', ' & EncodeForHTML(degrees) : '')#</h1>
        <div class='users-view-subtitle'>#SubTitle#</div>
        #flagsRowHtml#
    </div>

    <div class='users-view-masonry'>
        <div class='users-view-masonry-item#generalSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionGeneral'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingGeneral'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseGeneral' aria-expanded='true' aria-controls='collapseGeneral'>General Information</button>
                    </h2>
                    <div id='collapseGeneral' class='accordion-collapse collapse show' aria-labelledby='headingGeneral'>
                        <div class='accordion-body'>#generalInfoHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item#contactSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionContact'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingContact'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseContact' aria-expanded='true' aria-controls='collapseContact'>Contact Information</button>
                    </h2>
                    <div id='collapseContact' class='accordion-collapse collapse show' aria-labelledby='headingContact'>
                        <div class='accordion-body'>#contactInfoHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item#bioSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionBio'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingBio'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseBio' aria-expanded='true' aria-controls='collapseBio'>Biographical Information</button>
                    </h2>
                    <div id='collapseBio' class='accordion-collapse collapse show' aria-labelledby='headingBio'>
                        <div class='accordion-body'>#bioInfoHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item#orgSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionOrgs'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingOrgs'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseOrgs' aria-expanded='true' aria-controls='collapseOrgs'>Organizations</button>
                    </h2>
                    <div id='collapseOrgs' class='accordion-collapse collapse show' aria-labelledby='headingOrgs'>
                        <div class='accordion-body'>#organizationsHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item#flagsSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionFlags'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingFlags'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseFlags' aria-expanded='true' aria-controls='collapseFlags'>Flags</button>
                    </h2>
                    <div id='collapseFlags' class='accordion-collapse collapse show' aria-labelledby='headingFlags'>
                        <div class='accordion-body'>#flagsHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item#externalSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionExternal'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingExternal'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseExternal' aria-expanded='true' aria-controls='collapseExternal'>External IDs</button>
                    </h2>
                    <div id='collapseExternal' class='accordion-collapse collapse show' aria-labelledby='headingExternal'>
                        <div class='accordion-body'>#externalHtml#</div>
                    </div>
                </div>
            </div>
        </div>

        <div class='users-view-masonry-item users-view-images-panel#imagesSectionClass#'>
            <div class='accordion users-view-accordion accordion-feature' id='usersViewAccordionImages'>
                <div class='accordion-item users-view-card card-surface'>
                    <h2 class='accordion-header' id='headingImages'>
                        <button class='accordion-button' type='button' data-bs-toggle='collapse' data-bs-target='##collapseImages' aria-expanded='true' aria-controls='collapseImages'>Images</button>
                    </h2>
                    <div id='collapseImages' class='accordion-collapse collapse show' aria-labelledby='headingImages'>
                        <div class='accordion-body'>#imagesHtml#</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class='mt-4'>
        <a href='/admin/users/edit.cfm?userID=#profile.user.USERID#&returnTo=#urlEncodedFormat(returnTo)#' class='btn btn-ui-uh'>Edit</a>
        <a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-ui-neutral'>Back to Users</a>
    </div>
</div>
</div>
" />




<cfinclude template="/admin/layout.cfm">