<!---
    CS-migration.cfm
    Current Students Migration & Compare

    Grad_Year window logic:
      Memorial Day = last Monday of May for the current calendar year.
      Before Memorial Day : startYear = current year      (e.g. 2026 returns 2026-2029)
      On/After Memorial Day : startYear = current year + 1 (e.g. 2027 returns 2027-2030)
      The query returns 4 classes of currently enrolled students: startYear through startYear + 3.
--->

<!---  API credentials (mirrors uh_people_import pattern)  --->
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

<!---  Single-person API lookup (POST from Actions button)  --->
<cfparam name="form.lookupFirst"  default="">
<cfparam name="form.lookupLast"   default="">
<cfparam name="form.lookupMaiden" default="">
<cfparam name="form.quickInsert"  default="0">
<cfparam name="form.batchImport"  default="0">
<cfparam name="form.qiFirst"      default="">
<cfparam name="form.qiLast"       default="">
<cfparam name="form.qiMiddle"     default="">
<cfparam name="form.qiEmail"      default="">
<cfparam name="form.qiPsoft"      default="">
<cfparam name="form.qiCougarNet"  default="">
<cfparam name="form.qiGradYear"   default="">
<cfparam name="form.qiApiId"      default="">
<cfset singleLookupResult   = {}>
<cfset singleLookupDone     = false>
<cfset quickInsertResult    = {done=false, success=false, message="", firstName="", lastName="", userID=0}>
<cfset batchImportResult    = {run=false}>
<cfset batchResultIdx       = {}>

<cfif cgi.request_method EQ "POST" AND form.quickInsert EQ "1">
    <cfsilent>
        <cfset qiSteps    = []>   <!--- step-by-step result log --->
        <cfset qiNewUserID = 0>
        <cfset qiSuccess   = false>
        <cfset qiErrMsg    = "">

        <!--- Step 1: Create user --->
        <cftry>
            <cfset qiUsersService = createObject("component", "dir.cfc.users_service").init()>
            <cfset qiResult = qiUsersService.createUser({
                FirstName      = trim(form.qiFirst),
                MiddleName     = trim(form.qiMiddle),
                LastName       = trim(form.qiLast),
                PreferredName  = "",
                Pronouns       = "",
                EmailPrimary   = "",
                EmailSecondary = trim(form.qiEmail),
                Phone          = "",
                Room           = "",
                Building       = "",
                Title1         = "OD Student",
                Title2         = "",
                Title3         = "",
                UH_API_ID      = trim(form.qiApiId)
            })>
            <cfif NOT qiResult.success>
                <cfthrow message="#qiResult.message#">
            </cfif>
            <cfset qiNewUserID = val(qiResult.userID)>
            <cfset qiSuccess   = true>
            <cfset arrayAppend(qiSteps, "user:ok:#qiNewUserID#")>
        <cfcatch>
            <cfset qiErrMsg = cfcatch.message>
            <cfset arrayAppend(qiSteps, "user:err:#cfcatch.message#")>
        </cfcatch>
        </cftry>

        <cfif qiSuccess AND qiNewUserID GT 0>

            <!--- Step 2: External IDs --->
            <cftry>
                <cfset qiExtIDSvc    = createObject("component", "dir.cfc.externalID_service").init()>
                <cfset qiSystemsArr  = qiExtIDSvc.getSystems().data>
                <cfset qiPsoftSysID  = 0>
                <cfset qiCougarSysID = 0>
                <cfloop from="1" to="#arrayLen(qiSystemsArr)#" index="qisi">
                    <cfset qisLC = lCase(trim(qiSystemsArr[qisi].SYSTEMNAME))>
                    <cfif qisLC EQ "peoplesoft"><cfset qiPsoftSysID  = qiSystemsArr[qisi].SYSTEMID></cfif>
                    <cfif qisLC EQ "cougarnet"> <cfset qiCougarSysID = qiSystemsArr[qisi].SYSTEMID></cfif>
                </cfloop>
                <cfif qiPsoftSysID GT 0 AND len(trim(form.qiPsoft))>
                    <cfset qiExtIDSvc.setExternalID(qiNewUserID, qiPsoftSysID, trim(form.qiPsoft))>
                </cfif>
                <cfif qiCougarSysID GT 0 AND len(trim(form.qiCougarNet))>
                    <cfset qiExtIDSvc.setExternalID(qiNewUserID, qiCougarSysID, trim(form.qiCougarNet))>
                </cfif>
                <cfset arrayAppend(qiSteps, "extids:ok")>
            <cfcatch>
                <cfset arrayAppend(qiSteps, "extids:err:#cfcatch.message#")>
            </cfcatch>
            </cftry>

            <!--- Step 3: Academic / GradYear --->
            <cftry>
                <cfset qiAcadSvc  = createObject("component", "dir.cfc.academic_service").init()>
                <cfset qiGradYr   = trim(form.qiGradYear)>
                <cfif len(qiGradYr) AND isNumeric(qiGradYr) AND val(qiGradYr) GT 0>
                    <cfset qiAcadSvc.saveAcademicInfo(qiNewUserID, qiGradYr, "")>
                    <cfset arrayAppend(qiSteps, "gradyr:ok:#qiGradYr#")>
                <cfelse>
                    <cfset arrayAppend(qiSteps, "gradyr:skip")>
                </cfif>
            <cfcatch>
                <cfset arrayAppend(qiSteps, "gradyr:err:#cfcatch.message#")>
            </cfcatch>
            </cftry>

            <!--- Step 4: Flag (Current-Student) --->
            <cftry>
                <cfset qiFlagsService = createObject("component", "dir.cfc.flags_service").init()>
                <cfset qiFlagsAll     = qiFlagsService.getAllFlags().data>
                <cfset qiCurrStudentFlagID = 0>
                <cfloop from="1" to="#arrayLen(qiFlagsAll)#" index="qifi">
                    <cfif lCase(trim(qiFlagsAll[qifi].FLAGNAME)) EQ "current-student">
                        <cfset qiCurrStudentFlagID = val(qiFlagsAll[qifi].FLAGID)>
                        <cfbreak>
                    </cfif>
                </cfloop>
                <cfif qiCurrStudentFlagID GT 0>
                    <cfset qiFlagsService.addFlag(qiNewUserID, qiCurrStudentFlagID)>
                    <cfset arrayAppend(qiSteps, "flag:ok:#qiCurrStudentFlagID#")>
                <cfelse>
                    <cfset arrayAppend(qiSteps, "flag:notfound")>
                </cfif>
            <cfcatch>
                <cfset arrayAppend(qiSteps, "flag:err:#cfcatch.message#")>
            </cfcatch>
            </cftry>

            <!--- Step 5: Orgs (Academic Programs + OD Program) --->
            <cftry>
                <cfset qiOrgsService = createObject("component", "dir.cfc.organizations_service").init()>
                <cfset qiAllOrgs     = qiOrgsService.getAllOrgs().data>
                <cfset qiOrgIDs      = []>
                <cfloop from="1" to="#arrayLen(qiAllOrgs)#" index="qioi">
                    <cfset qioName = trim(qiAllOrgs[qioi].ORGNAME)>
                    <cfif qioName EQ "Academic Programs" OR qioName EQ "OD Program">
                        <cfset arrayAppend(qiOrgIDs, val(qiAllOrgs[qioi].ORGID))>
                    </cfif>
                </cfloop>
                <cfloop from="1" to="#arrayLen(qiOrgIDs)#" index="qioidx">
                    <cfset qiOrgsService.assignOrg(qiNewUserID, qiOrgIDs[qioidx])>
                </cfloop>
                <cfset arrayAppend(qiSteps, "orgs:ok:#arrayLen(qiOrgIDs)#")>
            <cfcatch>
                <cfset arrayAppend(qiSteps, "orgs:err:#cfcatch.message#")>
            </cfcatch>
            </cftry>

        </cfif>

        <cfset quickInsertResult = {
            done      = true,
            success   = qiSuccess,
            message   = qiSuccess ? "Created (ID: #qiNewUserID#)" : qiErrMsg,
            steps     = qiSteps,
            firstName = trim(form.qiFirst),
            lastName  = trim(form.qiLast),
            userID    = qiNewUserID
        }>
    </cfsilent>
