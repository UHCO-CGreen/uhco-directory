<cfif !structKeyExists(url, "userID") OR !isNumeric(url.userID)>
    <cflocation url="#request.webRoot#/admin/users/index.cfm" addtoken="false">
</cfif>

<cfset directoryService = createObject("component", "cfc.directory_service").init()>
<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset organizationsService = createObject("component", "cfc.organizations_service").init()>
<cfset user = directoryService.getFullProfile( url.userID ).user>
<cfset userFlags = directoryService.getFullProfile( url.userID ).flags>
<cfset userOrganizations = directoryService.getFullProfile( url.userID ).organizations>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data />
<cfset allOrganizationsResult = organizationsService.getAllOrgs()>
<cfset allOrganizations = allOrganizationsResult.data />


<cfset userFlagIDs = []>
<cfloop from="1" to="#arrayLen(userFlags)#" index="i">
    <cfset arrayAppend(userFlagIDs, userFlags[i].FLAGID)>
</cfloop>

<cfset userOrgIDs = []>
<cfset orgRoleMap  = {}>
<cfloop from="1" to="#arrayLen(userOrganizations)#" index="i">
    <cfset arrayAppend(userOrgIDs, val(userOrganizations[i].ORGID))>
    <cfset orgRoleMap[toString(userOrganizations[i].ORGID)] = {
        roleTitle: (userOrganizations[i].ROLETITLE ?: ""),
        roleOrder: (isNumeric(userOrganizations[i].ROLEORDER ?: "") ? val(userOrganizations[i].ROLEORDER) : 0)
    }>
</cfloop>

<!--- ── External IDs ── --->
<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset allSystemsResult = externalIDService.getSystems()>
<cfset allSystems = allSystemsResult.data>
<cfset userExtIDsResult = externalIDService.getExternalIDs(url.userID)>

<!--- ── Academic Info ── --->
<cfset academicService  = createObject("component", "cfc.academic_service").init()>
<cfset academicInfo     = academicService.getAcademicInfo(url.userID).data>
<cfset currentGradYear  = structIsEmpty(academicInfo) ? "" : (academicInfo.CURRENTGRADYEAR  ?: "")>
<cfset originalGradYear = structIsEmpty(academicInfo) ? "" : (academicInfo.ORIGINALGRADYEAR ?: "")>
<cfif NOT isNumeric(currentGradYear)  OR val(currentGradYear)  EQ 0><cfset currentGradYear  = ""></cfif>
<cfif NOT isNumeric(originalGradYear) OR val(originalGradYear) EQ 0><cfset originalGradYear = ""></cfif>

