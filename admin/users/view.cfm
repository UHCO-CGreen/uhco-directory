<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset profile = directoryService.getFullProfile(url.userID)>
<cfset returnTo = structKeyExists(url, "returnTo") AND len(trim(url.returnTo)) ? trim(url.returnTo) : (len(trim(cgi.HTTP_REFERER)) ? trim(cgi.HTTP_REFERER) : "/admin/users/index.cfm")>
<cfparam name="form.quickApiMatch" default="0">
<cfparam name="form.saveMatchedApiId" default="0">
<cfparam name="form.matchedApiId" default="">

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

<cfset dqDAO            = createObject("component", "dao.dataQuality_DAO").init()>
<cfset dqExclusionsList = dqDAO.getExclusionsForUser(val(url.userID))>
<cfset dqExclusionLabelMap = {
    "missing_uh_api_id"      : "Missing UH API ID",
    "missing_primary_alias"  : "Missing Primary Alias",
    "missing_email_primary"  : "Missing Primary Email",
    "missing_title1"         : "Missing Title",
    "missing_room"           : "Missing Room",
    "missing_building"       : "Missing Building",
    "missing_phone"          : "Missing Phone",
    "missing_degrees"        : "Missing Degrees",
    "no_flags"               : "Zero Flags",
    "no_orgs"                : "Zero Organizations",
    "no_images"              : "No Images",
    "missing_cougarnet"      : "Missing CougarNet ID",
    "missing_peoplesoft"     : "Missing PeopleSoft ID",
    "missing_legacy_id"      : "Missing Legacy ID",
    "missing_grad_year"      : "Missing Grad Year (Students Only)"
}>

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
    <cfset userAliasesHtml = "<div class='mb-2'><strong>Aliases:</strong><ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userAliases)#" index="aliasIndex">
        <cfset aliasItem = userAliases[aliasIndex]>
        <cfset aliasTypeHtml = len(trim(aliasItem.ALIASTYPE ?: "")) ? " <span class='badge bg-secondary text-dark users-view-badge'>" & EncodeForHTML(aliasItem.ALIASTYPE) & "</span>" : "">
        <cfset aliasInactiveHtml = val(aliasItem.ISACTIVE ?: 0) NEQ 1 ? " <span class='badge bg-light text-dark users-view-badge'>Inactive</span>" : "">
        <cfset userAliasesHtml &= "<li>" & EncodeForHTML(aliasItem.DISPLAYNAME ?: "") & aliasTypeHtml & aliasInactiveHtml & "</li>">
    </cfloop>
    <cfset userAliasesHtml &= "</ul></div>">
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
            <cfset SubTitle = len(degrees) ? "<p class='text-muted fs-5'>#degrees#</p>" : "">
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
        <cfset flagsRowHtml &= "<span class='badge rounded-pill users-view-badge users-view-badge-flag'>" & EncodeForHTML(flag.FLAGNAME) & "</span>">
    </cfloop>
    <cfset flagsRowHtml &= "</div>">
<cfelse>
    <cfset flagsRowHtml = "<p class='text-muted small mt-1 mb-2'>No flags assigned</p>">
</cfif>

<!---#quickMatchHtml#--->

<cfif len(trim(profile.user.UH_API_ID ?: ""))>
        <cfset uhSyncUrl = "/admin/users/uh_sync.cfm?userID=" & urlEncodedFormat(profile.user.USERID) & "&uhApiId=" & urlEncodedFormat(profile.user.UH_API_ID)>
        <cfset uhSyncButtonHtml = "<a href='" & uhSyncUrl & "' class='btn btn-sm btn-secondary text-dark'><i class='bi bi-cloud-download me-1'></i>UH Sync</a>">
    <cfelse>
        <cfset uhSyncButtonHtml = "<button type='button' class='btn btn-sm btn-secondary text-dark disabled' disabled><i class='bi bi-cloud-download me-1'></i>UH Sync</button>">
    </cfif>

<cfset content = "
<div class='d-flex flex-wrap align-items-center gap-2 mb-4'>
    <a href='/admin/users/edit.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-sm btn-secondary text-dark'>
        <i class='bi bi-pencil me-1'></i>Edit This User
    </a>
    #uhSyncButtonHtml#
    <a href='/admin/users/search_UH_API.cfm' class='btn btn-sm btn-secondary text-dark'>
        <i class='bi bi-search me-1'></i>Search The UH API
    </a>
    <a href='/admin/users/search_UH_LDAP.cfm' class='btn btn-sm btn-secondary text-dark'>
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




