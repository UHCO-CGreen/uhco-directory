<cfset directoryService = createObject("component", "dir.cfc.directory_service").init()>
<cfset profile = directoryService.getFullProfile(url.userID)>
<cfparam name="form.quickApiMatch" default="0">
<cfparam name="form.saveMatchedApiId" default="0">
<cfparam name="form.matchedApiId" default="">

<!--- Assign variables outside the content string --->
<cfset emailPrimary = profile.user.EMAILPRIMARY ?: "">
<cfset emailSecondary = profile.user.EMAILSECONDARY ?: "">
<cfset phone = profile.user.PHONE ?: "">
<cfset room = profile.user.ROOM ?: "">
<cfset building = profile.user.BUILDING ?: "">
<cfset cougarnetid = profile.user.COUGARNETID ?: "">
<cfset title1 = profile.user.TITLE1 ?: "">
<cfset title2 = profile.user.TITLE2 ?: "">
<cfset title3 = profile.user.TITLE3 ?: "">
<cfset uhApiId = trim(profile.user.UH_API_ID ?: "")>
<cfset showAcademicInfo = false>
<cfset quickMatchAttempted = (cgi.request_method EQ "POST" AND form.quickApiMatch EQ "1")>
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
            <cfbreak>
        </cfif>
    </cfloop>
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
        <cfset uhApi = createObject("component", "dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
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

        <cfset localFirstName = lCase(trim(profile.user.FIRSTNAME ?: ""))>
        <cfset localLastName = lCase(trim(profile.user.LASTNAME ?: ""))>

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
        <cfset usersService = createObject("component", "dir.cfc.users_service").init()>
        <cfset userData = {
            FirstName = profile.user.FIRSTNAME ?: "",
            MiddleName = profile.user.MIDDLENAME ?: "",
            LastName = profile.user.LASTNAME ?: "",
            PreferredName = profile.user.PREFERREDNAME ?: "",
            Pronouns = profile.user.PRONOUNS ?: "",
            EmailPrimary = profile.user.EMAILPRIMARY ?: "",
            EmailSecondary = profile.user.EMAILSECONDARY ?: "",
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

<cfset quickMatchHtml = "
<div class='card card-body mb-3'>
    <h5 class='mb-2'>Quick API Match</h5>
    <p class='text-muted mb-2'>Compare this user by first and last name against UH API.</p>
    <form method='post' action='/dir/admin/users/view.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='d-inline'>
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
        <form method='post' action='/dir/admin/users/view.cfm?userID=#urlEncodedFormat(profile.user.USERID)#' class='d-inline me-2'>
            <input type='hidden' name='quickApiMatch' value='1'>
            <input type='hidden' name='saveMatchedApiId' value='1'>
            <input type='hidden' name='matchedApiId' value='#EncodeForHTMLAttribute(quickMatchApiId)#'>
            <button type='submit' class='btn btn-sm btn-outline-success'>Save API ID to User</button>
        </form>
        <a href='/dir/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(quickMatchApiId)#&sourceUserID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-sm btn-success'>Sync from API</a>
        ">
    </cfif>
</cfif>

<cfset quickMatchHtml &= "</div>">

<cfset content = "
<h1>#profile.user.FIRSTNAME# #profile.user.LASTNAME#</h1>

#quickMatchHtml#

<div class='row mt-4'>
    <div class='col-md-4'>
        <h4>Profile Info</h4>
        " & (emailPrimary != "" ? "<p><strong>Email (@uh):</strong> #emailPrimary#</p>" : "") & "
        " & (emailSecondary != "" ? "<p><strong>Email (@central/@cougarnet):</strong> #emailSecondary#</p>" : "") & "
        " & (phone != "" ? "<p><strong>Phone:</strong> #phone#</p>" : "") & "
        " & (cougarnetid != "" ? "<p><strong>CougarNetID:</strong> #cougarnetid#</p>" : "") & "
        " & (title1 != "" ? "<p><strong>Title 1:</strong> #title1#</p>" : "") & "
        " & (title2 != "" ? "<p><strong>Title 2:</strong> #title2#</p>" : "") & "
        " & (title3 != "" ? "<p><strong>Title 3:</strong> #title3#</p>" : "") & "
        " & (room != "" ? "<p><strong>Room:</strong> #room#</p>" : "") & "
        " & (building != "" ? "<p><strong>Building:</strong> #building#</p>" : "") & "
    </div>

    <div class='col-md-4'>
        <h4>Flags</h4>
" />

<cfif arrayLen(profile.flags) gt 0>
    <cfloop from="1" to="#arrayLen(profile.flags)#" index="f">
        <cfset flag = profile.flags[f]>
        <cfset content &= "<span class='badge bg-info'>#flag.FLAGNAME#</span> ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted'>No flags assigned</p>">
</cfif>

<cfset content &= "
    </div>

    <div class='col-md-4'>
        <h4>Organizations</h4>
        <ul>
" />

<cfif arrayLen(profile.organizations) gt 0>
    <cfloop from="1" to="#arrayLen(profile.organizations)#" index="o">
        <cfset org = profile.organizations[o]>
        <cfset content &= "<li>#org.ORGNAME# (#org.ROLETITLE#)</li>">
    </cfloop>
<cfelse>
    <cfset content &= "<li class='text-muted'>No organizations assigned</li>">
</cfif>

<cfset content &= "
        </ul>
    </div>
</div>

<hr>

<h3>Images</h3>
<div class='row'>
" />

<cfif arrayLen(profile.images) gt 0>
    <cfloop from="1" to="#arrayLen(profile.images)#" index="i">
        <cfset img = profile.images[i]>
        <cfset content &= "
        <div class='col-md-3 mb-3'>
            <img class='img-fluid rounded shadow-sm'
                 src='#img.IMAGEURL#'
                 alt='#img.IMAGEDESCRIPTION#'
                 title='#img.IMAGEDESCRIPTION#'>
            <p class='mt-2'>#img.IMAGEDESCRIPTION#</p>
        </div>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted'>No images</p>">
</cfif>

<cfset content &= "
</div>

<hr>

" />

<cfif showAcademicInfo>
    <cfset content &= "
<h3>Academic Info</h3>
<div>
" />

    <cfif structCount(profile.academic) gt 0>
        <cfset ac = profile.academic>
        <cfset content &= "
    <p><strong>Degree:</strong> #ac.DEGREE#</p>
    <p><strong>Graduation Year:</strong> #ac.ORIGINALGRADYEAR#</p>
    ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>No academic information</p>">
    </cfif>

    <cfset content &= "
</div>

<hr>
">
</cfif>

<cfset content &= "
<div class='mt-4'>
    " & (uhApiId != "" ? "<a href='/dir/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(uhApiId)#&sourceUserID=#urlEncodedFormat(profile.user.USERID)#' class='btn btn-info me-2'>UH API Details</a>" : "") & "
    <a href='/dir/admin/users/edit.cfm?userID=#profile.user.USERID#' class='btn btn-primary'>Edit</a>
    <a href='/dir/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a>
</div>
" />

<cfinclude template="/dir/admin/layout.cfm">