<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfif NOT request.hasPermission("users.view")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset profile = directoryService.getFullProfile(url.userID)>
<cfset freshUserResult = usersService.getUser(val(url.userID))>
<cfset userActiveRaw = val(profile.user.ACTIVE ?: 0)>
<cfif structKeyExists(freshUserResult, "success") AND freshUserResult.success>
    <cfset userActiveRaw = val(freshUserResult.data.ACTIVE ?: userActiveRaw)>
</cfif>
<cftry>
    <cfset activeQry = queryExecute(
        "SELECT TOP 1 Active FROM Users WHERE UserID = :id",
        { id = { value=val(url.userID), cfsqltype="cf_sql_integer" } },
        { datasource=request.datasource, timeout=30 }
    )>
    <cfif activeQry.recordCount GT 0>
        <cfset userActiveRaw = val(activeQry.Active[1] ?: userActiveRaw)>
    </cfif>
    <cfcatch type="any">
        <!--- Keep previously resolved value when direct query is unavailable. --->
    </cfcatch>
</cftry>
<cfset userIsActive = userActiveRaw EQ 1>
<cfset userStatusBadgeHtml = userIsActive
    ? "<span class='badge badge-success users-view-badge'><i class='bi bi-check-circle me-1'></i>Record Active</span>"
    : "<span class='badge badge-danger users-view-badge'><i class='bi bi-x-circle me-1'></i>Record Inactive</span>">
<cfif NOT request.canAccessUserProfile(profile)>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>
<cfset _viewIsAlumni = false>
<cfset _viewIsFaculty = false>
<cfloop from="1" to="#arrayLen(profile.flags)#" index="_vf">
    <cfif compareNoCase(trim(profile.flags[_vf].FLAGNAME ?: ""), "Alumni") EQ 0>
        <cfset _viewIsAlumni = true>
    </cfif>
    <cfif listFindNoCase("Faculty-Fulltime,Faculty-Adjunct", trim(profile.flags[_vf].FLAGNAME ?: ""))>
        <cfset _viewIsFaculty = true>
    </cfif>
</cfloop>
<cfif _viewIsAlumni AND NOT (application.authService.hasRole("ALUMNI_ADMIN") OR (_viewIsFaculty AND application.authService.hasAnyRole(["USER_ADMIN", "CLINICAL_FACULTY_ADMIN", "RESEARCH_FACULTY_ADMIN"])))>
    <cflocation url="#request.webRoot#/admin/dashboard.cfm" addtoken="false">
    <cfabort>
</cfif>
<cfset returnTo = structKeyExists(url, "returnTo") AND len(trim(url.returnTo)) ? trim(url.returnTo) : (len(trim(cgi.HTTP_REFERER)) ? trim(cgi.HTTP_REFERER) : "/admin/users/index.cfm")>
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