<div class='row mt-4'>
    <div class='col-md-6'>
        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>General Information</div>
            <div class='card-body'>
                #(len(preferredName) ? '<p><strong>Preferred Name:</strong> ' & EncodeForHTML(preferredName) & ' <span class="text-muted small">(legacy)</span></p>' : '')#
                #(len(maidenName)    ? '<p><strong>Maiden Name:</strong> '    & EncodeForHTML(maidenName) & ' <span class="text-muted small">(legacy)</span></p>' : '')#
    #userAliasesHtml#
                #(len(pronouns)      ? '<p><strong>Pronouns:</strong> '        & EncodeForHTML(pronouns)      & '</p>' : '')#
                #(len(emailPrimary)  ? '<p><strong>Email (@uh):</strong> '      & EncodeForHTML(emailPrimary)  & '</p>' : '')#
                #(len(phone)         ? '<p><strong>Phone:</strong> '            & EncodeForHTML(phone)         & '</p>' : '')#
                #(len(cougarnetid)   ? '<p><strong>CougarNet ID:</strong> '     & EncodeForHTML(cougarnetid)   & '</p>' : '')#
                #(len(title1)        ? '<p><strong>Title 1:</strong> '          & EncodeForHTML(title1)        & '</p>' : '')#
                #(len(title2)        ? '<p><strong>Title 2:</strong> '          & EncodeForHTML(title2)        & '</p>' : '')#
                #(len(title3)        ? '<p><strong>Title 3:</strong> '          & EncodeForHTML(title3)        & '</p>' : '')#
            </div>
        </div>
        #( hasAddress ? "
        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>Address</div>
            <div class='card-body'>
                #(len(room)          ? '<p><strong>Room:</strong> '                  & EncodeForHTML(room)          & '</p>' : '')#
                #(len(building)      ? '<p><strong>Building:</strong> '              & EncodeForHTML(building)      & '</p>' : '')#
                #(len(campus)        ? '<p><strong>Campus:</strong> '               & EncodeForHTML(campus)        & '</p>' : '')#
                #(len(division)       ? '<p><strong>Division:</strong> '      & EncodeForHTML(division)       & (len(divisionName)   ? ' <span class="text-muted">(' & EncodeForHTML(divisionName)   & ')</span>' : '') & '</p>' : '')#
                #(len(department)     ? '<p><strong>Department:</strong> '    & EncodeForHTML(department)     & (len(departmentName) ? ' <span class="text-muted">(' & EncodeForHTML(departmentName) & ')</span>' : '') & '</p>' : '')#
                #(len(officeMailAddr)? '<p><strong>Office Mailing Address:</strong> '& EncodeForHTML(officeMailAddr)& '</p>' : '')#
                #(len(mailcode)      ? '<p><strong>Mailcode:</strong> '             & EncodeForHTML(mailcode)      & '</p>' : '')#
            </div>
        </div>" : "" )#
    </div>

    <div class='col-md-6'>
        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>Organizations</div>
            <div class='card-body'>
            <ul class='list-unstyled mb-0 users-view-org-list'>
" />

<cfif arrayLen(profile.organizations) gt 0>
    <cfloop from="1" to="#arrayLen(profile.organizations)#" index="o">
        <cfset org = profile.organizations[o]>
        <cfset orgLine = "<span class='badge rounded-pill users-view-badge users-view-badge-org'>" & EncodeForHTML(org.ORGNAME) & "</span>">
        <cfif len(trim(org.ROLETITLE ?: ""))>
            <cfset orgLine &= "<span class='text-muted small users-view-org-role'>(&nbsp;" & EncodeForHTML(org.ROLETITLE) & "&nbsp;)</span>">
        </cfif>
        <cfset content &= "<li>#orgLine#</li>">
    </cfloop>
<cfelse>
    <cfset content &= "<li class='text-muted'>No organizations assigned</li>">
</cfif>

<cfset content &= "
                </ul>
            </div>
        </div>
    </div>
</div>

<div class='row'>
    <div class='col-md-6'>
        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>Contact Details</div>
            <div class='card-body'>
                <p class='mb-2'><strong>Emails</strong></p>
">

<cfif arrayLen(userEmails) GT 0>
    <cfset content &= "<ul class='mb-3 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userEmails)#" index="emIdx">
        <cfset em = userEmails[emIdx]>
        <cfset emType = len(trim(em.EMAILTYPE ?: "")) ? " <span class='badge bg-secondary text-dark users-view-badge'>" & EncodeForHTML(em.EMAILTYPE) & "</span>" : "">
        <cfset emPrimary = val(em.ISPRIMARY ?: 0) EQ 1 ? " <span class='badge bg-success users-view-badge'>Primary</span>" : "">
        <cfset content &= "<li>" & EncodeForHTML(em.EMAILADDRESS ?: "") & emType & emPrimary & "</li>">
    </cfloop>
    <cfset content &= "</ul>">
