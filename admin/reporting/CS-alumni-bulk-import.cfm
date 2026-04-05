<!---
    CS-alumni-bulk-import.cfm
    Bulk import alumni from the legacy AlumniStudent table (grad years 1955–2014).

    For each legacy record:
      1. Skip if first+last already exists in local Users table.
      2. Map available fields and insert directly into Users + related tables.
         (No API lookup — these are historical records.)
--->
<cfsetting requesttimeout="300">

<!--- ── Params ── --->
<cfparam name="form.selectedYear" default="">
<cfset selectedYear = (cgi.request_method EQ "POST" AND isNumeric(form.selectedYear) AND val(form.selectedYear) GTE 1955 AND val(form.selectedYear) LTE 2025) ? val(form.selectedYear) : 0>

<cfset processed      = false>
<cfset processResults = []>
<cfset insertedCount  = 0>
<cfset skippedCount   = 0>
<cfset updatedCount   = 0>
<cfset errorCount     = 0>
<cfset globalError    = "">

<!--- ── Helper: read first non-empty column from a list of candidates ── --->
<cffunction name="getColVal" access="private" returntype="string" output="false">
    <cfargument name="row"        type="struct" required="true">
    <cfargument name="candidates" type="array"  required="true">
    <cfset var k = "">
    <cfloop array="#arguments.candidates#" item="k">
        <cfif structKeyExists(arguments.row, uCase(k)) AND len(trim(arguments.row[uCase(k)] ?: ""))>
            <cfreturn trim(arguments.row[uCase(k)])>
        </cfif>
        <cfif structKeyExists(arguments.row, k) AND len(trim(arguments.row[k] ?: ""))>
            <cfreturn trim(arguments.row[k])>
        </cfif>
    </cfloop>
    <cfreturn "">
</cffunction>

