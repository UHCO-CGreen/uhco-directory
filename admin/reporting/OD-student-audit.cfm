<!---
    OD-student-audit.cfm
    Audits every Users record where Title1 = 'OD Student'.

    Checks per user:
      1. UserAcademicInfo  — CurrentGradYear present
      2. UserFlagAssignments — Current-Student flag assigned
      3. UserOrganizations  — Academic Programs + OD Program assigned
      4. UserExternalIDs    — PeopleSoft ID + CougarNet set
      5. UH_API_ID          — populated on the Users row

    Repair strategy (non-destructive — only fills in missing data):
      • GradYear / PeopleSoft / CougarNet  →  look up matching AlumniStudent row
        in oldUHCOdirectory by FirstName+LastName (or FirstName+MaidenName).
      • Flag / Orgs     →  assign directly (no lookup needed).
      • UH_API_ID       →  call UH API as last resort (only when missing).

    No POST required — runs immediately on every page load.
--->
<cfsetting requesttimeout="600">

<!--- ── API credentials ── --->
<cfset uhApiToken  = structKeyExists(application, "uhApiToken")  ? trim(application.uhApiToken  ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">
<cfif (uhApiToken EQ "" OR uhApiSecret EQ "") AND structKeyExists(server, "system") AND structKeyExists(server.system, "environment")>
    <cfif structKeyExists(server.system.environment, "UH_API_TOKEN")>
        <cfset uhApiToken  = trim(server.system.environment["UH_API_TOKEN"])>
    </cfif>
    <cfif structKeyExists(server.system.environment, "UH_API_SECRET")>
        <cfset uhApiSecret = trim(server.system.environment["UH_API_SECRET"])>
    </cfif>
</cfif>
<cfif uhApiToken  EQ ""><cfset uhApiToken  = "my5Tu[{[VH%,dT{wR3SEigeWc%2w,ZyFT6=5!2Rv$f0g,_z!UpDduLxhgjSm$P6"></cfif>
<cfif uhApiSecret EQ ""><cfset uhApiSecret = "degxqhYPX2Vk@LFevunxX}:kTkX3fBXR"></cfif>

<!--- ── Helper: extract a field from a query row by trying multiple candidate column names ── --->
<cffunction name="getQueryVal" access="private" returntype="string" output="false">
    <cfargument name="qry"        required="true">
    <cfargument name="rowIndex"   type="numeric" required="true">
    <cfargument name="candidates" type="array"   required="true">
    <cfset var k = "">
    <cfloop array="#arguments.candidates#" item="k">
        <cfif listFindNoCase(arguments.qry.columnList, k)>
            <cfset var v = arguments.qry[k][arguments.rowIndex]>
            <cfif len(trim(v ?: ""))>
                <cfreturn trim(v)>
            </cfif>
        </cfif>
    </cfloop>
    <cfreturn "">
</cffunction>

<!--- ── State ── --->
<cfset globalError   = "">
<cfset auditResults  = []>
<cfset totalStudents = 0>
<cfset totalFixed    = 0>
<cfset totalIssues   = 0>
<cfset totalClean    = 0>

<!--- ── Resolve constants once ── --->
<cftry>
    <cfset svcFlags = createObject("component", "dir.cfc.flags_service").init()>
    <cfset svcOrgs  = createObject("component", "dir.cfc.organizations_service").init()>
    <cfset svcExtID = createObject("component", "dir.cfc.externalID_service").init()>
    <cfset svcAcad  = createObject("component", "dir.cfc.academic_service").init()>
    <cfset uhApi    = createObject("component", "dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
    <cfset svcUsers = createObject("component", "dir.cfc.users_service").init()>

    <!--- Current-Student flag ID --->
    <cfset reqFlagID = 0>
    <cfset allFlags  = svcFlags.getAllFlags().data>
    <cfloop array="#allFlags#" item="f">
        <cfif lCase(trim(f.FLAGNAME)) EQ "current-student">
            <cfset reqFlagID = val(f.FLAGID)>
            <cfbreak>
        </cfif>
    </cfloop>

    <!--- Required org IDs: Academic Programs + OD Program --->
    <cfset reqOrgIDs = {}>
    <cfset allOrgs   = svcOrgs.getAllOrgs().data>
    <cfloop array="#allOrgs#" item="o">
        <cfset oName = trim(o.ORGNAME)>
        <cfif oName EQ "Academic Programs" OR oName EQ "OD Program">
            <cfset reqOrgIDs[oName] = val(o.ORGID)>
        </cfif>
    </cfloop>

    <!--- External system IDs --->
    <cfset sysPsoftID  = 0>
    <cfset sysCougarID = 0>
    <cfset sysLegacyID = 0>
    <cfset allSystems  = svcExtID.getSystems().data>
    <cfloop array="#allSystems#" item="s">
        <cfset sLC = lCase(trim(s.SYSTEMNAME))>
        <cfif sLC EQ "peoplesoft"><cfset sysPsoftID  = val(s.SYSTEMID)></cfif>
        <cfif sLC EQ "cougarnet"> <cfset sysCougarID = val(s.SYSTEMID)></cfif>
        <cfif sLC EQ "legacyid">  <cfset sysLegacyID = val(s.SYSTEMID)></cfif>
    </cfloop>

<cfcatch>
    <cfset globalError = "Failed to initialise services: " & cfcatch.message>
</cfcatch>
</cftry>

<cfif NOT len(globalError)>

    <!--- ── Batch load from primary DB ── --->
    <cftry>
        <cfset qUsers = queryExecute(
            "SELECT * FROM Users WHERE Title1 = 'OD Student' ORDER BY LastName, FirstName",
            {}, { datasource="UHCO_Directory", timeout=60 }
        )>
        <cfset qAcad = queryExecute(
            "SELECT * FROM UserAcademicInfo
             WHERE UserID IN (SELECT UserID FROM Users WHERE Title1 = 'OD Student')",
            {}, { datasource="UHCO_Directory", timeout=60 }
        )>
        <cfset qFlags = queryExecute(
            "SELECT UFA.UserID, UF.FlagID, UF.FlagName
             FROM UserFlagAssignments UFA
             INNER JOIN UserFlags UF ON UFA.FlagID = UF.FlagID
             WHERE UFA.UserID IN (SELECT UserID FROM Users WHERE Title1 = 'OD Student')",
            {}, { datasource="UHCO_Directory", timeout=60 }
        )>
        <cfset qOrgs = queryExecute(
            "SELECT UO.UserID, UO.OrgID, O.OrgName
             FROM UserOrganizations UO
             INNER JOIN Organizations O ON UO.OrgID = O.OrgID
             WHERE UO.UserID IN (SELECT UserID FROM Users WHERE Title1 = 'OD Student')",
            {}, { datasource="UHCO_Directory", timeout=60 }
        )>
        <cfset qExtIDs = queryExecute(
            "SELECT UE.UserID, UE.SystemID, UE.ExternalValue, ES.SystemName
             FROM UserExternalIDs UE
             INNER JOIN ExternalSystems ES ON UE.SystemID = ES.SystemID
             WHERE UE.UserID IN (SELECT UserID FROM Users WHERE Title1 = 'OD Student')",
            {}, { datasource="UHCO_Directory", timeout=60 }
        )>
    <cfcatch>
        <cfset globalError = "Primary DB query failed: " & cfcatch.message>
    </cfcatch>
    </cftry>

</cfif>

<cfif NOT len(globalError)>

    <!--- ── Load old DB ── --->
    <cfset qOldDB = queryNew("x")>
    <cftry>
        <cfset qOldDB = queryExecute(
            "SELECT * FROM AlumniStudent WHERE GradYear BETWEEN 2024 AND 2030",
            {}, { datasource="oldUHCOdirectory", timeout=60 }
        )>
    <cfcatch>
        <!--- Old DB unavailable; proceed without it --->
    </cfcatch>
    </cftry>

    <!--- ── Build lookup indexes ── --->

    <!--- Academic: userID → {gradYear, originalGradYear} --->
    <cfset acadIdx = {}>
    <cfloop query="qAcad">
        <cfset acadIdx[toString(val(qAcad.USERID))] = {
            gradYear         = val(qAcad.CURRENTGRADYEAR  ?: 0),
            originalGradYear = val(qAcad.ORIGINALGRADYEAR ?: 0)
        }>
    </cfloop>

    <!--- Flags: userID → [flagID, ...] --->
    <cfset flagIdx = {}>
    <cfloop query="qFlags">
        <cfset fKey = toString(val(qFlags.USERID))>
        <cfif NOT structKeyExists(flagIdx, fKey)><cfset flagIdx[fKey] = []></cfif>
        <cfset arrayAppend(flagIdx[fKey], val(qFlags.FLAGID))>
    </cfloop>

    <!--- Orgs: userID → [orgID, ...] --->
    <cfset orgIdx = {}>
    <cfloop query="qOrgs">
        <cfset oKey = toString(val(qOrgs.USERID))>
        <cfif NOT structKeyExists(orgIdx, oKey)><cfset orgIdx[oKey] = []></cfif>
        <cfset arrayAppend(orgIdx[oKey], val(qOrgs.ORGID))>
    </cfloop>

    <!--- ExtIDs: userID → { systemID: value } --->
    <cfset extIdx = {}>
    <cfloop query="qExtIDs">
        <cfset eKey  = toString(val(qExtIDs.USERID))>
        <cfset eSKey = toString(val(qExtIDs.SYSTEMID))>
        <cfif NOT structKeyExists(extIdx, eKey)><cfset extIdx[eKey] = {}></cfif>
        <cfset extIdx[eKey][eSKey] = trim(qExtIDs.EXTERNALVALUE ?: "")>
    </cfloop>

    <!--- Old DB: name key → {gradYear, psoft, cougar, email} --->
    <cfset oldDbIdx       = {}>
    <cfset oldDbMaidenIdx = {}>
    <cfif qOldDB.recordCount GT 0>
        <cfloop from="1" to="#qOldDB.recordCount#" index="dbr">
            <cfset dbFN    = getQueryVal(qOldDB, dbr, ["FirstName","First_Name","fname","F_Name"])>
            <cfset dbLN    = getQueryVal(qOldDB, dbr, ["LastName","Last_Name","lname","L_Name"])>
            <cfset dbMN    = getQueryVal(qOldDB, dbr, ["MaidenName","Maiden_Name","MaidenLastName","Maiden"])>
            <cfset dbGY    = getQueryVal(qOldDB, dbr, ["GradYear","Grad_Year","GraduationYear","Graduation_Year"])>
            <cfset dbPS    = getQueryVal(qOldDB, dbr, ["Psoft","PSoft","PeopleSoft","PeopleSoftID"])>
            <cfset dbCN    = getQueryVal(qOldDB, dbr, ["CougarNet","CougarNetID","CougarNetId","CougaNet"])>
            <cfset dbEM    = getQueryVal(qOldDB, dbr, ["Email","EmailAddress","Email_Address","UH_Email","UHEmail"])>
            <!--- Active/Directory: read directly — 0 is a valid value, cannot use getQueryVal --->
            <cfset dbActive = listFindNoCase(qOldDB.columnList, "Active")    ? toString(qOldDB["Active"][dbr])    : "">
            <cfset dbDir    = listFindNoCase(qOldDB.columnList, "Directory") ? toString(qOldDB["Directory"][dbr]) : "">
            <cfset dbStuID  = getQueryVal(qOldDB, dbr, ["StudentID","Student_ID","Stu_ID"])>
            <cfset dbRow = { firstName=dbFN, lastName=dbLN, maidenName=dbMN, gradYear=dbGY, psoft=dbPS, cougar=dbCN, email=dbEM, active=dbActive, directory=dbDir, studentID=dbStuID }>
            <cfif len(dbFN) AND len(dbLN)>
                <cfset dbKey = lCase(dbFN) & "|" & lCase(dbLN)>
                <cfif NOT structKeyExists(oldDbIdx, dbKey)>
                    <cfset oldDbIdx[dbKey] = dbRow>
                </cfif>
            </cfif>
            <cfif len(dbFN) AND len(dbMN) AND dbMN NEQ dbLN>
                <cfset dbMKey = lCase(dbFN) & "|" & lCase(dbMN)>
                <cfif NOT structKeyExists(oldDbMaidenIdx, dbMKey)>
                    <cfset oldDbMaidenIdx[dbMKey] = dbRow>
                </cfif>
            </cfif>
        </cfloop>
    </cfif>

    <!--- ── Process each OD student ── --->
    <cfset totalStudents = qUsers.recordCount>

    <cfloop query="qUsers">
        <cfset uid    = val(qUsers.USERID)>
        <cfset uKey   = toString(uid)>
        <cfset uFirst = trim(qUsers.FIRSTNAME  ?: "")>
        <cfset uLast  = trim(qUsers.LASTNAME   ?: "")>
        <cfset uMaid  = trim(qUsers.MAIDENNAME ?: "")>
        <cfset uApiID = trim(qUsers.UH_API_ID  ?: "")>

        <cfset fixes  = []>
        <cfset issues = []>

        <!--- Locate old DB row (first+last, then first+maiden) --->
        <cfset nameKey = lCase(uFirst) & "|" & lCase(uLast)>
        <cfset oldRow  = {}>
        <cfif structKeyExists(oldDbIdx, nameKey)>
            <cfset oldRow = oldDbIdx[nameKey]>
        <cfelseif len(uMaid)>
            <cfset maidKey = lCase(uFirst) & "|" & lCase(uMaid)>
            <cfif structKeyExists(oldDbMaidenIdx, maidKey)>
                <cfset oldRow = oldDbMaidenIdx[maidKey]>
            </cfif>
        </cfif>

        <!--- ════ 0. Active / Directory gate ════ --->
        <!--- If the matched AlumniStudent row has Active≠1 or Directory≠1, delete the user --->
        <cfset wasDeleted    = false>
        <cfset legacyStatus  = "">
        <cfset gradYearStatus = "">
        <cfset flagStatus    = "">
        <cfset orgStatus     = []>
        <cfset psoftStatus   = "">
        <cfset cougarStatus  = "">
        <cfset apiIdStatus   = "">
        <cfif NOT structIsEmpty(oldRow)>
            <cfset odActive = trim(toString(oldRow.active    ?: ""))>
            <cfset odDir    = trim(toString(oldRow.directory ?: ""))>
            <cfif (len(odActive) AND odActive NEQ "1") OR (len(odDir) AND odDir NEQ "1")>
                <cftry>
                    <cfset svcUsers.deleteUser(uid)>
                    <cfset wasDeleted = true>
                    <cfset arrayAppend(fixes, "DELETED — AlumniStudent Active=[#odActive#] Directory=[#odDir#]")>
                <cfcatch>
                    <cfset arrayAppend(issues, "Delete failed (Active=#odActive#, Dir=#odDir#): #cfcatch.message#")>
                </cfcatch>
                </cftry>
            </cfif>
        </cfif>

        <cfif NOT wasDeleted>

        <!--- ════ 1. GradYear ════ --->
        <cfset acadRow    = structKeyExists(acadIdx, uKey) ? acadIdx[uKey] : {}>
        <cfset curGradYr  = structIsEmpty(acadRow) ? 0 : val(acadRow.gradYear)>
        <cfset oldDbGradYr = structKeyExists(oldRow, "gradYear") ? val(oldRow.gradYear) : 0>
        <cfset gradYearStatus = "">

        <cfif curGradYr GT 0>
            <cfif oldDbGradYr GT 0 AND curGradYr NEQ oldDbGradYr>
                <cfset gradYearStatus = "mismatch">
                <cfset arrayAppend(issues, "GradYear mismatch: DB=#curGradYr#, OldDB=#oldDbGradYr#")>
            <cfelse>
                <cfset gradYearStatus = "ok:#curGradYr#">
            </cfif>
        <cfelse>
            <cfif oldDbGradYr GT 0>
                <cftry>
                    <cfset svcAcad.saveAcademicInfo(uid, oldDbGradYr, "")>
                    <cfset gradYearStatus = "fixed:#oldDbGradYr#">
                    <cfset arrayAppend(fixes, "GradYear set to #oldDbGradYr#")>
                <cfcatch>
                    <cfset gradYearStatus = "fix-err">
                    <cfset arrayAppend(issues, "GradYear fix failed: #cfcatch.message#")>
                </cfcatch>
                </cftry>
            <cfelse>
                <cfset gradYearStatus = "missing">
                <cfset arrayAppend(issues, "GradYear missing — #(NOT structIsEmpty(oldRow) ? 'old DB has no value' : 'no old DB match')#")>
            </cfif>
        </cfif>

        <!--- ════ 2. Current-Student flag ════ --->
        <cfset userFlagIDs = structKeyExists(flagIdx, uKey) ? flagIdx[uKey] : []>
        <cfset hasCurrFlag = false>
        <cfloop array="#userFlagIDs#" item="fid">
            <cfif val(fid) EQ reqFlagID><cfset hasCurrFlag = true><cfbreak></cfif>
        </cfloop>
        <cfset flagStatus = "">
        <cfif hasCurrFlag>
            <cfset flagStatus = "ok">
        <cfelseif reqFlagID GT 0>
            <cftry>
                <cfset svcFlags.addFlag(uid, reqFlagID)>
                <cfset flagStatus = "fixed">
                <cfset arrayAppend(fixes, "Current-Student flag added")>
            <cfcatch>
                <cfset flagStatus = "fix-err">
                <cfset arrayAppend(issues, "Flag fix failed: #cfcatch.message#")>
            </cfcatch>
            </cftry>
        <cfelse>
            <cfset flagStatus = "flag-id-not-found">
            <cfset arrayAppend(issues, "Current-Student flag ID not resolved")>
        </cfif>

        <!--- ════ 3. Org assignments ════ --->
        <cfset userOrgIDs = structKeyExists(orgIdx, uKey) ? orgIdx[uKey] : []>
        <cfset orgStatus  = []>
        <cfloop collection="#reqOrgIDs#" item="orgName">
            <cfset reqOID   = reqOrgIDs[orgName]>
            <cfset hasOrg   = false>
            <cfloop array="#userOrgIDs#" item="oid">
                <cfif val(oid) EQ reqOID><cfset hasOrg = true><cfbreak></cfif>
            </cfloop>
            <cfif hasOrg>
                <cfset arrayAppend(orgStatus, { org=orgName, status="ok" })>
            <cfelse>
                <cftry>
                    <cfset svcOrgs.assignOrg(uid, reqOID)>
                    <cfset arrayAppend(orgStatus, { org=orgName, status="fixed" })>
                    <cfset arrayAppend(fixes, "#orgName# org assigned")>
                <cfcatch>
                    <cfset arrayAppend(orgStatus, { org=orgName, status="fix-err" })>
                    <cfset arrayAppend(issues, "#orgName# org fix failed: #cfcatch.message#")>
                </cfcatch>
                </cftry>
            </cfif>
        </cfloop>

        <!--- ════ 4. External IDs ════ --->
        <cfset userExtMap   = structKeyExists(extIdx, uKey) ? extIdx[uKey] : {}>
        <cfset psoSIDKey    = toString(sysPsoftID)>
        <cfset couSIDKey    = toString(sysCougarID)>
        <cfset curPsoft     = (sysPsoftID  GT 0 AND structKeyExists(userExtMap, psoSIDKey))  ? userExtMap[psoSIDKey]  : "">
        <cfset curCougar    = (sysCougarID GT 0 AND structKeyExists(userExtMap, couSIDKey)) ? userExtMap[couSIDKey] : "">
        <cfset psoftStatus  = "">
        <cfset cougarStatus = "">

        <!--- PeopleSoft --->
        <cfif len(curPsoft)>
            <cfset psoftStatus = "ok:#curPsoft#">
        <cfelseif structKeyExists(oldRow, "psoft") AND len(oldRow.psoft)>
            <cftry>
                <cfset svcExtID.setExternalID(uid, sysPsoftID, oldRow.psoft)>
                <cfset psoftStatus = "fixed:#oldRow.psoft#">
                <cfset arrayAppend(fixes, "PeopleSoft ID set to #oldRow.psoft#")>
            <cfcatch>
                <cfset psoftStatus = "fix-err">
                <cfset arrayAppend(issues, "PeopleSoft fix failed: #cfcatch.message#")>
            </cfcatch>
            </cftry>
        <cfelse>
            <cfset psoftStatus = "missing">
            <cfset arrayAppend(issues, "PeopleSoft ID missing — #(NOT structIsEmpty(oldRow) ? 'old DB has no value' : 'no old DB match')#")>
        </cfif>

        <!--- CougarNet --->
        <cfif len(curCougar)>
            <cfset cougarStatus = "ok:#curCougar#">
        <cfelseif structKeyExists(oldRow, "cougar") AND len(oldRow.cougar)>
            <cftry>
                <cfset svcExtID.setExternalID(uid, sysCougarID, oldRow.cougar)>
                <cfset cougarStatus = "fixed:#oldRow.cougar#">
                <cfset arrayAppend(fixes, "CougarNet set to #oldRow.cougar#")>
            <cfcatch>
                <cfset cougarStatus = "fix-err">
                <cfset arrayAppend(issues, "CougarNet fix failed: #cfcatch.message#")>
            </cfcatch>
            </cftry>
        <cfelse>
            <cfset cougarStatus = "missing">
            <cfset arrayAppend(issues, "CougarNet missing — #(NOT structIsEmpty(oldRow) ? 'old DB has no value' : 'no old DB match')#")>
        </cfif>

        <!--- ════ 5. UH_API_ID (API call only when missing) ════ --->
        <cfset apiIdStatus = "">
        <cfif len(uApiID)>
            <cfset apiIdStatus = "ok">
        <cfelse>
            <cfset apiIdStatus = "missing">
            <cftry>
                <cfset apiResp  = uhApi.getPeople(student=true, staff=false, faculty=false, department="H0113", q=uLast)>
                <cfset apiPeople = []>
                <cfif left(apiResp.statusCode, 3) EQ "200">
                    <cfset apiData = apiResp.data ?: {}>
                    <cfif isStruct(apiData) AND structKeyExists(apiData, "data") AND isArray(apiData.data)>
                        <cfset apiPeople = apiData.data>
                    <cfelseif isArray(apiData)>
                        <cfset apiPeople = apiData>
                    </cfif>
                </cfif>
                <cfset apiMatch = {}>
                <cfloop from="1" to="#arrayLen(apiPeople)#" index="ai">
                    <cfset ap       = apiPeople[ai]>
                    <cfset apFirst  = lCase(trim(ap.first_name ?: ap.firstName ?: ""))>
                    <cfset apLast   = lCase(trim(ap.last_name  ?: ap.lastName  ?: ""))>
                    <cfif apFirst EQ lCase(uFirst) AND (apLast EQ lCase(uLast) OR (len(uMaid) AND apLast EQ lCase(uMaid)))>
                        <cfset apiMatch = ap>
                        <cfbreak>
                    </cfif>
                </cfloop>
                <cfif NOT structIsEmpty(apiMatch)>
                    <cfset newApiID = trim(apiMatch.id ?: "")>
                    <cfif len(newApiID)>
                        <cfset queryExecute(
                            "UPDATE Users SET UH_API_ID = :apiID, UpdatedAt = GETDATE() WHERE UserID = :uid",
                            {
                                apiID = { value=newApiID, cfsqltype="cf_sql_varchar" },
                                uid   = { value=uid,      cfsqltype="cf_sql_integer" }
                            },
                            { datasource="UHCO_Directory" }
                        )>
                        <cfset apiIdStatus = "fixed">
                        <cfset arrayAppend(fixes, "UH_API_ID set from API")>
                    </cfif>
                <cfelse>
                    <cfset apiIdStatus = "missing-not-in-api">
                    <cfset arrayAppend(issues, "Not found in UH API by name")>
                </cfif>
            <cfcatch>
                <cfset apiIdStatus = "api-err">
                <cfset arrayAppend(issues, "API lookup failed: #cfcatch.message#")>
            </cfcatch>
            </cftry>
        </cfif>

        <!--- ════ 6. LegacyID (StudentID from AlumniStudent) ════ --->
        <!--- Applied to all valid records, including already-migrated ones --->
        <cfif sysLegacyID GT 0 AND NOT structIsEmpty(oldRow) AND len(trim(toString(oldRow.studentID ?: "")))>
            <cfset legSIDKey = toString(sysLegacyID)>
            <cfset curLegacy = structKeyExists(userExtMap, legSIDKey) ? userExtMap[legSIDKey] : "">
            <cfset oldStuID  = trim(toString(oldRow.studentID))>
            <cfif curLegacy EQ oldStuID>
                <cfset legacyStatus = "ok:#oldStuID#">
            <cfelse>
                <cftry>
                    <cfset svcExtID.setExternalID(uid, sysLegacyID, oldStuID)>
                    <cfset legacyStatus = "fixed:#oldStuID#">
                    <cfset arrayAppend(fixes, "LegacyID set to #oldStuID#")>
                <cfcatch>
                    <cfset legacyStatus = "fix-err">
                    <cfset arrayAppend(issues, "LegacyID fix failed: #cfcatch.message#")>
                </cfcatch>
                </cftry>
            </cfif>
        <cfelseif sysLegacyID EQ 0>
            <cfset legacyStatus = "no-system">
        <cfelse>
            <cfset legacyStatus = "no-source">
        </cfif>

        </cfif><!--- /NOT wasDeleted --->

        <!--- ── Tally ── --->
        <cfset rowHasFix    = arrayLen(fixes)  GT 0>
        <cfset rowHasIssue  = arrayLen(issues) GT 0>
        <cfif rowHasFix>   <cfset totalFixed++></cfif>
        <cfif rowHasIssue> <cfset totalIssues++>
        <cfelseif NOT rowHasFix><cfset totalClean++>
        </cfif>

        <cfset arrayAppend(auditResults, {
            userID        = uid,
            firstName     = uFirst,
            lastName      = uLast,
            hasOldDbMatch = NOT structIsEmpty(oldRow),
            wasDeleted    = wasDeleted,
            gradYearStatus = gradYearStatus,
            flagStatus     = flagStatus,
            orgStatus      = orgStatus,
            psoftStatus    = psoftStatus,
            cougarStatus   = cougarStatus,
            legacyStatus   = legacyStatus,
            apiIdStatus    = apiIdStatus,
            fixes          = fixes,
            issues         = issues
        })>
    </cfloop>

</cfif>

<!--- ── Render ── --->
<cfsavecontent variable="content"><cfoutput>
<h1>OD Student Audit</h1>
<p class="text-muted mb-4">
    Checks every <code>Users</code> record where <code>Title1 = 'OD Student'</code> against
    <code>UserAcademicInfo</code>, flag assignments, org assignments, external IDs, and
    <code>UH_API_ID</code>. Missing data is repaired automatically using the legacy
    <code>AlumniStudent</code> table and, when necessary, the UH API.
</p>

<cfif len(globalError)>
    <div class="alert alert-danger"><strong>Error:</strong> #encodeForHTML(globalError)#</div>
<cfelse>
    <div class="d-flex gap-3 mb-4 flex-wrap">
        <span class="badge bg-secondary fs-6 px-3 py-2">#totalStudents# Total OD Students</span>
        <span class="badge bg-success  fs-6 px-3 py-2">#totalClean# All OK</span>
        <span class="badge bg-primary  fs-6 px-3 py-2">#totalFixed# Had Fixes</span>
        <span class="badge bg-danger   fs-6 px-3 py-2">#totalIssues# Have Remaining Issues</span>
    </div>

    <div class="table-responsive">
    <table class="table table-sm table-bordered align-middle" style="font-size:0.85rem;">
        <thead class="table-dark">
            <tr>
                <th>ID</th>
                <th>Name</th>
                <th>Old DB</th>
                <th>Grad Year</th>
                <th>Flag</th>
                <th>Orgs</th>
                <th>PeopleSoft</th>
                <th>CougarNet</th>
                <th>LegacyID</th>
                <th>UH API ID</th>
                <th>Fixed</th>
                <th>Issues</th>
            </tr>
        </thead>
        <tbody>
        <cfloop from="1" to="#arrayLen(auditResults)#" index="ri">
            <cfset r = auditResults[ri]>
            <cfset hasIssue = arrayLen(r.issues) GT 0>
            <cfset hasFix   = arrayLen(r.fixes)  GT 0>
            <cfset rowClass = r.wasDeleted ? " class='table-secondary'" : (hasIssue ? " class='table-danger'" : (hasFix ? " class='table-info'" : ""))>
            <tr#rowClass#>
                <td><cfif NOT r.wasDeleted><a href="/dir/admin/users/edit.cfm?userID=#r.userID#">#r.userID#</a><cfelse>#r.userID#</cfif></td>
                <td>#encodeForHTML(r.firstName)# #encodeForHTML(r.lastName)#</td>
                <td>
                    <cfif r.hasOldDbMatch>
                        <span class="badge bg-success">matched</span>
                    <cfelse>
                        <span class="badge bg-warning text-dark">no match</span>
                    </cfif>
                </td>

                <!--- Grad Year --->
                <td>
                    <cfif left(r.gradYearStatus, 2) EQ "ok">
                        <span class="badge bg-success">#listLast(r.gradYearStatus, ':')#</span>
                    <cfelseif left(r.gradYearStatus, 5) EQ "fixed">
                        <span class="badge bg-primary">Fixed: #listLast(r.gradYearStatus, ':')#</span>
                    <cfelseif r.gradYearStatus EQ "mismatch">
                        <span class="badge bg-warning text-dark">Mismatch</span>
                    <cfelse>
                        <span class="badge bg-danger">Missing</span>
                    </cfif>
                </td>

                <!--- Flag --->
                <td>
                    <cfif r.flagStatus EQ "ok">
                        <span class="badge bg-success">OK</span>
                    <cfelseif r.flagStatus EQ "fixed">
                        <span class="badge bg-primary">Fixed</span>
                    <cfelse>
                        <span class="badge bg-danger">Error</span>
                    </cfif>
                </td>

                <!--- Orgs --->
                <td>
                    <cfloop array="#r.orgStatus#" item="os">
                        <cfif os.status EQ "ok">
                            <span class="badge bg-success me-1" title="#encodeForHTMLAttribute(os.org)#">#left(os.org, 2)#</span>
                        <cfelseif os.status EQ "fixed">
                            <span class="badge bg-primary me-1" title="Fixed: #encodeForHTMLAttribute(os.org)#">#left(os.org, 2)#+</span>
                        <cfelse>
                            <span class="badge bg-danger me-1" title="Error: #encodeForHTMLAttribute(os.org)#">#left(os.org, 2)#!</span>
                        </cfif>
                    </cfloop>
                </td>

                <!--- PeopleSoft --->
                <td>
                    <cfif left(r.psoftStatus, 2) EQ "ok">
                        <span class="badge bg-success">#listLast(r.psoftStatus, ':')#</span>
                    <cfelseif left(r.psoftStatus, 5) EQ "fixed">
                        <span class="badge bg-primary">Fixed: #listLast(r.psoftStatus, ':')#</span>
                    <cfelseif r.psoftStatus EQ "fix-err">
                        <span class="badge bg-danger">Error</span>
                    <cfelse>
                        <span class="badge bg-warning text-dark">Missing</span>
                    </cfif>
                </td>

                <!--- CougarNet --->
                <td>
                    <cfif left(r.cougarStatus, 2) EQ "ok">
                        <span class="badge bg-success">#listLast(r.cougarStatus, ':')#</span>
                    <cfelseif left(r.cougarStatus, 5) EQ "fixed">
                        <span class="badge bg-primary">Fixed: #listLast(r.cougarStatus, ':')#</span>
                    <cfelseif r.cougarStatus EQ "fix-err">
                        <span class="badge bg-danger">Error</span>
                    <cfelse>
                        <span class="badge bg-warning text-dark">Missing</span>
                    </cfif>
                </td>

                <!--- LegacyID (StudentID) --->
                <td>
                    <cfif left(r.legacyStatus, 2) EQ "ok">
                        <span class="badge bg-success">#listLast(r.legacyStatus, ':')#</span>
                    <cfelseif left(r.legacyStatus, 5) EQ "fixed">
                        <span class="badge bg-primary">Fixed: #listLast(r.legacyStatus, ':')#</span>
                    <cfelseif r.legacyStatus EQ "fix-err">
                        <span class="badge bg-danger">Error</span>
                    <cfelseif r.legacyStatus EQ "no-system">
                        <span class="badge bg-secondary">No System</span>
                    <cfelse>
                        <span class="badge bg-warning text-dark">No Source</span>
                    </cfif>
                </td>

                <!--- UH API ID --->
                <td>
                    <cfif r.apiIdStatus EQ "ok">
                        <span class="badge bg-success">OK</span>
                    <cfelseif r.apiIdStatus EQ "fixed">
                        <span class="badge bg-primary">Fixed</span>
                    <cfelseif r.apiIdStatus EQ "missing-not-in-api">
                        <span class="badge bg-danger">Not in API</span>
                    <cfelseif r.apiIdStatus EQ "api-err">
                        <span class="badge bg-danger">API Err</span>
                    <cfelse>
                        <span class="badge bg-warning text-dark">Missing</span>
                    </cfif>
                </td>

                <!--- Fixes applied --->
                <td>
                    <cfif arrayLen(r.fixes) GT 0>
                        <ul class="mb-0 ps-3">
                        <cfloop array="#r.fixes#" item="fx">
                            <li>#encodeForHTML(fx)#</li>
                        </cfloop>
                        </ul>
                    <cfelse>
                        <span class="text-muted">—</span>
                    </cfif>
                </td>

                <!--- Remaining issues --->
                <td>
                    <cfif arrayLen(r.issues) GT 0>
                        <ul class="mb-0 ps-3">
                        <cfloop array="#r.issues#" item="iss">
                            <li class="text-danger">#encodeForHTML(iss)#</li>
                        </cfloop>
                        </ul>
                    <cfelse>
                        <span class="text-muted">—</span>
                    </cfif>
                </td>
            </tr>
        </cfloop>
        </tbody>
    </table>
    </div>

    <p class="text-muted mt-2" style="font-size:0.8rem;">
        Org badge key: <strong>AC</strong> = Academic Programs, <strong>OD</strong> = OD Program.
        Blue rows = fixes were applied. Red rows = issues remain after attempted fixes.
    </p>
</cfif>
</cfoutput></cfsavecontent>

<cfinclude template="/dir/admin/layout.cfm">