<cfelse>
    <cfset content &= "<p class='text-muted small mb-3'>No email records.</p>">
</cfif>

<cfset content &= "<p class='mb-2'><strong>Phones</strong></p>">

<cfif arrayLen(userPhones) GT 0>
    <cfset content &= "<ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(userPhones)#" index="phIdx">
        <cfset ph = userPhones[phIdx]>
        <cfset phType = len(trim(ph.PHONETYPE ?: "")) ? " <span class='badge bg-secondary text-dark users-view-badge'>" & EncodeForHTML(ph.PHONETYPE) & "</span>" : "">
        <cfset phPrimary = val(ph.ISPRIMARY ?: 0) EQ 1 ? " <span class='badge bg-success users-view-badge'>Primary</span>" : "">
        <cfset content &= "<li>" & EncodeForHTML(ph.PHONENUMBER ?: "") & phType & phPrimary & "</li>">
    </cfloop>
    <cfset content &= "</ul>">
<cfelse>
    <cfset content &= "<p class='text-muted small mb-0'>No phone records.</p>">
</cfif>

<cfset content &= "
            </div>
        </div>

        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>External IDs</div>
            <div class='card-body'>
                <ul class='mb-0 users-view-org-list'>
">

<cfif arrayLen(allSystems) GT 0>
    <cfloop from="1" to="#arrayLen(allSystems)#" index="sysIdx">
        <cfset sys = allSystems[sysIdx]>
        <cfset sysVal = structKeyExists(externalBySystem, toString(sys.SYSTEMID)) ? externalBySystem[toString(sys.SYSTEMID)] : "">
        <cfset content &= "<li><strong>" & EncodeForHTML(sys.SYSTEMNAME ?: "System") & ":</strong> " & (len(trim(sysVal)) ? EncodeForHTML(sysVal) : "<span class='text-muted'>Not set</span>") & "</li>">
    </cfloop>
<cfelse>
    <cfset content &= "<li class='text-muted'>No external systems configured.</li>">
</cfif>

<cfset content &= "
                </ul>
            </div>
        </div>
    </div>

    <div class='col-md-6'>
        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>Bio / About Me</div>
            <div class='card-body'>
                " & (len(trim(bioContent)) ? bioContent : "<p class='text-muted mb-0'>No bio content.</p>") & "
            </div>
        </div>

        <div class='card mb-3 users-view-card'>
            <div class='card-header fw-semibold'>Data Quality Exclusions</div>
            <div class='card-body'>
">

<cfif arrayLen(dqExclusionsList) GT 0>
    <cfset content &= "<ul class='mb-0 users-view-org-list'>">
    <cfloop from="1" to="#arrayLen(dqExclusionsList)#" index="dqIdx">
        <cfset dqCode = dqExclusionsList[dqIdx]>
        <cfset dqLabel = structKeyExists(dqExclusionLabelMap, dqCode) ? dqExclusionLabelMap[dqCode] : dqCode>
        <cfset content &= "<li>" & EncodeForHTML(dqLabel) & "</li>">
    </cfloop>
    <cfset content &= "</ul>">
<cfelse>
    <cfset content &= "<p class='text-muted mb-0'>No exclusions; all checks are included.</p>">
</cfif>

<cfset content &= "
            </div>
        </div>
    </div>
</div>

<hr>

<h3 class='d-flex justify-content-between align-items-center users-view-images-header users-view-section-title'>
    Images
">

<cfif request.hasPermission("media.edit")>
    <cfset content &= "
    <a href='/admin/user-media/sources.cfm?userid=#url.userID#'
       class='btn btn-sm btn-outline-primary'>
        <i class='bi bi-pencil-square me-1'></i> Manage Images
    </a>
    ">
</cfif>

<cfset content &= "
</h3>
">