<cfelseif cgi.request_method EQ "POST" AND len(trim(form.lookupFirst)) AND len(trim(form.lookupLast))>
    <cfsilent>
        <cftry>
            <cfset uhApi         = createObject("component", "dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
            <cfset peopleResp    = uhApi.getPeople(student=true, staff=false, faculty=false, department="H0113", q=trim(form.lookupLast))>
            <cfset apiPeople     = []>
            <cfif left(peopleResp.statusCode, 3) EQ "200">
                <cfset rData = peopleResp.data ?: {}>
                <cfif isStruct(rData) AND structKeyExists(rData, "data") AND isArray(rData.data)>
                    <cfset apiPeople = rData.data>
                <cfelseif isArray(rData)>
                    <cfset apiPeople = rData>
                </cfif>
            </cfif>

            <cfset searchFirst  = lCase(trim(form.lookupFirst))>
            <cfset searchLast   = lCase(trim(form.lookupLast))>
            <cfset searchMaiden = lCase(trim(form.lookupMaiden))>
            <cfset foundPerson  = {}>

            <cfloop from="1" to="#arrayLen(apiPeople)#" index="ap">
                <cfset p = apiPeople[ap]>
                <cfset apFirst = lCase(trim(p.first_name ?: p.firstName ?: ""))>
                <cfset apLast  = lCase(trim(p.last_name  ?: p.lastName  ?: ""))>
                <cfif apFirst EQ searchFirst AND (apLast EQ searchLast OR (len(searchMaiden) AND apLast EQ searchMaiden))>
                    <cfset foundPerson = p>
                    <cfbreak>
                </cfif>
            </cfloop>

            <cfset singleLookupResult = {
                firstName = form.lookupFirst,
                lastName  = form.lookupLast,
                found     = NOT structIsEmpty(foundPerson),
                apiId     = structIsEmpty(foundPerson) ? "" : trim(foundPerson.id ?: ""),
                raw       = foundPerson
            }>
            <cfset singleLookupDone = true>
        <cfcatch>
            <cfset singleLookupResult = {
                firstName = form.lookupFirst,
                lastName  = form.lookupLast,
                found     = false,
                apiId     = "",
                error     = cfcatch.message
            }>
            <cfset singleLookupDone = true>
        </cfcatch>
        </cftry>
    </cfsilent>
<cfelseif cgi.request_method EQ "POST" AND form.batchImport EQ "1">
    <cfsilent>
        <cfsetting requesttimeout="600">

        <!--- Local column-lookup helper (cffunction at page scope, available throughout this block) --->
        <cffunction name="bGetCol" access="private" returntype="string" output="false">
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

        <cfset bErr = "">

        <!--- Re-derive year window --->
        <cfset bYear   = year(now())>
        <cfset bMay31  = createDate(bYear, 5, 31)>
        <cfset bDow    = dayOfWeek(bMay31)>
        <cfset bBack   = (bDow - 2 + 7) MOD 7>
        <cfset bMemDay = dateAdd("d", -bBack, bMay31)>
        <cfset bStart  = (now() LT bMemDay) ? bYear : bYear + 1>
        <cfset bMaxYr  = bStart + 3>

        <cftry>
            <cfset bAlumQ = queryExecute(
                "SELECT * FROM AlumniStudent WHERE GradYear BETWEEN :s AND :m AND Active = 1 AND Directory = 1 ORDER BY GradYear ASC, LastName, FirstName",
                { s={value=bStart,cfsqltype="cf_sql_integer"}, m={value=bMaxYr,cfsqltype="cf_sql_integer"} },
                { datasource="oldUHCOdirectory", timeout=60 }
            )>
        <cfcatch>
            <cfset bErr = "Query failed: " & cfcatch.message>
        </cfcatch>
        </cftry>

        <cfif NOT len(bErr)>
            <!--- Dedup --->
            <cfset bSeen = {}>
            <cfset bRows = []>
            <cfset bCols = listToArray(bAlumQ.columnList)>
            <cfloop from="1" to="#bAlumQ.recordCount#" index="bi">
                <cfset bPts = []>
                <cfloop array="#bCols#" item="bc"><cfset arrayAppend(bPts, toString(bAlumQ[bc][bi]))></cfloop>
                <cfset bRK = arrayToList(bPts, "|")>
                <cfif NOT structKeyExists(bSeen, bRK)>
                    <cfset bSeen[bRK] = true>
                    <cfset bR = {}>
                    <cfloop array="#bCols#" item="bc"><cfset bR[bc] = bAlumQ[bc][bi]></cfloop>
                    <cfset arrayAppend(bRows, bR)>
                </cfif>
            </cfloop>

            <!--- Local Users name index --->
            <cfset bUsSvc = createObject("component","dir.cfc.users_service").init()>
            <cfset bLUAll = bUsSvc.listUsers()>
            <cfset bNIdx  = {}>
            <cfloop array="#bLUAll#" item="blu">
                <cfset bluf = lCase(trim(blu.FIRSTNAME ?: ""))>
                <cfset blul = lCase(trim(blu.LASTNAME  ?: ""))>
                <cfif len(bluf) AND len(blul)><cfset bNIdx[bluf & "|" & blul] = true></cfif>
            </cfloop>

            <!--- Pre-resolve services and IDs once --->
            <cfset bExtSvc = createObject("component","dir.cfc.externalID_service").init()>
            <cfset bFlgSvc = createObject("component","dir.cfc.flags_service").init()>
            <cfset bOrgSvc = createObject("component","dir.cfc.organizations_service").init()>
            <cfset bAcdSvc = createObject("component","dir.cfc.academic_service").init()>
            <cfset bApi    = createObject("component","dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>

            <cfset bFlgID = 0>
            <cfloop array="#bFlgSvc.getAllFlags().data#" item="bfl">
                <cfif lCase(trim(bfl.FLAGNAME)) EQ "current-student">
                    <cfset bFlgID = val(bfl.FLAGID)><cfbreak>
                </cfif>
            </cfloop>

            <cfset bOrgIDs = []>
            <cfloop array="#bOrgSvc.getAllOrgs().data#" item="borg">
                <cfif trim(borg.ORGNAME) EQ "Academic Programs" OR trim(borg.ORGNAME) EQ "OD Program">
                    <cfset arrayAppend(bOrgIDs, val(borg.ORGID))>
                </cfif>
            </cfloop>

            <cfset bPsoftID = 0>
            <cfset bCguarID = 0>
            <cfloop array="#bExtSvc.getSystems().data#" item="bsys">
                <cfset bslc = lCase(trim(bsys.SYSTEMNAME))>
                <cfif bslc EQ "peoplesoft"><cfset bPsoftID = bsys.SYSTEMID></cfif>
                <cfif bslc EQ "cougarnet"> <cfset bCguarID = bsys.SYSTEMID></cfif>
            </cfloop>

            <!--- Process each row not already in Users --->
            <cfset bResults  = []>
            <cfset bTotProc  = 0>
            <cfset bTotIns   = 0>
            <cfset bTotFound = 0>
            <cfset bTotMiss  = 0>
            <cfset bTotErr   = 0>

            <cfloop array="#bRows#" item="bsrc">
                <cfset bFN  = bGetCol(bsrc, ["FirstName","First_Name","fname","F_Name"])>
                <cfset bLN  = bGetCol(bsrc, ["LastName","Last_Name","lname","L_Name"])>
                <cfset bMid = bGetCol(bsrc, ["MiddleName","Middle_Name","MiddleInitial","MI"])>
                <cfset bMdn = bGetCol(bsrc, ["MaidenName","Maiden_Name","MaidenLastName","Maiden"])>
                <cfset bEm  = bGetCol(bsrc, ["Email","EmailAddress","Email_Address","UH_Email","UHEmail"])>
                <cfset bPS  = bGetCol(bsrc, ["Psoft","PSoft","PeopleSoft","PeopleSoftID"])>
                <cfset bCN  = bGetCol(bsrc, ["CougarNet","CougarNetID","CougarNetId","CougaNet"])>
                <cfset bGY  = bGetCol(bsrc, ["GradYear","Grad_Year","GraduationYear","Graduation_Year"])>

                <!--- Only process rows not already in Users --->
                <cfset bNK = lCase(bFN) & "|" & lCase(bLN)>
                <cfif NOT (len(bFN) AND len(bLN) AND structKeyExists(bNIdx, bNK))>
                    <cfset bTotProc++>
                    <cfset bPR = { firstName=bFN, lastName=bLN, gradYear=bGY,
                                   apiFound=false, apiId="", inserted=false,
                                   userID=0, steps=[], error="" }>

                    <!--- API lookup --->
                    <cftry>
                        <cfset bResp = bApi.getPeople(student=true, staff=false, faculty=false, department="H0113", q=bLN)>
                        <cfset bPpl  = []>
                        <cfif left(bResp.statusCode, 3) EQ "200">
                            <cfset bRD = bResp.data ?: {}>
                            <cfif isStruct(bRD) AND structKeyExists(bRD,"data") AND isArray(bRD.data)>
                                <cfset bPpl = bRD.data>
                            <cfelseif isArray(bRD)>
                                <cfset bPpl = bRD>
                            </cfif>
                        </cfif>
                        <cfset bMatch = {}>
                        <cfloop array="#bPpl#" item="bap">
                            <cfset bapF = lCase(trim(bap.first_name ?: bap.firstName ?: ""))>
                            <cfset bapL = lCase(trim(bap.last_name  ?: bap.lastName  ?: ""))>
                            <cfif bapF EQ lCase(bFN) AND (bapL EQ lCase(bLN) OR (len(bMdn) AND bapL EQ lCase(bMdn)))>
                                <cfset bMatch = bap><cfbreak>
                            </cfif>
                        </cfloop>

                        <cfif NOT structIsEmpty(bMatch)>
                            <cfset bPR.apiFound = true>
                            <cfset bPR.apiId    = trim(bMatch.id ?: "")>
                            <cfset bTotFound++>

                            <!--- Insert user --->
                            <cftry>
                                <cfset bCrRes = bUsSvc.createUser({
                                    FirstName=bFN, MiddleName=bMid, LastName=bLN,
                                    PreferredName="", Pronouns="",
                                    EmailPrimary="", EmailSecondary=bEm,
                                    Phone="", Room="", Building="",
                                    Title1="OD Student", Title2="", Title3="",
                                    UH_API_ID=bPR.apiId
                                })>
                                <cfif NOT bCrRes.success><cfthrow message="#bCrRes.message#"></cfif>
                                <cfset bNUID = val(bCrRes.userID)>
                                <cfset bPR.inserted = true>
                                <cfset bPR.userID   = bNUID>
                                <cfset bTotIns++>
                                <cfset arrayAppend(bPR.steps, "user:ok:#bNUID#")>

                                <cftry>
                                    <cfif bPsoftID GT 0 AND len(bPS)><cfset bExtSvc.setExternalID(bNUID,bPsoftID,bPS)></cfif>
                                    <cfif bCguarID GT 0 AND len(bCN)><cfset bExtSvc.setExternalID(bNUID,bCguarID,bCN)></cfif>
                                    <cfset arrayAppend(bPR.steps, "extids:ok")>
                                <cfcatch><cfset arrayAppend(bPR.steps, "extids:err:#cfcatch.message#")></cfcatch>
                                </cftry>

                                <cftry>
                                    <cfif len(bGY) AND isNumeric(bGY) AND val(bGY) GT 0>
                                        <cfset bAcdSvc.saveAcademicInfo(bNUID, bGY, "")>
                                        <cfset arrayAppend(bPR.steps, "gradyr:ok:#bGY#")>
                                    <cfelse>
                                        <cfset arrayAppend(bPR.steps, "gradyr:skip")>
                                    </cfif>
                                <cfcatch><cfset arrayAppend(bPR.steps, "gradyr:err:#cfcatch.message#")></cfcatch>
                                </cftry>

                                <cftry>
                                    <cfif bFlgID GT 0>
                                        <cfset bFlgSvc.addFlag(bNUID, bFlgID)>
                                        <cfset arrayAppend(bPR.steps, "flag:ok")>
                                    <cfelse>
                                        <cfset arrayAppend(bPR.steps, "flag:notfound")>
                                    </cfif>
                                <cfcatch><cfset arrayAppend(bPR.steps, "flag:err:#cfcatch.message#")></cfcatch>
                                </cftry>

                                <cftry>
                                    <cfloop array="#bOrgIDs#" item="boid">
                                        <cfset bOrgSvc.assignOrg(bNUID, boid)>
                                    </cfloop>
                                    <cfset arrayAppend(bPR.steps, "orgs:ok:#arrayLen(bOrgIDs)#")>
                                <cfcatch><cfset arrayAppend(bPR.steps, "orgs:err:#cfcatch.message#")></cfcatch>
                                </cftry>

                                <!--- Mark as inserted so duplicates later in the list are skipped --->
                                <cfset bNIdx[bNK] = true>
                            <cfcatch>
                                <cfset bPR.error = cfcatch.message>
                                <cfset bTotErr++>
                                <cfset arrayAppend(bPR.steps, "user:err:#cfcatch.message#")>
                            </cfcatch>
                            </cftry>
                        <cfelse>
                            <cfset bTotMiss++>
                        </cfif>
                    <cfcatch>
                        <cfset bPR.error = "API error: " & cfcatch.message>
                        <cfset bTotErr++>
                    </cfcatch>
                    </cftry>

                    <cfset arrayAppend(bResults, bPR)>
                </cfif>
            </cfloop>

            <cfset batchImportResult = {
                run=true, totalProcessed=bTotProc, totalInserted=bTotIns,
                totalFound=bTotFound, totalNotFound=bTotMiss, totalErrors=bTotErr,
                results=bResults
            }>
            <cfloop array="#bResults#" item="bir">
                <cfset batchResultIdx[lCase(bir.firstName) & "|" & lCase(bir.lastName)] = bir>
            </cfloop>
        <cfelse>
            <cfset batchImportResult = {
                run=true, error=bErr,
                totalProcessed=0, totalInserted=0, totalFound=0, totalNotFound=0, totalErrors=0,
                results=[]
            }>
        </cfif>
    </cfsilent>
</cfif>

<!---  Determine Memorial Day (last Monday of May)  --->
<cfset currentYear  = year(now())>
<cfset may31        = createDate(currentYear, 5, 31)>
<cfset dowMay31     = dayOfWeek(may31)>
<cfset daysBack     = (dowMay31 - 2 + 7) MOD 7>
<cfset memorialDay  = dateAdd("d", -daysBack, may31)>

<!---  Derive the 4-year Grad_Year window  --->
<cfif now() LT memorialDay>
    <cfset startYear = currentYear>
<cfelse>
    <cfset startYear = currentYear + 1>
</cfif>
<cfset maxYear = startYear + 3>

<!---  Query  --->
<cfset alumniQuery = queryExecute(
    "
    SELECT *
    FROM   AlumniStudent
    WHERE  GradYear BETWEEN :startYear AND :maxYear
      AND  Active    = 1
      AND  Directory = 1
    ORDER  BY GradYear ASC, LastName, FirstName
    ",
    {
        startYear = { value = startYear, cfsqltype = "cf_sql_integer" },
        maxYear   = { value = maxYear,   cfsqltype = "cf_sql_integer" }
    },
    { datasource = "oldUHCOdirectory", timeout = 30 }
)>

<!--- Deduplicate: fingerprint each row across all columns --->
<cfset seenKeys  = {}>
<cfset dedupedRows = []>
<cfset dupCount  = 0>
<cfset colList   = alumniQuery.columnList>
<cfset columns   = listToArray(colList)>

<cfloop from="1" to="#alumniQuery.recordCount#" index="r">
    <cfset parts = []>
    <cfloop from="1" to="#arrayLen(columns)#" index="c">
        <cfset arrayAppend(parts, toString(alumniQuery[columns[c]][r]))>
    </cfloop>
    <cfset rowKey = arrayToList(parts, "|")>
    <cfif NOT structKeyExists(seenKeys, rowKey)>
        <cfset seenKeys[rowKey] = true>
        <cfset row = {}>
        <cfloop from="1" to="#arrayLen(columns)#" index="c">
            <cfset row[columns[c]] = alumniQuery[columns[c]][r]>
        </cfloop>
        <cfset arrayAppend(dedupedRows, row)>
    <cfelse>
        <cfset dupCount++>
    </cfif>
</cfloop>

<!--- ── Build local Users name index ── --->
<cfset usersService   = createObject("component", "dir.cfc.users_service").init()>
<cfset localUsers     = usersService.listUsers()>
<cfset localNameIndex = {}>

<!--- ── Resolve fixed mapping targets ── --->
<cfset flagsService      = createObject("component", "dir.cfc.flags_service").init()>
<cfset orgsService       = createObject("component", "dir.cfc.organizations_service").init()>
<cfset externalIDService = createObject("component", "dir.cfc.externalID_service").init()>

<cfset currentStudentFlagID = 0>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfloop from="1" to="#arrayLen(allFlagsResult.data)#" index="fi">
    <cfif lCase(trim(allFlagsResult.data[fi].FLAGNAME)) EQ "current-student">
        <cfset currentStudentFlagID = allFlagsResult.data[fi].FLAGID>
        <cfbreak>
    </cfif>
</cfloop>

<cfset targetOrgNames = ["Academic Programs", "OD Program"]>
<cfset targetOrgIDs   = []>
<cfset foundOrgNames  = []>
<cfset allOrgsResult  = orgsService.getAllOrgs()>
<cfloop from="1" to="#arrayLen(allOrgsResult.data)#" index="oi">
    <cfif arrayFindNoCase(targetOrgNames, trim(allOrgsResult.data[oi].ORGNAME))>
        <cfset arrayAppend(targetOrgIDs,  allOrgsResult.data[oi].ORGID)>
        <cfset arrayAppend(foundOrgNames, trim(allOrgsResult.data[oi].ORGNAME))>
    </cfif>
</cfloop>

<cfset psoftSystemID    = 0>
<cfset cougarNetSystemID = 0>
<cfset allSystemsResult = externalIDService.getSystems()>
<cfloop from="1" to="#arrayLen(allSystemsResult.data)#" index="si">
    <cfset sysNameLC = lCase(trim(allSystemsResult.data[si].SYSTEMNAME))>
    <cfif sysNameLC EQ "peoplesoft">
        <cfset psoftSystemID = allSystemsResult.data[si].SYSTEMID>
    </cfif>
    <cfif sysNameLC EQ "cougarnet">
        <cfset cougarNetSystemID = allSystemsResult.data[si].SYSTEMID>
    </cfif>
</cfloop>

<cfloop from="1" to="#arrayLen(localUsers)#" index="u">
    <cfset lu      = localUsers[u]>
    <cfset luFirst = lCase(trim(lu.FIRSTNAME ?: ""))>
    <cfset luLast  = lCase(trim(lu.LASTNAME  ?: ""))>
    <cfif len(luFirst) AND len(luLast)>
        <cfset localNameIndex[luFirst & "|" & luLast] = true>
    </cfif>
</cfloop>

<!---  Helper: first non-empty match across candidate column names  --->
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

<!---  Map each deduped row; tag if it matches the just-looked-up name  --->
<cfset mappedRows   = []>
<cfset matchCount   = 0>
<cfset noMatchCount = 0>

<cfloop from="1" to="#arrayLen(dedupedRows)#" index="r">
    <cfset src = dedupedRows[r]>
    <cfset mapped = {}>
    <cfset mapped.FirstName      = getColVal(src, ["FirstName",  "First_Name",   "fname",          "F_Name"])>
    <cfset mapped.LastName       = getColVal(src, ["LastName",   "Last_Name",    "lname",           "L_Name"])>
    <cfset mapped.MiddleName     = getColVal(src, ["MiddleName", "Middle_Name",  "MiddleInitial",   "MI"])>
    <cfset mapped.EmailSecondary = getColVal(src, ["Email", "EmailAddress", "Email_Address", "UH_Email", "UHEmail"])>
    <cfset mapped.PsoftID        = getColVal(src, ["Psoft", "PSoft", "PeopleSoft", "PeopleSoftID"])>
    <cfset mapped.CougarNetExtID = getColVal(src, ["CougarNet", "CougarNetID", "CougarNetId", "CougaNet"])>
    <cfset mapped.GradYear       = getColVal(src, ["GradYear",   "Grad_Year",    "GraduationYear",  "Graduation_Year"])>
    <cfset mapped.MaidenName     = getColVal(src, ["MaidenName", "Maiden_Name",  "MaidenLastName",  "Maiden"])>

    <cfset nameKey = lCase(mapped.FirstName) & "|" & lCase(mapped.LastName)>
    <cfset mapped.inUsers = (len(mapped.FirstName) AND len(mapped.LastName) AND structKeyExists(localNameIndex, nameKey))>

    <!--- Carry over API lookup result if this row was the one just checked  --->
    <cfset mapped.apiLookupDone   = false>
    <cfset mapped.apiFound        = false>
    <cfset mapped.apiId           = "">
    <cfset mapped.apiLookupError  = "">
    <cfif singleLookupDone
          AND lCase(trim(mapped.FirstName)) EQ lCase(trim(singleLookupResult.firstName ?: ""))
          AND lCase(trim(mapped.LastName))  EQ lCase(trim(singleLookupResult.lastName  ?: ""))>
        <cfset mapped.apiLookupDone  = true>
        <cfset mapped.apiFound       = singleLookupResult.found ?: false>
        <cfset mapped.apiId          = singleLookupResult.apiId ?: "">
        <cfset mapped.apiLookupError = singleLookupResult.error ?: "">
    </cfif>

    <cfif mapped.inUsers>
        <cfset matchCount++>
    <cfelse>
        <cfset noMatchCount++>
    </cfif>

    <cfset arrayAppend(mappedRows, mapped)>
</cfloop>

<!---  Build the output table  --->
<cfset tableHtml = "
<div class='table-responsive mt-4'>
<table class='table table-sm table-bordered align-middle'>
    <thead class='table-dark'>
        <tr>
            <th>Status</th>
            <th>Grad Year</th>
            <th>First Name</th>
            <th>Middle</th>
            <th>Last Name</th>
            <th>Maiden Name</th>
            <th>Email &rarr; Secondary</th>
            <th>PeopleSoft ID</th>
            <th>CougarNet ID</th>
            <th>Actions</th>
        </tr>
    </thead>
    <tbody>
">

<cfloop from="1" to="#arrayLen(mappedRows)#" index="r">
    <cfset m = mappedRows[r]>
    <cfif m.inUsers>
        <cfset statusBadge = "<span class='badge bg-success'>Match Found</span>">
        <cfset rowClass    = "">
    <cfelse>
        <cfset statusBadge = "<span class='badge bg-warning text-dark'>Not in Users</span>">
        <cfset rowClass    = " class='table-warning'">
    </cfif>

    <!--- Actions cell --->
    <cfset mRowKey = lCase(m.FirstName) & "|" & lCase(m.LastName)>
    <cfif batchImportResult.run AND NOT m.inUsers AND structKeyExists(batchResultIdx, mRowKey)>
        <cfset birRow = batchResultIdx[mRowKey]>
        <cfif birRow.inserted>
            <cfset bStepHtml = "">
            <cfloop array="#birRow.steps#" item="bSt">
                <cfif left(bSt,7) EQ "user:ok">
                    <cfset bStepHtml &= " <span class='badge bg-success' title='User created'>user</span>">
                <cfelseif left(bSt,9) EQ "extids:ok">
                    <cfset bStepHtml &= " <span class='badge bg-success' title='External IDs'>ext IDs</span>">
                <cfelseif left(bSt,10) EQ "extids:err">
                    <cfset bStepHtml &= " <span class='badge bg-warning text-dark' title='Ext ID error'>ext IDs!</span>">
                <cfelseif left(bSt,8) EQ "gradyr:ok">
                    <cfset bStepHtml &= " <span class='badge bg-success' title='Grad year saved'>grad yr</span>">
                <cfelseif left(bSt,11) EQ "gradyr:skip">
                    <cfset bStepHtml &= " <span class='badge bg-secondary' title='Grad year blank'>grad yr</span>">
                <cfelseif left(bSt,10) EQ "gradyr:err">
                    <cfset bStepHtml &= " <span class='badge bg-warning text-dark' title='Grad yr error'>grad yr!</span>">
                <cfelseif left(bSt,7) EQ "flag:ok">
                    <cfset bStepHtml &= " <span class='badge bg-success' title='Current-Student flag'>flag</span>">
                <cfelseif left(bSt,13) EQ "flag:notfound">
                    <cfset bStepHtml &= " <span class='badge bg-danger' title='Current-Student not found in DB'>flag?</span>">
                <cfelseif left(bSt,8) EQ "flag:err">
                    <cfset bStepHtml &= " <span class='badge bg-warning text-dark' title='Flag error'>flag!</span>">
                <cfelseif left(bSt,7) EQ "orgs:ok">
                    <cfset bStepHtml &= " <span class='badge bg-success' title='Orgs assigned'>orgs(#listLast(bSt,':')#)</span>">
                <cfelseif left(bSt,8) EQ "orgs:err">
                    <cfset bStepHtml &= " <span class='badge bg-warning text-dark' title='Orgs error'>orgs!</span>">
                </cfif>
            </cfloop>
            <cfset actionCell = "<span class='badge bg-success'>Batch Inserted</span>#bStepHtml# <a href='/dir/admin/users/edit.cfm?userID=#birRow.userID#' class='btn btn-xs btn-outline-success ms-1' style='font-size:0.75rem;padding:1px 6px;'>Edit</a>">
        <cfelseif birRow.apiFound>
            <cfset actionCell = "<span class='badge bg-warning text-dark'>Insert Failed</span> <small class='text-muted ms-1'>#EncodeForHTML(birRow.error)#</small>">
        <cfelseif len(birRow.error)>
            <cfset actionCell = "<span class='badge bg-danger'>Batch Error</span> <small class='text-muted ms-1'>#EncodeForHTML(birRow.error)#</small>">
        <cfelse>
            <cfset actionCell = "<span class='badge bg-secondary'>Not in API</span>">
        </cfif>
    <cfelseif quickInsertResult.done
          AND lCase(m.FirstName) EQ lCase(quickInsertResult.firstName)
          AND lCase(m.LastName)  EQ lCase(quickInsertResult.lastName)>
        <cfif quickInsertResult.success>
            <cfset qiStepHtml = "">
            <cfloop array="#quickInsertResult.steps#" item="qiStep">
                <cfif left(qiStep,7) EQ "user:ok">
                    <cfset qiStepHtml &= " <span class='badge bg-success' title='User created'>user</span>">
                <cfelseif left(qiStep,9) EQ "extids:ok">
                    <cfset qiStepHtml &= " <span class='badge bg-success' title='External IDs'>ext IDs</span>">
                <cfelseif left(qiStep,10) EQ "extids:err">
                    <cfset qiStepHtml &= " <span class='badge bg-warning text-dark' title='Ext ID error'>ext IDs!</span>">
                <cfelseif left(qiStep,8) EQ "gradyr:ok">
                    <cfset qiStepHtml &= " <span class='badge bg-success' title='Grad year saved'>grad yr</span>">
                <cfelseif left(qiStep,11) EQ "gradyr:skip">
                    <cfset qiStepHtml &= " <span class='badge bg-secondary' title='Grad year blank'>grad yr</span>">
                <cfelseif left(qiStep,10) EQ "gradyr:err">
                    <cfset qiStepHtml &= " <span class='badge bg-warning text-dark' title='Grad yr error'>grad yr!</span>">
                <cfelseif left(qiStep,7) EQ "flag:ok">
                    <cfset qiStepHtml &= " <span class='badge bg-success' title='Current-Student flag'>flag</span>">
                <cfelseif left(qiStep,13) EQ "flag:notfound">
                    <cfset qiStepHtml &= " <span class='badge bg-danger' title='Current-Student not found in DB'>flag?</span>">
                <cfelseif left(qiStep,8) EQ "flag:err">
                    <cfset qiStepHtml &= " <span class='badge bg-warning text-dark' title='Flag error'>flag!</span>">
                <cfelseif left(qiStep,7) EQ "orgs:ok">
                    <cfset qiStepHtml &= " <span class='badge bg-success' title='Orgs assigned'>orgs(#listLast(qiStep,':')#)</span>">
                <cfelseif left(qiStep,8) EQ "orgs:err">
                    <cfset qiStepHtml &= " <span class='badge bg-warning text-dark' title='Orgs error'>orgs!</span>">
                </cfif>
            </cfloop>
            <cfset actionCell = "<span class='badge bg-success'>Inserted</span>#qiStepHtml# <a href='/dir/admin/users/edit.cfm?userID=#quickInsertResult.userID#' class='btn btn-xs btn-outline-success ms-1' style='font-size:0.75rem;padding:1px 6px;'>Edit</a>">
        <cfelse>
            <cfset actionCell = "<span class='badge bg-danger'>Insert Error</span> <small class='text-muted ms-1'>#EncodeForHTML(quickInsertResult.message)#</small>">
        </cfif>
    <cfelseif m.apiLookupDone>
        <cfif len(m.apiLookupError)>
            <cfset actionCell = "<span class='badge bg-danger'>Error</span> <small class='text-muted'>#EncodeForHTML(m.apiLookupError)#</small>">
        <cfelseif m.apiFound>
            <cfif NOT m.inUsers>
                <cfset actionCell = "<span class='badge bg-success'>API Match</span> <code class='ms-1'>#EncodeForHTML(m.apiId)#</code> <a href='/dir/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(m.apiId)#' class='btn btn-xs btn-outline-primary ms-1' style='font-size:0.75rem;padding:1px 6px;'>Review</a> <form method='post' style='display:inline;'><input type='hidden' name='quickInsert' value='1'><input type='hidden' name='qiFirst' value='#EncodeForHTMLAttribute(m.FirstName)#'><input type='hidden' name='qiLast' value='#EncodeForHTMLAttribute(m.LastName)#'><input type='hidden' name='qiMiddle' value='#EncodeForHTMLAttribute(m.MiddleName)#'><input type='hidden' name='qiEmail' value='#EncodeForHTMLAttribute(m.EmailSecondary)#'><input type='hidden' name='qiPsoft' value='#EncodeForHTMLAttribute(m.PsoftID)#'><input type='hidden' name='qiCougarNet' value='#EncodeForHTMLAttribute(m.CougarNetExtID)#'><input type='hidden' name='qiGradYear' value='#EncodeForHTMLAttribute(m.GradYear)#'><input type='hidden' name='qiApiId' value='#EncodeForHTMLAttribute(m.apiId)#'><button type='submit' class='btn btn-sm btn-success ms-1'>Quick Insert</button></form>">
            <cfelse>
                <cfset actionCell = "<span class='badge bg-success'>API Match</span> <code class='ms-1'>#EncodeForHTML(m.apiId)#</code> <a href='/dir/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(m.apiId)#' class='btn btn-xs btn-outline-primary ms-2' style='font-size:0.75rem;padding:1px 6px;'>Review</a>">
            </cfif>
        <cfelse>
            <cfset actionCell = "<span class='badge bg-secondary'>Not in API</span>">
        </cfif>
    <cfelse>
        <cfset actionCell = "
            <form method='post' style='display:inline;'>
                <input type='hidden' name='lookupFirst'  value='#EncodeForHTMLAttribute(m.FirstName)#'>
                <input type='hidden' name='lookupLast'   value='#EncodeForHTMLAttribute(m.LastName)#'>
                <input type='hidden' name='lookupMaiden' value='#EncodeForHTMLAttribute(m.MaidenName)#'>
                <button type='submit' class='btn btn-sm btn-outline-secondary'>Check API</button>
            </form>
        ">
    </cfif>

    <cfset tableHtml &= "
        <tr#rowClass#>
            <td>#statusBadge#</td>
            <td>#EncodeForHTML(m.GradYear)#</td>
            <td>#EncodeForHTML(m.FirstName)#</td>
            <td>#EncodeForHTML(m.MiddleName)#</td>
            <td>#EncodeForHTML(m.LastName)#</td>
            <td>#EncodeForHTML(m.MaidenName)#</td>
            <td>#EncodeForHTML(m.EmailSecondary)#</td>
            <td>#EncodeForHTML(m.PsoftID)#</td>
            <td>#EncodeForHTML(m.CougarNetExtID)#</td>
            <td>#actionCell#</td>
        </tr>
    ">
</cfloop>

<cfset tableHtml &= "
    </tbody>
</table>
</div>
">

<cfset flagBadge  = currentStudentFlagID GT 0 ? "<span class='badge bg-primary'>Current-Student</span>" : "<span class='badge bg-danger'>Flag 'Current-Student' not found!</span>">
<cfset orgBadges  = "">
<cfloop from="1" to="#arrayLen(targetOrgNames)#" index="toi">
    <cfset orgFound = arrayFindNoCase(foundOrgNames, targetOrgNames[toi]) GT 0>
    <cfif orgFound>
        <cfset orgBadges &= "<span class='badge bg-primary me-1'>" & EncodeForHTML(targetOrgNames[toi]) & "</span>">
    <cfelse>
        <cfset orgBadges &= "<span class='badge bg-danger me-1'>Org '" & EncodeForHTML(targetOrgNames[toi]) & "' not found!</span>">
    </cfif>
</cfloop>
<cfset psoftBadge     = psoftSystemID GT 0    ? "<span class='badge bg-primary'>PeopleSoft (SystemID ##psoftSystemID##)</span>"    : "<span class='badge bg-danger'>System 'PeopleSoft' not found!</span>">
<cfset cougarNetBadge = cougarNetSystemID GT 0 ? "<span class='badge bg-primary'>CougarNet (SystemID ##cougarNetSystemID##)</span>" : "<span class='badge bg-danger'>System 'CougarNet' not found!</span>">

<!--- Pre-compute for embedding in content string --->
<cfset batchBtnDisabled = noMatchCount EQ 0 ? " disabled" : "">
<cfset batchSummaryHtml = "">
<cfif batchImportResult.run>
    <cfset batchSummaryHtml = "<div class='alert alert-success mb-3'>">
    <cfif structKeyExists(batchImportResult, "error")>
        <cfset batchSummaryHtml &= "<strong>Batch Import Error:</strong> " & encodeForHTML(batchImportResult.error)>
    <cfelse>
        <cfset batchSummaryHtml &= "<strong>Batch Import Complete:</strong>">
        <cfset batchSummaryHtml &= " <span class='badge bg-secondary'>" & batchImportResult.totalProcessed & " checked</span>">
        <cfset batchSummaryHtml &= " <span class='badge bg-success'>" & batchImportResult.totalInserted & " inserted</span>">
        <cfset batchSummaryHtml &= " <span class='badge bg-primary'>" & batchImportResult.totalFound & " found in API</span>">
        <cfset batchSummaryHtml &= " <span class='badge bg-warning text-dark'>" & batchImportResult.totalNotFound & " not in API</span>">
        <cfif batchImportResult.totalErrors GT 0>
            <cfset batchSummaryHtml &= " <span class='badge bg-danger'>" & batchImportResult.totalErrors & " errors</span>">
        </cfif>
    </cfif>
    <cfset batchSummaryHtml &= "</div>">
</cfif>

<cfset content = "
<h1>Current Students Migration &amp; Compare</h1>
<p class='text-muted mb-3'>
    Grad Years <strong>#startYear#</strong> &ndash; <strong>#maxYear#</strong>
    &nbsp;&middot;&nbsp;
    Memorial Day #currentYear#: <strong>#dateFormat(memorialDay, 'mmmm d, yyyy')#</strong>
    &nbsp;&middot;&nbsp;
    #alumniQuery.recordCount# raw &mdash; <strong>#arrayLen(dedupedRows)#</strong> unique (#dupCount# duplicate(s) removed)
</p>
<div class='alert alert-info mb-3'>
    <strong>Applied to all records on import:</strong>
    <div class='mt-2 d-flex flex-wrap gap-3 align-items-center'>
        <div><span class='text-muted me-1'>Flag:</span>#flagBadge#</div>
        <div><span class='text-muted me-1'>Organizations:</span>#orgBadges#</div>
        <div><span class='text-muted me-1'>Title 1:</span><span class='badge bg-secondary'>OD Student</span></div>
        <div><span class='text-muted me-1'>PeopleSoft External ID:</span>#psoftBadge#</div>
        <div><span class='text-muted me-1'>CougarNet External ID:</span>#cougarNetBadge#</div>
    </div>
</div>
<div class='d-flex gap-3 mb-3 align-items-center flex-wrap'>
    <span class='badge bg-success fs-6'>#matchCount# Match(es) Found</span>
    <span class='badge bg-warning text-dark fs-6'>#noMatchCount# Not in Users</span>
    <form method='post' class='ms-2 mb-0'>
        <input type='hidden' name='batchImport' value='1'>
        <button type='submit' class='btn btn-primary btn-sm'#batchBtnDisabled#>Import All Not in Users (#noMatchCount# records)</button>
    </form>
</div>
#batchSummaryHtml#
#tableHtml#
">

<cfinclude template="/dir/admin/layout.cfm">
