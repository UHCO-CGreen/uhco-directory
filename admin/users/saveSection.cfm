<cfsetting showdebugoutput="false">
<cfcontent type="application/json">

<cfif NOT request.hasPermission("users.edit")>
    <cfoutput>{"success":false,"message":"Unauthorized: users.edit permission required."}</cfoutput><cfabort>
</cfif>

<cfif NOT structKeyExists(form, "userID") OR NOT isNumeric(form.userID)>
    <cfoutput>{"success":false,"message":"Missing userID."}</cfoutput><cfabort>
</cfif>
<cfif NOT structKeyExists(form, "section")>
    <cfoutput>{"success":false,"message":"Missing section."}</cfoutput><cfabort>
</cfif>

<cfset userID = val(form.userID)>
<cfset section = lCase(trim(form.section))>

<cffunction name="getFieldValue" access="private" returntype="string" output="false">
    <cfargument name="value" required="true">
    <cfif isStruct(arguments.value) AND structKeyExists(arguments.value, "value")>
        <cfreturn trim(arguments.value.value ?: "")>
    </cfif>
    <cfreturn trim(arguments.value ?: "")>
</cffunction>

<cffunction name="isStudentHometownSyncUser" access="private" returntype="boolean" output="false">
    <cfargument name="userID" type="numeric" required="true">
    <cfset var flagsService = createObject("component", "cfc.flags_service").init()>
    <cfset var userFlags = flagsService.getUserFlags(arguments.userID).data>
    <cfset var userFlag = {}>
    <cfloop array="#userFlags#" index="userFlag">
        <cfif listFindNoCase("current-student,current student,alumni", trim(userFlag.FLAGNAME ?: "")) GT 0>
            <cfreturn true>
        </cfif>
    </cfloop>
    <cfreturn false>
</cffunction>

<cffunction name="syncStudentProfileHometownFromAddresses" access="private" returntype="void" output="false">
    <cfargument name="userID" type="numeric" required="true">
    <cfargument name="addresses" type="array" required="true">
    <cfset var studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
    <cfset var addressRow = {}>
    <cfset var hometownCity = "">
    <cfset var hometownState = "">

    <cfif NOT isStudentHometownSyncUser(arguments.userID)>
        <cfreturn>
    </cfif>

    <cfloop array="#arguments.addresses#" index="addressRow">
        <cfif compareNoCase(getFieldValue(addressRow.AddressType ?: ""), "Hometown") EQ 0>
            <cfset hometownCity = getFieldValue(addressRow.City ?: "")>
            <cfset hometownState = getFieldValue(addressRow.State ?: "")>
        </cfif>
    </cfloop>

    <cfset studentProfileSvc.syncHometown(arguments.userID, hometownCity, hometownState)>
</cffunction>

<!--- Proper-case helper: "JANE DOE" / "jane doe" → "Jane Doe", handles McX / O'X / hyphens --->
<cffunction name="toProperName" access="private" returntype="string" output="false">
    <cfargument name="input" type="string" required="true">
    <cfset var raw = trim(arguments.input)>
    <cfif NOT len(raw)><cfreturn ""></cfif>
    <cfset var words = listToArray(raw, " ")>
    <cfset var result = []>
    <cfloop array="#words#" index="local.w">
        <cfset var hParts = listToArray(local.w, "-")>
        <cfset var hResult = []>
        <cfloop array="#hParts#" index="local.h">
            <cfset var part = lCase(local.h)>
            <cfif len(part) GT 2 AND left(part, 2) EQ "mc">
                <cfset part = "Mc" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3)>
            <cfelseif len(part) GT 2 AND left(part, 2) EQ "o'">
                <cfset part = "O'" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3)>
            <cfelse>
                <cfset part = uCase(left(part, 1)) & mid(part, 2, len(part) - 1)>
            </cfif>
            <cfset arrayAppend(hResult, part)>
        </cfloop>
        <cfset arrayAppend(result, arrayToList(hResult, "-"))>
    </cfloop>
    <cfreturn arrayToList(result, " ")>
</cffunction>

