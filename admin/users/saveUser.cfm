<cfset usersService = createObject("component", "dir.cfc.users_service").init()>
<cfset flagsService = createObject("component", "dir.cfc.flags_service").init()>
<cfset organizationsService = createObject("component", "dir.cfc.organizations_service").init()>

<!--- Map form data to userData with correct CamelCase naming for DAO SQL parameters --->
<cfset userData = {}>
<cfset userData.FirstName = form.FIRSTNAME>
<cfset userData.MiddleName = structKeyExists(form, "MIDDLENAME") ? form.MIDDLENAME : "">
<cfset userData.LastName = form.LASTNAME>
<cfset userData.PreferredName = structKeyExists(form, "PREFERREDNAME") ? form.PREFERREDNAME : "">
<cfset userData.Pronouns = structKeyExists(form, "PRONOUNS") ? form.PRONOUNS : "">
<cfset userData.EmailPrimary = form.EMAILPRIMARY>
<cfset userData.EmailSecondary = structKeyExists(form, "EMAILSECONDARY") ? form.EMAILSECONDARY : "">
<cfset userData.Phone = structKeyExists(form, "PHONE") ? form.PHONE : "">
<cfset userData.Room = structKeyExists(form, "ROOM") ? form.ROOM : "">
<cfset userData.Building = structKeyExists(form, "BUILDING") ? form.BUILDING : "">
<cfset userData.Title1 = structKeyExists(form, "TITLE1") ? form.TITLE1 : "">
<cfset userData.Title2 = structKeyExists(form, "TITLE2") ? form.TITLE2 : "">
<cfset userData.Title3 = structKeyExists(form, "TITLE3") ? form.TITLE3 : "">
<cfset userData.UH_API_ID = structKeyExists(form, "UH_API_ID") ? form.UH_API_ID : "">

<cfif structKeyExists(form, "UserID")>
    <!--- Update user --->
    <cfset result = usersService.updateUser( form.UserID, userData )>
    <cfset userID = form.UserID>
<cfelse>
    <!--- Create user --->
    <cfset result = usersService.createUser( userData )>
    <cfset userID = result.userID>
</cfif>