<!--- ── Student Profile (Current Students & Alumni) ── --->
<cfset showStudentProfile = false>
<cfset studentFlagIDs     = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flagNameLC = lCase(trim(allFlags[i].FLAGNAME))>
    <cfif flagNameLC EQ "current-student" OR flagNameLC EQ "alumni">
        <cfset arrayAppend(studentFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showStudentProfile = true>
        </cfif>
    </cfif>
</cfloop>
<!--- ── Faculty Profile tab visibility ── --->
<cfset showFacultyProfile = false>
<cfset facultyFlagIDs     = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flagNameLC = lCase(trim(allFlags[i].FLAGNAME))>
    <cfif flagNameLC EQ "faculty-adjunct" OR flagNameLC EQ "faculty-fulltime" OR flagNameLC EQ "joint faculty appointment">
        <cfset arrayAppend(facultyFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showFacultyProfile = true>
        </cfif>
    </cfif>
</cfloop>

<!--- ── Staff Profile tab visibility ── --->
<cfset showStaffProfile = false>
<cfset staffFlagIDs    = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfif lCase(trim(allFlags[i].FLAGNAME)) EQ "staff">
        <cfset arrayAppend(staffFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showStaffProfile = true>
        </cfif>
    </cfif>
</cfloop>

<!--- ── Professor Emeritus Profile tab visibility ── --->
<cfset showEmeritusProfile = false>
<cfset emeritusFlagIDs     = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfif lCase(trim(allFlags[i].FLAGNAME)) EQ "professor-emeritus">
        <cfset arrayAppend(emeritusFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showEmeritusProfile = true>
        </cfif>
    </cfif>
</cfloop>

<!--- ── Resident Profile tab visibility ── --->
<cfset showResidentProfile = false>
<cfset residentFlagIDs     = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfif lCase(trim(allFlags[i].FLAGNAME)) EQ "resident">
        <cfset arrayAppend(residentFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showResidentProfile = true>
        </cfif>
    </cfif>
</cfloop>

<!--- ── Bio tab visibility (tied to public-facing flag) ── --->
<cfset showBio      = false>
<cfset bioFlagIDs   = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfif lCase(trim(allFlags[i].FLAGNAME)) EQ "public-facing">
        <cfset arrayAppend(bioFlagIDs, allFlags[i].FLAGID)>
        <cfif arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
            <cfset showBio = true>
        </cfif>
    </cfif>
</cfloop>

<!--- ── Bio data ── --->
<cfset bioSvc     = createObject("component", "cfc.bio_service").init()>
<cfset bioData    = bioSvc.getBio(url.userID).data>
<cfset bioContent = structIsEmpty(bioData) ? "" : (bioData.BIOCONTENT ?: "")>

<!--- ── Emails (repeatable) ── --->
<cfset emailsSvc  = createObject("component", "cfc.emails_service").init()>
<cfset userEmails  = emailsSvc.getEmails(url.userID).data>

<!--- ── Phones (repeatable) ── --->
<cfset phoneSvc   = createObject("component", "cfc.phone_service").init()>
<cfset userPhones  = phoneSvc.getPhones(url.userID).data>

<!--- ── Aliases (repeatable) ── --->
<cfset aliasesSvc   = createObject("component", "cfc.aliases_service").init()>
<cfset userAliases  = aliasesSvc.getAliases(url.userID).data>
<cfset aliasTypes   = aliasesSvc.getAliasTypes()>

<!--- ── Degrees (shared across Faculty, Emeritus, Resident) ── --->
<cfset showDegrees = showFacultyProfile OR showEmeritusProfile OR showResidentProfile OR showStudentProfile>
<cfset degreesSvc  = createObject("component", "cfc.degrees_service").init()>
<cfset userDegrees = degreesSvc.getDegrees(url.userID).data>

<!--- Role check (needed early for General tab email fields) --->
<cfset isSuperAdmin = application.authService.hasRole("SUPER_ADMIN")>

<!--- ── Addresses (repeatable) ── --->
<cfset addressesSvc  = createObject("component", "cfc.addresses_service").init()>
<cfset userAddresses = addressesSvc.getAddresses(url.userID).data>

<cfif showStudentProfile>
    <cfset studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
    <cfset spProfile  = studentProfileSvc.getProfile(url.userID).data>
    <cfset spAwards   = studentProfileSvc.getAwards(url.userID).data>
    <cfset spFirstExt      = structIsEmpty(spProfile) ? "" : (spProfile.FIRSTEXTERNSHIP   ?: "")>
    <cfset spSecondExt     = structIsEmpty(spProfile) ? "" : (spProfile.SECONDEXTERNSHIP  ?: "")>
    <cfset spCommAge       = structIsEmpty(spProfile) ? "" : (spProfile.COMMENCEMENTAGE   ?: "")>
    <!--- Legacy vars kept for hidden old Student Profile tab --->
    <cfset spHometownCity  = structIsEmpty(spProfile) ? "" : (spProfile.HOMETOWNCITY      ?: "")>
    <cfset spHometownState = structIsEmpty(spProfile) ? "" : (spProfile.HOMETOWNSTATE     ?: "")>
    <cfset spDOB           = structIsEmpty(spProfile) ? "" : (spProfile.DOB              ?: "")>
    <cfset spGender        = structIsEmpty(spProfile) ? "" : (spProfile.GENDER           ?: "")>
<cfelse>
    <cfset spAwards        = []>
    <cfset spFirstExt      = "">
    <cfset spSecondExt     = "">
    <cfset spCommAge       = "">
    <cfset spHometownCity  = "">
    <cfset spHometownState = "">
    <cfset spDOB           = "">
    <cfset spGender        = "">
</cfif>

<cfset userExternalIDs = userExtIDsResult.data>
<cfset externalBySystem = {}>
<cfloop from="1" to="#arrayLen(userExternalIDs)#" index="i">
    <cfset externalBySystem[toString(userExternalIDs[i].SYSTEMID)] = userExternalIDs[i].EXTERNALVALUE>
</cfloop>

<cfset extIDHtml = "<div class='mb-3 users-edit-extids'><label class='form-label fw-semibold'>External IDs</label><div class='border p-3 rounded users-edit-extids-shell'><div class='row g-2'>">
<cfif arrayLen(allSystems) GT 0>
    <cfloop from="1" to="#arrayLen(allSystems)#" index="i">
        <cfset sys = allSystems[i]>
        <cfset sysVal = structKeyExists(externalBySystem, toString(sys.SYSTEMID)) ? externalBySystem[toString(sys.SYSTEMID)] : "">
        <cfset extIDHtml &= "<div class='col-md-6 col-lg-4'><label class='form-label form-label-sm text-muted mb-1'>" & EncodeForHTML(sys.SYSTEMNAME) & "</label><input class='form-control form-control-sm' name='extID_" & sys.SYSTEMID & "' value='" & EncodeForHTMLAttribute(sysVal) & "' placeholder='Not set'></div>">
    </cfloop>
<cfelse>
    <cfset extIDHtml &= "<p class='text-muted mb-0'>No external systems configured.</p>">
</cfif>
<cfset extIDHtml &= "</div></div></div>">

<cfset orgIds = {}>
<cfset orgChildrenByParent = {}>

<cfloop from="1" to="#arrayLen(allOrganizations)#" index="i">
    <cfset org = allOrganizations[i]>
    <cfset orgIds[toString(org.ORGID)] = true>
</cfloop>

<cfloop from="1" to="#arrayLen(allOrganizations)#" index="i">
    <cfset org = allOrganizations[i]>
    <cfset parentValue = trim((org.PARENTORGID ?: "") & "")>
    <cfset parentKey = "ROOT">

    <cfif len(parentValue) AND structKeyExists(orgIds, parentValue)>
        <cfset parentKey = parentValue>
    </cfif>

    <cfif NOT structKeyExists(orgChildrenByParent, parentKey)>
        <cfset orgChildrenByParent[parentKey] = []>
    </cfif>
    <cfset arrayAppend(orgChildrenByParent[parentKey], org)>
</cfloop>

<cffunction name="renderOrgPanels" access="private" returntype="string" output="false">
    <cfargument name="selectedOrgIDs" type="array" required="true">

    <cfset var html         = "">
    <cfset var rootOrgs     = []>
    <cfset var ro           = {}>
    <cfset var children     = []>
    <cfset var child        = {}>
    <cfset var gcKey        = "">
    <cfset var grandchildren = []>
    <cfset var gc           = {}>
    <cfset var i            = 0>
    <cfset var j            = 0>
    <cfset var k            = 0>
    <cfset var isRootChecked  = false>
    <cfset var isChildChecked = false>
    <cfset var isGcChecked    = false>
    <cfset var collapseID     = "">

    <cfif NOT structKeyExists(orgChildrenByParent, "ROOT") OR arrayLen(orgChildrenByParent["ROOT"]) EQ 0>
        <cfreturn "<p class='text-muted'>No organizations available</p>">
    </cfif>

    <cfset rootOrgs = orgChildrenByParent["ROOT"]>
    <cfset html = "<div class='row row-cols-1 row-cols-md-2 row-cols-xl-3 g-3'>">

    <cfloop from="1" to="#arrayLen(rootOrgs)#" index="i">
        <cfset ro           = rootOrgs[i]>
        <cfset collapseID   = "orgPanel#ro.ORGID#">
        <cfset isRootChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(ro.ORGID)) GT 0>
        <cfset children     = structKeyExists(orgChildrenByParent, toString(ro.ORGID)) ? orgChildrenByParent[toString(ro.ORGID)] : []>

        <cfset html &= "<div class='col'><div class='card shadow-sm h-100 users-edit-org-card'>">

        <!--- Card header with parent checkbox --->
        <cfset html &= "<div class='card-header d-flex align-items-center gap-2 py-2 px-3 users-edit-org-card-header'>">
        <cfset var roRoleTitle = (structKeyExists(orgRoleMap, toString(ro.ORGID)) ? orgRoleMap[toString(ro.ORGID)].roleTitle : '')>
        <cfset var roRoleOrder = (structKeyExists(orgRoleMap, toString(ro.ORGID)) ? val(orgRoleMap[toString(ro.ORGID)].roleOrder) : 0)>
        <cfset html &= "<div class='form-check mb-0 flex-grow-1 d-flex align-items-center gap-1'>">
        <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#ro.ORGID#' id='org#ro.ORGID#' data-orgid='#ro.ORGID#' data-orgname='#EncodeForHTMLAttribute(ro.ORGNAME)#' data-parentorgid='' data-panelid='#collapseID#' data-isparent='1' #(isRootChecked ? 'checked' : '')#>">
        <cfset html &= "<label class='form-check-label fw-semibold user-select-none' for='org#ro.ORGID#'>#EncodeForHTML(ro.ORGNAME)#</label>">
        <cfset html &= "</div>">
        <cfif arrayLen(children) GT 0>
            <cfset html &= "<button class='btn btn-sm border-0 text-muted p-0 ms-1 org-chevron users-edit-org-chevron' type='button' data-bs-toggle='collapse' data-bs-target='###collapseID#' aria-expanded='true'><i class='bi bi-chevron-down'></i></button>">
        </cfif>
        <cfset html &= "</div>">

        <!--- Description (parent orgs only) --->
        <cfset var roDesc = trim(ro.ORGDESCRIPTION ?: '')>
        <cfif len(roDesc)>
            <cfset html &= "<div class='px-3 pt-2 pb-1 text-muted small border-bottom users-edit-org-description'>#EncodeForHTML(roDesc)#</div>">
        </cfif>

        <!--- Collapsible card body with children --->
        <cfif arrayLen(children) GT 0>
            <cfset html &= "<div id='#collapseID#' class='collapse show'>">
            <cfset html &= "<div class='card-body py-2 px-3 users-edit-org-card-body'>">

            <cfloop from="1" to="#arrayLen(children)#" index="j">
                <cfset child        = children[j]>
                <cfset isChildChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(child.ORGID)) GT 0>
                <cfset gcKey        = toString(child.ORGID)>
                <cfset grandchildren = structKeyExists(orgChildrenByParent, gcKey) ? orgChildrenByParent[gcKey] : []>

                <cfset var chRoleTitle = (structKeyExists(orgRoleMap, toString(child.ORGID)) ? orgRoleMap[toString(child.ORGID)].roleTitle : '')>
                <cfset var chRoleOrder = (structKeyExists(orgRoleMap, toString(child.ORGID)) ? val(orgRoleMap[toString(child.ORGID)].roleOrder) : 0)>
                <cfset var chAdditionalRoles = (isNumeric(child.ADDITIONALROLES ?: '') AND val(child.ADDITIONALROLES) EQ 1) ? 1 : 0>
                <cfset html &= "<div class='form-check mb-1 d-flex align-items-center gap-1'>">
                <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#child.ORGID#' id='org#child.ORGID#' data-orgid='#child.ORGID#' data-orgname='#EncodeForHTMLAttribute(child.ORGNAME)#' data-parentorgid='#ro.ORGID#' data-additionalroles='#chAdditionalRoles#' #(isChildChecked ? 'checked' : '')#>">
                <cfset html &= "<label class='form-check-label user-select-none' for='org#child.ORGID#'>#EncodeForHTML(child.ORGNAME)#</label>">
                <cfif chAdditionalRoles>
                    <cfset html &= "<button type='button' class='org-role-edit users-edit-org-role-button btn btn-link p-0 ms-1 text-secondary#(isChildChecked ? ' is-visible' : '')#' data-orgid='#child.ORGID#' data-orgname='#EncodeForHTMLAttribute(child.ORGNAME)#' title='Edit role'><i class='bi bi-pencil-square'></i></button>">
                </cfif>
                <cfif isChildChecked>
                    <cfset html &= "<input type='hidden' name='roleTitle_#child.ORGID#' id='roleTitle_#child.ORGID#' value='#EncodeForHTMLAttribute(chRoleTitle)#'><input type='hidden' name='roleOrder_#child.ORGID#' id='roleOrder_#child.ORGID#' value='#chRoleOrder#'>">
                </cfif>
                <cfset html &= "</div>">

                <cfloop from="1" to="#arrayLen(grandchildren)#" index="k">
                    <cfset gc = grandchildren[k]>
                    <cfset isGcChecked = arrayFindNoCase(arguments.selectedOrgIDs, val(gc.ORGID)) GT 0>
                    <cfset var gcRoleTitle = (structKeyExists(orgRoleMap, toString(gc.ORGID)) ? orgRoleMap[toString(gc.ORGID)].roleTitle : '')>
                    <cfset var gcRoleOrder = (structKeyExists(orgRoleMap, toString(gc.ORGID)) ? val(orgRoleMap[toString(gc.ORGID)].roleOrder) : 0)>
                    <cfset var gcAdditionalRoles = (isNumeric(gc.ADDITIONALROLES ?: '') AND val(gc.ADDITIONALROLES) EQ 1) ? 1 : 0>
                    <cfset html &= "<div class='form-check mb-1 ms-3 d-flex align-items-center gap-1'>">
                    <cfset html &= "<input class='form-check-input flex-shrink-0 org-checkbox' type='checkbox' name='Organizations' value='#gc.ORGID#' id='org#gc.ORGID#' data-orgid='#gc.ORGID#' data-orgname='#EncodeForHTMLAttribute(gc.ORGNAME)#' data-parentorgid='#child.ORGID#' data-additionalroles='#gcAdditionalRoles#' #(isGcChecked ? 'checked' : '')#>">
                    <cfset html &= "<label class='form-check-label user-select-none small text-muted' for='org#gc.ORGID#'>#EncodeForHTML(gc.ORGNAME)#</label>">
                    <cfif gcAdditionalRoles>
                        <cfset html &= "<button type='button' class='org-role-edit users-edit-org-role-button btn btn-link p-0 ms-1 text-secondary#(isGcChecked ? ' is-visible' : '')#' data-orgid='#gc.ORGID#' data-orgname='#EncodeForHTMLAttribute(gc.ORGNAME)#' title='Edit role'><i class='bi bi-pencil-square'></i></button>">
                    </cfif>
                    <cfif isGcChecked>
                        <cfset html &= "<input type='hidden' name='roleTitle_#gc.ORGID#' id='roleTitle_#gc.ORGID#' value='#EncodeForHTMLAttribute(gcRoleTitle)#'><input type='hidden' name='roleOrder_#gc.ORGID#' id='roleOrder_#gc.ORGID#' value='#gcRoleOrder#'>">
                    </cfif>
                    <cfset html &= "</div>">
                </cfloop>
            </cfloop>

            <cfset html &= "</div></div>">
        </cfif>

        <cfset html &= "</div></div>">
    </cfloop>

    <cfset html &= "</div>">
    <cfreturn html>
</cffunction>

<cffunction name="renderDegreesPanel" access="private" returntype="string" output="false">
    <cfargument name="degrees" type="array" required="true">
    <cfargument name="prefix" type="string" required="true" hint="Unique prefix per tab, e.g. fac, emer, res">
    <cfargument name="showComposite" type="boolean" required="false" default="false" hint="Show read-only composite Degrees field for Super Admins">
    <cfargument name="compositeValue" type="string" required="false" default="">

    <cfset var html = "">
    <cfif arguments.showComposite>
        <cfset html &= "<div class='row mb-3'><div class='col-md-8'>">
        <cfset html &= "<label class='form-label text-muted'>Combined Degrees (auto-generated, read-only)</label>">
        <cfset html &= "<input class='form-control form-control-sm' id='#arguments.prefix#_composite' value='#EncodeForHTMLAttribute(arguments.compositeValue)#' readonly disabled>">
        <cfset html &= "</div></div>">
    </cfif>
    <cfset html &= "<div class='mb-4'>">
    <cfset html &= "<label class='form-label fw-semibold'>Degrees</label>">
    <cfset html &= "<div id='#arguments.prefix#_degreesContainer'>">
    <cfloop from="1" to="#arrayLen(arguments.degrees)#" index="local.di">
        <cfset local.dg = arguments.degrees[local.di]>
        <cfset html &= "<div class='row g-2 mb-2 degree-row'>">
        <cfset html &= "<div class='col-md-4'><input class='form-control form-control-sm' name='#arguments.prefix#_deg_name_#(local.di-1)#' data-field='deg_name' value='#EncodeForHTMLAttribute(local.dg.DEGREENAME)#' placeholder='Degree (required)' required></div>">
        <cfset html &= "<div class='col-md-4'><input class='form-control form-control-sm' name='#arguments.prefix#_deg_univ_#(local.di-1)#' data-field='deg_univ' value='#EncodeForHTMLAttribute(local.dg.UNIVERSITY ?: "")#' placeholder='University'></div>">
        <cfset html &= "<div class='col-md-2'><input class='form-control form-control-sm' name='#arguments.prefix#_deg_year_#(local.di-1)#' data-field='deg_year' value='#EncodeForHTMLAttribute(local.dg.DEGREEYEAR ?: "")#' placeholder='Year'></div>">
        <cfset html &= "<div class='col-md-2'><button type='button' class='btn btn-sm btn-outline-danger remove-degree-row w-100'>Remove</button></div>">
        <cfset html &= "</div>">
    </cfloop>
    <cfset html &= "</div>">
    <cfset html &= "<input type='hidden' name='#arguments.prefix#_degree_count' id='#arguments.prefix#_degreeCount' value='#arrayLen(arguments.degrees)#'>">
    <cfset html &= "<button type='button' class='btn btn-sm btn-outline-primary mt-2 add-degree-row' data-prefix='#arguments.prefix#'>+ Add Degree</button>">
    <cfset html &= "</div>">
    <cfreturn html>
</cffunction>

<!--- ── Data Quality Exclusions ── --->
<cfset dqDAO            = createObject("component", "dao.dataQuality_DAO").init()>
<cfset dqExclusionsList = dqDAO.getExclusionsForUser(url.userID)>
<cfset dqExclusionMap   = {}>
<cfloop from="1" to="#arrayLen(dqExclusionsList)#" index="i">
    <cfset dqExclusionMap[dqExclusionsList[i]] = true>
</cfloop>

<cfset dqAllCodes = [
    { code="missing_uh_api_id",       label="Missing UH API ID" },
    { code="missing_firstname",        label="Missing First Name" },
    { code="missing_lastname",         label="Missing Last Name" },
    { code="missing_email_primary",    label="Missing Primary Email" },
    { code="missing_title1",           label="Missing Title" },
    { code="missing_room",             label="Missing Room" },
    { code="missing_building",         label="Missing Building" },
    { code="missing_phone",            label="Missing Phone" },
    { code="missing_degrees",          label="Missing Degrees" },
    { code="no_flags",                 label="Zero Flags" },
    { code="no_orgs",                  label="Zero Organizations" },
    { code="no_images",                label="No Images" },
    { code="missing_cougarnet",        label="Missing CougarNet ID" },
    { code="missing_peoplesoft",       label="Missing PeopleSoft ID" },
    { code="missing_legacy_id",        label="Missing Legacy ID" },
    { code="missing_grad_year",        label="Missing Grad Year (Students Only)" }
]>

<cfset returnTo = structKeyExists(url, "returnTo") AND len(trim(url.returnTo)) ? trim(url.returnTo) : (len(trim(cgi.HTTP_REFERER)) ? trim(cgi.HTTP_REFERER) : "/admin/users/index.cfm")>

<!--- ── UH Sync pending diffs for this user ── --->
<cfset uhSyncPendingDiffs = []>
<cfset uhSyncPanelHtml    = "">
<cftry>
    <cfset uhSyncDAO_edit = createObject("component", "dao.uhSync_DAO").init()>
    <cfset uhSyncPendingDiffs = uhSyncDAO_edit.getUnresolvedDiffsForUser(val(url.userID))>
<cfcatch>
    <!--- Non-fatal: sync panel is suppressed if tables don't exist yet --->
</cfcatch>
</cftry>

<cfif arrayLen(uhSyncPendingDiffs) GT 0>
    <cfset uhSyncFieldLabels_edit = {
        "FirstName"              : "First Name",
        "LastName"               : "Last Name",
        "EmailPrimary"           : "Primary Email",
        "Phone"                  : "Phone",
        "Room"                   : "Room",
        "Building"               : "Building",
        "Title1"                 : "Title",
        "Division"               : "Division",
        "DivisionName"           : "Division Name",
        "Campus"                 : "Campus",
        "Department"             : "Department",
        "DepartmentName"         : "Department Name",
        "Office_Mailing_Address" : "Office Mailing Address",
        "Mailcode"               : "Mailcode"
    }>
    <cfset editReturnTo = "/admin/users/edit.cfm?userID=" & urlEncodedFormat(url.userID)>

    <cfset uhSyncPanelHtml = "
    <div class='alert alert-warning border-warning mb-4 p-0 users-edit-sync-panel'>
        <div class='d-flex align-items-center justify-content-between px-3 pt-3 pb-2 border-bottom users-edit-sync-panel-header'>
            <div>
                <i class='bi bi-arrow-left-right me-2 text-warning'></i>
                <strong>#arrayLen(uhSyncPendingDiffs)# UH Sync difference(s) detected</strong>
                <span class='text-muted small ms-2'>from the last sync report run</span>
            </div>
            <div class='d-flex gap-2 users-edit-sync-panel-actions'>
                <a href='/admin/reporting/uh_sync_report.cfm' class='btn btn-sm btn-outline-secondary py-0 users-edit-secondary-button'>
                    <i class='bi bi-clipboard-data'></i> View Full Report
                </a>
                <button class='btn btn-sm btn-outline-warning py-0 users-edit-warning-button' type='button'
                        data-bs-toggle='collapse' data-bs-target='##uhSyncDiffPanel'>
                    <i class='bi bi-chevron-down'></i> Details
                </button>
            </div>
        </div>
        <div class='collapse show' id='uhSyncDiffPanel'>
            <div class='px-3 py-2 users-edit-sync-panel-body'>
                <div class='table-responsive'>
                <table class='table table-sm table-bordered mb-2 users-edit-sync-table'>
                    <thead class='table-light users-edit-sync-table-head'>
                        <tr>
                            <th class='users-edit-diff-col-field'>Field</th>
                            <th class='users-edit-diff-col-local'>Local Value</th>
                            <th class='users-edit-diff-col-api'>API Value</th>
                            <th class='text-end users-edit-diff-col-actions'>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
    ">
    <cfloop from="1" to="#arrayLen(uhSyncPendingDiffs)#" index="dIdx">
        <cfset pd     = uhSyncPendingDiffs[dIdx]>
        <cfset pdLbl  = structKeyExists(uhSyncFieldLabels_edit, pd.FIELDNAME) ? uhSyncFieldLabels_edit[pd.FIELDNAME] : pd.FIELDNAME>
        <cfset uhSyncPanelHtml &= "
                        <tr>
                            <td class='fw-semibold small'>#EncodeForHTML(pdLbl)#</td>
                            <td class='text-muted small'>#(len(trim(pd.LOCALVALUE)) ? EncodeForHTML(pd.LOCALVALUE) : '<em>empty</em>')#</td>
                            <td class='small'><strong>#EncodeForHTML(pd.APIVALUE)#</strong></td>
                            <td class='text-end text-nowrap'>
                                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline'>
                                    <input type='hidden' name='diffID'     value='#pd.DIFFID#'>
                                    <input type='hidden' name='resolution' value='synced'>
                                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(editReturnTo)#'>
                                    <button type='submit' class='btn btn-xs btn-sm btn-success py-0 px-2 users-edit-success-button'>
                                        <i class='bi bi-cloud-download'></i> Sync
                                    </button>
                                </form>
                                <form method='post' action='/admin/users/resolve_uh_sync_diff.cfm' class='d-inline ms-1'>
                                    <input type='hidden' name='diffID'     value='#pd.DIFFID#'>
                                    <input type='hidden' name='resolution' value='discarded'>
                                    <input type='hidden' name='returnTo'   value='#EncodeForHTMLAttribute(editReturnTo)#'>
                                    <button type='submit' class='btn btn-xs btn-sm btn-outline-secondary py-0 px-2 users-edit-secondary-button'>
                                        <i class='bi bi-x'></i> Discard
                                    </button>
                                </form>
                            </td>
                        </tr>
        ">
    </cfloop>
    <cfset uhSyncSyncAllBtn = "">
    <cfif len(trim(user.UH_API_ID ?: ""))>
        <cfset uhSyncSyncAllBtn = "<a href='/admin/users/uh_sync.cfm?userID=#urlEncodedFormat(url.userID)#&returnTo=#urlEncodedFormat(editReturnTo)#' class='btn btn-sm btn-success'><i class='bi bi-cloud-download me-1'></i>Sync All Fields from UH API</a>">
    </cfif>
    <cfset uhSyncPanelHtml &= "
                    </tbody>
                </table>
                </div>
                <div class='d-flex gap-2 pb-1 users-edit-sync-panel-footer'>
                    #uhSyncSyncAllBtn#
                </div>
            </div>
        </div>
    </div>
    ">
</cfif>

<cfset content = "
<div class='container users-edit-page'>

" & uhSyncPanelHtml & " 


<input type='hidden' id='pageUserID' value='#user.USERID#'>

        <div class='d-flex justify-content-between mb-3 align-items-center users-edit-header'>
            <h1>Edit User: #EncodeForHTML(user.LASTNAME)#</h1>
            <div class='text-center bg-dark text-white py-2 px-3 rounded users-edit-record-status'>
                <label class='form-label'><strong>Record Status</strong></label>

                <div class='form-check form-switch'>
                    <input class='form-check-input' type='checkbox' value='1'
                        id='activeSwitch'
                        data-userid='#val(user.USERID)#'
                        #((val(user.ACTIVE ?: 1) EQ 1) ? 'checked' : '')#>
                    <label class='form-check-label' id='activeSwitchLabel' for='activeSwitch'>
                        #((val(user.ACTIVE ?: 1) EQ 1) ? 'Active' : 'Inactive')#
                    </label>
                </div>
                
            </div>
        </div>

    <ul class='nav nav-pills mb-3 users-edit-tabs' id='editTabs' role='tablist'>
        <li class='nav-item' role='presentation'>
            <button class='nav-link active' id='general-tab' data-bs-toggle='tab' data-bs-target='##general-pane' type='button' role='tab' aria-controls='general-pane' aria-selected='true'>General Information</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='contact-tab' data-bs-toggle='tab' data-bs-target='##contact-pane' type='button' role='tab' aria-controls='contact-pane' aria-selected='false'>Contact Information</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='bio-info-tab' data-bs-toggle='tab' data-bs-target='##bio-info-pane' type='button' role='tab' aria-controls='bio-info-pane' aria-selected='false'>Biographical Information</button>
        </li>
        <li class='nav-item d-none' id='bio-tab-li' role='presentation'>
            <button class='nav-link' id='bio-tab' data-bs-toggle='tab' data-bs-target='##bio-pane' type='button' role='tab' aria-controls='bio-pane' aria-selected='false'>Bio</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='flags-tab' data-bs-toggle='tab' data-bs-target='##flags-pane' type='button' role='tab' aria-controls='flags-pane' aria-selected='false'>Flags</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='orgs-tab' data-bs-toggle='tab' data-bs-target='##orgs-pane' type='button' role='tab' aria-controls='orgs-pane' aria-selected='false'>Organizations</button>
        </li>
        <li class='nav-item' role='presentation'>
            <button class='nav-link' id='extids-tab' data-bs-toggle='tab' data-bs-target='##extids-pane' type='button' role='tab' aria-controls='extids-pane' aria-selected='false'>External IDs</button>
        </li>
        <li class='nav-item" & (isSuperAdmin ? "" : " d-none") & "' role='presentation'>
            <button class='nav-link' id='address-tab' data-bs-toggle='tab' data-bs-target='##address-pane' type='button' role='tab' aria-controls='address-pane' aria-selected='false'>UH</button>
        </li>
        <li class='nav-item d-none' id='student-profile-tab-li' role='presentation'>
            <button class='nav-link' id='student-profile-tab' data-bs-toggle='tab' data-bs-target='##student-profile-pane' type='button' role='tab' aria-controls='student-profile-pane' aria-selected='false'>Student Profile</button>
        </li>
        <li class='nav-item d-none' id='faculty-profile-tab-li' role='presentation'>
            <button class='nav-link' id='faculty-profile-tab' data-bs-toggle='tab' data-bs-target='##faculty-profile-pane' type='button' role='tab' aria-controls='faculty-profile-pane' aria-selected='false'>Faculty Profile</button>
        </li>
        <li class='nav-item d-none' id='staff-profile-tab-li' role='presentation'>
            <button class='nav-link' id='staff-profile-tab' data-bs-toggle='tab' data-bs-target='##staff-profile-pane' type='button' role='tab' aria-controls='staff-profile-pane' aria-selected='false'>Staff Profile</button>
        </li>
        <li class='nav-item d-none' id='emeritus-profile-tab-li' role='presentation'>
            <button class='nav-link' id='emeritus-profile-tab' data-bs-toggle='tab' data-bs-target='##emeritus-profile-pane' type='button' role='tab' aria-controls='emeritus-profile-pane' aria-selected='false'>Professor Emeritus Profile</button>
        </li>
        <li class='nav-item d-none' id='resident-profile-tab-li' role='presentation'>
            <button class='nav-link' id='resident-profile-tab' data-bs-toggle='tab' data-bs-target='##resident-profile-pane' type='button' role='tab' aria-controls='resident-profile-pane' aria-selected='false'>Resident Profile</button>
        </li>
        
    </ul>

    <div class='tab-content users-edit-tab-content' id='editTabsContent'>

        <div class='tab-pane fade show active users-edit-tab-pane' id='general-pane' role='tabpanel' aria-labelledby='general-tab'>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Prefix</label>
                    <input class='form-control' name='Prefix' value='#(user.PREFIX ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Suffix</label>
                    <input class='form-control' name='Suffix' value='#(user.SUFFIX ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Pronouns</label>
                    <input class='form-control' name='Pronouns' value='#(user.PRONOUNS ?: "")#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>First Name</label>
                    <input class='form-control' name='FirstName' value='#user.FIRSTNAME#' required>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Middle Name</label>
                    <input class='form-control' name='MiddleName' value='#user.MIDDLENAME#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Last Name</label>
                    <input class='form-control' name='LastName' value='#user.LASTNAME#' required>
                </div>
            </div>

            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Maiden Name</label>
                    <input class='form-control' name='MaidenName' value='#user.MAIDENNAME#' readonly disabled>
                    <small class='text-muted'>(legacy — migrated to aliases)</small>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Preferred Name</label>
                    <input class='form-control' name='PreferredName' value='#user.PREFERREDNAME#' readonly disabled>
                    <small class='text-muted'>(legacy — migrated to aliases)</small>
                </div>
                
            </div>



            <div class='mb-4'>
                <label class='form-label fw-semibold'>Name Aliases</label>
                <div id='aliasesContainer'>
">
<cfloop from="1" to="#arrayLen(userAliases)#" index="local.ai">
    <cfset local.al = userAliases[local.ai]>
    <cfset local.alDisplay = "">
    <cfif len(trim(local.al.FIRSTNAME ?: ""))><cfset local.alDisplay &= trim(local.al.FIRSTNAME) & " "></cfif>
    <cfif len(trim(local.al.MIDDLENAME ?: ""))><cfset local.alDisplay &= trim(local.al.MIDDLENAME) & " "></cfif>
    <cfif len(trim(local.al.LASTNAME ?: ""))><cfset local.alDisplay &= trim(local.al.LASTNAME)></cfif>
    <cfset content &= "
                    <div class='card mb-2 alias-card users-edit-item-card' data-idx='#(local.ai-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(trim(local.alDisplay))#</strong>
                                    <cfif len(trim(local.al.ALIASTYPE ?: ""))> <span class='badge bg-secondary'>#EncodeForHTML(local.al.ALIASTYPE)#</span></cfif>
                                    <cfif len(trim(local.al.SOURCESYSTEM ?: ""))> <small class='text-muted'>Source: #EncodeForHTML(local.al.SOURCESYSTEM)#</small></cfif>
                                    <cfif val(local.al.ISACTIVE ?: 0)> <span class='badge bg-success'>Active</span><cfelse> <span class='badge bg-warning text-dark'>Inactive</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-outline-secondary edit-alias-btn users-edit-secondary-button' data-idx='#(local.ai-1)#'>Edit</button>
                                    <button type='button' class='btn btn-sm btn-outline-danger remove-alias-btn users-edit-danger-button' data-idx='#(local.ai-1)#'>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='aliasCount' value='#arrayLen(userAliases)#'>
">
<cfloop from="1" to="#arrayLen(userAliases)#" index="local.ai">
    <cfset local.al = userAliases[local.ai]>
    <cfset content &= "
                <input type='hidden' data-alias-field='first' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.FIRSTNAME ?: "")#'>
                <input type='hidden' data-alias-field='middle' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.MIDDLENAME ?: "")#'>
                <input type='hidden' data-alias-field='last' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.LASTNAME ?: "")#'>
                <input type='hidden' data-alias-field='type' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.ALIASTYPE ?: "")#'>
                <input type='hidden' data-alias-field='source' data-alias-idx='#(local.ai-1)#' value='#EncodeForHTMLAttribute(local.al.SOURCESYSTEM ?: "")#'>
                <input type='hidden' data-alias-field='active' data-alias-idx='#(local.ai-1)#' value='#val(local.al.ISACTIVE ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary users-edit-outline-button' id='addAliasBtn'>+ Add Alias</button>
                    <button type='button' class='btn btn-sm btn-success ms-2 users-edit-success-button' id='saveAliasesBtn'>Save Aliases</button>
                </div>
            </div>

            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Title 1 (UH Title)" & (isSuperAdmin ? " <span class='badge bg-warning text-dark'>Super Admin</span>" : "") & "</label>
                    <input class='form-control' name='Title1' value='#user.TITLE1#'" & (isSuperAdmin ? "" : " readonly") & ">
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Title 2 (UHCO Appointments)</label>
                    <input class='form-control' name='Title2' value='#user.TITLE2#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Title 3 (UHCO Appointments)</label>
                    <input class='form-control' name='Title3' value='#user.TITLE3#'>
                </div>
            </div>
            <div class='mt-3'>
                <button type='button' class='btn btn-primary' id='save-general-btn'>Save General Info</button>
                <span id='save-general-status' class='ms-2'></span>
            </div>
        </div>

        <div class='tab-pane fade users-edit-tab-pane' id='contact-pane' role='tabpanel' aria-labelledby='contact-tab'>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Email Addresses</label>