<!--- Helper: builds a full userData struct from existing record, overlaying only supplied keys --->
<cffunction name="buildUserData" access="private" returntype="struct" output="false">
    <cfargument name="existing" type="struct" required="true">
    <cfargument name="overrides" type="struct" required="false" default="#{}#">
    <cfset var e = arguments.existing>
    <cfset var o = arguments.overrides>
    <cfset var ud = {
        FirstName  = structKeyExists(o, "FirstName")  ? o.FirstName  : (e.FIRSTNAME ?: ""),
        MiddleName = structKeyExists(o, "MiddleName") ? o.MiddleName : (e.MIDDLENAME ?: ""),
        LastName   = structKeyExists(o, "LastName")   ? o.LastName   : (e.LASTNAME ?: ""),
        Prefix     = structKeyExists(o, "Prefix")     ? o.Prefix     : (e.PREFIX ?: ""),
        Suffix     = structKeyExists(o, "Suffix")     ? o.Suffix     : (e.SUFFIX ?: ""),
        Pronouns   = structKeyExists(o, "Pronouns")   ? o.Pronouns   : (e.PRONOUNS ?: ""),
        Title1     = structKeyExists(o, "Title1")     ? o.Title1     : (e.TITLE1 ?: ""),
        Title2     = structKeyExists(o, "Title2")     ? o.Title2     : (e.TITLE2 ?: ""),
        Title3     = structKeyExists(o, "Title3")     ? o.Title3     : (e.TITLE3 ?: ""),
        EmailPrimary = structKeyExists(o, "EmailPrimary") ? o.EmailPrimary : (e.EMAILPRIMARY ?: ""),
        Phone      = structKeyExists(o, "Phone")      ? o.Phone      : (e.PHONE ?: ""),
        Room       = structKeyExists(o, "Room")       ? o.Room       : (e.ROOM ?: ""),
        Building   = structKeyExists(o, "Building")   ? o.Building   : (e.BUILDING ?: ""),
        UH_API_ID  = structKeyExists(o, "UH_API_ID")  ? o.UH_API_ID  : (e.UH_API_ID ?: ""),
        Degrees    = structKeyExists(o, "Degrees")    ? o.Degrees    : (e.DEGREES ?: ""),
        Campus     = structKeyExists(o, "Campus")     ? o.Campus     : (e.CAMPUS ?: ""),
        Division   = structKeyExists(o, "Division")   ? o.Division   : (e.DIVISION ?: ""),
        DivisionName = structKeyExists(o, "DivisionName") ? o.DivisionName : (e.DIVISIONNAME ?: ""),
        Department   = structKeyExists(o, "Department")   ? o.Department   : (e.DEPARTMENT ?: ""),
        DepartmentName = structKeyExists(o, "DepartmentName") ? o.DepartmentName : (e.DEPARTMENTNAME ?: ""),
        Office_Mailing_Address = structKeyExists(o, "Office_Mailing_Address") ? o.Office_Mailing_Address : (e.OFFICE_MAILING_ADDRESS ?: ""),
        Mailcode   = structKeyExists(o, "Mailcode")   ? o.Mailcode   : (e.MAILCODE ?: ""),
        Active     = val(e.ACTIVE ?: 1)
    }>
    <!--- DOB / Gender: use override if present, else existing --->
    <cfset var dobVal = structKeyExists(o, "DOB") ? o.DOB : (e.DOB ?: "")>
    <cfset var genVal = structKeyExists(o, "Gender") ? o.Gender : (e.GENDER ?: "")>
    <cfset ud.DOB = { value=(len(dobVal) ? dobVal : ""), cfsqltype="cf_sql_date", null=(NOT len(dobVal)) }>
    <cfset ud.Gender = { value=genVal, cfsqltype="cf_sql_nvarchar", null=(NOT len(genVal)) }>
    <cfreturn ud>
</cffunction>