<cfif result.success>
    <!--- Handle flag assignments --->
    <cfif structKeyExists(form, "Flags")>
        <!--- Get current flags for user --->
        <cfset currentFlagsResult = flagsService.getUserFlags(userID)>
        <cfset currentFlags = currentFlagsResult.data>
        <cfset currentFlagIDs = []>
        <cfloop from="1" to="#arrayLen(currentFlags)#" index="i">
            <cfset arrayAppend(currentFlagIDs, val(currentFlags[i].FLAGID))>
        </cfloop>
        
        <!--- Parse the submitted flags (ColdFusion sends as comma-delimited list) --->
        <cfset submittedFlagIDs = []>
        <cfif isArray(form.Flags)>
            <!--- If it's already an array, process directly --->
            <cfloop from="1" to="#arrayLen(form.Flags)#" index="i">
                <cfset arrayAppend(submittedFlagIDs, val(form.Flags[i]))>
            </cfloop>
        <cfelse>
            <!--- If it's a list string, split by comma --->
            <cfset flagList = listToArray(form.Flags)>
            <cfloop from="1" to="#arrayLen(flagList)#" index="i">
                <cfset arrayAppend(submittedFlagIDs, val(trim(flagList[i])))>
            </cfloop>
        </cfif>
        
        <!--- Remove flags that were unchecked --->
        <cfloop from="1" to="#arrayLen(currentFlagIDs)#" index="i">
            <cfif arrayFindNoCase(submittedFlagIDs, currentFlagIDs[i]) == 0>
                <cfset flagsService.removeFlag(userID, val(currentFlagIDs[i]))>
            </cfif>
        </cfloop>
        
        <!--- Add flags that were checked --->
        <cfloop from="1" to="#arrayLen(submittedFlagIDs)#" index="i">
            <cfif arrayFindNoCase(currentFlagIDs, submittedFlagIDs[i]) == 0>
                <cfset flagsService.addFlag(userID, val(submittedFlagIDs[i]))>
            </cfif>
        </cfloop>
    <cfelse>
        <!--- No flags submitted, remove all existing flags --->
        <cfset currentFlagsResult = flagsService.getUserFlags(userID)>
        <cfset currentFlags = currentFlagsResult.data>
        <cfloop from="1" to="#arrayLen(currentFlags)#" index="i">
            <cfset flagsService.removeFlag(userID, val(currentFlags[i].FLAGID))>
        </cfloop>
    </cfif>

    <!--- Handle organization assignments when org controls are present on the form --->
    <cfif structKeyExists(form, "processOrganizations")>
        <cfset currentOrgsResult = organizationsService.getUserOrgs(userID)>
        <cfset currentOrgs = currentOrgsResult.data>
        <cfset currentOrgIDs = []>
        <cfloop from="1" to="#arrayLen(currentOrgs)#" index="i">
            <cfset arrayAppend(currentOrgIDs, val(currentOrgs[i].ORGID))>
        </cfloop>

        <cfset submittedOrgIDs = []>
        <cfif structKeyExists(form, "Organizations")>
            <cfif isArray(form.Organizations)>
                <cfloop from="1" to="#arrayLen(form.Organizations)#" index="i">
                    <cfset arrayAppend(submittedOrgIDs, val(form.Organizations[i]))>
                </cfloop>
            <cfelse>
                <cfset orgList = listToArray(form.Organizations)>
                <cfloop from="1" to="#arrayLen(orgList)#" index="i">
                    <cfset arrayAppend(submittedOrgIDs, val(trim(orgList[i])))>
                </cfloop>
            </cfif>
        </cfif>

        <cfloop from="1" to="#arrayLen(currentOrgIDs)#" index="i">
            <cfif arrayFindNoCase(submittedOrgIDs, currentOrgIDs[i]) == 0>
                <cfset organizationsService.removeOrg(userID, val(currentOrgIDs[i]))>
            </cfif>
        </cfloop>

        <cfloop from="1" to="#arrayLen(submittedOrgIDs)#" index="i">
            <cfset orgID     = val(submittedOrgIDs[i])>
            <cfset roleTitle = structKeyExists(form, "roleTitle_" & orgID) ? trim(form["roleTitle_" & orgID]) : "">
            <cfset roleOrder = (structKeyExists(form, "roleOrder_" & orgID) AND isNumeric(form["roleOrder_" & orgID])) ? val(form["roleOrder_" & orgID]) : 0>
            <cfif arrayFindNoCase(currentOrgIDs, orgID) == 0>
                <cfset organizationsService.assignOrg(userID, orgID, roleTitle, roleOrder)>
            <cfelse>
                <cfset organizationsService.updateOrgAssignment(userID, orgID, roleTitle, roleOrder)>
            </cfif>
        </cfloop>
    </cfif>

    <!--- Handle external ID assignments --->
    <cfif structKeyExists(form, "processExternalIDs")>
        <cfset externalIDService = createObject("component", "dir.cfc.externalID_service").init()>
        <cfset allSystemsResult = externalIDService.getSystems()>
        <cfset extSystems = allSystemsResult.data>
        <cfloop from="1" to="#arrayLen(extSystems)#" index="i">
            <cfset sys = extSystems[i]>
            <cfset fieldName = "extID_" & sys.SYSTEMID>
            <cfif structKeyExists(form, fieldName) AND len(trim(form[fieldName]))>
                <cfset externalIDService.setExternalID(userID, sys.SYSTEMID, trim(form[fieldName]))>
            </cfif>
        </cfloop>
    </cfif>

    <!--- Handle academic info --->
    <cfif structKeyExists(form, "processAcademicInfo")>
        <cfset academicService = createObject("component", "dir.cfc.academic_service").init()>
        <cfset academicService.saveAcademicInfo(
            userID,
            structKeyExists(form, "CurrentGradYear")  ? trim(form.CurrentGradYear)  : "",
            structKeyExists(form, "OriginalGradYear") ? trim(form.OriginalGradYear) : ""
        )>
    </cfif>
    
    <cflocation url="/dir/admin/users/index.cfm" addtoken="false">
<cfelse>
    <cfoutput><h2>Error: #result.message#</h2></cfoutput>
</cfif>