" & (len(trim(user.EMAILPRIMARY)) ? "
                <p class='text-muted mb-2'><strong>@UH Email:</strong> #EncodeForHTML(user.EMAILPRIMARY)#</p>
" : "") & "
                <div id='emailsContainer'>
"> 
<cfloop from="1" to="#arrayLen(userEmails)#" index="local.ei">
    <cfset local.em = userEmails[local.ei]>
    <cfset content &= "
                    <div class='card mb-2 email-card users-edit-item-card' data-idx='#(local.ei-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(local.em.EMAILADDRESS)#</strong>
                                    <cfif len(trim(local.em.EMAILTYPE ?: ""))> <span class='badge bg-secondary'>#EncodeForHTML(local.em.EMAILTYPE)#</span></cfif>
                                    <cfif val(local.em.ISPRIMARY ?: 0)> <span class='badge bg-success'>Primary</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-outline-secondary edit-email-btn users-edit-secondary-button' data-idx='#(local.ei-1)#'>Edit</button>
                                    <button type='button' class='btn btn-sm btn-outline-danger remove-email-btn users-edit-danger-button' data-idx='#(local.ei-1)#'>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='emailCount' value='#arrayLen(userEmails)#'>
">
<cfloop from="1" to="#arrayLen(userEmails)#" index="local.ei">
    <cfset local.em = userEmails[local.ei]>
    <cfset content &= "
                <input type='hidden' data-email-field='addr' data-email-idx='#(local.ei-1)#' value='#EncodeForHTMLAttribute(local.em.EMAILADDRESS)#'>
                <input type='hidden' data-email-field='type' data-email-idx='#(local.ei-1)#' value='#EncodeForHTMLAttribute(local.em.EMAILTYPE ?: "")#'>
                <input type='hidden' data-email-field='primary' data-email-idx='#(local.ei-1)#' value='#val(local.em.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary users-edit-outline-button' id='addEmailBtn'>+ Add Email</button>
                    <button type='button' class='btn btn-sm btn-success ms-2 users-edit-success-button' id='saveEmailsBtn'>Save Emails</button>
                </div>
            </div>

            <hr>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Phone Numbers</label>
                <div id='phonesContainer'>
">
<cfloop from="1" to="#arrayLen(userPhones)#" index="local.pi">
    <cfset local.ph = userPhones[local.pi]>
    <cfset content &= "
                    <div class='card mb-2 phone-card users-edit-item-card' data-idx='#(local.pi-1)#'>
                        <div class='card-body py-2 px-3 users-edit-item-card-body'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(local.ph.PHONENUMBER)#</strong>
                                    <cfif len(trim(local.ph.PHONETYPE ?: ""))> <span class='badge bg-secondary'>#EncodeForHTML(local.ph.PHONETYPE)#</span></cfif>
                                    <cfif val(local.ph.ISPRIMARY ?: 0)> <span class='badge bg-success'>Primary</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-outline-secondary edit-phone-btn users-edit-secondary-button' data-idx='#(local.pi-1)#'>Edit</button>
                                    <button type='button' class='btn btn-sm btn-outline-danger remove-phone-btn users-edit-danger-button' data-idx='#(local.pi-1)#'>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='phoneCount' value='#arrayLen(userPhones)#'>
">
<cfloop from="1" to="#arrayLen(userPhones)#" index="local.pi">
    <cfset local.ph = userPhones[local.pi]>
    <cfset content &= "
                <input type='hidden' data-phone-field='number' data-phone-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.ph.PHONENUMBER)#'>
                <input type='hidden' data-phone-field='type' data-phone-idx='#(local.pi-1)#' value='#EncodeForHTMLAttribute(local.ph.PHONETYPE ?: "")#'>
                <input type='hidden' data-phone-field='primary' data-phone-idx='#(local.pi-1)#' value='#val(local.ph.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary users-edit-outline-button' id='addPhoneBtn'>+ Add Phone</button>
                    <button type='button' class='btn btn-sm btn-success ms-2 users-edit-success-button' id='savePhonesBtn'>Save Phones</button>
                </div>
            </div>

            <hr>
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Addresses</label>
                <div id='addressesContainer'>
">
<cfloop from="1" to="#arrayLen(userAddresses)#" index="local.adi">
    <cfset local.addr = userAddresses[local.adi]>
    <cfset content &= "
                <div class='card mb-2 address-card users-edit-item-card'>
                    <div class='card-body py-2 px-3 users-edit-item-card-body'>
                        <div class='d-flex justify-content-between align-items-start'>
                            <div>
                                <strong>#EncodeForHTML(local.addr.ADDRESSTYPE ?: "")#</strong>
                                <cfif val(local.addr.ISPRIMARY ?: 0)> <span class='badge bg-success'>Primary</span></cfif>
                                <br>
                                <small class='text-muted'>
                                    #EncodeForHTML(local.addr.ADDRESS1 ?: "")#
                                    <cfif len(trim(local.addr.ADDRESS2 ?: ""))>, #EncodeForHTML(local.addr.ADDRESS2)#</cfif>
                                    <cfif len(trim(local.addr.CITY ?: "")) OR len(trim(local.addr.STATE ?: "")) OR len(trim(local.addr.ZIPCODE ?: ""))>
                                        <br>#EncodeForHTML(local.addr.CITY ?: "")#<cfif len(trim(local.addr.STATE ?: ""))>, #EncodeForHTML(local.addr.STATE)#</cfif> #EncodeForHTML(local.addr.ZIPCODE ?: "")#
                                    </cfif>
                                    <cfif len(trim(local.addr.BUILDING ?: ""))> | Bldg: #EncodeForHTML(local.addr.BUILDING)#</cfif>
                                    <cfif len(trim(local.addr.ROOM ?: ""))> Rm: #EncodeForHTML(local.addr.ROOM)#</cfif>
                                    <cfif len(trim(local.addr.MAILCODE ?: ""))> | MC: #EncodeForHTML(local.addr.MAILCODE)#</cfif>
                                </small>
                            </div>
                            <div>
                                <button type='button' class='btn btn-sm btn-outline-secondary edit-address-btn users-edit-secondary-button' data-idx='#(local.adi-1)#'>Edit</button>
                                <button type='button' class='btn btn-sm btn-outline-danger remove-address-btn users-edit-danger-button' data-idx='#(local.adi-1)#'>Remove</button>
                            </div>
                        </div>
                    </div>
                </div>
    ">
</cfloop>
<cfset content &= "
                <input type='hidden' id='addressCount' value='#arrayLen(userAddresses)#'>
">
<cfloop from="1" to="#arrayLen(userAddresses)#" index="local.adi">
    <cfset local.addr = userAddresses[local.adi]>
    <cfset content &= "
                <input type='hidden' data-addr-field='type' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESSTYPE ?: "")#'>
                <input type='hidden' data-addr-field='addr1' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESS1 ?: "")#'>
                <input type='hidden' data-addr-field='addr2' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ADDRESS2 ?: "")#'>
                <input type='hidden' data-addr-field='city' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.CITY ?: "")#'>
                <input type='hidden' data-addr-field='state' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.STATE ?: "")#'>
                <input type='hidden' data-addr-field='zip' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ZIPCODE ?: "")#'>
                <input type='hidden' data-addr-field='building' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.BUILDING ?: "")#'>
                <input type='hidden' data-addr-field='room' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.ROOM ?: "")#'>
                <input type='hidden' data-addr-field='mailcode' data-addr-idx='#(local.adi-1)#' value='#EncodeForHTMLAttribute(local.addr.MAILCODE ?: "")#'>
                <input type='hidden' data-addr-field='primary' data-addr-idx='#(local.adi-1)#' value='#val(local.addr.ISPRIMARY ?: 0)#'>
    ">
</cfloop>
<cfset content &= "
                </div>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary users-edit-outline-button' id='addAddressBtn'>+ Add Address</button>
                    <button type='button' class='btn btn-sm btn-success ms-2 users-edit-success-button' id='saveAddressesBtn'>Save Addresses</button>
                </div>
            </div>
        </div>

        <div class='tab-pane fade' id='flags-pane' role='tabpanel' aria-labelledby='flags-tab'>
            <div class='border p-3 rounded users-edit-scroll-panel'>
" />

<cfif arrayLen(allFlags) gt 0>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset flag = allFlags[i]>
        <cfset isChecked = arrayFindNoCase(userFlagIDs, flag.FLAGID) gt 0>
        <cfset content &= "
            <div class='form-check form-check-inline'>
                <input class='form-check-input' type='checkbox' name='Flags' value='#flag.FLAGID#' id='flag#flag.FLAGID#' data-flagname='#lCase(flag.FLAGNAME)#' " & (isChecked ? "checked" : "") & ">
                <label class='form-check-label' for='flag#flag.FLAGID#'>
                    #flag.FLAGNAME#
                </label>
            </div>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted'>No flags available</p>">
</cfif>

<cfset content &= "
            <div class='mt-3'>
                <button type='button' class='btn btn-primary' id='save-flags-btn'>Save Flags</button>
                <span id='save-flags-status' class='ms-2'></span>
            </div>
            </div>
        </div>

        <div class='tab-pane fade' id='orgs-pane' role='tabpanel' aria-labelledby='orgs-tab'>

" />

<cfset content &= renderOrgPanels(userOrgIDs)>

<cfset content &= "
        <div class='mt-3'>
            <button type='button' class='btn btn-primary' id='save-orgs-btn'>Save Organizations</button>
            <span id='save-orgs-status' class='ms-2'></span>
        </div>
        </div>

        <div class='tab-pane fade' id='extids-pane' role='tabpanel' aria-labelledby='extids-tab'>
            #extIDHtml#
            <div class='mt-3'>
                <button type='button' class='btn btn-primary' id='save-extids-btn'>Save External IDs</button>
                <span id='save-extids-status' class='ms-2'></span>
            </div>
        </div>

" & (isSuperAdmin ? "
        <div class='tab-pane fade' id='address-pane' role='tabpanel' aria-labelledby='address-tab'>
            <div class='row mb-3'>
                <div class='col-md-6'>
                    <label class='form-label text-muted'>@UH Primary Email</label>
                    <input class='form-control form-control-sm' id='emailPrimary' name='EmailPrimary' value='#user.EMAILPRIMARY#' type='email'>
                    <div class='invalid-feedback' id='emailPrimaryErr'></div>
                </div>
                <div class='col-md-6'>
                    <label class='form-label'>UH API ID</label>
                    <input class='form-control' name='UH_API_ID' value='#user.UH_API_ID#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Room</label>
                    <input class='form-control' name='Room' value='#(user.ROOM ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Building</label>
                    <input class='form-control' name='Building' value='#(user.BUILDING ?: "")#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Campus</label>
                    <input class='form-control' name='Campus' value='#(user.CAMPUS ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Division</label>
                    <input class='form-control' name='Division' value='#(user.DIVISION ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Division Name</label>
                    <input class='form-control' name='DivisionName' value='#(user.DIVISIONNAME ?: "")#'>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label'>Department</label>
                    <input class='form-control' name='Department' value='#(user.DEPARTMENT ?: "")#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Department Name</label>
                    <input class='form-control' name='DepartmentName' value='#(user.DEPARTMENTNAME ?: "")#'>
                </div>
                <div class='col-md-4'></div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-4'>
                    <label class='form-label text-muted'>Hometown City</label>
                    <input class='form-control' value='#EncodeForHTMLAttribute(spHometownCity)#' readonly>
                </div>
                <div class='col-md-4'>
                    <label class='form-label text-muted'>Hometown State</label>
                    <input class='form-control' value='#EncodeForHTMLAttribute(spHometownState)#' readonly>
                </div>
                <div class='col-md-4 d-flex align-items-end'>
                    <small class='text-muted'>Mirrored from the user's Hometown address for Alumni and Current Student records.</small>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-8'>
                    <label class='form-label'>Office Mailing Address</label>
                    <div class='input-group'>
                        <input class='form-control' name='Office_Mailing_Address' id='officeMailingAddress' value='#(user.OFFICE_MAILING_ADDRESS ?: "")#'>
                        <button type='button' class='btn btn-outline-secondary' id='copyToAddressesBtn' title='Parse and copy to Addresses tab'>
                            <i class='bi bi-arrow-right-square'></i> Copy to Addresses
                        </button>
                    </div>
                    <small class='text-muted'>Copies parsed address as a new Office entry on the Contact tab</small>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Mailcode</label>
                    <input class='form-control' name='Mailcode' value='#(user.MAILCODE ?: "")#'>
                </div>
            </div>
            <div class='mt-3'>
                <button type='button' class='btn btn-primary' id='save-uh-btn'>Save UH Fields</button>
                <span id='save-uh-status' class='ms-2'></span>
            </div>
        </div>
" : "") & "

">