<cfif cgi.request_method EQ "POST" AND selectedYear GTE 1955 AND selectedYear LTE 2025>
    <cfset processed = true>

    <!--- ── Initialise services once ── --->
    <cftry>
        <cfset biFlagsService = createObject("component", "dir.cfc.flags_service").init()>
        <cfset biOrgsService  = createObject("component", "dir.cfc.organizations_service").init()>
        <cfset biExtIDSvc     = createObject("component", "dir.cfc.externalID_service").init()>
        <cfset biAcadSvc      = createObject("component", "dir.cfc.academic_service").init()>
        <cfset biUsersService = createObject("component", "dir.cfc.users_service").init()>

        <!--- Find "Alumni" flag (case-insensitive contains match) --->
        <cfset biAlumniFlagID   = 0>
        <cfset biDeceasedFlagID = 0>
        <cfset biAllFlags = biFlagsService.getAllFlags().data>
        <cfloop from="1" to="#arrayLen(biAllFlags)#" index="bifi">
            <cfset biFlag = biAllFlags[bifi]>
            <cfif findNoCase("alumni", biFlag.FLAGNAME) AND biAlumniFlagID EQ 0>
                <cfset biAlumniFlagID = val(biFlag.FLAGID)>
            </cfif>
            <cfif findNoCase("deceased", biFlag.FLAGNAME) AND biDeceasedFlagID EQ 0>
                <cfset biDeceasedFlagID = val(biFlag.FLAGID)>
            </cfif>
        </cfloop>

        <!--- Orgs: Academic Programs + OD Program --->
        <cfset biOrgIDs  = []>
        <cfset biAllOrgs = biOrgsService.getAllOrgs().data>
        <cfloop from="1" to="#arrayLen(biAllOrgs)#" index="bioi">
            <cfset bioName = trim(biAllOrgs[bioi].ORGNAME)>
            <cfif bioName EQ "Academic Programs" OR bioName EQ "OD Program">
                <cfset arrayAppend(biOrgIDs, val(biAllOrgs[bioi].ORGID))>
            </cfif>
        </cfloop>

        <!--- External systems --->
        <cfset biPsoftSysID  = 0>
        <cfset biCougarSysID = 0>
        <cfset biSystems = biExtIDSvc.getSystems().data>
        <cfloop from="1" to="#arrayLen(biSystems)#" index="bisi">
            <cfset bisLC = lCase(trim(biSystems[bisi].SYSTEMNAME))>
            <cfif bisLC EQ "peoplesoft"><cfset biPsoftSysID  = biSystems[bisi].SYSTEMID></cfif>
            <cfif bisLC EQ "cougarnet"> <cfset biCougarSysID = biSystems[bisi].SYSTEMID></cfif>
        </cfloop>

        <!--- Build local Users name+gradyear index to detect duplicates --->
        <!--- keys on firstname|lastname|currentgradyear so same-name people with different years are treated as different --->
        <cfset biLocalIndex   = {}>
        <cfset biLocalUsers   = biUsersService.listUsers()>
        <cfset biAcademicMap  = biAcadSvc.getAllAcademicInfoMap()>
        <!--- Also build PeopleSoft-ID and email indexes for stronger matching on later years --->
        <cfset biPsoftIndex   = (biPsoftSysID GT 0) ? biExtIDSvc.getValueToUserMap(biPsoftSysID) : {}>
        <cfset biEmailIndex   = {}>
        <cfloop from="1" to="#arrayLen(biLocalUsers)#" index="biu">
            <cfset biLU     = biLocalUsers[biu]>
            <cfset biLUAcad = structKeyExists(biAcademicMap, toString(biLU.USERID)) ? biAcademicMap[toString(biLU.USERID)] : {}>
            <cfset biLUGrad = (NOT structIsEmpty(biLUAcad) AND isNumeric(biLUAcad.CURRENTGRADYEAR ?: "") AND val(biLUAcad.CURRENTGRADYEAR) GT 0) ? toString(val(biLUAcad.CURRENTGRADYEAR)) : "">
            <cfset biKey    = lCase(trim(biLU.FIRSTNAME ?: "")) & "|" & lCase(trim(biLU.LASTNAME ?: "")) & "|" & biLUGrad>
            <cfif len(biKey) GT 2>
                <cfset biLocalIndex[biKey] = biLU><!--- store full struct for update checking --->
            </cfif>
            <!--- Email index: primary then secondary --->
            <cfset biLUEmail = lCase(trim(biLU.EMAILPRIMARY ?: ""))>
            <cfif NOT len(biLUEmail)><cfset biLUEmail = lCase(trim(biLU.EMAILSECONDARY ?: ""))></cfif>
            <cfif len(biLUEmail) AND NOT structKeyExists(biEmailIndex, biLUEmail)>
                <cfset biEmailIndex[biLUEmail] = biLU>
            </cfif>
        </cfloop>

    <cfcatch>
        <cfset globalError = "Failed to initialise services: " & cfcatch.message>
    </cfcatch>
    </cftry>

    <!--- ── Query legacy DB ── --->
    <cfif NOT len(globalError)>
        <cftry>
            <cfset biQuery = queryExecute(
                "SELECT * FROM AlumniStudent WHERE GradYear = :yr ORDER BY LastName, FirstName",
                { yr = { value=selectedYear, cfsqltype="cf_sql_integer" } },
                { datasource="oldUHCOdirectory", timeout=60 }
            )>
        <cfcatch>
            <cfset globalError = "Legacy DB query failed: " & cfcatch.message>
        </cfcatch>
        </cftry>
    </cfif>

    <!--- ── Deduplicate query rows ── --->
    <cfif NOT len(globalError)>
        <cfset biSeenKeys = {}>
        <cfset biDeduped  = []>
        <cfset biCols     = listToArray(biQuery.columnList)>
        <cfloop from="1" to="#biQuery.recordCount#" index="biqr">
            <cfset biParts = []>
            <cfloop from="1" to="#arrayLen(biCols)#" index="biqc">
                <cfset arrayAppend(biParts, toString(biQuery[biCols[biqc]][biqr]))>
            </cfloop>
            <cfset biRowKey = arrayToList(biParts, "|")>
            <cfif NOT structKeyExists(biSeenKeys, biRowKey)>
                <cfset biSeenKeys[biRowKey] = true>
                <cfset biRow = {}>
                <cfloop from="1" to="#arrayLen(biCols)#" index="biqc">
                    <cfset biRow[biCols[biqc]] = biQuery[biCols[biqc]][biqr]>
                </cfloop>
                <cfset arrayAppend(biDeduped, biRow)>
            </cfif>
        </cfloop>

        <!--- ── Process each record ── --->
        <cfloop from="1" to="#arrayLen(biDeduped)#" index="bir">
            <cfset src = biDeduped[bir]>

            <!--- Map fields from legacy columns --->
            <cfset biFirst  = getColVal(src, ["FirstName",  "First_Name",  "fname",  "F_Name"])>
            <cfset biLast   = getColVal(src, ["LastName",   "Last_Name",   "lname",  "L_Name"])>
            <cfset biMiddle = getColVal(src, ["MiddleName", "Middle_Name", "MiddleInitial", "MI"])>
            <cfset biEmail  = getColVal(src, ["Email", "EmailAddress", "Email_Address", "UH_Email", "UHEmail"])>
            <cfset biPsoft  = getColVal(src, ["Psoft", "PSoft", "PeopleSoft", "PeopleSoftID"])>
            <cfset biCougar = getColVal(src, ["CougarNet", "CougarNetID", "CougarNetId", "CougaNet"])>
            <cfset biGradYr    = getColVal(src, ["GradYear", "Grad_Year", "GraduationYear", "Graduation_Year"])>
            <cfset biOrigGradYr = getColVal(src, ["OriginalGradYear", "Original_GradYear", "OrigGradYear", "OrigYear"])>
            <cfset biMaiden    = getColVal(src, ["MaidenName", "Maiden_Name", "MaidenLastName", "Maiden"])>
            <cfset biDeceased = getColVal(src, ["Deceased", "IsDeceased", "Is_Deceased", "Dead"])>

            <cfif NOT len(biFirst) OR NOT len(biLast)>
                <cfset arrayAppend(processResults, {
                    status    = "error",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    message   = "Missing first or last name — skipped"
                })>
                <cfset errorCount++>
                <cfcontinue>
            </cfif>

            <!--- Three-tier match: PeopleSoft ID (strongest) → email → name+gradyear --->
            <!--- Tiers 1 & 2 require both first AND last name to match to prevent false positives --->
            <cfset biEffLookupGr = (len(biGradYr) AND isNumeric(biGradYr) AND val(biGradYr) GT 0) ? toString(val(biGradYr)) : toString(selectedYear)>
            <cfset biExisting    = "">
            <!--- Tier 1: PeopleSoft ID + name confirmation --->
            <cfif len(biPsoft) AND structKeyExists(biPsoftIndex, lCase(trim(biPsoft)))>
                <cfset biMatchedUID = biPsoftIndex[lCase(trim(biPsoft))]>
                <!--- find the full user struct from biLocalUsers --->
                <cfloop from="1" to="#arrayLen(biLocalUsers)#" index="biLookup">
                    <cfif biLocalUsers[biLookup].USERID == biMatchedUID>
                        <cfset biCandidate = biLocalUsers[biLookup]>
                        <!--- only accept if both first and last name match --->
                        <cfif lCase(trim(biCandidate.FIRSTNAME ?: "")) EQ lCase(biFirst) AND lCase(trim(biCandidate.LASTNAME ?: "")) EQ lCase(biLast)>
                            <cfset biExisting = biCandidate>
                        </cfif>
                        <cfbreak>
                    </cfif>
                </cfloop>
            </cfif>
            <!--- Tier 2: Email + name confirmation --->
            <cfif isSimpleValue(biExisting) AND len(biEmail) AND structKeyExists(biEmailIndex, lCase(trim(biEmail)))>
                <cfset biCandidate = biEmailIndex[lCase(trim(biEmail))]>
                <!--- only accept if both first and last name match --->
                <cfif lCase(trim(biCandidate.FIRSTNAME ?: "")) EQ lCase(biFirst) AND lCase(trim(biCandidate.LASTNAME ?: "")) EQ lCase(biLast)>
                    <cfset biExisting = biCandidate>
                </cfif>
            </cfif>
            <!--- Tier 3: Name + grad year --->
            <cfset biNameKey = lCase(biFirst) & "|" & lCase(biLast) & "|" & biEffLookupGr>
            <cfif isSimpleValue(biExisting) AND structKeyExists(biLocalIndex, biNameKey)>
                <cfset biExisting = biLocalIndex[biNameKey]>
            </cfif>

            <cfif NOT isSimpleValue(biExisting)><!--- matched an existing user --->
                <cfset biExistUID = val(biExisting.USERID)>
                <cfset biUpdSteps = []>
                <cfset biUpdated  = false>

                <!--- ── User record fields ── --->
                <cfset biNeedUserUpdate = false>
                <cfset biUpdData = {
                    FirstName      = biExisting.FIRSTNAME     ?: biFirst,
                    MiddleName     = biExisting.MIDDLENAME    ?: "",
                    LastName       = biExisting.LASTNAME      ?: biLast,
                    MaidenName     = biExisting.MAIDENNAME    ?: "",
                    PreferredName  = biExisting.PREFERREDNAME ?: "",
                    Pronouns       = biExisting.PRONOUNS      ?: "",
                    EmailPrimary   = biExisting.EMAILPRIMARY  ?: "",
                    EmailSecondary = biExisting.EMAILSECONDARY ?: "",
                    Phone          = biExisting.PHONE         ?: "",
                    Room           = biExisting.ROOM          ?: "",
                    Building       = biExisting.BUILDING      ?: "",
                    Title1         = biExisting.TITLE1        ?: "",
                    Title2         = biExisting.TITLE2        ?: "",
                    Title3         = biExisting.TITLE3        ?: "",
                    UH_API_ID      = biExisting.UH_API_ID     ?: ""
                }>
                <cfif NOT len(biUpdData.MiddleName)     AND len(biMiddle)><cfset biUpdData.MiddleName     = biMiddle><cfset biNeedUserUpdate = true></cfif>
                <cfif NOT len(biUpdData.MaidenName)     AND len(biMaiden)><cfset biUpdData.MaidenName     = biMaiden><cfset biNeedUserUpdate = true></cfif>
                <cfif NOT len(biUpdData.EmailSecondary) AND len(biEmail)> <cfset biUpdData.EmailSecondary = biEmail> <cfset biNeedUserUpdate = true></cfif>
                <cftry>
                    <cfif biNeedUserUpdate>
                        <cfset biUsersService.updateUser(biExistUID, biUpdData)>
                        <cfset arrayAppend(biUpdSteps, "user:ok")>
                        <cfset biUpdated = true>
                    <cfelse>
                        <cfset arrayAppend(biUpdSteps, "user:skip")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biUpdSteps, "user:err:#cfcatch.message#")>
                </cfcatch>
                </cftry>

                <!--- ── External IDs ── --->
                <cftry>
                    <cfset biExistExtIDs = biExtIDSvc.getExternalIDs(biExistUID).data>
                    <cfset biExistExtMap = {}>
                    <cfloop from="1" to="#arrayLen(biExistExtIDs)#" index="biexi">
                        <cfset biExistExtMap[toString(biExistExtIDs[biexi].SYSTEMID)] = trim(biExistExtIDs[biexi].EXTERNALVALUE ?: "")>
                    </cfloop>
                    <cfset biExtUpdated = false>
                    <cfif biPsoftSysID GT 0 AND len(biPsoft) AND NOT (structKeyExists(biExistExtMap, toString(biPsoftSysID)) AND len(biExistExtMap[toString(biPsoftSysID)]))>
                        <cfset biExtIDSvc.setExternalID(biExistUID, biPsoftSysID, biPsoft)>
                        <cfset biExtUpdated = true>
                        <cfset biUpdated = true>
                    </cfif>
                    <cfif biCougarSysID GT 0 AND len(biCougar) AND NOT (structKeyExists(biExistExtMap, toString(biCougarSysID)) AND len(biExistExtMap[toString(biCougarSysID)]))>
                        <cfset biExtIDSvc.setExternalID(biExistUID, biCougarSysID, biCougar)>
                        <cfset biExtUpdated = true>
                        <cfset biUpdated = true>
                    </cfif>
                    <cfset arrayAppend(biUpdSteps, biExtUpdated ? "extids:ok" : "extids:skip")>
                <cfcatch>
                    <cfset arrayAppend(biUpdSteps, "extids:err")>
                </cfcatch>
                </cftry>

                <!--- ── Academic / GradYear ── --->
                <cftry>
                    <cfset biExistAcad   = biAcadSvc.getAcademicInfo(biExistUID).data>
                    <cfset biEffGradYr    = (len(biGradYr) AND isNumeric(biGradYr) AND val(biGradYr) GT 0) ? biGradYr : selectedYear>
                    <cfset biEffOrigGradYr = (len(biOrigGradYr) AND isNumeric(biOrigGradYr) AND val(biOrigGradYr) GT 0) ? biOrigGradYr : "">
                    <cfset biMissingGrad  = (structIsEmpty(biExistAcad) OR NOT (isNumeric(biExistAcad.CURRENTGRADYEAR ?: "") AND val(biExistAcad.CURRENTGRADYEAR) GT 0))>
                    <cfif biMissingGrad>
                        <cfset biAcadSvc.saveAcademicInfo(biExistUID, biEffGradYr, biEffOrigGradYr)>
                        <cfset arrayAppend(biUpdSteps, "gradyr:ok:#biEffGradYr#")>
                        <cfset biUpdated = true>
                    <cfelse>
                        <cfset arrayAppend(biUpdSteps, "gradyr:skip")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biUpdSteps, "gradyr:err:#cfcatch.message#")>
                </cfcatch>
                </cftry>

                <!--- ── Flags ── --->
                <cftry>
                    <cfset biExistFlags   = biFlagsService.getUserFlags(biExistUID).data>
                    <cfset biExistFlagMap = {}>
                    <cfloop from="1" to="#arrayLen(biExistFlags)#" index="biefx">
                        <cfset biExistFlagMap[toString(biExistFlags[biefx].FLAGID)] = true>
                    </cfloop>
                    <!--- Alumni flag --->
                    <cfif biAlumniFlagID GT 0 AND NOT structKeyExists(biExistFlagMap, toString(biAlumniFlagID))>
                        <cfset biFlagsService.addFlag(biExistUID, biAlumniFlagID)>
                        <cfset arrayAppend(biUpdSteps, "flag:ok")>
                        <cfset biUpdated = true>
                    <cfelse>
                        <cfset arrayAppend(biUpdSteps, "flag:skip")>
                    </cfif>
                    <!--- Deceased flag --->
                    <cfset biIsDeceased = (len(biDeceased) AND (biDeceased EQ "1" OR lCase(biDeceased) EQ "true" OR lCase(biDeceased) EQ "yes" OR lCase(biDeceased) EQ "y"))>
                    <cfif biIsDeceased AND biDeceasedFlagID GT 0 AND NOT structKeyExists(biExistFlagMap, toString(biDeceasedFlagID))>
                        <cfset biFlagsService.addFlag(biExistUID, biDeceasedFlagID)>
                        <cfset arrayAppend(biUpdSteps, "deceased:ok")>
                        <cfset biUpdated = true>
                    <cfelseif biIsDeceased AND biDeceasedFlagID EQ 0>
                        <cfset arrayAppend(biUpdSteps, "deceased:notfound")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biUpdSteps, "flag:err")>
                </cfcatch>
                </cftry>

                <!--- ── Orgs ── --->
                <cftry>
                    <cfset biExistOrgs   = biOrgsService.getUserOrgs(biExistUID).data>
                    <cfset biExistOrgMap = {}>
                    <cfloop from="1" to="#arrayLen(biExistOrgs)#" index="bieox">
                        <cfset biExistOrgMap[toString(biExistOrgs[bieox].ORGID)] = true>
                    </cfloop>
                    <cfset biOrgsUpdated = false>
                    <cfloop from="1" to="#arrayLen(biOrgIDs)#" index="bioidx">
                        <cfif NOT structKeyExists(biExistOrgMap, toString(biOrgIDs[bioidx]))>
                            <cfset biOrgsService.assignOrg(biExistUID, biOrgIDs[bioidx])>
                            <cfset biOrgsUpdated = true>
                            <cfset biUpdated     = true>
                        </cfif>
                    </cfloop>
                    <cfset arrayAppend(biUpdSteps, biOrgsUpdated ? "orgs:ok" : "orgs:skip")>
                <cfcatch>
                    <cfset arrayAppend(biUpdSteps, "orgs:err")>
                </cfcatch>
                </cftry>

                <cfif biUpdated>
                    <cfset arrayAppend(processResults, {
                        status    = "updated",
                        firstName = biFirst,
                        lastName  = biLast,
                        gradYear  = biGradYr,
                        userID    = biExistUID,
                        steps     = biUpdSteps,
                        message   = ""
                    })>
                    <cfset updatedCount++>
                <cfelse>
                    <cfset arrayAppend(processResults, {
                        status    = "skipped",
                        firstName = biFirst,
                        lastName  = biLast,
                        gradYear  = biGradYr,
                        message   = "Already complete — nothing to update"
                    })>
                    <cfset skippedCount++>
                </cfif>
                <cfcontinue>
            </cfif>

            <!--- ── Insert user directly (no API lookup) ── --->
            <cfset biSteps  = []>
            <cfset biNewUID = 0>
            <cfset biInsOK  = false>
            <cfset biInsMsg = "">

            <!--- Step 1: Create user --->
            <cftry>
                <cfset biCreateResult = biUsersService.createUser({
                    FirstName      = biFirst,
                    MiddleName     = biMiddle,
                    LastName       = biLast,
                    MaidenName     = biMaiden,
                    PreferredName  = "",
                    Pronouns       = "",
                    EmailPrimary   = "",
                    EmailSecondary = biEmail,
                    Phone          = "",
                    Room           = "",
                    Building       = "",
                    Title1         = "",
                    Title2         = "",
                    Title3         = "",
                    UH_API_ID      = ""
                })>
                <cfif NOT biCreateResult.success>
                    <cfthrow message="#biCreateResult.message#">
                </cfif>
                <cfset biNewUID = val(biCreateResult.userID)>
                <cfset biInsOK  = true>
                <cfset arrayAppend(biSteps, "user:ok:#biNewUID#")>
            <cfcatch>
                <cfset biInsMsg = cfcatch.message>
                <cfset arrayAppend(biSteps, "user:err:#cfcatch.message#")>
            </cfcatch>
            </cftry>

            <cfif biInsOK AND biNewUID GT 0>

                <!--- Step 2: External IDs --->
                <cftry>
                    <cfif biPsoftSysID GT 0 AND len(biPsoft)>
                        <cfset biExtIDSvc.setExternalID(biNewUID, biPsoftSysID, biPsoft)>
                    </cfif>
                    <cfif biCougarSysID GT 0 AND len(biCougar)>
                        <cfset biExtIDSvc.setExternalID(biNewUID, biCougarSysID, biCougar)>
                    </cfif>
                    <cfset arrayAppend(biSteps, "extids:ok")>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "extids:err")>
                </cfcatch>
                </cftry>

                <!--- Step 3: Academic / GradYear --->
                <cftry>
                    <cfset biEffectiveGradYr    = (len(biGradYr) AND isNumeric(biGradYr) AND val(biGradYr) GT 0) ? biGradYr : selectedYear>
                    <cfset biEffectiveOrigGradYr = (len(biOrigGradYr) AND isNumeric(biOrigGradYr) AND val(biOrigGradYr) GT 0) ? biOrigGradYr : "">
                    <cfset biAcadSvc.saveAcademicInfo(biNewUID, biEffectiveGradYr, biEffectiveOrigGradYr)>
                    <cfset arrayAppend(biSteps, "gradyr:ok:#biEffectiveGradYr#")>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "gradyr:err:#cfcatch.message#")>
                </cfcatch>
                </cftry>

                <!--- Step 4: Alumni flag --->
                <cftry>
                    <cfif biAlumniFlagID GT 0>
                        <cfset biFlagsService.addFlag(biNewUID, biAlumniFlagID)>
                        <cfset arrayAppend(biSteps, "flag:ok")>
                    <cfelse>
                        <cfset arrayAppend(biSteps, "flag:notfound")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "flag:err")>
                </cfcatch>
                </cftry>

                <!--- Step 4b: Deceased flag --->
                <cftry>
                    <cfset biIsDeceased = (len(biDeceased) AND (biDeceased EQ "1" OR lCase(biDeceased) EQ "true" OR lCase(biDeceased) EQ "yes" OR lCase(biDeceased) EQ "y"))>
                    <cfif biIsDeceased AND biDeceasedFlagID GT 0>
                        <cfset biFlagsService.addFlag(biNewUID, biDeceasedFlagID)>
                        <cfset arrayAppend(biSteps, "deceased:ok")>
                    <cfelseif biIsDeceased AND biDeceasedFlagID EQ 0>
                        <cfset arrayAppend(biSteps, "deceased:notfound")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "deceased:err")>
                </cfcatch>
                </cftry>

                <!--- Step 5: Orgs --->
                <cftry>
                    <cfloop from="1" to="#arrayLen(biOrgIDs)#" index="bioidx">
                        <cfset biOrgsService.assignOrg(biNewUID, biOrgIDs[bioidx])>
                    </cfloop>
                    <cfset arrayAppend(biSteps, "orgs:ok:#arrayLen(biOrgIDs)#")>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "orgs:err")>
                </cfcatch>
                </cftry>

                <!--- Mark in local index to catch duplicates within the same batch --->
                <cfset biLocalIndex[biNameKey] = true>
                <cfset insertedCount++>

                <cfset arrayAppend(processResults, {
                    status    = "inserted",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    userID    = biNewUID,
                    steps     = biSteps,
                    message   = ""
                })>

            <cfelse>
                <cfset arrayAppend(processResults, {
                    status    = "error",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    message   = "Create failed: " & biInsMsg
                })>
                <cfset errorCount++>
            </cfif>

        </cfloop><!--- end record loop --->

    </cfif><!--- end no globalError --->