<cfset usersTopToolBar = "
    <nav class='navbar sticky-top users-list-toolbar'>
        <div class='container-fluid users-list-toolbar-shell'>
            <div class='users-list-toolbar-primary'>
                <button class='btn btn-sm btn-ui-cancel me-2 admin-sidebar-toggle' id='sidebarToggle' type='button' title='Toggle Sidebar' aria-label='Toggle Sidebar'>
                    <i class='bi bi-list'></i>
                </button>
                <div class='navbar-brand users-list-toolbar-brand mb-0 fs-5 d-flex align-items-center gap-2'>
                    <span>UHCO_Identity</span>
                    <span class='users-list-toolbar-brand-divider'>|</span>
                    <i class='bi bi-people-fill'></i>
                    <span class='users-list-toolbar-brand-label'>Users</span>
                </div>
                <div class='users-list-toolbar-controls'>
                    <form method='get' action='/admin/users/index.cfm' class='users-list-toolbar-search-form'>
                        <input type='hidden' name='list' value='#toolbarListType#'>
                        <input type='hidden' name='page' value='1'>
                        <div class='input-group users-list-toolbar-search users-list-toolbar-input-group'>
                            <input type='text' name='search' class='form-control' placeholder='Search name/email or use field:value (e.g. lastname:Doe &amp;&amp; firstname:Jane)' value='#encodeForHTMLAttribute(toolbarSearchTerm)#'>
                            <button class='btn btn-ui-filter' type='submit'><i class='bi bi-search me-1'></i>Search</button>
                        </div>
                    </form>
                </div>
            </div>
        
            <ul class='navbar-nav d-flex flex-row align-items-center gap-2 ms-auto users-list-toolbar-nav'>
                <li class='nav-item dropdown ms-3 users-list-toolbar-account'>
                    <a class='nav-link dropdown-toggle p-0 d-flex align-items-center gap-2 text-dark' href='##' role='button' data-bs-toggle='dropdown' aria-expanded='false' aria-label='User menu'>
                        <img src='#encodeForHTMLAttribute(currentUserImageSrc)#' alt='Profile image for #encodeForHTMLAttribute(trim(currentAdminUser.displayName ?: "Admin User"))#' class='rounded-circle users-list-toolbar-avatar admin-toolbar-avatar'>
                        <span class='d-none d-lg-inline small'>#currentUserDisplayName#</span>
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
                        #(structCount(impersonationState) ? "<div class='users-list-toolbar-impersonation alert alert-warning mb-3 py-2 px-3'><div class='small fw-semibold text-uppercase mb-1'>Impersonation Active</div><div class='small mb-2'>You are currently using <strong>" & encodeForHTML(impersonationState.label ?: "") & "</strong>.</div><form method='post' action='" & request.webRoot & "/admin/settings/admin-users/save.cfm' class='mb-0'><input type='hidden' name='action' value='clearImpersonation'><input type='hidden' name='returnURL' value='" & encodeForHTMLAttribute(currentRequestUrl) & "'><button type='submit' class='btn btn-sm btn-ui-warning w-100'><i class='bi bi-x-octagon me-1'></i>Stop Impersonating</button></form></div>" : "")#
                        <div class='d-grid'>
                            <a href='#request.webRoot#/admin/logout.cfm' class='btn btn-sm btn-ui-go'><i class='bi bi-box-arrow-right me-1'></i>Logout</a>
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

<!--- ── Appointments ── --->
<cfset userAppointments = (structKeyExists(profile, "appointments") AND isArray(profile.appointments)) ? profile.appointments : []>
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

<cfset isFacultyProfile = false>
<cfloop from="1" to="#arrayLen(profile.flags)#" index="ff">
    <cfif listFindNoCase("clinical-attending,faculty-adjunct,faculty-fulltime", lCase(trim(profile.flags[ff].FLAGNAME ?: "")))>
        <cfset isFacultyProfile = true>
        <cfbreak>
    </cfif>
</cfloop>

<cfset clinicalBioData    = isFacultyProfile ? bioSvc.getBio(val(url.userID), "ClinicalBio").data : {}>
<cfset clinicalBioContent = structIsEmpty(clinicalBioData) ? "" : (clinicalBioData.BIOCONTENT ?: "")>

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
<cfset uhApiId     = trim(profile.user.UH_API_ID ?: "")>
<cfset showAcademicInfo   = false>
<cfset showStudentProfile = false>
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

<cfset userAliasesHtml = "">
<cfif arrayLen(userAliases)>
    <cfset userAliasesHtml = "<div class='mb-3'><strong>Aliases:</strong><div class='table-responsive mt-2'><table class='table table-sm table-striped mb-0'><thead><tr><th>First</th><th>Middle</th><th>Last</th><th>Type / System</th><th>Alias Status</th></tr></thead><tbody>">
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
        <cfif aliasIsActive AND NOT userIsActive>
            <cfset aliasStatusHtml = "<span class='badge badge-warning users-view-badge'>Alias Active (Record Inactive)</span>">
        <cfelse>
            <cfset aliasStatusHtml = (aliasIsActive ? "<span class='badge badge-success users-view-badge'>Alias Active</span>" : "<span class='badge badge-danger users-view-badge'>Alias Inactive</span>")>
        </cfif>
        <cfset aliasStatusHtml &= (aliasIsPrimary ? " <span class='badge badge-isprimary users-view-badge'><i class='bi bi-check2 me-1'></i>Primary</span>" : "")>
        <cfset userAliasesHtml &= "<tr><td>" & (len(aliasFirst) ? EncodeForHTML(aliasFirst) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasMiddle) ? EncodeForHTML(aliasMiddle) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasLast) ? EncodeForHTML(aliasLast) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(aliasTypeSystem) ? EncodeForHTML(aliasTypeSystem) : "<span class='text-muted'>-</span>") & "</td><td>" & aliasStatusHtml & "</td></tr>">
    </cfloop>
    <cfset userAliasesHtml &= "</tbody></table></div></div>">