<!--- ── Biographical Information pane ── --->
<cfset content &= "
        <div class='tab-pane fade' id='bio-info-pane' role='tabpanel' aria-labelledby='bio-info-tab'>

            <h6 class='fw-bold mb-3'>Personal</h6>
            <div class='row mb-3'>
                <div class='col-md-3'>
                    <label class='form-label'>Date of Birth</label>
                    <input class='form-control' type='date' name='DOB' value='#(isDate(user.DOB ?: "") ? dateFormat(user.DOB, "yyyy-mm-dd") : "")#'>
                </div>
                <div class='col-md-3'>
                    <label class='form-label'>Gender</label>
                    <select class='form-select' name='Gender'>
                        <option value=''>--</option>
                        <option value='Male' #((user.GENDER ?: "") EQ "Male" ? "selected" : "")#>Male</option>
                        <option value='Female' #((user.GENDER ?: "") EQ "Female" ? "selected" : "")#>Female</option>
                    </select>
                </div>
            </div>

">

<!--- ── Determine which role flags are active ── --->
<cfset showCurrentStudent = false>
<cfset showAlumni = false>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset local.fn = lCase(trim(allFlags[i].FLAGNAME))>
    <cfif local.fn EQ "current-student" AND arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
        <cfset showCurrentStudent = true>
    </cfif>
    <cfif local.fn EQ "alumni" AND arrayFindNoCase(userFlagIDs, allFlags[i].FLAGID) GT 0>
        <cfset showAlumni = true>
    </cfif>
</cfloop>

<cfset showDegreesAwards = showFacultyProfile OR showAlumni OR showCurrentStudent OR showEmeritusProfile OR showResidentProfile>

<!--- ── Degrees & Awards (shared, shown once) ── --->
<cfif showDegreesAwards>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Degrees &amp; Awards</h6>">
    
    <!--- Degrees as cards --->
    <cfif isSuperAdmin AND len(trim(user.DEGREES ?: ""))>
        <cfset content &= "<div class='row mb-3'><div class='col-md-8'>
            <label class='form-label text-muted'>Combined Degrees (auto-generated, read-only)</label>
            <input class='form-control form-control-sm' id='bio_composite' value='#EncodeForHTMLAttribute(user.DEGREES ?: "")#' readonly disabled>
        </div></div>">
    </cfif>
    <cfset content &= "
            <div class='mb-4'>
                <label class='form-label fw-semibold'>Degrees</label>
                <div id='degreesContainer'>
    ">
</cfif>
<cfif showDegreesAwards>
    <cfloop from="1" to="#arrayLen(userDegrees)#" index="local.di">
        <cfset local.dg = userDegrees[local.di]>
        <cfset content &= "
                    <div class='card mb-2 degree-card' data-idx='#(local.di-1)#'>
                        <div class='card-body py-2 px-3'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(local.dg.DEGREENAME)#</strong>
                                    <cfif len(trim(local.dg.UNIVERSITY ?: ""))> — #EncodeForHTML(local.dg.UNIVERSITY)#</cfif>
                                    <cfif len(trim(local.dg.DEGREEYEAR ?: ""))> <span class='badge bg-secondary'>#EncodeForHTML(local.dg.DEGREEYEAR)#</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-outline-secondary edit-degree-btn' data-idx='#(local.di-1)#'>Edit</button>
                                    <button type='button' class='btn btn-sm btn-outline-danger remove-degree-btn' data-idx='#(local.di-1)#'>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
        ">
    </cfloop>
    <cfloop from="1" to="#arrayLen(userDegrees)#" index="local.di">
        <cfset local.dg = userDegrees[local.di]>
        <cfset content &= "
                <input type='hidden' data-degree-field='name' data-degree-idx='#(local.di-1)#' value='#EncodeForHTMLAttribute(local.dg.DEGREENAME)#'>
                <input type='hidden' data-degree-field='university' data-degree-idx='#(local.di-1)#' value='#EncodeForHTMLAttribute(local.dg.UNIVERSITY ?: "")#'>
                <input type='hidden' data-degree-field='year' data-degree-idx='#(local.di-1)#' value='#EncodeForHTMLAttribute(local.dg.DEGREEYEAR ?: "")#'>
        ">
    </cfloop>
    <cfset content &= "
                </div>
                <input type='hidden' id='degreeCount' value='#arrayLen(userDegrees)#'>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary' id='addDegreeBtn'>+ Add Degree</button>
                    <button type='button' class='btn btn-sm btn-success ms-2' id='saveDegreesBtn'>Save Degrees</button>
                </div>
            </div>
    ">

    <!--- Awards as cards --->
    <cfset awardOptions = 'Gold Key,Summa cum laude,Magna cum laude,BSK Gold,BSK Black & Gold,AOSA Honors,NOSA Honors,Other'>
    <cfset content &= "
            <div class='mb-4 mt-3'>
                <label class='form-label fw-semibold'>Awards &amp; Honors</label>
                <div id='awardsContainer'>
    ">
    <cfloop from="1" to="#arrayLen(spAwards)#" index="ai">
        <cfset aw = spAwards[ai]>
        <cfset awName = trim(aw.AWARDNAME)>
        <cfset content &= "
                    <div class='card mb-2 award-card' data-idx='#(ai-1)#'>
                        <div class='card-body py-2 px-3'>
                            <div class='d-flex justify-content-between align-items-center'>
                                <div>
                                    <strong>#EncodeForHTML(awName)#</strong>
                                    <cfif len(trim(aw.AWARDTYPE ?: ""))> <span class='badge bg-secondary'>#EncodeForHTML(aw.AWARDTYPE)#</span></cfif>
                                </div>
                                <div>
                                    <button type='button' class='btn btn-sm btn-outline-secondary edit-award-btn' data-idx='#(ai-1)#'>Edit</button>
                                    <button type='button' class='btn btn-sm btn-outline-danger remove-award-btn' data-idx='#(ai-1)#'>Remove</button>
                                </div>
                            </div>
                        </div>
                    </div>
        ">
    </cfloop>
    <cfloop from="1" to="#arrayLen(spAwards)#" index="ai">
        <cfset aw = spAwards[ai]>
        <cfset content &= "
                <input type='hidden' data-award-field='name' data-award-idx='#(ai-1)#' value='#EncodeForHTMLAttribute(trim(aw.AWARDNAME))#'>
                <input type='hidden' data-award-field='type' data-award-idx='#(ai-1)#' value='#EncodeForHTMLAttribute(aw.AWARDTYPE ?: "")#'>
        ">
    </cfloop>
    <cfset content &= "
                </div>
                <input type='hidden' id='awardCount' value='#arrayLen(spAwards)#'>
                <div class='mt-2'>
                    <button type='button' class='btn btn-sm btn-outline-primary' id='addAwardBtn'>+ Add Award / Honor</button>
                    <button type='button' class='btn btn-sm btn-success ms-2' id='saveAwardsBtn'>Save Awards</button>
                </div>
            </div>
    ">
</cfif>

<!--- ── Faculty section (bio editor) ── --->
<cfif showFacultyProfile>
    <cfset content &= "
            <hr>
            <h6 class='fw-bold mb-3'>Faculty</h6>
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio / About Me</label>
                <div id='bio-editor' class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' id='bioContentHidden' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
    ">
</cfif>

<!--- ── Staff section (bio editor if public-facing) ── --->
<cfif showStaffProfile>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Staff</h6>">
    <cfif showBio AND NOT showFacultyProfile>
        <cfset content &= "
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio (Public-Facing)</label>
                <div id='bio-editor' class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' id='bioContentHidden' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
        ">
    <cfelseif NOT showBio>
        <cfset content &= "<p class='text-muted'>Bio is available when the <em>public-facing</em> flag is enabled.</p>">
    <cfelse>
        <cfset content &= "<p class='text-muted'>Bio is managed in the Faculty section above.</p>">
    </cfif>
</cfif>

<!--- ── Student Data section (Current Students & Alumni) ── --->
<cfif showCurrentStudent OR showAlumni>
    <cfset content &= "
            <hr>
            <h6 class='fw-bold mb-3'>Student Data</h6>
            <input type='hidden' name='processAcademicInfo' value='1'>
            <input type='hidden' name='processStudentProfile' value='1'>
            <div class='row mb-3'>
                <div class='col-md-6'>
                    <label class='form-label'>Current Grad Year</label>
                    <input class='form-control' name='CurrentGradYear' id='currentGradYear' value='#currentGradYear#' placeholder='e.g. 2028'>
                </div>
                <div class='col-md-6'>
                    <label class='form-label'>Original Grad Year</label>
                    <input class='form-control' name='OriginalGradYear' id='originalGradYear' value='#originalGradYear#' placeholder='e.g. 2027' #(len(currentGradYear) ? '' : 'disabled')#>
                    <div class='form-text'>Requires a Current Grad Year.</div>
                </div>
            </div>
            <div class='row mb-3'>
                <div class='col-md-3'>
                    <label class='form-label'>Commencement Age</label>
                    <input class='form-control' type='number' name='sp_commencement_age' min='0' max='120' value='#EncodeForHTMLAttribute(spCommAge)#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>First Externship</label>
                    <input class='form-control' name='sp_first_externship' value='#EncodeForHTMLAttribute(spFirstExt)#'>
                </div>
                <div class='col-md-4'>
                    <label class='form-label'>Second Externship</label>
                    <input class='form-control' name='sp_second_externship' value='#EncodeForHTMLAttribute(spSecondExt)#'>
                </div>
            </div>
    ">
</cfif>

<!--- ── Alumni Data section ── --->
<cfif showAlumni>
    <cfset content &= "
            <hr>
            <h6 class='fw-bold mb-3'>Alumni Data</h6>
            <p class='text-muted'>Academic data is shared with the Student Data section above.</p>
    ">
</cfif>

<!--- ── Emeritus section (bio if no faculty) ── --->
<cfif showEmeritusProfile>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Professor Emeritus</h6>">
    <cfif NOT showFacultyProfile>
        <cfset content &= "
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio / About Me</label>
                <div id='bio-editor' class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' id='bioContentHidden' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
        ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>Bio is managed in the Faculty section above.</p>">
    </cfif>
</cfif>

<!--- ── Resident section (bio if no faculty/emeritus) ── --->
<cfif showResidentProfile>
    <cfset content &= "<hr><h6 class='fw-bold mb-3'>Resident</h6>">
    <cfif NOT showFacultyProfile AND NOT showEmeritusProfile>
        <cfset content &= "
            <input type='hidden' name='processBio' value='1'>
            <div class='mb-4'>
                <label class='form-label fw-bold'>Bio / About Me</label>
                <div id='bio-editor' class='users-edit-bio-editor'>#bioContent#</div>
                <input type='hidden' name='bioContent' id='bioContentHidden' value='#EncodeForHTMLAttribute(bioContent)#'>
            </div>
        ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>Bio is managed in the " & (showFacultyProfile ? "Faculty" : "Emeritus") & " section above.</p>">
    </cfif>
</cfif>

<cfset content &= "
        <div class='mt-3'>
            <button type='button' class='btn btn-primary' id='save-bioinfo-btn'>Save Biographical Info</button>
            <span id='save-bioinfo-status' class='ms-2'></span>
        </div>
        </div>
">

<!--- ── Student Profile pane ── --->
<cfset content &= "<div class='tab-pane fade' id='student-profile-pane' role='tabpanel' aria-labelledby='student-profile-tab'>">
<cfif showStudentProfile>
    <cfset content &= "
        <div class='row mb-3'>
            <div class='col-md-6'>
                <label class='form-label'>Current Grad Year</label>
                <input class='form-control' name='CurrentGradYear' id='currentGradYear' value='#currentGradYear#' placeholder='e.g. 2028'>
            </div>
            <div class='col-md-6'>
                <label class='form-label'>Original Grad Year</label>
                <input class='form-control' name='OriginalGradYear' id='originalGradYear' value='#originalGradYear#' placeholder='e.g. 2027' #(len(currentGradYear) ? '' : 'disabled')#>
                <div class='form-text'>Requires a Current Grad Year.</div>
            </div>
        </div>
        <div class='row mb-3'>
            <div class='col-md-4'>
                <label class='form-label'>Hometown City</label>
                <input class='form-control' name='sp_hometown_city' value='#EncodeForHTMLAttribute(spHometownCity)#'>
            </div>
            <div class='col-md-2'>
                <label class='form-label'>State</label>
                <select class='form-select' name='sp_hometown_state'>
                    <option value=''>--</option>
                    ">
    <cfloop list="AL,AK,AZ,AR,CA,CO,CT,DE,FL,GA,HI,ID,IL,IN,IA,KS,KY,LA,ME,MD,MA,MI,MN,MS,MO,MT,NE,NV,NH,NJ,NM,NY,NC,ND,OH,OK,OR,PA,RI,SC,SD,TN,TX,UT,VT,VA,WA,WV,WI,WY,DC" index="st">
        <cfset content &= "<option value='#st#' #(spHometownState EQ st ? 'selected' : '')#>#st#</option>">
    </cfloop>
    <cfset content &= "
                </select>
            </div>
            <div class='col-md-3'>
                <label class='form-label'>Date of Birth</label>
                <input class='form-control' type='date' name='sp_dob' value='#(isDate(spDOB) ? dateFormat(spDOB, "yyyy-mm-dd") : "")#'>
            </div>
            <div class='col-md-3'>
                <label class='form-label'>Gender</label>
                <select class='form-select' name='sp_gender'>
                    <option value=''>--</option>
                    <option value='Male' #(spGender EQ 'Male' ? 'selected' : '')#>Male</option>
                    <option value='Female' #(spGender EQ 'Female' ? 'selected' : '')#>Female</option>
                </select>
            </div>
        </div>
        <div class='row mb-3'>
            <div class='col-md-3'>
                <label class='form-label'>Commencement Age</label>
                <input class='form-control' type='number' name='sp_commencement_age' min='0' max='120' value='#EncodeForHTMLAttribute(spCommAge)#'>
            </div>
            <div class='col-md-4'>
                <label class='form-label'>First Externship</label>
                <input class='form-control' name='sp_first_externship' value='#EncodeForHTMLAttribute(spFirstExt)#'>
            </div>
            <div class='col-md-4'>
                <label class='form-label'>Second Externship</label>
                <input class='form-control' name='sp_second_externship' value='#EncodeForHTMLAttribute(spSecondExt)#'>
            </div>
        </div>
    ">
    <cfset content &= renderDegreesPanel(userDegrees, "sp", false, "")>
    <cfset content &= "
        <div class='mb-4'>
            <label class='form-label fw-semibold'>Awards &amp; Honors</label>
            <div id='spAwardsContainer'>
    ">
    <cfset awardOptions = 'Gold Key,Summa cum laude,Magna cum laude,BSK Gold,BSK Black & Gold,AOSA Honors,NOSA Honors,Other'>
    <cfloop from="1" to="#arrayLen(spAwards)#" index="ai">
        <cfset aw = spAwards[ai]>
        <cfset awName = trim(aw.AWARDNAME)>
        <cfset isOther = (listFindNoCase(awardOptions, awName) EQ 0 AND len(awName))>
        <cfset selVal = isOther ? "Other" : awName>
        <cfset content &= "<div class='row g-2 mb-2 award-row'>
                <div class='col-md-4'>
                    <select class='form-select form-select-sm award-select' data-field='select'>
                        <option value=''>-- Select --</option>">
        <cfloop list="#awardOptions#" index="aOpt">
            <cfset content &= "<option value='#EncodeForHTMLAttribute(aOpt)#' #(selVal EQ aOpt ? 'selected' : '')#>#EncodeForHTML(aOpt)#</option>">
        </cfloop>
        <cfset content &= "</select>
                </div>
                <div class='col-md-3 award-other-col #(isOther ? '' : 'd-none')#'>
                    <input class='form-control form-control-sm award-other-input' placeholder='Specify award' value='#(isOther ? EncodeForHTMLAttribute(awName) : "")#'>
                </div>
                <input type='hidden' class='award-name-hidden' data-field='name' value='#EncodeForHTMLAttribute(awName)#'>
                <div class='col-md-3'>
                    <select class='form-select form-select-sm' data-field='type'>
                        <option value=''>-- Type --</option>
                        <option value='Honor' #(aw.AWARDTYPE EQ 'Honor' ? 'selected' : '')#>Honor</option>
                        <option value='Award' #(aw.AWARDTYPE EQ 'Award' ? 'selected' : '')#>Award</option>
                    </select>
                </div>
                <div class='col-md-2'><button type='button' class='btn btn-sm btn-outline-danger remove-award-row w-100'>Remove</button></div>
            </div>">
    </cfloop>
    <cfset content &= "
            </div>
            <input type='hidden' id='spAwardCount' value='#arrayLen(spAwards)#'>
            <button type='button' class='btn btn-sm btn-outline-primary mt-2' id='addSpAwardRow'>+ Add Award / Honor</button>
        </div>
    ">
</cfif>
<cfset content &= "
    <div class='mt-3'>
        <button type='button' class='btn btn-primary' id='save-studentprofile-btn'>Save Student Profile</button>
        <span id='save-studentprofile-status' class='ms-2'></span>
    </div>
</div>">

<!--- ── Faculty Profile pane ── --->
<cfset content &= "
    <div class='tab-pane fade' id='faculty-profile-pane' role='tabpanel' aria-labelledby='faculty-profile-tab'>
">
<cfset content &= renderDegreesPanel(userDegrees, "fac", isSuperAdmin, user.DEGREES ?: "")>
<cfset content &= "
    <div class='mt-3'>
        <button type='button' class='btn btn-primary' id='save-facultydeg-btn'>Save Faculty Degrees</button>
        <span id='save-facultydeg-status' class='ms-2'></span>
    </div>
    </div>