<cftry>
<cfswitch expression="#section#">

    <!--- ── Emails ── --->
    <cfcase value="emails">
        <cfset emailsSvc = createObject("component", "cfc.emails_service").init()>
        <cfset emailCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset primaryIdx = structKeyExists(form, "primary_idx") ? val(form.primary_idx) : -1>
        <cfset emailsToSave = []>
        <cfloop from="0" to="#emailCount - 1#" index="i">
            <cfset eAddr = structKeyExists(form, "addr_#i#") ? trim(form["addr_#i#"]) : "">
            <cfset eType = structKeyExists(form, "type_#i#") ? trim(form["type_#i#"]) : "">
            <cfif len(eAddr) AND NOT reFindNoCase('@uh\.edu$', eAddr)>
                <cfset arrayAppend(emailsToSave, { address=eAddr, type=eType, isPrimary=(i EQ primaryIdx) })>
            </cfif>
        </cfloop>
        <cfset emailsSvc.replaceEmails(userID, emailsToSave)>
        <cfoutput>{"success":true,"message":"Emails saved."}</cfoutput>
    </cfcase>

    <!--- ── Phones ── --->
    <cfcase value="phones">
        <cfset phoneSvc = createObject("component", "cfc.phone_service").init()>
        <cfset phoneCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset primaryIdx = structKeyExists(form, "primary_idx") ? val(form.primary_idx) : -1>
        <cfset phonesToSave = []>
        <cfloop from="0" to="#phoneCount - 1#" index="i">
            <cfset pNum  = structKeyExists(form, "number_#i#") ? trim(form["number_#i#"]) : "">
            <cfset pType = structKeyExists(form, "type_#i#") ? trim(form["type_#i#"]) : "">
            <cfif len(pNum)>
                <cfset arrayAppend(phonesToSave, { number=pNum, type=pType, isPrimary=(i EQ primaryIdx) })>
            </cfif>
        </cfloop>
        <cfset phoneSvc.replacePhones(userID, phonesToSave)>
        <cfoutput>{"success":true,"message":"Phones saved."}</cfoutput>
    </cfcase>

    <!--- ── Aliases ── --->
    <cfcase value="aliases">
        <cfset aliasesSvc = createObject("component", "cfc.aliases_service").init()>
        <cfset aliasCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset aliasesToSave = []>
        <cfloop from="0" to="#aliasCount - 1#" index="i">
            <cfset aFirst  = structKeyExists(form, "first_#i#")  ? trim(form["first_#i#"])  : "">
            <cfset aMiddle = structKeyExists(form, "middle_#i#") ? trim(form["middle_#i#"]) : "">
            <cfset aLast   = structKeyExists(form, "last_#i#")   ? trim(form["last_#i#"])   : "">
            <cfset aType   = structKeyExists(form, "type_#i#")   ? trim(form["type_#i#"])   : "">
            <cfset aSource = structKeyExists(form, "source_#i#") ? trim(form["source_#i#"]) : "">
            <cfset aActive = structKeyExists(form, "active_#i#") ? val(form["active_#i#"])  : 0>
            <cfif len(aType) AND (len(aFirst) OR len(aMiddle) OR len(aLast))>
                <cfset arrayAppend(aliasesToSave, { firstName=aFirst, middleName=aMiddle, lastName=aLast, aliasType=aType, sourceSystem=aSource, isActive=aActive })>
            </cfif>
        </cfloop>
        <cfset aliasesSvc.replaceAliases(userID, aliasesToSave)>
        <cfoutput>{"success":true,"message":"Aliases saved."}</cfoutput>
    </cfcase>

    <!--- ── Awards ── --->
    <cfcase value="awards">
        <cfset studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
        <cfset awardCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset awardsToSave = []>
        <cfloop from="0" to="#awardCount - 1#" index="i">
            <cfset aName = structKeyExists(form, "name_#i#") ? trim(form["name_#i#"]) : "">
            <cfset aType = structKeyExists(form, "type_#i#") ? trim(form["type_#i#"]) : "">
            <cfif len(aName)>
                <cfset arrayAppend(awardsToSave, { name=aName, type=aType })>
            </cfif>
        </cfloop>
        <cfset studentProfileSvc.replaceAwards(userID, awardsToSave)>
        <cfoutput>{"success":true,"message":"Awards saved."}</cfoutput>
    </cfcase>

    <!--- ── Degrees ── --->
    <cfcase value="degrees">
        <cfset degreesSvc = createObject("component", "cfc.degrees_service").init()>
        <cfset degCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset degreesToSave = []>
        <cfloop from="0" to="#degCount - 1#" index="i">
            <cfset dName = structKeyExists(form, "name_#i#") ? trim(form["name_#i#"]) : "">
            <cfset dUniv = structKeyExists(form, "univ_#i#") ? trim(form["univ_#i#"]) : "">
            <cfset dYear = structKeyExists(form, "year_#i#") ? trim(form["year_#i#"]) : "">
            <cfif len(dName)>
                <cfset arrayAppend(degreesToSave, { name=dName, university=dUniv, year=dYear })>
            </cfif>
        </cfloop>
        <cfset degreesSvc.replaceDegrees(userID, degreesToSave)>
        <cfset compositeStr = degreesSvc.buildDegreesString(userID)>
        <cfoutput>{"success":true,"message":"Degrees saved.","composite":"#jsStringFormat(compositeStr)#"}</cfoutput>
    </cfcase>

    <!--- ── Addresses ── --->
    <cfcase value="addresses">
        <cfset addressesSvc = createObject("component", "cfc.addresses_service").init()>
        <cfset addrCount = (structKeyExists(form, "count") AND isNumeric(form.count)) ? val(form.count) : 0>
        <cfset addressesToSave = []>
        <cfloop from="0" to="#addrCount - 1#" index="i">
            <cfset aType     = structKeyExists(form, "type_#i#")     ? trim(form["type_#i#"])     : "">
            <cfset aAddr1    = structKeyExists(form, "addr1_#i#")    ? trim(form["addr1_#i#"])    : "">
            <cfset aAddr2    = structKeyExists(form, "addr2_#i#")    ? trim(form["addr2_#i#"])    : "">
            <cfset aCity     = structKeyExists(form, "city_#i#")     ? trim(form["city_#i#"])     : "">
            <cfset aState    = structKeyExists(form, "state_#i#")    ? trim(form["state_#i#"])    : "">
            <cfset aZip      = structKeyExists(form, "zip_#i#")      ? trim(form["zip_#i#"])      : "">
            <cfset aBuilding = structKeyExists(form, "building_#i#") ? trim(form["building_#i#"]) : "">
            <cfset aRoom     = structKeyExists(form, "room_#i#")     ? trim(form["room_#i#"])     : "">
            <cfset aMailcode = structKeyExists(form, "mailcode_#i#") ? trim(form["mailcode_#i#"]) : "">
            <cfset aPrimary  = structKeyExists(form, "primary_#i#")  ? val(form["primary_#i#"])   : 0>
            <cfif len(aType)>
                <cfset arrayAppend(addressesToSave, {
                    AddressType = { value=aType, cfsqltype="cf_sql_varchar" },
                    Address1    = { value=aAddr1, cfsqltype="cf_sql_varchar" },
                    Address2    = { value=aAddr2, cfsqltype="cf_sql_varchar" },
                    City        = { value=aCity, cfsqltype="cf_sql_varchar" },
                    State       = { value=aState, cfsqltype="cf_sql_varchar" },
                    Zipcode     = { value=aZip, cfsqltype="cf_sql_varchar" },
                    Building    = { value=aBuilding, cfsqltype="cf_sql_varchar" },
                    Room        = { value=aRoom, cfsqltype="cf_sql_varchar" },
                    MailCode    = { value=aMailcode, cfsqltype="cf_sql_varchar" },
                    isPrimary   = { value=aPrimary, cfsqltype="cf_sql_bit" }
                })>
            </cfif>
        </cfloop>
        <cfset addressesSvc.replaceAddresses(userID, addressesToSave)>
        <cfset syncStudentProfileHometownFromAddresses(userID, addressesToSave)>
        <cfoutput>{"success":true,"message":"Addresses saved."}</cfoutput>
    </cfcase>

    <!--- ── Add Single Address ── --->
    <cfcase value="addAddress">
        <cfset addressesSvc = createObject("component", "cfc.addresses_service").init()>
        <cfset addrData = {
            UserID      = { value=userID, cfsqltype="cf_sql_integer" },
            AddressType = { value=trim(form.type ?: ""), cfsqltype="cf_sql_varchar" },
            Address1    = { value=trim(form.addr1 ?: ""), cfsqltype="cf_sql_varchar" },
            Address2    = { value=trim(form.addr2 ?: ""), cfsqltype="cf_sql_varchar" },
            City        = { value=trim(form.city ?: ""), cfsqltype="cf_sql_varchar" },
            State       = { value=trim(form.state ?: ""), cfsqltype="cf_sql_varchar" },
            Zipcode     = { value=trim(form.zip ?: ""), cfsqltype="cf_sql_varchar" },
            Building    = { value=trim(form.building ?: ""), cfsqltype="cf_sql_varchar" },
            Room        = { value=trim(form.room ?: ""), cfsqltype="cf_sql_varchar" },
            MailCode    = { value=trim(form.mailcode ?: ""), cfsqltype="cf_sql_varchar" },
            isPrimary   = { value=val(form.primary ?: 0), cfsqltype="cf_sql_bit" }
        }>
        <cfset result = addressesSvc.addAddress(addrData)>
        <cfif compareNoCase(trim(form.type ?: ""), "Hometown") EQ 0>
            <cfset syncStudentProfileHometownFromAddresses(userID, [addrData])>
        </cfif>
        <cfoutput>{"success":true,"message":"Address added.","addressID":#result.addressID#}</cfoutput>
    </cfcase>

    <!--- ── General (name, titles, pronouns) ── --->
    <cfcase value="general">
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset existing = usersService.getUser(userID).data>
        <cfset firstName = structKeyExists(form, "FirstName") ? toProperName(form.FirstName) : (existing.FIRSTNAME ?: "")>
        <cfset middleName = structKeyExists(form, "MiddleName") ? toProperName(form.MiddleName) : (existing.MIDDLENAME ?: "")>
        <cfif len(trim(middleName)) EQ 1 AND reFind("^[A-Za-z]$", trim(middleName))>
            <cfset middleName = trim(middleName) & ".">
        </cfif>
        <cfset lastName = structKeyExists(form, "LastName") ? toProperName(form.LastName) : (existing.LASTNAME ?: "")>
        <cfset overrides = {
            FirstName  = firstName,
            MiddleName = middleName,
            LastName   = lastName,
            Prefix     = structKeyExists(form, "Prefix")   ? trim(form.Prefix)   : (existing.PREFIX ?: ""),
            Suffix     = structKeyExists(form, "Suffix")   ? trim(form.Suffix)   : (existing.SUFFIX ?: ""),
            Pronouns   = structKeyExists(form, "Pronouns") ? trim(form.Pronouns) : (existing.PRONOUNS ?: ""),
            Title1     = structKeyExists(form, "Title1")   ? trim(form.Title1)   : (existing.TITLE1 ?: ""),
            Title2     = structKeyExists(form, "Title2")   ? trim(form.Title2)   : (existing.TITLE2 ?: ""),
            Title3     = structKeyExists(form, "Title3")   ? trim(form.Title3)   : (existing.TITLE3 ?: "")
        }>
        <cfset userData = buildUserData(existing, overrides)>
        <cfset usersService.updateUser(userID, userData)>
        <cfoutput>{"success":true,"message":"General info saved."}</cfoutput>
    </cfcase>

    <!--- ── Flags ── --->
    <cfcase value="flags">
        <cfset flagsService = createObject("component", "cfc.flags_service").init()>
        <cfset currentFlagsResult = flagsService.getUserFlags(userID)>
        <cfset currentFlags = currentFlagsResult.data>
        <cfset currentFlagIDs = []>
        <cfloop from="1" to="#arrayLen(currentFlags)#" index="i">
            <cfset arrayAppend(currentFlagIDs, val(currentFlags[i].FLAGID))>
        </cfloop>
        <cfset submittedFlagIDs = []>
        <cfif structKeyExists(form, "flagIDs") AND len(trim(form.flagIDs))>
            <cfset flagList = listToArray(form.flagIDs)>
            <cfloop from="1" to="#arrayLen(flagList)#" index="i">
                <cfset arrayAppend(submittedFlagIDs, val(trim(flagList[i])))>
            </cfloop>
        </cfif>
        <!--- Remove unchecked flags --->
        <cfloop from="1" to="#arrayLen(currentFlagIDs)#" index="i">
            <cfif arrayFindNoCase(submittedFlagIDs, currentFlagIDs[i]) EQ 0>
                <cfset flagsService.removeFlag(userID, val(currentFlagIDs[i]))>
            </cfif>
        </cfloop>
        <!--- Add newly checked flags --->
        <cfloop from="1" to="#arrayLen(submittedFlagIDs)#" index="i">
            <cfif arrayFindNoCase(currentFlagIDs, submittedFlagIDs[i]) EQ 0>
                <cfset flagsService.addFlag(userID, val(submittedFlagIDs[i]))>
            </cfif>
        </cfloop>
        <cfoutput>{"success":true,"message":"Flags saved."}</cfoutput>
    </cfcase>

    <!--- ── Organizations ── --->
    <cfcase value="orgs">
        <cfset organizationsService = createObject("component", "cfc.organizations_service").init()>
        <cfset currentOrgsResult = organizationsService.getUserOrgs(userID)>
        <cfset currentOrgs = currentOrgsResult.data>
        <cfset currentOrgIDs = []>
        <cfset currentOrgMap = {}>
        <cfloop from="1" to="#arrayLen(currentOrgs)#" index="i">
            <cfset arrayAppend(currentOrgIDs, val(currentOrgs[i].ORGID))>
            <cfset currentOrgMap[val(currentOrgs[i].ORGID)] = true>
        </cfloop>
        <cfset submittedOrgIDs = []>
        <cfset submittedOrgMap = {}>
        <cfif structKeyExists(form, "orgIDs") AND len(trim(form.orgIDs))>
            <cfset orgList = listToArray(form.orgIDs)>
            <cfloop from="1" to="#arrayLen(orgList)#" index="i">
                <cfset arrayAppend(submittedOrgIDs, val(trim(orgList[i])))>
                <cfset submittedOrgMap[val(trim(orgList[i]))] = true>
            </cfloop>
        </cfif>
        <!--- Remove unchecked orgs --->
        <cfloop from="1" to="#arrayLen(currentOrgIDs)#" index="i">
            <cfif NOT structKeyExists(submittedOrgMap, currentOrgIDs[i])>
                <cfset organizationsService.removeOrg(userID, val(currentOrgIDs[i]))>
            </cfif>
        </cfloop>
        <!--- Add or update checked orgs --->
        <cfloop from="1" to="#arrayLen(submittedOrgIDs)#" index="i">
            <cfset orgID = val(submittedOrgIDs[i])>
            <cfset roleTitle = structKeyExists(form, "roleTitle_" & orgID) ? trim(form["roleTitle_" & orgID]) : "">
            <cfset roleOrder = (structKeyExists(form, "roleOrder_" & orgID) AND isNumeric(form["roleOrder_" & orgID])) ? val(form["roleOrder_" & orgID]) : 0>
            <cfif NOT structKeyExists(currentOrgMap, orgID)>
                <cfset organizationsService.assignOrg(userID, orgID, roleTitle, roleOrder)>
            <cfelse>
                <cfset organizationsService.updateOrgAssignment(userID, orgID, roleTitle, roleOrder)>
            </cfif>
        </cfloop>
        <cfoutput>{"success":true,"message":"Organizations saved."}</cfoutput>
    </cfcase>

    <!--- ── External IDs ── --->
    <cfcase value="extids">
        <cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
        <cfset allSystemsResult = externalIDService.getSystems()>
        <cfset extSystems = allSystemsResult.data>
        <cfloop from="1" to="#arrayLen(extSystems)#" index="i">
            <cfset sys = extSystems[i]>
            <cfset fieldName = "extID_" & sys.SYSTEMID>
            <cfif structKeyExists(form, fieldName) AND len(trim(form[fieldName]))>
                <cfset externalIDService.setExternalID(userID, sys.SYSTEMID, trim(form[fieldName]))>
            </cfif>
        </cfloop>
        <cfoutput>{"success":true,"message":"External IDs saved."}</cfoutput>
    </cfcase>

    <!--- ── UH fields (SuperAdmin only) ── --->
    <cfcase value="uh">
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset existing = usersService.getUser(userID).data>
        <cfset overrides = {
            EmailPrimary = structKeyExists(form, "EmailPrimary") ? trim(form.EmailPrimary) : (existing.EMAILPRIMARY ?: ""),
            UH_API_ID  = structKeyExists(form, "UH_API_ID") ? trim(form.UH_API_ID) : (existing.UH_API_ID ?: ""),
            Room       = structKeyExists(form, "Room")     ? trim(form.Room)     : (existing.ROOM ?: ""),
            Building   = structKeyExists(form, "Building") ? trim(form.Building) : (existing.BUILDING ?: ""),
            Campus     = structKeyExists(form, "Campus")   ? trim(form.Campus)   : (existing.CAMPUS ?: ""),
            Division   = structKeyExists(form, "Division") ? trim(form.Division) : (existing.DIVISION ?: ""),
            DivisionName = structKeyExists(form, "DivisionName") ? trim(form.DivisionName) : (existing.DIVISIONNAME ?: ""),
            Department   = structKeyExists(form, "Department")   ? trim(form.Department)   : (existing.DEPARTMENT ?: ""),
            DepartmentName = structKeyExists(form, "DepartmentName") ? trim(form.DepartmentName) : (existing.DEPARTMENTNAME ?: ""),
            Office_Mailing_Address = structKeyExists(form, "Office_Mailing_Address") ? trim(form.Office_Mailing_Address) : (existing.OFFICE_MAILING_ADDRESS ?: ""),
            Mailcode   = structKeyExists(form, "Mailcode") ? trim(form.Mailcode) : (existing.MAILCODE ?: "")
        }>
        <cfset userData = buildUserData(existing, overrides)>
        <cfset usersService.updateUser(userID, userData)>
        <cfoutput>{"success":true,"message":"UH fields saved."}</cfoutput>
    </cfcase>

    <!--- ── Biographical Info (DOB, Gender, Student Data) ── --->
    <cfcase value="bioinfo">
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset existing = usersService.getUser(userID).data>
        <cfset overrides = {
            DOB    = structKeyExists(form, "DOB") ? trim(form.DOB) : (existing.DOB ?: ""),
            Gender = structKeyExists(form, "Gender") ? trim(form.Gender) : (existing.GENDER ?: "")
        }>
        <cfset userData = buildUserData(existing, overrides)>
        <cfset usersService.updateUser(userID, userData)>

        <!--- Student Data fields now live on the Biographical Information tab. --->
        <cfset academicService = createObject("component", "cfc.academic_service").init()>
        <cfset academicService.saveAcademicInfo(
            userID,
            structKeyExists(form, "CurrentGradYear")  ? trim(form.CurrentGradYear)  : "",
            structKeyExists(form, "OriginalGradYear") ? trim(form.OriginalGradYear) : ""
        )>

        <cfset studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
        <cfset studentProfileSvc.saveProfile(
            userID,
            structKeyExists(form, "sp_first_externship")  ? trim(form.sp_first_externship)  : "",
            structKeyExists(form, "sp_second_externship") ? trim(form.sp_second_externship) : "",
            structKeyExists(form, "sp_commencement_age")  ? trim(form.sp_commencement_age)  : ""
        )>

        <cfif structKeyExists(form, "bioContent")>
            <cfset bioSvc = createObject("component", "cfc.bio_service").init()>
            <cfset bioSvc.saveBio(userID, form.bioContent ?: "")>
        </cfif>

        <cfoutput>{"success":true,"message":"Biographical info saved."}</cfoutput>
    </cfcase>

    <!--- ── Student Profile ── --->
    <cfcase value="studentprofile">
        <cfset academicService = createObject("component", "cfc.academic_service").init()>
        <cfset academicService.saveAcademicInfo(
            userID,
            structKeyExists(form, "CurrentGradYear")  ? trim(form.CurrentGradYear)  : "",
            structKeyExists(form, "OriginalGradYear") ? trim(form.OriginalGradYear) : ""
        )>
        <cfset studentProfileSvc = createObject("component", "cfc.studentProfile_service").init()>
        <cfset studentProfileSvc.saveProfile(
            userID,
            structKeyExists(form, "sp_first_externship")  ? trim(form.sp_first_externship)  : "",
            structKeyExists(form, "sp_second_externship") ? trim(form.sp_second_externship) : "",
            structKeyExists(form, "sp_commencement_age")  ? trim(form.sp_commencement_age)  : ""
        )>
        <!--- Process student profile degrees if present --->
        <cfset spDegCount = (structKeyExists(form, "sp_degree_count") AND isNumeric(form.sp_degree_count)) ? val(form.sp_degree_count) : 0>
        <cfif spDegCount GT 0>
            <cfset degreesSvc = createObject("component", "cfc.degrees_service").init()>
            <cfset degreesToSave = []>
            <cfloop from="0" to="#spDegCount - 1#" index="di">
                <cfset dName = structKeyExists(form, "sp_deg_name_#di#") ? trim(form["sp_deg_name_#di#"]) : "">
                <cfset dUniv = structKeyExists(form, "sp_deg_univ_#di#") ? trim(form["sp_deg_univ_#di#"]) : "">
                <cfset dYear = structKeyExists(form, "sp_deg_year_#di#") ? trim(form["sp_deg_year_#di#"]) : "">
                <cfif len(dName)>
                    <cfset arrayAppend(degreesToSave, { name=dName, university=dUniv, year=dYear })>
                </cfif>
            </cfloop>
            <cfset degreesSvc.replaceDegrees(userID, degreesToSave)>
        </cfif>
        <cfoutput>{"success":true,"message":"Student profile saved."}</cfoutput>
    </cfcase>

    <!--- ── Bio content ── --->
    <cfcase value="bio">
        <cfset bioSvc = createObject("component", "cfc.bio_service").init()>
        <cfset bioSvc.saveBio(userID, structKeyExists(form, "bioContent") ? form.bioContent : "")>
        <cfoutput>{"success":true,"message":"Bio saved."}</cfoutput>
    </cfcase>

    <!--- ── Tab degrees (fac/emer/res profile tabs) ── --->
    <cfcase value="tabdegrees">
        <cfset pfx = structKeyExists(form, "prefix") ? lCase(trim(form.prefix)) : "">
        <cfif NOT listFindNoCase("fac,emer,res", pfx)>
            <cfoutput>{"success":false,"message":"Invalid degree prefix."}</cfoutput>
        <cfelse>
            <cfset degreesSvc = createObject("component", "cfc.degrees_service").init()>
            <cfset degCount = (structKeyExists(form, "#pfx#_degree_count") AND isNumeric(form["#pfx#_degree_count"])) ? val(form["#pfx#_degree_count"]) : 0>
            <cfset degreesToSave = []>
            <cfloop from="0" to="#degCount - 1#" index="di">
                <cfset dName = structKeyExists(form, "#pfx#_deg_name_#di#") ? trim(form["#pfx#_deg_name_#di#"]) : "">
                <cfset dUniv = structKeyExists(form, "#pfx#_deg_univ_#di#") ? trim(form["#pfx#_deg_univ_#di#"]) : "">
                <cfset dYear = structKeyExists(form, "#pfx#_deg_year_#di#") ? trim(form["#pfx#_deg_year_#di#"]) : "">
                <cfif len(dName)>
                    <cfset arrayAppend(degreesToSave, { name=dName, university=dUniv, year=dYear })>
                </cfif>
            </cfloop>
            <cfset degreesSvc.replaceDegrees(userID, degreesToSave)>
            <cfset compositeStr = degreesSvc.buildDegreesString(userID)>
            <cfoutput>{"success":true,"message":"Degrees saved.","composite":"#jsStringFormat(compositeStr)#"}</cfoutput>
        </cfif>
    </cfcase>

    <cfdefaultcase>
        <cfoutput>{"success":false,"message":"Unknown section: #jsStringFormat(section)#"}</cfoutput>
    </cfdefaultcase>

</cfswitch>

<cfcatch type="any">
    <cfoutput>{"success":false,"message":"#jsStringFormat(cfcatch.message)#"}</cfoutput>
</cfcatch>
</cftry>