</cfif>

<cfset userAppointmentsHtml = "">
<cfif arrayLen(userAppointments)>
    <cfset userAppointmentsHtml = "<div class='mb-3'><strong>Appointments:</strong><div class='table-responsive mt-2'><table class='table table-sm table-striped mb-0'><thead><tr><th>Appointment Name</th><th>Type</th></tr></thead><tbody>">
    <cfloop from="1" to="#arrayLen(userAppointments)#" index="apptIndex">
        <cfset apptItem = userAppointments[apptIndex]>
        <cfset apptName = trim(apptItem.APPOINTMENTNAME ?: "")>
        <cfset apptType = trim(apptItem.APPOINTMENTTYPE ?: "")>
        <cfset userAppointmentsHtml &= "<tr><td>" & (len(apptName) ? EncodeForHTML(apptName) : "<span class='text-muted'>-</span>") & "</td><td>" & (len(apptType) ? EncodeForHTML(apptType) : "<span class='text-muted'>-</span>") & "</td></tr>">
    </cfloop>
    <cfset userAppointmentsHtml &= "</tbody></table></div></div>">
</cfif>

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
<cfset hasGeneralInfo = len(trim(preferredName)) OR len(trim(maidenName)) OR arrayLen(userAliases) GT 0 OR len(trim(pronouns)) OR len(trim(cougarnetid)) OR len(trim(title1)) OR arrayLen(userAppointments) GT 0>
<cfset hasContactInfo = arrayLen(userEmails) GT 0 OR arrayLen(userPhones) GT 0 OR arrayLen(userAddresses) GT 0>
<cfset hasBioInfo = isDate(userDOB) OR len(trim(userGender)) OR arrayLen(userDegrees) GT 0 OR arrayLen(spAwards) GT 0 OR len(trim(bioContent)) OR len(trim(clinicalBioContent))>
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
<cfset generalInfoHtml &= userAppointmentsHtml>
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
<cfset bioInfoHtml &= "<div><strong>Bio / About Me:</strong>" & (len(trim(bioContent)) ? "<div class='mt-2'>" & bioContent & "</div>" : "<p class='text-muted mb-0 mt-2'>No bio content.</p>") & "</div>">
<cfif isFacultyProfile AND len(trim(clinicalBioContent))>
    <cfset bioInfoHtml &= "<div class='mt-3'><strong>Clinical Bio:</strong><div class='mt-2'>" & clinicalBioContent & "</div></div>">
</cfif>
<cfset bioInfoHtml &= "</div>">

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
<div class='users-page-secondary-toolbar users-view-secondary-toolbar mb-4'>
    <div class='users-page-secondary-toolbar-heading users-view-header'>
        <img src='#profileThumbnail#' alt='Profile Thumbnail' class='rounded admin-object-cover users-view-profile-thumb'>
        <div class='users-view-header-body'>
            <h1 class='users-view-title'>#(len(prefix) ? prefix & ' ' : '')##resolvedFirstName# #resolvedLastName##(len(suffix) ? ', ' & suffix : '')#<cfif len(trim(degrees))><span class='users-view-degrees'>, #EncodeForHTML(degrees)#</span></cfif></h1>
            <div class='users-view-subtitle'>#SubTitle#</div>
            <div class='mb-2'>#userStatusBadgeHtml#</div>
        </div>
    </div>
    <div class='users-page-secondary-toolbar-actions'>
        <a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-sm btn-ui-cancel'>
            <i class='bi bi-people-fill me-1'></i>Back to User List
        </a>
        <a href='/admin/users/edit.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-sm btn-ui-edit'>
            <i class='bi bi-pencil me-1'></i>Edit This User
        </a>
    </div>
</div>

<div class='users-view-page'>
    #flagsRowHtml#

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
        <a href='/admin/users/edit.cfm?userID=#profile.user.USERID#&returnTo=#urlEncodedFormat(returnTo)#' class='btn btn-ui-edit'>Edit</a>
        <a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-ui-cancel'>Back to Users</a>
    </div>
</div>
</div>
" />




<cfinclude template="/admin/layout.cfm">