</cfif><!--- end POST --->

<!--- ── Build page content ── --->
<cfsavecontent variable="content"><cfoutput>
<h1>CS Alumni Bulk Import</h1>
<p class="text-muted mb-4">
    Select a legacy grad year (1955–2014) to import alumni directly from the AlumniStudent table.
    Records already in the Users table are skipped. No API lookup is performed.
</p>

<form method="post" class="d-flex align-items-center gap-3 mb-4">
    <label for="selectedYear" class="form-label mb-0 fw-semibold">Select Grad Year:</label>
    <select name="selectedYear" id="selectedYear" class="form-select" style="width:auto;">
        <option value="">-- Choose Year --</option>
        <cfset yearList = []>
        <cfloop from="2025" to="1955" step="-1" index="yr">
            <cfset arrayAppend(yearList, yr)>
        </cfloop>
        <cfloop array="#yearList#" item="yr">
            <option value="#yr#"#(selectedYear EQ yr ? " selected" : "")#>#yr#</option>
        </cfloop>
    </select>
    <button type="submit" class="btn btn-primary">Run Import</button>
</form>

<cfif processed>
    <cfif len(globalError)>
        <div class="alert alert-danger"><strong>Error:</strong> #encodeForHTML(globalError)#</div>
    <cfelse>
        <div class="d-flex gap-3 mb-3 flex-wrap">
            <span class="badge bg-success fs-6 px-3 py-2"><i class="bi bi-person-plus-fill me-1"></i> #insertedCount# Inserted</span>
            <span class="badge bg-info text-dark fs-6 px-3 py-2"><i class="bi bi-pencil-fill me-1"></i> #updatedCount# Updated</span>
            <span class="badge bg-secondary fs-6 px-3 py-2"><i class="bi bi-skip-forward-fill me-1"></i> #skippedCount# Skipped</span>
            <span class="badge bg-danger fs-6 px-3 py-2"><i class="bi bi-exclamation-triangle-fill me-1"></i> #errorCount# Errors</span>
        </div>

        <cfif arrayLen(processResults) GT 0>
            <div class="table-responsive">
            <table class="table table-sm table-bordered align-middle">
                <thead class="table-dark">
                    <tr>
                        <th>##</th>
                        <th>Status</th>
                        <th>Grad Year</th>
                        <th>First Name</th>
                        <th>Last Name</th>
                        <th>Detail</th>
                    </tr>
                </thead>
                <tbody>
                <cfloop from="1" to="#arrayLen(processResults)#" index="bir">
                    <cfset biRow = processResults[bir]>
                    <cfif biRow.status EQ "inserted">
                        <tr>
                            <td>#bir#</td>
                            <td><span class="badge bg-success">Inserted</span></td>
                            <td>#encodeForHTML(biRow.gradYear ?: "")#</td>
                            <td>#encodeForHTML(biRow.firstName)#</td>
                            <td>#encodeForHTML(biRow.lastName)#</td>
                            <td>
                                <cfloop array="#biRow.steps#" item="biSt">
                                    <cfif left(biSt,7) EQ "user:ok">
                                        <span class="badge bg-success me-1" title="User ID ##listLast(biSt,':')##">user</span>
                                    <cfelseif left(biSt,8) EQ "user:err">
                                        <span class="badge bg-danger me-1">user!</span>
                                    <cfelseif left(biSt,9) EQ "extids:ok">
                                        <span class="badge bg-success me-1">ext IDs</span>
                                    <cfelseif left(biSt,10) EQ "extids:err">
                                        <span class="badge bg-warning text-dark me-1">ext IDs!</span>
                                    <cfelseif left(biSt,8) EQ "gradyr:ok">
                                        <span class="badge bg-success me-1" title="Year ##listLast(biSt,':')##">grad yr</span>
                                    <cfelseif left(biSt,10) EQ "gradyr:err">
                                        <span class="badge bg-warning text-dark me-1" title="#encodeForHTMLAttribute(listRest(biSt,':'))#">grad yr!</span>
                                    <cfelseif left(biSt,7) EQ "flag:ok">
                                        <span class="badge bg-success me-1">flag</span>
                                    <cfelseif left(biSt,13) EQ "flag:notfound">
                                        <span class="badge bg-danger me-1" title="No Alumni flag found in system">flag?</span>
                                    <cfelseif left(biSt,8) EQ "flag:err">
                                        <span class="badge bg-warning text-dark me-1">flag!</span>
                                    <cfelseif left(biSt,12) EQ "deceased:ok">
                                        <span class="badge bg-dark me-1">deceased</span>
                                    <cfelseif left(biSt,18) EQ "deceased:notfound">
                                        <span class="badge bg-danger me-1" title="No Deceased flag found in system">deceased?</span>
                                    <cfelseif left(biSt,13) EQ "deceased:err">
                                        <span class="badge bg-warning text-dark me-1">deceased!</span>
                                    <cfelseif left(biSt,7) EQ "orgs:ok">
                                        <span class="badge bg-success me-1">orgs(#listLast(biSt,':')#)</span>
                                    <cfelseif left(biSt,8) EQ "orgs:err">
                                        <span class="badge bg-warning text-dark me-1">orgs!</span>
                                    </cfif>
                                </cfloop>
                                <a href="/dir/admin/users/edit.cfm?userID=#biRow.userID#" class="btn btn-outline-success ms-1" style="font-size:0.75rem;padding:1px 6px;">Edit</a>
                            </td>
                        </tr>
                    <cfelseif biRow.status EQ "updated">
                        <tr class="table-info">
                            <td>#bir#</td>
                            <td><span class="badge bg-info text-dark">Updated</span></td>
                            <td>#encodeForHTML(biRow.gradYear ?: "")#</td>
                            <td>#encodeForHTML(biRow.firstName)#</td>
                            <td>#encodeForHTML(biRow.lastName)#</td>
                            <td>
                                <cfloop array="#biRow.steps#" item="biSt">
                                    <cfif left(biSt,7) EQ "user:ok">
                                        <span class="badge bg-info text-dark me-1">user</span>
                                    <cfelseif left(biSt,9) EQ "user:skip">
                                        <span class="badge bg-light text-muted me-1">user</span>
                                    <cfelseif left(biSt,8) EQ "user:err">
                                        <span class="badge bg-danger me-1">user!</span>
                                    <cfelseif left(biSt,9) EQ "extids:ok">
                                        <span class="badge bg-info text-dark me-1">ext IDs</span>
                                    <cfelseif left(biSt,11) EQ "extids:skip">
                                        <span class="badge bg-light text-muted me-1">ext IDs</span>
                                    <cfelseif left(biSt,10) EQ "extids:err">
                                        <span class="badge bg-warning text-dark me-1">ext IDs!</span>
                                    <cfelseif left(biSt,8) EQ "gradyr:ok">
                                        <span class="badge bg-info text-dark me-1" title="Year ##listLast(biSt,':')##">grad yr</span>
                                    <cfelseif left(biSt,11) EQ "gradyr:skip">
                                        <span class="badge bg-light text-muted me-1">grad yr</span>
                                    <cfelseif left(biSt,10) EQ "gradyr:err">
                                        <span class="badge bg-warning text-dark me-1">grad yr!</span>
                                    <cfelseif left(biSt,7) EQ "flag:ok">
                                        <span class="badge bg-info text-dark me-1">flag</span>
                                    <cfelseif left(biSt,9) EQ "flag:skip">
                                        <span class="badge bg-light text-muted me-1">flag</span>
                                    <cfelseif left(biSt,8) EQ "flag:err">
                                        <span class="badge bg-warning text-dark me-1">flag!</span>
                                    <cfelseif left(biSt,12) EQ "deceased:ok">
                                        <span class="badge bg-dark me-1">deceased</span>
                                    <cfelseif left(biSt,18) EQ "deceased:notfound">
                                        <span class="badge bg-danger me-1" title="No Deceased flag found in system">deceased?</span>
                                    <cfelseif left(biSt,7) EQ "orgs:ok">
                                        <span class="badge bg-info text-dark me-1">orgs</span>
                                    <cfelseif left(biSt,9) EQ "orgs:skip">
                                        <span class="badge bg-light text-muted me-1">orgs</span>
                                    <cfelseif left(biSt,8) EQ "orgs:err">
                                        <span class="badge bg-warning text-dark me-1">orgs!</span>
                                    </cfif>
                                </cfloop>
                                <a href="/dir/admin/users/edit.cfm?userID=#biRow.userID#" class="btn btn-outline-info ms-1" style="font-size:0.75rem;padding:1px 6px;">Edit</a>
                            </td>
                        </tr>
                    <cfelseif biRow.status EQ "skipped">
                        <tr class="table-secondary">
                            <td>#bir#</td>
                            <td><span class="badge bg-secondary">Skipped</span></td>
                            <td>#encodeForHTML(biRow.gradYear ?: "")#</td>
                            <td>#encodeForHTML(biRow.firstName)#</td>
                            <td>#encodeForHTML(biRow.lastName)#</td>
                            <td><small class="text-muted">#encodeForHTML(biRow.message)#</small></td>
                        </tr>
                    <cfelse>
                        <tr class="table-danger">
                            <td>#bir#</td>
                            <td><span class="badge bg-danger">Error</span></td>
                            <td>#encodeForHTML(biRow.gradYear ?: "")#</td>
                            <td>#encodeForHTML(biRow.firstName)#</td>
                            <td>#encodeForHTML(biRow.lastName)#</td>
                            <td><small class="text-danger">#encodeForHTML(biRow.message)#</small></td>
                        </tr>
                    </cfif>
                </cfloop>
                </tbody>
            </table>
            </div>
        <cfelse>
            <p class="text-muted">No records found in AlumniStudent for grad year #selectedYear#.</p>
        </cfif>
    </cfif>
</cfif>
</cfoutput></cfsavecontent>

<cfinclude template="/dir/admin/layout.cfm">