">

<!--- ── Staff Profile pane ── --->
<cfset content &= "
    <div class='tab-pane fade' id='staff-profile-pane' role='tabpanel' aria-labelledby='staff-profile-tab'>
        <p class='text-muted'>Staff profile fields coming soon.</p>
    </div>
">

<!--- ── Professor Emeritus Profile pane ── --->
<cfset content &= "
    <div class='tab-pane fade' id='emeritus-profile-pane' role='tabpanel' aria-labelledby='emeritus-profile-tab'>
">
<cfset content &= renderDegreesPanel(userDegrees, "emer", isSuperAdmin, user.DEGREES ?: "")>
<cfset content &= "
    <div class='mt-3'>
        <button type='button' class='btn btn-primary' id='save-emeritusdeg-btn'>Save Emeritus Degrees</button>
        <span id='save-emeritusdeg-status' class='ms-2'></span>
    </div>
    </div>
">

<!--- ── Resident Profile pane ── --->
<cfset content &= "
    <div class='tab-pane fade' id='resident-profile-pane' role='tabpanel' aria-labelledby='resident-profile-tab'>
">
<cfset content &= renderDegreesPanel(userDegrees, "res", isSuperAdmin, user.DEGREES ?: "")>
<cfset content &= "
    <div class='mt-3'>
        <button type='button' class='btn btn-primary' id='save-residentdeg-btn'>Save Resident Degrees</button>
        <span id='save-residentdeg-status' class='ms-2'></span>
    </div>
    </div>
">

<!--- ── Bio pane ── --->
<cfset content &= "
    <div class='tab-pane fade' id='bio-pane' role='tabpanel' aria-labelledby='bio-tab'>
        <label class='form-label fw-bold'>Bio / About Me</label>
        <div id='bio-editor' class='users-edit-bio-editor'>#bioContent#</div>
        <input type='hidden' name='bioContent' id='bioContentHidden' value='#EncodeForHTMLAttribute(bioContent)#'>
        <div class='mt-3'>
            <button type='button' class='btn btn-primary' id='save-bio-btn'>Save Bio</button>
            <span id='save-bio-status' class='ms-2'></span>
        </div>
    </div>
">

<cfset content &= "
    </div>

    
    <div class='mt-3'>
    " & (user.UH_API_ID != "" ? "<a href='/admin/users/uh_sync.cfm?userID=#urlEncodedFormat(user.USERID)#&uhApiId=#urlEncodedFormat(user.UH_API_ID)#' class='btn btn-info me-2'>UH Sync</a>" : "") & "
        <a href='/admin/users/index.cfm' class='btn btn-secondary'>Back to Users</a>
    </div>

    <script>
    (function () {
        var epEl  = document.getElementById('emailPrimary');
        var epErr = document.getElementById('emailPrimaryErr');
        function showError(el, errEl, msg) { el.classList.add('is-invalid'); errEl.textContent = msg; }
        function clearError(el, errEl)     { el.classList.remove('is-invalid'); errEl.textContent = ''; }
        function validatePrimary() {
            var val = (epEl ? epEl.value : '').trim().toLowerCase();
            if (val && !val.endsWith('@uh.edu')) {
                showError(epEl, epErr, 'Must be a @uh.edu address (e.g. jsmith@uh.edu).');
                return false;
            }
            if (epEl) clearError(epEl, epErr);
            return true;
        }
        if (epEl) epEl.addEventListener('blur', validatePrimary);
        var form = epEl ? epEl.closest('form') : null;
        if (form) {
            form.addEventListener('submit', function (e) {
                if (!validatePrimary()) { e.preventDefault(); var inv = document.querySelector('.is-invalid'); if (inv) inv.focus(); }
            });
        }
    })();
    </script>

    <script>
    /* ── Email rows removed — now modal-based ── */
    </script>

    <script>
    /* ── Phone rows removed — now modal-based ── */
    </script>
">

<cfset aliasTypeOptsJS = "''">
<cfset aliasTypeLblsJS = "'-- Type --'">
<cfloop from="1" to="#arrayLen(aliasTypes)#" index="local._ati">
    <cfset aliasTypeOptsJS &= ",'" & jsStringFormat(aliasTypes[local._ati].ALIASTYPECODE) & "'">
    <cfset aliasTypeLblsJS &= ",'" & jsStringFormat(aliasTypes[local._ati].DESCRIPTION) & "'">
</cfloop>

<cfset content &= "
    <script>
    /* ── Alias rows removed — now modal-based ── */
    /* Alias type options preserved for modal */
    var aliasTypeOptions = [#aliasTypeOptsJS#];
    var aliasTypeLabels  = [#aliasTypeLblsJS#];
    </script>

    <script>
    document.addEventListener('DOMContentLoaded', function () {
        var orgCheckboxes = Array.prototype.slice.call(document.querySelectorAll('input.org-checkbox'));
        if (!orgCheckboxes.length) return;

        var byOrgId = {};
        var childrenByParent = {};

        orgCheckboxes.forEach(function (cb) {
            var orgId    = cb.getAttribute('data-orgid')       || '';
            var parentId = cb.getAttribute('data-parentorgid') || '';
            byOrgId[orgId] = cb;
            if (!childrenByParent[parentId]) childrenByParent[parentId] = [];
            childrenByParent[parentId].push(cb);
        });

        // ── Ancestor cascade helpers ──────────────────────────────────────
        function checkAncestors(cb) {
            var parentId = cb.getAttribute('data-parentorgid') || '';
            while (parentId && byOrgId[parentId]) {
                byOrgId[parentId].checked = true;
                parentId = byOrgId[parentId].getAttribute('data-parentorgid') || '';
            }
        }

        function hasAnyCheckedDescendant(orgId) {
            var stack = (childrenByParent[orgId] || []).slice();
            while (stack.length) {
                var child = stack.pop();
                if (child.checked) return true;
                var grandChildren = childrenByParent[child.getAttribute('data-orgid') || ''] || [];
                for (var i = 0; i < grandChildren.length; i++) stack.push(grandChildren[i]);
            }
            return false;
        }

        function uncheckAncestorsIfNoCheckedChildren(cb) {
            var parentId = cb.getAttribute('data-parentorgid') || '';
            while (parentId && byOrgId[parentId]) {
                if (!hasAnyCheckedDescendant(parentId)) byOrgId[parentId].checked = false;
                parentId = byOrgId[parentId].getAttribute('data-parentorgid') || '';
            }
        }

        // ── Role modal ────────────────────────────────────────────────────
        var modalEl      = document.getElementById('orgRoleModal');
        var bsModal      = new bootstrap.Modal(modalEl);
        var modalOrgName = document.getElementById('orgRoleModalOrgName');
        var modalTitle   = document.getElementById('modalRoleTitle');
        var modalOrder   = document.getElementById('modalRoleOrder');
        var modalSaveBtn = document.getElementById('orgRoleModalSave');
        var pendingCheckbox = null;   // set when modal opened by a new check

        function getEditBtn(orgId) {
            var cb = byOrgId[orgId];
            return cb ? cb.parentNode.querySelector('.org-role-edit') : null;
        }

        function setOrgRole(orgId, roleTitle, roleOrder) {
            var tEl = document.getElementById('roleTitle_' + orgId);
            var oEl = document.getElementById('roleOrder_' + orgId);
            var cb  = byOrgId[orgId];
            if (!tEl) {
                tEl = document.createElement('input');
                tEl.type = 'hidden'; tEl.name = 'roleTitle_' + orgId; tEl.id = 'roleTitle_' + orgId;
                if (cb) cb.parentNode.appendChild(tEl);
            }
            if (!oEl) {
                oEl = document.createElement('input');
                oEl.type = 'hidden'; oEl.name = 'roleOrder_' + orgId; oEl.id = 'roleOrder_' + orgId;
                if (cb) cb.parentNode.appendChild(oEl);
            }
            tEl.value = roleTitle;
            oEl.value = roleOrder;
        }

        function removeOrgRole(orgId) {
            ['roleTitle_', 'roleOrder_'].forEach(function (prefix) {
                var el = document.getElementById(prefix + orgId);
                if (el) el.remove();
            });
        }

        function openRoleModal(cb) {
            var orgId   = cb.getAttribute('data-orgid');
            var orgName = cb.getAttribute('data-orgname');
            var tEl     = document.getElementById('roleTitle_' + orgId);
            var oEl     = document.getElementById('roleOrder_' + orgId);
            modalOrgName.textContent = orgName;
            modalTitle.value = tEl ? tEl.value : '';
            modalOrder.value = oEl ? oEl.value : '';
            modalEl.setAttribute('data-current-orgid', orgId);
            bsModal.show();
        }

        modalSaveBtn.addEventListener('click', function () {
            var orgId = modalEl.getAttribute('data-current-orgid');
            setOrgRole(orgId, modalTitle.value.trim(), modalOrder.value.trim());
            var btn = getEditBtn(orgId);
            if (btn) btn.classList.add('is-visible');
            pendingCheckbox = null;
            bsModal.hide();
        });

        // Cancel / backdrop: if triggered by a new check, undo it
        modalEl.addEventListener('hidden.bs.modal', function () {
            if (pendingCheckbox) {
                var orgId = pendingCheckbox.getAttribute('data-orgid');
                pendingCheckbox.checked = false;
                uncheckAncestorsIfNoCheckedChildren(pendingCheckbox);
                orgCheckboxes.forEach(function (c) {
                    var btn = getEditBtn(c.getAttribute('data-orgid'));
                    if (btn) btn.classList.toggle('is-visible', c.checked);
                });
                removeOrgRole(orgId);
                pendingCheckbox = null;
            }
        });

        // Edit button click (existing assignments)
        document.querySelectorAll('.org-role-edit').forEach(function (btn) {
            btn.addEventListener('click', function (e) {
                e.preventDefault();
                var orgId = btn.getAttribute('data-orgid');
                var cb = byOrgId[orgId];
                if (!cb) return;
                pendingCheckbox = null;
                openRoleModal(cb);
            });
        });

        // ── Wire up checkboxes ────────────────────────────────────────────
        orgCheckboxes.forEach(function (cb) {
            if (cb.checked) checkAncestors(cb);

            cb.addEventListener('change', function () {
                var isParent = cb.getAttribute('data-isparent') === '1';
                var hasRoles = cb.getAttribute('data-additionalroles') === '1';
                if (cb.checked) {
                    checkAncestors(cb);
                    if (!isParent && hasRoles) {
                        pendingCheckbox = cb;
                        openRoleModal(cb);
                    }
                } else {
                    uncheckAncestorsIfNoCheckedChildren(cb);
                    if (!isParent && hasRoles) {
                        var orgId = cb.getAttribute('data-orgid');
                        var btn = getEditBtn(orgId);
                        if (btn) btn.classList.remove('is-visible');
                        removeOrgRole(orgId);
                    }
                }
            });
        });

        // Expand card panel when parent org checkbox is checked
        orgCheckboxes.forEach(function (cb) {
            var panelId = cb.getAttribute('data-panelid');
            if (!panelId) return;
            cb.addEventListener('change', function () {
                if (cb.checked) {
                    var el = document.getElementById(panelId);
                    if (el) bootstrap.Collapse.getOrCreateInstance(el, { toggle: false }).show();
                }
            });
        });
    });
    </script>

</form>

<div class='modal fade' id='orgRoleModal' tabindex='-1' aria-labelledby='orgRoleModalLabel' aria-hidden='true'>
    <div class='modal-dialog modal-sm'>
        <div class='modal-content'>
            <div class='modal-header py-2'>
                <h6 class='modal-title fw-semibold mb-0' id='orgRoleModalLabel'>
                    <i class='bi bi-pencil-square me-1 text-primary'></i>
                    <span id='orgRoleModalOrgName'></span>
                </h6>
                <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>
            </div>
            <div class='modal-body'>
                <div class='mb-3'>
                    <label class='form-label fw-semibold' for='modalRoleTitle'>Role Title</label>
                    <input type='text' class='form-control' id='modalRoleTitle' placeholder='e.g. Program Director'>
                    <div class='form-text'>Optional. Describe this person's role within the organization.</div>
                </div>
                <div class='mb-1'>
                    <label class='form-label fw-semibold' for='modalRoleOrder'>Display Order</label>
                    <input type='number' class='form-control' id='modalRoleOrder' placeholder='e.g. 1' min='0'>
                    <div class='form-text'>Optional. Lower numbers appear first in listings.</div>
                </div>
            </div>
            <div class='modal-footer py-2'>
                <button type='button' class='btn btn-sm btn-secondary' data-bs-dismiss='modal'>Cancel</button>
                <button type='button' class='btn btn-sm btn-primary' id='orgRoleModalSave'>Save Role</button>
            </div>
        </div>
    </div>
</div>

    <script>
    /* ── Award rows removed — now modal-based ── */
    var awardOptions = ['Gold Key','Summa cum laude','Magna cum laude','BSK Gold','BSK Black & Gold','AOSA Honors','NOSA Honors','Other'];
    var honorsSet = {'Gold Key':1,'Summa cum laude':1,'Magna cum laude':1,'BSK Gold':1,'BSK Black & Gold':1,'AOSA Honors':1,'NOSA Honors':1};
    </script>

    <script>
    (function () {
        var studentFlagIDs = [#arrayToList(studentFlagIDs)#];
        var spTabLi  = document.getElementById('student-profile-tab-li');
        var spTabBtn = document.getElementById('student-profile-tab');
        var curr     = document.getElementById('currentGradYear');
        var orig     = document.getElementById('originalGradYear');

        function syncOriginal() {
            if (!curr || !orig) return;
            var hasValue = curr.value.trim().length > 0;
            orig.disabled = !hasValue;
            if (!hasValue) orig.value = '';
        }

        function isStudentFlagChecked() {
            return studentFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }

        function syncSpTabVisibility() {
            if (!spTabLi) return;
            if (isStudentFlagChecked()) {
                spTabLi.classList.remove('d-none');
            } else {
                spTabLi.classList.add('d-none');
                if (curr) curr.value = '';
                if (orig) { orig.value = ''; orig.disabled = true; }
                if (spTabBtn && spTabBtn.classList.contains('active')) {
                    var generalTab = document.getElementById('general-tab');
                    if (generalTab) generalTab.click();
                }
            }
        }

        if (curr) curr.addEventListener('input', syncOriginal);

        studentFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncSpTabVisibility);
        });
    })();
    </script>

    <script>
    (function () {
        var facultyFlagIDs = [#arrayToList(facultyFlagIDs)#];
        var tabLi  = document.getElementById('faculty-profile-tab-li');
        var tabBtn = document.getElementById('faculty-profile-tab');
        function isFacultyFlagChecked() {
            return facultyFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }
        function syncFacultyTabVisibility() {
            if (!tabLi) return;
            if (isFacultyFlagChecked()) {
                tabLi.classList.remove('d-none');
            } else {
                tabLi.classList.add('d-none');
                if (tabBtn && tabBtn.classList.contains('active')) {
                    document.getElementById('general-tab').click();
                }
            }
        }
        facultyFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncFacultyTabVisibility);
        });
    })();
    </script>

    <script>
    (function () {
        var staffFlagIDs = [#arrayToList(staffFlagIDs)#];
        var tabLi  = document.getElementById('staff-profile-tab-li');
        var tabBtn = document.getElementById('staff-profile-tab');
        function isStaffFlagChecked() {
            return staffFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }
        function syncStaffTabVisibility() {
            if (!tabLi) return;
            if (isStaffFlagChecked()) {
                tabLi.classList.remove('d-none');
            } else {
                tabLi.classList.add('d-none');
                if (tabBtn && tabBtn.classList.contains('active')) {
                    document.getElementById('general-tab').click();
                }
            }
        }
        staffFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncStaffTabVisibility);
        });
    })();
    </script>

    <script>
    (function () {
        var emeritusFlagIDs = [#arrayToList(emeritusFlagIDs)#];
        var tabLi  = document.getElementById('emeritus-profile-tab-li');
        var tabBtn = document.getElementById('emeritus-profile-tab');
        function isEmeritusFlagChecked() {
            return emeritusFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }
        function syncEmeritusTabVisibility() {
            if (!tabLi) return;
            if (isEmeritusFlagChecked()) {
                tabLi.classList.remove('d-none');
            } else {
                tabLi.classList.add('d-none');
                if (tabBtn && tabBtn.classList.contains('active')) {
                    document.getElementById('general-tab').click();
                }
            }
        }
        emeritusFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncEmeritusTabVisibility);
        });
    })();
    </script>

    <script>
    (function () {
        var triggerNames = ['clinical-attending','faculty-adjunct','faculty-fulltime','professor-emeritus','accepting-patients'];
        var publicFacingCb = document.querySelector('input[name=""Flags""][data-flagname=""public-facing""]');
        if (!publicFacingCb) return;
        var allFlagCbs = document.querySelectorAll('input[name=""Flags""]');
        allFlagCbs.forEach(function (cb) {
            var fn = (cb.getAttribute('data-flagname') || '').toLowerCase();
            if (triggerNames.indexOf(fn) === -1) return;
            cb.addEventListener('change', function () {
                if (this.checked) publicFacingCb.checked = true;
            });
        });
    })();
    </script>

    <script>
    (function () {
        var residentFlagIDs = [#arrayToList(residentFlagIDs)#];
        var tabLi  = document.getElementById('resident-profile-tab-li');
        var tabBtn = document.getElementById('resident-profile-tab');
        function isResidentFlagChecked() {
            return residentFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }
        function syncResidentTabVisibility() {
            if (!tabLi) return;
            if (isResidentFlagChecked()) {
                tabLi.classList.remove('d-none');
            } else {
                tabLi.classList.add('d-none');
                if (tabBtn && tabBtn.classList.contains('active')) {
                    document.getElementById('general-tab').click();
                }
            }
        }
        residentFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncResidentTabVisibility);
        });
    })();
    </script>

    <script>
    /* ── Bio tab toggle (tied to public-facing flag) ── */
    (function () {
        var bioFlagIDs = [#arrayToList(bioFlagIDs)#];
        var tabLi  = document.getElementById('bio-tab-li');
        var tabBtn = document.getElementById('bio-tab');
        function isBioFlagChecked() {
            return bioFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }
        function syncBioTabVisibility() {
            if (!tabLi) return;
            if (isBioFlagChecked()) {
                tabLi.classList.remove('d-none');
            } else {
                tabLi.classList.add('d-none');
                if (tabBtn && tabBtn.classList.contains('active')) {
                    document.getElementById('general-tab').click();
                }
            }
        }
        bioFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncBioTabVisibility);
        });
    })();
    </script>

    <script>
    /* ── Degrees rows (shared across fac / emer / res tabs) ── */
    document.addEventListener('DOMContentLoaded', function () {
        var prefixes = ['fac', 'emer', 'res'];

        function initDegreePanel(prefix) {
            var container  = document.getElementById(prefix + '_degreesContainer');
            var countInput = document.getElementById(prefix + '_degreeCount');
            if (!container || !countInput) return;

            function reindex() {
                var rows = container.querySelectorAll('.degree-row');
                rows.forEach(function (row, idx) {
                    var n = row.querySelector('[data-field=deg_name]');
                    var u = row.querySelector('[data-field=deg_univ]');
                    var y = row.querySelector('[data-field=deg_year]');
                    if (n) n.name = prefix + '_deg_name_' + idx;
                    if (u) u.name = prefix + '_deg_univ_' + idx;
                    if (y) y.name = prefix + '_deg_year_' + idx;
                });
                countInput.value = rows.length;
                updateComposite(prefix);
            }

            function makeRemovable(btn) {
                btn.addEventListener('click', function () {
                    this.closest('.degree-row').remove();
                    reindex();
                });
            }

            container.querySelectorAll('.remove-degree-row').forEach(makeRemovable);
        }

        function updateComposite(prefix) {
            var container  = document.getElementById(prefix + '_degreesContainer');
            var composite  = document.getElementById(prefix + '_composite');
            if (!container || !composite) return;
            var names = [];
            container.querySelectorAll('[data-field=deg_name]').forEach(function (inp) {
                var v = inp.value.trim();
                if (v) names.push(v);
            });
            composite.value = names.join(', ');
        }

        /* Delegate click for all Add Degree buttons */
        document.addEventListener('click', function (e) {
            var addBtn = e.target.closest('.add-degree-row');
            if (!addBtn) return;
            var prefix     = addBtn.getAttribute('data-prefix');
            var container  = document.getElementById(prefix + '_degreesContainer');
            var countInput = document.getElementById(prefix + '_degreeCount');
            if (!container || !countInput) return;
            var idx = parseInt(countInput.value, 10);
            var row = document.createElement('div');
            row.className = 'row g-2 mb-2 degree-row';

            var c1 = document.createElement('div'); c1.className = 'col-md-4';
            var n  = document.createElement('input');
            n.className = 'form-control form-control-sm'; n.name = prefix + '_deg_name_' + idx;
            n.setAttribute('data-field', 'deg_name'); n.placeholder = 'Degree (required)'; n.required = true;
            n.addEventListener('input', function () { updateComposite(prefix); });
            c1.appendChild(n);

            var c2 = document.createElement('div'); c2.className = 'col-md-4';
            var u  = document.createElement('input');
            u.className = 'form-control form-control-sm'; u.name = prefix + '_deg_univ_' + idx;
            u.setAttribute('data-field', 'deg_univ'); u.placeholder = 'University';
            c2.appendChild(u);

            var c3 = document.createElement('div'); c3.className = 'col-md-2';
            var y  = document.createElement('input');
            y.className = 'form-control form-control-sm'; y.name = prefix + '_deg_year_' + idx;
            y.setAttribute('data-field', 'deg_year'); y.placeholder = 'Year';
            c3.appendChild(y);

            var c4  = document.createElement('div'); c4.className = 'col-md-2';
            var btn = document.createElement('button');
            btn.type = 'button'; btn.className = 'btn btn-sm btn-outline-danger remove-degree-row w-100';
            btn.textContent = 'Remove';
            btn.addEventListener('click', function () {
                row.remove();
                /* reindex */
                var rows = container.querySelectorAll('.degree-row');
                rows.forEach(function (r, ri) {
                    var nn = r.querySelector('[data-field=deg_name]');
                    var uu = r.querySelector('[data-field=deg_univ]');
                    var yy = r.querySelector('[data-field=deg_year]');
                    if (nn) nn.name = prefix + '_deg_name_' + ri;
                    if (uu) uu.name = prefix + '_deg_univ_' + ri;
                    if (yy) yy.name = prefix + '_deg_year_' + ri;
                });
                countInput.value = rows.length;
                updateComposite(prefix);
            });
            c4.appendChild(btn);

            row.appendChild(c1); row.appendChild(c2); row.appendChild(c3); row.appendChild(c4);
            container.appendChild(row);
            countInput.value = idx + 1;
        });

        /* Bind existing name inputs for composite update */
        prefixes.forEach(function (prefix) {
            initDegreePanel(prefix);
            var container = document.getElementById(prefix + '_degreesContainer');
            if (container) {
                container.querySelectorAll('[data-field=deg_name]').forEach(function (inp) {
                    inp.addEventListener('input', function () { updateComposite(prefix); });
                });
            }
        });
    });
    </script>

    <script>
    (function () {
        var sw    = document.getElementById('activeSwitch');
        var label = document.getElementById('activeSwitchLabel');
        if (!sw) return;

        sw.addEventListener('change', function () {
            var newActive = sw.checked ? 1 : 0;
            var userID    = sw.dataset.userid;
            sw.disabled   = true;

            var body = new URLSearchParams();
            body.append('userID', userID);
            body.append('active', newActive);

            fetch('/admin/users/toggleActive.cfm', {
                method:      'POST',
                headers:     { 'Content-Type': 'application/x-www-form-urlencoded' },
                credentials: 'same-origin',
                body:        body.toString()
            })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                if (data.success) {
                    label.textContent = data.active ? 'Active' : 'Inactive';
                } else {
                    // Revert the toggle on failure
                    sw.checked = !sw.checked;
                    alert('Could not update status: ' + (data.message || 'Unknown error'));
                }
            })
            .catch(function () {
                sw.checked = !sw.checked;
                alert('Network error — status not saved.');
            })
            .finally(function () {
                sw.disabled = false;
            });
        });
    })();
    </script>