<cfif arrayLen(profile.images) GT 0>
    <!--- Group images by ImageVariant --->
    <cfset variantGroups = {}>
    <cfset variantOrder  = []>
    <cfloop from="1" to="#arrayLen(profile.images)#" index="i">
        <cfset img = profile.images[i]>
        <cfset vKey = lCase(trim(img.IMAGEVARIANT ?: "unknown"))>
        <cfif NOT structKeyExists(variantGroups, vKey)>
            <cfset variantGroups[vKey] = []>
            <cfset arrayAppend(variantOrder, vKey)>
        </cfif>
        <cfset arrayAppend(variantGroups[vKey], img)>
    </cfloop>

    <cfset content &= "<div class='accordion users-view-images-accordion' id='imagesAccordion'>">

    <cfloop from="1" to="#arrayLen(variantOrder)#" index="gi">
        <cfset gKey   = variantOrder[gi]>
        <cfset gItems = variantGroups[gKey]>
        <cfset gLabel = encodeForHTML(uCase(gKey))>
        <cfset gCount = arrayLen(gItems)>
        <!--- Use the first image's dimensions as the group dimension hint --->
        <cfset gDim = "">
        <cfif len(gItems[1].IMAGEDIMENSIONS ?: "")>
            <cfset gDim = encodeForHTML(gItems[1].IMAGEDIMENSIONS)>
        </cfif>
        <cfset collapseID = "imgGroup_#gi#">

        <cfset content &= "
        <div class='accordion-item'>
            <h2 class='accordion-header' id='heading_#collapseID#'>
                <button class='accordion-button #gi GT 1 ? "collapsed" : ""#' type='button'
                        data-bs-toggle='collapse' data-bs-target='###collapseID#'
                        aria-expanded='#gi EQ 1 ? "true" : "false"#'
                        aria-controls='#collapseID#'>
                    <span class='fw-semibold'>#gLabel#</span>
                    <span class='badge users-view-image-count-badge ms-2'>#gCount#</span>
                    #len(gDim) ? "<span class='users-view-image-dimension small ms-2'>" & gDim & "</span>" : ""#
                </button>
            </h2>
            <div id='#collapseID#' class='accordion-collapse collapse #gi EQ 1 ? "show" : ""#'
                 aria-labelledby='heading_#collapseID#'
                 data-bs-parent='##imagesAccordion'>
                <div class='accordion-body'>
                    <div class='row'>
        ">

        <cfloop from="1" to="#arrayLen(gItems)#" index="j">
            <cfset img = gItems[j]>
            <cfset content &= "
                    <div class='col-md-3 mb-3'>
                        <img class='img-fluid rounded shadow-sm'
                             src='#img.IMAGEURL#'
                             alt='#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#'
                             title='#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#'>
                        <p class='mt-2 mb-0'>#encodeForHTML(img.IMAGEDESCRIPTION ?: "")#</p>
                        <cfif len(img.IMAGEDIMENSIONS ?: '')>
                            <p class='text-muted small mb-0'>#encodeForHTML(img.IMAGEDIMENSIONS)#</p>
                        </cfif>
                    </div>
            ">
        </cfloop>

        <cfset content &= "
                    </div>
                </div>
            </div>
        </div>
        ">
    </cfloop>

    <cfset content &= "</div>">
<cfelse>
    <cfset content &= "<p class='text-muted'>No images</p>">
</cfif>

<cfif showAcademicInfo>
    <cfset content &= "<hr><h3 class='users-view-section-title'>Academic Info</h3><div>">

    <cfif structCount(profile.academic) gt 0>
        <cfset ac = profile.academic>
        <cfif isNumeric(ac.CURRENTGRADYEAR ?: "") AND val(ac.CURRENTGRADYEAR) GT 0>
            <cfset content &= "<p><strong>Current Grad Year:</strong> #val(ac.CURRENTGRADYEAR)#</p>">
        </cfif>
        <cfif isNumeric(ac.ORIGINALGRADYEAR ?: "") AND val(ac.ORIGINALGRADYEAR) GT 0>
            <cfset content &= "<p><strong>Original Grad Year:</strong> #val(ac.ORIGINALGRADYEAR)#</p>">
        </cfif>
    <cfelse>
        <cfset content &= "<p class='text-muted'>No academic information</p>">
    </cfif>

    <cfset content &= "</div>">
</cfif>

<!--- ── Biographical Information card ── --->
<cfset hasBioInfo = isDate(userDOB) OR len(userGender) OR arrayLen(userAddresses) GT 0>
<cfif hasBioInfo>
    <cfset content &= "<hr><h3 class='users-view-section-title'>Biographical Information</h3>">
    <cfset content &= "<div class='card mb-3 users-view-card'><div class='card-body'>">
    <cfif isDate(userDOB)>
        <cfset content &= "<p><strong>Date of Birth:</strong> " & dateFormat(userDOB, 'mmmm d, yyyy') & "</p>">
    </cfif>
    <cfif len(userGender)>
        <cfset content &= "<p><strong>Gender:</strong> " & EncodeForHTML(userGender) & "</p>">
    </cfif>
    <cfset content &= "</div></div>">