"  />

<!--- ── Data Quality Exclusions panel ── --->
<cfsavecontent variable="local.dqPanel">
<cfoutput>
<div class='card mt-4 border-warning'>
    <div class='card-header bg-warning bg-opacity-10 d-flex align-items-center justify-content-between'>
        <strong><i class='bi bi-funnel'></i> Data Quality Report Exclusions</strong>
        <span class='text-muted small'>Checked = included in report &nbsp;|&nbsp; Unchecked = excluded</span>
    </div>
    <div class='card-body'>
        <p class='text-muted small mb-3'>Uncheck any item to exclude this user from that specific data quality check.</p>
        <form method='POST' action='/admin/users/saveDQExclusions.cfm'>
            <input type='hidden' name='UserID'   value='#user.USERID#'>
            <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(returnTo)#'>
            <div class='row g-2'>
</cfoutput>
<cfloop array="#dqAllCodes#" item="dqItem">
    <cfset isExcluded = structKeyExists(dqExclusionMap, dqItem.code)>
    <cfoutput>
    <div class='col-sm-6 col-md-4'>
        <div class='form-check'>
            <input class='form-check-input' type='checkbox'
                   name='dqInclude' value='#dqItem.code#'
                   id='dq_#dqItem.code#'
                   #isExcluded ? '' : 'checked'#>
            <label class='form-check-label small' for='dq_#dqItem.code#'>
                #dqItem.label#
            </label>
        </div>
    </div>
    </cfoutput>
</cfloop>
<cfoutput>
            </div>
            <div class='mt-3'>
                <button type='submit' class='btn btn-warning btn-sm'>
                    <i class='bi bi-save'></i> Save Exclusions
                </button>
            </div>
        </form>
    </div>
</div>
</cfoutput>
</cfsavecontent>
<cfset content &= local.dqPanel>

<cfset ViewContent = "">
<cfset ViewContent &= "
<h1>#user.FIRSTNAME# #user.LASTNAME#</h1>

">

<!--- ── Quill.js WYSIWYG for Bio tab ── --->
<cfsavecontent variable="pageScripts">
<link href="https://cdn.jsdelivr.net/npm/quill@2/dist/quill.snow.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/quill@2/dist/quill.js"></script>
<script>
document.addEventListener('DOMContentLoaded', function () {
    var editorEl = document.getElementById('bio-editor');
    if (!editorEl) return;

    var quill = new Quill('#bio-editor', {
        theme: 'snow',
        placeholder: 'Write a short bio...',
        modules: {
            toolbar: [
                ['bold', 'italic'],
                ['link'],
                [{ list: 'ordered' }, { list: 'bullet' }],
                ['clean']
            ],
            clipboard: { matchVisual: false }
        }
    });

    /* ── Paste as plain text ── */
    var Delta = Quill.import('delta');
    quill.clipboard.addMatcher(Node.ELEMENT_NODE, function (node, delta) {
        var plaintext = node.textContent || '';
        return new Delta().insert(plaintext);
    });

    /* ── Quill editor initialized; no form sync needed (AJAX save reads from .ql-editor directly) ── */
});
</script>

<!--- ── Email Modal ── --->
<div class="modal fade" id="emailModal" tabindex="-1" aria-labelledby="emailModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="emailModalLabel">Add Email</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="emailEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Email Address</label>
                    <input class="form-control" type="email" id="emailAddr">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="emailType">
                        <option value="">-- Type --</option>
                        <option value="@Central">@Central</option>
                        <option value="@CougarNet">@CougarNet</option>
                        <option value="Personal">Personal</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="emailPrimaryChk">
                    <label class="form-check-label">Primary</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="saveEmailModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Phone Modal ── --->
<div class="modal fade" id="phoneModal" tabindex="-1" aria-labelledby="phoneModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="phoneModalLabel">Add Phone</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="phoneEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Phone Number</label>
                    <input class="form-control" type="text" id="phoneNumber">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="phoneType">
                        <option value="">-- Type --</option>
                        <option value="Business">Business</option>
                        <option value="Personal">Personal</option>
                    </select>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="phonePrimaryChk">
                    <label class="form-check-label">Primary</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="savePhoneModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Alias Modal ── --->
<div class="modal fade" id="aliasModal" tabindex="-1" aria-labelledby="aliasModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="aliasModalLabel">Add Alias</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="aliasEditIdx" value="-1">
                <div class="row mb-3">
                    <div class="col-md-4">
                        <label class="form-label">First Name</label>
                        <input class="form-control" id="aliasFirst">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Middle Name</label>
                        <input class="form-control" id="aliasMiddle">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Last Name</label>
                        <input class="form-control" id="aliasLast">
                    </div>
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="aliasType"></select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Source System</label>
                    <input class="form-control" id="aliasSource">
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="aliasActive" checked>
                    <label class="form-check-label">Active</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="saveAliasModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Degree Modal ── --->
<div class="modal fade" id="degreeModal" tabindex="-1" aria-labelledby="degreeModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="degreeModalLabel">Add Degree</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="degreeEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Degree Name</label>
                    <input class="form-control" id="degreeName">
                </div>
                <div class="mb-3">
                    <label class="form-label">University</label>
                    <input class="form-control" id="degreeUniversity">
                </div>
                <div class="mb-3">
                    <label class="form-label">Year</label>
                    <input class="form-control" id="degreeYear">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="saveDegreeModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Award Modal ── --->
<div class="modal fade" id="awardModal" tabindex="-1" aria-labelledby="awardModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-sm">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="awardModalLabel">Add Award</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="awardEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Award</label>
                    <select class="form-select" id="awardSelect">
                        <option value="">-- Select --</option>
                        <option value="Gold Key">Gold Key</option>
                        <option value="Summa cum laude">Summa cum laude</option>
                        <option value="Magna cum laude">Magna cum laude</option>
                        <option value="BSK Gold">BSK Gold</option>
                        <option value="BSK Black &amp; Gold">BSK Black &amp; Gold</option>
                        <option value="AOSA Honors">AOSA Honors</option>
                        <option value="NOSA Honors">NOSA Honors</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="mb-3 d-none" id="awardOtherWrap">
                    <label class="form-label">Specify Award</label>
                    <input class="form-control" id="awardOtherInput">
                </div>
                <div class="mb-3">
                    <label class="form-label">Type</label>
                    <select class="form-select" id="awardType">
                        <option value="">-- Type --</option>
                        <option value="Honor">Honor</option>
                        <option value="Award">Award</option>
                    </select>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="saveAwardModalBtn">Save</button>
            </div>
        </div>
    </div>
</div>

<!--- ── Address Modal ── --->
<div class="modal fade" id="addressModal" tabindex="-1" aria-labelledby="addressModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="addressModalLabel">Add Address</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <input type="hidden" id="addrEditIdx" value="-1">
                <div class="mb-3">
                    <label class="form-label">Address Type</label>
                    <select class="form-select" id="addrType">
                        <option value="">-- Select --</option>
                        <option value="Office">Office</option>
                        <option value="Home">Home</option>
                        <option value="Hometown">Hometown</option>
                        <option value="Other">Other</option>
                    </select>
                </div>
                <div class="mb-3">
                    <label class="form-label">Address Line 1</label>
                    <input class="form-control" id="addrAddr1">
                </div>
                <div class="mb-3">
                    <label class="form-label">Address Line 2</label>
                    <input class="form-control" id="addrAddr2">
                </div>
                <div class="row mb-3">
                    <div class="col-md-5">
                        <label class="form-label">City</label>
                        <input class="form-control" id="addrCity">
                    </div>
                    <div class="col-md-3">
                        <label class="form-label">State</label>
                        <input class="form-control" id="addrState">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Zipcode</label>
                        <input class="form-control" id="addrZip">
                    </div>
                </div>
                <div class="row mb-3">
                    <div class="col-md-4">
                        <label class="form-label">Building</label>
                        <input class="form-control" id="addrBuilding">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Room</label>
                        <input class="form-control" id="addrRoom">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label">Mail Code</label>
                        <input class="form-control" id="addrMailcode">
                    </div>
                </div>
                <div class="form-check">
                    <input class="form-check-input" type="checkbox" id="addrPrimary">
                    <label class="form-check-label">Primary Address</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <button type="button" class="btn btn-primary" id="saveAddressBtn">Save Address</button>
                <button type="button" class="btn btn-success d-none" id="saveAddressToDbBtn">Save to Database</button>
            </div>
        </div>
    </div>
</div>

<script>
/* ══════════════════════════════════════════════════════════
   Modal + AJAX CRUD for all repeating sections
   Each section: cards (display) + hidden inputs (data) + modal (edit) + AJAX save
   ══════════════════════════════════════════════════════════ */