</cfif>
<cfif arrayLen(userAddresses) GT 0>
    <cfif NOT hasBioInfo><cfset content &= "<hr><h3 class='users-view-section-title'>Biographical Information</h3>"></cfif>
    <cfset content &= "<div class='card mb-3 users-view-card'><div class='card-header fw-semibold'>Addresses</div><div class='card-body'>">
</cfif>
<cfloop from="1" to="#arrayLen(userAddresses)#" index="adI">
    <cfset addrItem = userAddresses[adI]>
    <cfset content &= "<div class='mb-2'>">
    <cfset content &= "<strong>" & EncodeForHTML(addrItem.ADDRESSTYPE ?: "") & "</strong>">
    <cfif val(addrItem.ISPRIMARY ?: 0)><cfset content &= " <span class='badge bg-success'>Primary</span>"></cfif>
    <cfset content &= "<br><small class='text-muted'>">
    <cfif len(trim(addrItem.ADDRESS1 ?: ""))><cfset content &= EncodeForHTML(addrItem.ADDRESS1)></cfif>
    <cfif len(trim(addrItem.ADDRESS2 ?: ""))><cfset content &= ", " & EncodeForHTML(addrItem.ADDRESS2)></cfif>
    <cfif len(trim(addrItem.CITY ?: "")) OR len(trim(addrItem.STATE ?: "")) OR len(trim(addrItem.ZIPCODE ?: ""))>
        <cfset content &= "<br>" & EncodeForHTML(addrItem.CITY ?: "")>
        <cfif len(trim(addrItem.STATE ?: ""))><cfset content &= ", " & EncodeForHTML(addrItem.STATE)></cfif>
        <cfset content &= " " & EncodeForHTML(addrItem.ZIPCODE ?: "")>
    </cfif>
    <cfif len(trim(addrItem.BUILDING ?: ""))><cfset content &= " | Bldg: " & EncodeForHTML(addrItem.BUILDING)></cfif>
    <cfif len(trim(addrItem.ROOM ?: ""))><cfset content &= " Rm: " & EncodeForHTML(addrItem.ROOM)></cfif>
    <cfif len(trim(addrItem.MAILCODE ?: ""))><cfset content &= " | MC: " & EncodeForHTML(addrItem.MAILCODE)></cfif>
    <cfset content &= "</small></div>">
</cfloop>
<cfif arrayLen(userAddresses) GT 0>
    <cfset content &= "</div></div>">
</cfif>

<cfif showStudentProfile>
    <cfset content &= "<hr><h3 class='users-view-section-title'>Student Profile</h3><div class='row'>">
    <cfset content &= "<div class='col-md-6'>">
    <cfif len(spCommAge) AND isNumeric(spCommAge)> <cfset content &= "<p><strong>Commencement Age:</strong> " & int(spCommAge) & "</p>"> </cfif>
    <cfif len(spFirstExt)>  <cfset content &= "<p><strong>First Externship:</strong> " & EncodeForHTML(spFirstExt)  & "</p>"> </cfif>
    <cfif len(spSecondExt)> <cfset content &= "<p><strong>Second Externship:</strong> "& EncodeForHTML(spSecondExt) & "</p>"> </cfif>
    <cfset content &= "</div>">
    <cfif arrayLen(spAwards) GT 0>
        <cfset content &= "<div class='col-md-6'><h5>Awards</h5><ul class='list-group list-group-flush'>">
        <cfloop from="1" to="#arrayLen(spAwards)#" index="aw">
            <cfset award = spAwards[aw]>
            <cfset awardLine = "<li class='list-group-item px-0'>" & EncodeForHTML(award.AWARDNAME)>
            <cfif len(trim(award.AWARDTYPE ?: ""))>
                <cfset awardLine &= " <span class='badge bg-secondary text-dark ms-1 users-view-badge'>" & EncodeForHTML(award.AWARDTYPE) & "</span>">
            </cfif>
            <cfset awardLine &= "</li>">
            <cfset content &= awardLine>
        </cfloop>
        <cfset content &= "</ul></div>">
    </cfif>
    <cfset content &= "</div>">
</cfif>

<cfset content &= "
<div class='mt-4'>
    " & (uhApiId != "" ? "<a href='/admin/users/uh_sync.cfm?uhApiId=#urlEncodedFormat(uhApiId)#&sourceUserID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-info me-2 users-view-badge'>UH Sync</a>" : "") & "
    <a href='/admin/users/edit.cfm?userID=#profile.user.USERID#&returnTo=#urlEncodedFormat(returnTo)#' class='btn btn-primary'>Edit</a>
    <a href='#EncodeForHTMLAttribute(returnTo)#' class='btn btn-secondary'>Back to Users</a>
</div>
</div>
" />




<cfinclude template="/admin/layout.cfm">