document.addEventListener('DOMContentLoaded', function () {

    /* ── Helper: AJAX save a section ── */
    function ajaxSave(section, body, statusEl, onSuccess) {
        statusEl.textContent = 'Saving...';
        statusEl.className = 'text-muted small ms-2';
        fetch('/admin/users/saveSection.cfm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            credentials: 'same-origin',
            body: body.toString()
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (data.success) {
                statusEl.textContent = 'Saved!';
                statusEl.className = 'text-success small ms-2';
                if (onSuccess) onSuccess(data);
            } else {
                statusEl.textContent = 'Error: ' + (data.message || 'Unknown');
                statusEl.className = 'text-danger small ms-2';
            }
            setTimeout(function () { statusEl.textContent = ''; }, 3000);
        })
        .catch(function () {
            statusEl.textContent = 'Network error';
            statusEl.className = 'text-danger small ms-2';
            setTimeout(function () { statusEl.textContent = ''; }, 3000);
        });
    }

    function esc(v) { return (v || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/'/g,'&#39;').replace(/"/g,'&quot;'); }

    /* ────────────────────────────────────────────────────────
       EMAIL SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('emailsContainer');
        if (!container) return;
        var modalEl = document.getElementById('emailModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-email-field="addr"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-email-idx');
                items.push({
                    addr: el.value,
                    type: (container.querySelector('input[data-email-field="type"][data-email-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-email-field="primary"][data-email-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.addr) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-email-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-email-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-email-field='addr' data-email-idx='" + i + "' value='" + esc(d.addr) + "'>" +
                    "<input type='hidden' data-email-field='type' data-email-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-email-field='primary' data-email-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('emailEditIdx').value = '-1';
            document.getElementById('emailAddr').value = '';
            document.getElementById('emailType').value = '';
            document.getElementById('emailPrimaryChk').checked = false;
            document.getElementById('emailModalLabel').textContent = 'Add Email';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('emailEditIdx').value = idx;
            document.getElementById('emailAddr').value = d.addr;
            document.getElementById('emailType').value = d.type;
            document.getElementById('emailPrimaryChk').checked = d.primary === '1';
            document.getElementById('emailModalLabel').textContent = 'Edit Email';
        }

        function readModal() {
            return {
                addr: document.getElementById('emailAddr').value.trim(),
                type: document.getElementById('emailType').value,
                primary: document.getElementById('emailPrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addEmailBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveEmailModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.addr) { alert('Email address is required.'); return; }
            if (/@uh\.edu\s*$/i.test(d.addr)) { alert('@uh.edu addresses cannot be added here.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('emailEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-email-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-email-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('saveEmailsBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'emails');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('addr_' + i, d.addr);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = document.getElementById('saveEmailsBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('saveEmailsBtn').parentNode.appendChild(status); }
            ajaxSave('emails', body, status);
        });
    })();

    /* ────────────────────────────────────────────────────────
       PHONE SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('phonesContainer');
        if (!container) return;
        var modalEl = document.getElementById('phoneModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-phone-field="number"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-phone-idx');
                items.push({
                    number: el.value,
                    type: (container.querySelector('input[data-phone-field="type"][data-phone-idx="'+idx+'"]') || {}).value || '',
                    primary: (container.querySelector('input[data-phone-field="primary"][data-phone-idx="'+idx+'"]') || {}).value || '0'
                });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.number) + "</strong>" +
                    (d.type ? " <span class='badge bg-secondary'>" + esc(d.type) + "</span>" : "") +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-phone-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-phone-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-phone-field='number' data-phone-idx='" + i + "' value='" + esc(d.number) + "'>" +
                    "<input type='hidden' data-phone-field='type' data-phone-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-phone-field='primary' data-phone-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('phoneEditIdx').value = '-1';
            document.getElementById('phoneNumber').value = '';
            document.getElementById('phoneType').value = '';
            document.getElementById('phonePrimaryChk').checked = false;
            document.getElementById('phoneModalLabel').textContent = 'Add Phone';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('phoneEditIdx').value = idx;
            document.getElementById('phoneNumber').value = d.number;
            document.getElementById('phoneType').value = d.type;
            document.getElementById('phonePrimaryChk').checked = d.primary === '1';
            document.getElementById('phoneModalLabel').textContent = 'Edit Phone';
        }

        function readModal() {
            return {
                number: document.getElementById('phoneNumber').value.trim(),
                type: document.getElementById('phoneType').value,
                primary: document.getElementById('phonePrimaryChk').checked ? '1' : '0'
            };
        }

        document.getElementById('addPhoneBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('savePhoneModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.number) { alert('Phone number is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('phoneEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-phone-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-phone-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('savePhonesBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'phones');
            body.append('count', items.length);
            var primaryIdx = -1;
            items.forEach(function (d, i) {
                body.append('number_' + i, d.number);
                body.append('type_' + i, d.type);
                if (d.primary === '1') primaryIdx = i;
            });
            body.append('primary_idx', primaryIdx);
            var status = document.getElementById('savePhonesBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('savePhonesBtn').parentNode.appendChild(status); }
            ajaxSave('phones', body, status);
        });
    })();

    /* ────────────────────────────────────────────────────────
       ALIAS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('aliasesContainer');
        if (!container) return;
        var modalEl = document.getElementById('aliasModal');
        var modal = new bootstrap.Modal(modalEl);

        /* Populate alias type select from global vars set by CF */
        var typeSel = document.getElementById('aliasType');
        if (typeof aliasTypeOptions !== 'undefined') {
            for (var ti = 0; ti < aliasTypeOptions.length; ti++) {
                var opt = document.createElement('option');
                opt.value = aliasTypeOptions[ti];
                opt.textContent = aliasTypeLabels[ti];
                typeSel.appendChild(opt);
            }
        }

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-alias-field="first"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-alias-idx');
                var get = function(f) { return (container.querySelector('input[data-alias-field="'+f+'"][data-alias-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ first: el.value, middle: get('middle'), last: get('last'), type: get('type'), source: get('source'), active: get('active') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var name = [d.first, d.middle, d.last].filter(Boolean).join(' ');
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    (d.source ? " <small class='text-muted'>(" + esc(d.source) + ")</small>" : "") +
                    (d.active === '1' ? " <span class='badge bg-success'>Active</span>" : " <span class='badge bg-secondary'>Inactive</span>") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-alias-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-alias-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-alias-field='first' data-alias-idx='" + i + "' value='" + esc(d.first) + "'>" +
                    "<input type='hidden' data-alias-field='middle' data-alias-idx='" + i + "' value='" + esc(d.middle) + "'>" +
                    "<input type='hidden' data-alias-field='last' data-alias-idx='" + i + "' value='" + esc(d.last) + "'>" +
                    "<input type='hidden' data-alias-field='type' data-alias-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-alias-field='source' data-alias-idx='" + i + "' value='" + esc(d.source) + "'>" +
                    "<input type='hidden' data-alias-field='active' data-alias-idx='" + i + "' value='" + (d.active || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('aliasEditIdx').value = '-1';
            document.getElementById('aliasFirst').value = '';
            document.getElementById('aliasMiddle').value = '';
            document.getElementById('aliasLast').value = '';
            document.getElementById('aliasType').value = '';
            document.getElementById('aliasSource').value = '';
            document.getElementById('aliasActive').checked = true;
            document.getElementById('aliasModalLabel').textContent = 'Add Alias';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('aliasEditIdx').value = idx;
            document.getElementById('aliasFirst').value = d.first;
            document.getElementById('aliasMiddle').value = d.middle;
            document.getElementById('aliasLast').value = d.last;
            document.getElementById('aliasType').value = d.type;
            document.getElementById('aliasSource').value = d.source;
            document.getElementById('aliasActive').checked = d.active === '1';
            document.getElementById('aliasModalLabel').textContent = 'Edit Alias';
        }

        function readModal() {
            return {
                first: document.getElementById('aliasFirst').value.trim(),
                middle: document.getElementById('aliasMiddle').value.trim(),
                last: document.getElementById('aliasLast').value.trim(),
                type: document.getElementById('aliasType').value,
                source: document.getElementById('aliasSource').value.trim(),
                active: document.getElementById('aliasActive').checked ? '1' : '0'
            };
        }

        document.getElementById('addAliasBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAliasModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.first && !d.last) { alert('First or Last name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('aliasEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-alias-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-alias-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('saveAliasesBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'aliases');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('first_' + i, d.first);
                body.append('middle_' + i, d.middle);
                body.append('last_' + i, d.last);
                body.append('type_' + i, d.type);
                body.append('source_' + i, d.source);
                body.append('active_' + i, d.active);
            });
            var status = document.getElementById('saveAliasesBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('saveAliasesBtn').parentNode.appendChild(status); }
            ajaxSave('aliases', body, status);
        });
    })();

    /* ────────────────────────────────────────────────────────
       DEGREE SECTION (Bio tab)
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('degreesContainer');
        if (!container) return;
        var modalEl = document.getElementById('degreeModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-degree-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-degree-idx');
                var get = function(f) { return (container.querySelector('input[data-degree-field="'+f+'"][data-degree-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ name: el.value, university: get('university'), year: get('year') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.university ? " <small class='text-muted'>— " + esc(d.university) + "</small>" : "") +
                    (d.year ? " <small class='text-muted'>(" + esc(d.year) + ")</small>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-degree-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-degree-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-degree-field='name' data-degree-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-degree-field='university' data-degree-idx='" + i + "' value='" + esc(d.university) + "'>" +
                    "<input type='hidden' data-degree-field='year' data-degree-idx='" + i + "' value='" + esc(d.year) + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('degreeEditIdx').value = '-1';
            document.getElementById('degreeName').value = '';
            document.getElementById('degreeUniversity').value = '';
            document.getElementById('degreeYear').value = '';
            document.getElementById('degreeModalLabel').textContent = 'Add Degree';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('degreeEditIdx').value = idx;
            document.getElementById('degreeName').value = d.name;
            document.getElementById('degreeUniversity').value = d.university;
            document.getElementById('degreeYear').value = d.year;
            document.getElementById('degreeModalLabel').textContent = 'Edit Degree';
        }

        function readModal() {
            return {
                name: document.getElementById('degreeName').value.trim(),
                university: document.getElementById('degreeUniversity').value.trim(),
                year: document.getElementById('degreeYear').value.trim()
            };
        }

        document.getElementById('addDegreeBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveDegreeModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { alert('Degree name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('degreeEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-degree-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-degree-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('saveDegreesBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'degrees');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('univ_' + i, d.university);
                body.append('year_' + i, d.year);
            });
            var status = document.getElementById('saveDegreesBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('saveDegreesBtn').parentNode.appendChild(status); }
            ajaxSave('degrees', body, status, function (data) {
                /* Update composite degrees field if present */
                var comp = document.getElementById('compositeDegreesField');
                if (comp && data.composite) comp.value = data.composite;
            });
        });
    })();

    /* ────────────────────────────────────────────────────────
       AWARD SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('awardsContainer');
        if (!container) return;
        var modalEl = document.getElementById('awardModal');
        var modal = new bootstrap.Modal(modalEl);

        var awardSel = document.getElementById('awardSelect');
        var otherWrap = document.getElementById('awardOtherWrap');
        awardSel.addEventListener('change', function () {
            if (awardSel.value === 'Other') { otherWrap.classList.remove('d-none'); } else { otherWrap.classList.add('d-none'); document.getElementById('awardOtherInput').value = ''; }
            /* Auto-set type for predefined honors */
            if (typeof honorsSet !== 'undefined' && honorsSet[awardSel.value]) { document.getElementById('awardType').value = 'Honor'; }
        });

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-award-field="name"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-award-idx');
                var get = function(f) { return (container.querySelector('input[data-award-field="'+f+'"][data-award-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ name: el.value, type: get('type') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-center'><div>" +
                    "<strong>" + esc(d.name) + "</strong>" +
                    (d.type ? " <span class='badge bg-info text-dark'>" + esc(d.type) + "</span>" : "") +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-award-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-award-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-award-field='name' data-award-idx='" + i + "' value='" + esc(d.name) + "'>" +
                    "<input type='hidden' data-award-field='type' data-award-idx='" + i + "' value='" + esc(d.type) + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('awardEditIdx').value = '-1';
            document.getElementById('awardSelect').value = '';
            document.getElementById('awardOtherInput').value = '';
            otherWrap.classList.add('d-none');
            document.getElementById('awardType').value = '';
            document.getElementById('awardModalLabel').textContent = 'Add Award';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('awardEditIdx').value = idx;
            /* Check if name matches a predefined option */
            var opts = awardSel.options;
            var found = false;
            for (var oi = 0; oi < opts.length; oi++) {
                if (opts[oi].value === d.name) { found = true; break; }
            }
            if (found) {
                awardSel.value = d.name;
                otherWrap.classList.add('d-none');
            } else {
                awardSel.value = 'Other';
                otherWrap.classList.remove('d-none');
                document.getElementById('awardOtherInput').value = d.name;
            }
            document.getElementById('awardType').value = d.type;
            document.getElementById('awardModalLabel').textContent = 'Edit Award';
        }

        function readModal() {
            var name = awardSel.value === 'Other' ? document.getElementById('awardOtherInput').value.trim() : awardSel.value;
            return { name: name, type: document.getElementById('awardType').value };
        }

        document.getElementById('addAwardBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAwardModalBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.name) { alert('Award name is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('awardEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-award-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-award-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('saveAwardsBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'awards');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('name_' + i, d.name);
                body.append('type_' + i, d.type);
            });
            var status = document.getElementById('saveAwardsBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('saveAwardsBtn').parentNode.appendChild(status); }
            ajaxSave('awards', body, status);
        });
    })();

    /* ────────────────────────────────────────────────────────
       ADDRESS SECTION
       ──────────────────────────────────────────────────────── */
    (function () {
        var container = document.getElementById('addressesContainer');
        if (!container) return;
        var modalEl = document.getElementById('addressModal');
        var modal = new bootstrap.Modal(modalEl);

        function getAllData() {
            var items = [];
            var hiddens = container.querySelectorAll('input[data-addr-field="type"]');
            hiddens.forEach(function (el) {
                var idx = el.getAttribute('data-addr-idx');
                var get = function(f) { return (container.querySelector('input[data-addr-field="'+f+'"][data-addr-idx="'+idx+'"]') || {}).value || ''; };
                items.push({ type: el.value, addr1: get('addr1'), addr2: get('addr2'), city: get('city'),
                             state: get('state'), zip: get('zip'), building: get('building'), room: get('room'),
                             mailcode: get('mailcode'), primary: get('primary') });
            });
            return items;
        }

        function rebuild(items) {
            container.innerHTML = '';
            items.forEach(function (d, i) {
                var loc = [];
                if (d.addr1) loc.push(esc(d.addr1));
                if (d.addr2) loc.push(esc(d.addr2));
                var csz = [];
                if (d.city) csz.push(d.city);
                if (d.state) csz.push(d.state);
                var cszStr = csz.join(', ');
                if (d.zip) cszStr += ' ' + d.zip;
                if (cszStr) loc.push(esc(cszStr));
                var extras = [];
                if (d.building) extras.push('Bldg: ' + esc(d.building));
                if (d.room) extras.push('Rm: ' + esc(d.room));
                if (d.mailcode) extras.push('MC: ' + esc(d.mailcode));
                if (extras.length) loc.push(extras.join(' | '));

                container.insertAdjacentHTML('beforeend',
                    "<div class='card mb-2'><div class='card-body py-2 px-3'>" +
                    "<div class='d-flex justify-content-between align-items-start'><div>" +
                    "<strong>" + esc(d.type || '') + "</strong>" +
                    (d.primary === '1' ? " <span class='badge bg-success'>Primary</span>" : "") +
                    "<br><small class='text-muted'>" + loc.join('<br>') + "</small>" +
                    "</div><div>" +
                    "<button type='button' class='btn btn-sm btn-outline-secondary edit-address-btn' data-idx='" + i + "'>Edit</button> " +
                    "<button type='button' class='btn btn-sm btn-outline-danger remove-address-btn' data-idx='" + i + "'>Remove</button>" +
                    "</div></div></div></div>" +
                    "<input type='hidden' data-addr-field='type' data-addr-idx='" + i + "' value='" + esc(d.type) + "'>" +
                    "<input type='hidden' data-addr-field='addr1' data-addr-idx='" + i + "' value='" + esc(d.addr1) + "'>" +
                    "<input type='hidden' data-addr-field='addr2' data-addr-idx='" + i + "' value='" + esc(d.addr2) + "'>" +
                    "<input type='hidden' data-addr-field='city' data-addr-idx='" + i + "' value='" + esc(d.city) + "'>" +
                    "<input type='hidden' data-addr-field='state' data-addr-idx='" + i + "' value='" + esc(d.state) + "'>" +
                    "<input type='hidden' data-addr-field='zip' data-addr-idx='" + i + "' value='" + esc(d.zip) + "'>" +
                    "<input type='hidden' data-addr-field='building' data-addr-idx='" + i + "' value='" + esc(d.building) + "'>" +
                    "<input type='hidden' data-addr-field='room' data-addr-idx='" + i + "' value='" + esc(d.room) + "'>" +
                    "<input type='hidden' data-addr-field='mailcode' data-addr-idx='" + i + "' value='" + esc(d.mailcode) + "'>" +
                    "<input type='hidden' data-addr-field='primary' data-addr-idx='" + i + "' value='" + (d.primary || '0') + "'>"
                );
            });
        }

        function clearModal() {
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = '';
            document.getElementById('addrAddr1').value = '';
            document.getElementById('addrAddr2').value = '';
            document.getElementById('addrCity').value = '';
            document.getElementById('addrState').value = '';
            document.getElementById('addrZip').value = '';
            document.getElementById('addrBuilding').value = '';
            document.getElementById('addrRoom').value = '';
            document.getElementById('addrMailcode').value = '';
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Add Address';
        }

        function fillModal(idx) {
            var items = getAllData();
            var d = items[idx];
            document.getElementById('addrEditIdx').value = idx;
            document.getElementById('addrType').value = d.type;
            document.getElementById('addrAddr1').value = d.addr1;
            document.getElementById('addrAddr2').value = d.addr2;
            document.getElementById('addrCity').value = d.city;
            document.getElementById('addrState').value = d.state;
            document.getElementById('addrZip').value = d.zip;
            document.getElementById('addrBuilding').value = d.building;
            document.getElementById('addrRoom').value = d.room;
            document.getElementById('addrMailcode').value = d.mailcode;
            document.getElementById('addrPrimary').checked = d.primary === '1';
            document.getElementById('addressModalLabel').textContent = 'Edit Address';
        }

        function readModal() {
            return {
                type: document.getElementById('addrType').value,
                addr1: document.getElementById('addrAddr1').value.trim(),
                addr2: document.getElementById('addrAddr2').value.trim(),
                city: document.getElementById('addrCity').value.trim(),
                state: document.getElementById('addrState').value.trim(),
                zip: document.getElementById('addrZip').value.trim(),
                building: document.getElementById('addrBuilding').value.trim(),
                room: document.getElementById('addrRoom').value.trim(),
                mailcode: document.getElementById('addrMailcode').value.trim(),
                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
            };
        }

        /* Expose helpers so the "Copy to Addresses" button on the UH tab can inject a parsed address */
        container._addrGetAllData = getAllData;
        container._addrRebuild = rebuild;

        document.getElementById('addAddressBtn').addEventListener('click', function () { clearModal(); modal.show(); });

        document.getElementById('saveAddressBtn').addEventListener('click', function () {
            var d = readModal();
            if (!d.type) { alert('Address Type is required.'); return; }
            var items = getAllData();
            var editIdx = parseInt(document.getElementById('addrEditIdx').value);
            if (editIdx >= 0) { items[editIdx] = d; } else { items.push(d); }
            rebuild(items);
            modal.hide();
        });

        container.addEventListener('click', function (e) {
            var btn = e.target.closest('.edit-address-btn');
            if (btn) { fillModal(parseInt(btn.dataset.idx)); modal.show(); return; }
            btn = e.target.closest('.remove-address-btn');
            if (btn) { var items = getAllData(); items.splice(parseInt(btn.dataset.idx), 1); rebuild(items); }
        });

        document.getElementById('saveAddressesBtn').addEventListener('click', function () {
            var items = getAllData();
            var body = new URLSearchParams();
            body.append('userID', document.getElementById('pageUserID').value);
            body.append('section', 'addresses');
            body.append('count', items.length);
            items.forEach(function (d, i) {
                body.append('type_' + i, d.type);
                body.append('addr1_' + i, d.addr1);
                body.append('addr2_' + i, d.addr2);
                body.append('city_' + i, d.city);
                body.append('state_' + i, d.state);
                body.append('zip_' + i, d.zip);
                body.append('building_' + i, d.building);
                body.append('room_' + i, d.room);
                body.append('mailcode_' + i, d.mailcode);
                body.append('primary_' + i, d.primary);
            });
            var status = document.getElementById('saveAddressesBtn').parentNode.querySelector('.save-status') || document.createElement('span');
            if (!status.classList.contains('save-status')) { status.className = 'save-status'; document.getElementById('saveAddressesBtn').parentNode.appendChild(status); }
            ajaxSave('addresses', body, status);
        });
    })();

    /* ══════════════════════════════════════════════════════════════
       Per-Tab AJAX Save Handlers
       ══════════════════════════════════════════════════════════════ */

    function saveSectionAjax(section, body, statusEl) {
        statusEl.textContent = 'Saving...';
        statusEl.style.color = '#666';
        fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
            .then(function (r) { return r.json(); })
            .then(function (data) {
                statusEl.textContent = data.message || (data.success ? 'Saved!' : 'Error');
                statusEl.style.color = data.success ? 'green' : 'red';
                setTimeout(function () { statusEl.textContent = ''; }, 3000);
            })
            .catch(function (err) {
                statusEl.textContent = 'Network error: ' + err.message;
                statusEl.style.color = 'red';
            });
    }

    var pageUserID = document.getElementById('pageUserID').value;

    /* ── General tab ── */
    var saveGeneralBtn = document.getElementById('save-general-btn');
    if (saveGeneralBtn) {
        saveGeneralBtn.addEventListener('click', function () {
            var pane = document.getElementById('general-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'general');
            ['Prefix','Suffix','Pronouns','FirstName','MiddleName','LastName','Title1','Title2','Title3'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('general', body, document.getElementById('save-general-status'));
        });
    }

    /* ── Flags tab ── */
    var saveFlagsBtn = document.getElementById('save-flags-btn');
    if (saveFlagsBtn) {
        saveFlagsBtn.addEventListener('click', function () {
            var pane = document.getElementById('flags-pane');
            var checked = pane.querySelectorAll('input[name="Flags"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'flags');
            body.append('flagIDs', ids.join(','));
            saveSectionAjax('flags', body, document.getElementById('save-flags-status'));
        });
    }

    /* ── Organizations tab ── */
    var saveOrgsBtn = document.getElementById('save-orgs-btn');
    if (saveOrgsBtn) {
        saveOrgsBtn.addEventListener('click', function () {
            var pane = document.getElementById('orgs-pane');
            var checked = pane.querySelectorAll('input[name="Organizations"]:checked');
            var ids = [];
            checked.forEach(function (cb) { ids.push(cb.value); });
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'orgs');
            body.append('orgIDs', ids.join(','));
            checked.forEach(function (cb) {
                var orgID = cb.value;
                var titleEl = pane.querySelector('[name="roleTitle_' + orgID + '"]');
                var orderEl = pane.querySelector('[name="roleOrder_' + orgID + '"]');
                body.append('roleTitle_' + orgID, titleEl ? titleEl.value : '');
                body.append('roleOrder_' + orgID, orderEl ? orderEl.value : '0');
            });
            saveSectionAjax('orgs', body, document.getElementById('save-orgs-status'));
        });
    }

    /* ── External IDs tab ── */
    var saveExtidsBtn = document.getElementById('save-extids-btn');
    if (saveExtidsBtn) {
        saveExtidsBtn.addEventListener('click', function () {
            var pane = document.getElementById('extids-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'extids');
            pane.querySelectorAll('input[name^="extID_"]').forEach(function (inp) {
                body.append(inp.name, inp.value);
            });
            saveSectionAjax('extids', body, document.getElementById('save-extids-status'));
        });
    }

    /* ── UH Admin tab (SuperAdmin) ── */
    var saveUhBtn = document.getElementById('save-uh-btn');
    if (saveUhBtn) {
        saveUhBtn.addEventListener('click', function () {
            var pane = document.getElementById('address-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'uh');
            ['EmailPrimary','UH_API_ID','Room','Building','Campus','Division','DivisionName','Department','DepartmentName','Office_Mailing_Address','Mailcode'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            saveSectionAjax('uh', body, document.getElementById('save-uh-status'));
        });
    }

    /* ── Copy Office Mailing Address → Addresses tab ── */
    var copyAddrBtn = document.getElementById('copyToAddressesBtn');
    if (copyAddrBtn) {
        copyAddrBtn.addEventListener('click', function () {
            var raw = (document.getElementById('officeMailingAddress').value || '').trim();
            if (!raw) { alert('Office Mailing Address is empty.'); return; }

            /* Parse: "4349 Martin Luther King Blvd Health 1 RM 230 Houston, TX 77204-2020" */
            var parsed = { type: 'Office', addr1: '', addr2: '', city: '', state: '', zip: '',
                           building: '', room: '', mailcode: '', primary: '0' };

            var work = raw;

            /* Extract Room: RM/Room followed by digits */
            var rmMatch = work.match(/\b(?:RM|Room)\s+(\S+)/i);
            if (rmMatch) {
                parsed.room = rmMatch[1];
                work = work.replace(rmMatch[0], '').trim();
            }

            /* Known addresses and buildings for UHCO campus — match these FIRST
               so that punctuation in building names (e.g. "J. Davis Armistead")
               doesn't confuse the city/state/zip regex. */
            var knownAddresses = [
                { street: '4401 Martin Luther King Blvd', building: 'J. Davis Armistead' },
                { street: '4349 Martin Luther King Blvd', building: 'Health 1' }
            ];
            var matched = false;
            for (var ki = 0; ki < knownAddresses.length; ki++) {
                var ka = knownAddresses[ki];
                if (work.indexOf(ka.street) === 0) {
                    parsed.addr1 = ka.street;
                    var remainder = work.substring(ka.street.length).trim();
                    /* Strip known building name from the front of remainder */
                    if (remainder.indexOf(ka.building) === 0) {
                        parsed.building = ka.building;
                        remainder = remainder.substring(ka.building.length).trim();
                    }
                    /* Whatever is left should be "Houston, TX 77204-2020" */
                    var cszMatch = remainder.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                    if (cszMatch) {
                        parsed.city  = cszMatch[1].trim();
                        parsed.state = cszMatch[2];
                        parsed.zip   = cszMatch[3];
                    } else if (!parsed.building && remainder.length) {
                        /* Couldn't parse city/state — put leftover in building */
                        parsed.building = remainder;
                    }
                    matched = true;
                    break;
                }
            }

            if (!matched) {
                /* Extract City, State ZIP from the end: "Houston, TX 77204-2020" */
                var cszMatch = work.match(/,?\s*([A-Za-z\s]+),\s*([A-Z]{2})\s+(\d{5}(?:-\d{4})?)\s*$/);
                if (cszMatch) {
                    parsed.city  = cszMatch[1].trim();
                    parsed.state = cszMatch[2];
                    parsed.zip   = cszMatch[3];
                    work = work.substring(0, work.length - cszMatch[0].length).trim();
                }
                /* Fallback: split at street suffix */
                var streetEnd = work.search(/\b(Blvd|Boulevard|St|Street|Ave|Avenue|Dr|Drive|Rd|Road|Hwy|Highway|Pkwy|Parkway|Way|Lane|Ln|Circle|Cir)\b\.?\s*/i);
                if (streetEnd >= 0) {
                    var suffixMatch = work.substring(streetEnd).match(/^(\S+\.?)\s*(.*)/);
                    if (suffixMatch) {
                        parsed.addr1 = work.substring(0, streetEnd).trim() + ' ' + suffixMatch[1];
                        parsed.building = (suffixMatch[2] || '').trim();
                    }
                } else {
                    parsed.addr1 = work;
                }
            }

            /* Pull Mailcode from the UH pane if present */
            var mcEl = document.querySelector('[name="Mailcode"]');
            if (mcEl && mcEl.value.trim()) { parsed.mailcode = mcEl.value.trim(); }

            /* Pre-fill the address modal with parsed values for user review */
            document.getElementById('addrEditIdx').value = '-1';
            document.getElementById('addrType').value = parsed.type;
            document.getElementById('addrAddr1').value = parsed.addr1;
            document.getElementById('addrAddr2').value = parsed.addr2;
            document.getElementById('addrCity').value = parsed.city;
            document.getElementById('addrState').value = parsed.state;
            document.getElementById('addrZip').value = parsed.zip;
            document.getElementById('addrBuilding').value = parsed.building;
            document.getElementById('addrRoom').value = parsed.room;
            document.getElementById('addrMailcode').value = parsed.mailcode;
            document.getElementById('addrPrimary').checked = false;
            document.getElementById('addressModalLabel').textContent = 'Review Parsed Address';

            /* Swap buttons: hide the JS-only Save, show the Save to Database button */
            document.getElementById('saveAddressBtn').classList.add('d-none');
            document.getElementById('saveAddressToDbBtn').classList.remove('d-none');

            var addrModal = bootstrap.Modal.getOrCreateInstance(document.getElementById('addressModal'));
            addrModal.show();
        });
    }

    /* Save to Database button — direct AJAX insert for copied addresses */
    var saveToDbBtn = document.getElementById('saveAddressToDbBtn');
    if (saveToDbBtn) {
        saveToDbBtn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'addAddress');
            body.append('type', document.getElementById('addrType').value);
            body.append('addr1', document.getElementById('addrAddr1').value.trim());
            body.append('addr2', document.getElementById('addrAddr2').value.trim());
            body.append('city', document.getElementById('addrCity').value.trim());
            body.append('state', document.getElementById('addrState').value.trim());
            body.append('zip', document.getElementById('addrZip').value.trim());
            body.append('building', document.getElementById('addrBuilding').value.trim());
            body.append('room', document.getElementById('addrRoom').value.trim());
            body.append('mailcode', document.getElementById('addrMailcode').value.trim());
            body.append('primary', document.getElementById('addrPrimary').checked ? '1' : '0');

            saveToDbBtn.disabled = true;
            saveToDbBtn.textContent = 'Saving...';

            fetch('/admin/users/saveSection.cfm', { method: 'POST', body: body })
                .then(function (r) { return r.json(); })
                .then(function (data) {
                    if (data.success) {
                        /* Add the new address card to the Contact tab via exposed helpers */
                        var addrContainer = document.getElementById('addressesContainer');
                        if (addrContainer && addrContainer._addrGetAllData && addrContainer._addrRebuild) {
                            var items = addrContainer._addrGetAllData();
                            items.push({
                                type: document.getElementById('addrType').value,
                                addr1: document.getElementById('addrAddr1').value.trim(),
                                addr2: document.getElementById('addrAddr2').value.trim(),
                                city: document.getElementById('addrCity').value.trim(),
                                state: document.getElementById('addrState').value.trim(),
                                zip: document.getElementById('addrZip').value.trim(),
                                building: document.getElementById('addrBuilding').value.trim(),
                                room: document.getElementById('addrRoom').value.trim(),
                                mailcode: document.getElementById('addrMailcode').value.trim(),
                                primary: document.getElementById('addrPrimary').checked ? '1' : '0'
                            });
                            addrContainer._addrRebuild(items);
                        }
                        bootstrap.Modal.getInstance(document.getElementById('addressModal')).hide();
                    } else {
                        alert('Error: ' + (data.message || 'Save failed.'));
                    }
                })
                .catch(function (err) { alert('Network error: ' + err.message); })
                .finally(function () {
                    saveToDbBtn.disabled = false;
                    saveToDbBtn.textContent = 'Save to Database';
                });
        });
    }

    /* Reset address modal buttons when closed */
    var addrModalEl = document.getElementById('addressModal');
    if (addrModalEl) {
        addrModalEl.addEventListener('hidden.bs.modal', function () {
            document.getElementById('saveAddressBtn').classList.remove('d-none');
            document.getElementById('saveAddressToDbBtn').classList.add('d-none');
        });
    }

    /* ── Biographical Info tab (DOB, Gender) ── */
    var saveBioinfoBtn = document.getElementById('save-bioinfo-btn');
    if (saveBioinfoBtn) {
        saveBioinfoBtn.addEventListener('click', function () {
            var pane = document.getElementById('bio-info-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'bioinfo');
            var dobEl = pane.querySelector('[name="DOB"]');
            var genEl = pane.querySelector('[name="Gender"]');
            body.append('DOB', dobEl ? dobEl.value : '');
            body.append('Gender', genEl ? genEl.value : '');
            saveSectionAjax('bioinfo', body, document.getElementById('save-bioinfo-status'));
        });
    }

    /* ── Student Profile tab ── */
    var saveStudentBtn = document.getElementById('save-studentprofile-btn');
    if (saveStudentBtn) {
        saveStudentBtn.addEventListener('click', function () {
            var pane = document.getElementById('student-profile-pane');
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'studentprofile');
            ['CurrentGradYear','OriginalGradYear','sp_first_externship','sp_second_externship','sp_commencement_age'].forEach(function (f) {
                var el = pane.querySelector('[name="' + f + '"]');
                body.append(f, el ? el.value : '');
            });
            /* sp degrees */
            var countEl = pane.querySelector('[id="sp_degreeCount"]');
            var spCount = countEl ? parseInt(countEl.value, 10) || 0 : 0;
            body.append('sp_degree_count', spCount);
            for (var i = 0; i < spCount; i++) {
                var n = pane.querySelector('[name="sp_deg_name_' + i + '"]');
                var u = pane.querySelector('[name="sp_deg_univ_' + i + '"]');
                var y = pane.querySelector('[name="sp_deg_year_' + i + '"]');
                body.append('sp_deg_name_' + i, n ? n.value : '');
                body.append('sp_deg_univ_' + i, u ? u.value : '');
                body.append('sp_deg_year_' + i, y ? y.value : '');
            }
            saveSectionAjax('studentprofile', body, document.getElementById('save-studentprofile-status'));
        });
    }

    /* ── Faculty / Emeritus / Resident degree tabs ── */
    function setupDegreeTabSave(btnId, statusId, prefix) {
        var btn = document.getElementById(btnId);
        if (!btn) return;
        btn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'tabdegrees');
            body.append('prefix', prefix);
            var countEl = document.getElementById(prefix + '_degreeCount');
            var count = countEl ? parseInt(countEl.value, 10) || 0 : 0;
            body.append(prefix + '_degree_count', count);
            for (var i = 0; i < count; i++) {
                var n = document.querySelector('[name="' + prefix + '_deg_name_' + i + '"]');
                var u = document.querySelector('[name="' + prefix + '_deg_univ_' + i + '"]');
                var y = document.querySelector('[name="' + prefix + '_deg_year_' + i + '"]');
                body.append(prefix + '_deg_name_' + i, n ? n.value : '');
                body.append(prefix + '_deg_univ_' + i, u ? u.value : '');
                body.append(prefix + '_deg_year_' + i, y ? y.value : '');
            }
            saveSectionAjax('tabdegrees', body, document.getElementById(statusId));
        });
    }
    setupDegreeTabSave('save-facultydeg-btn', 'save-facultydeg-status', 'fac');
    setupDegreeTabSave('save-emeritusdeg-btn', 'save-emeritusdeg-status', 'emer');
    setupDegreeTabSave('save-residentdeg-btn', 'save-residentdeg-status', 'res');

    /* ── Bio tab ── */
    var saveBioBtn = document.getElementById('save-bio-btn');
    if (saveBioBtn) {
        saveBioBtn.addEventListener('click', function () {
            var body = new URLSearchParams();
            body.append('userID', pageUserID);
            body.append('section', 'bio');
            var editorEl = document.getElementById('bio-editor');
            var html = editorEl ? editorEl.querySelector('.ql-editor').innerHTML : '';
            if (html === '<p><br></p>') html = '';
            body.append('bioContent', html);
            saveSectionAjax('bio', body, document.getElementById('save-bio-status'));
        });
    }

});
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">