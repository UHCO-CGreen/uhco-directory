<!---
    CS-bulk-import.cfm
    Bulk import CS students for a single grad year from the legacy AlumniStudent table.

    For each legacy record:
      1. Skip if first+last already exists in local Users table.
      2. Call UH API (q=lastName, department=H0113, student=true).
      3. Match returned people by first+last (or first+maiden).
      4. API match  → create user + external IDs + academic info + flag + orgs.
      5. No match   → insert into UHApiPeopleStaging with a Reason note.
--->
<cfsetting requesttimeout="300">

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

<!--- ── Ensure staging table has Reason column ── --->
<cftry>
    <cfset queryExecute(
        "IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.UHApiPeopleStaging') AND name = 'Reason')
         ALTER TABLE dbo.UHApiPeopleStaging ADD Reason NVARCHAR(500) NULL",
        {},
        { datasource="UHCO_Directory", timeout=30 }
    )>
<cfcatch></cfcatch>
</cftry>

<!--- ── Params ── --->
<cfparam name="form.selectedYear" default="">
<cfset selectedYear = (cgi.request_method EQ "POST" AND isNumeric(form.selectedYear)) ? val(form.selectedYear) : 0>

<cfset processed       = false>
<cfset processResults  = []>
<cfset insertedCount   = 0>
<cfset skippedCount    = 0>
<cfset stagedCount     = 0>
<cfset errorCount      = 0>
<cfset globalError     = "">

<!--- ── Helper function ── --->
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

<cfif cgi.request_method EQ "POST" AND selectedYear GTE 2026 AND selectedYear LTE 2029>
    <cfset processed = true>

    <!--- ── Resolve constants once ── --->
    <cftry>
        <cfset biFlagsService = createObject("component", "dir.cfc.flags_service").init()>
        <cfset biOrgsService  = createObject("component", "dir.cfc.organizations_service").init()>
        <cfset biExtIDSvc     = createObject("component", "dir.cfc.externalID_service").init()>
        <cfset biAcadSvc      = createObject("component", "dir.cfc.academic_service").init()>
        <cfset biUsersService = createObject("component", "dir.cfc.users_service").init()>

        <!--- Flag: Current-Student --->
        <cfset biCurrFlagID = 0>
        <cfset biAllFlags = biFlagsService.getAllFlags().data>
        <cfloop from="1" to="#arrayLen(biAllFlags)#" index="bifi">
            <cfset biFlag = biAllFlags[bifi]>
            <cfif lCase(trim(biFlag.FLAGNAME)) EQ "current-student">
                <cfset biCurrFlagID = val(biFlag.FLAGID)>
                <cfbreak>
            </cfif>
        </cfloop>

        <!--- Orgs: Academic Programs + OD Program --->
        <cfset biOrgIDs = []>
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

        <!--- Build local Users name index (skip already-existing) --->
        <!--- Key includes grad year so same name in different years isn't skipped --->
        <cfset biLocalIndex = {}>
        <cfset biLocalUsers = biUsersService.listUsers()>
        <cfset biLocalAcadMap = biAcadSvc.getAllAcademicInfoMap()>
        <cfloop from="1" to="#arrayLen(biLocalUsers)#" index="biu">
            <cfset biLU = biLocalUsers[biu]>
            <cfset biLUFirst = lCase(trim(biLU.FIRSTNAME ?: ""))>
            <cfset biLULast  = lCase(trim(biLU.LASTNAME  ?: ""))>
            <cfset biLUAcad  = structKeyExists(biLocalAcadMap, toString(biLU.USERID)) ? biLocalAcadMap[toString(biLU.USERID)] : {}>
            <cfset biLUGradYr = (NOT structIsEmpty(biLUAcad) AND structKeyExists(biLUAcad, "CURRENTGRADYEAR") AND isNumeric(biLUAcad.CURRENTGRADYEAR)) ? toString(val(biLUAcad.CURRENTGRADYEAR)) : "">
            <cfset biKey = biLUFirst & "|" & biLULast & "|" & biLUGradYr>
            <cfif len(biLUFirst) AND len(biLULast)>
                <cfset biLocalIndex[biKey] = true>
            </cfif>
        </cfloop>

        <!--- Init API once --->
        <cfset biUhApi = createObject("component", "dir.cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>

    <cfcatch>
        <cfset globalError = "Failed to initialise services: " & cfcatch.message>
    </cfcatch>
    </cftry>

    <cfif NOT len(globalError)>

        <!--- ── Query legacy DB ── --->
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

    <cfif NOT len(globalError)>

        <!--- ── Deduplicate ── --->
        <cfset biSeenKeys  = {}>
        <cfset biDeduped   = []>
        <cfset biCols      = listToArray(biQuery.columnList)>
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

            <!--- Map fields --->
            <cfset biFirst   = getColVal(src, ["FirstName",  "First_Name",  "fname",  "F_Name"])>
            <cfset biLast    = getColVal(src, ["LastName",   "Last_Name",   "lname",  "L_Name"])>
            <cfset biMiddle  = getColVal(src, ["MiddleName", "Middle_Name", "MiddleInitial", "MI"])>
            <cfset biEmail   = getColVal(src, ["Email", "EmailAddress", "Email_Address", "UH_Email", "UHEmail"])>
            <cfset biPsoft   = getColVal(src, ["Psoft", "PSoft", "PeopleSoft", "PeopleSoftID"])>
            <cfset biCougar  = getColVal(src, ["CougarNet", "CougarNetID", "CougarNetId", "CougaNet"])>
            <cfset biGradYr  = getColVal(src, ["GradYear", "Grad_Year", "GraduationYear", "Graduation_Year"])>
            <cfset biMaiden  = getColVal(src, ["MaidenName", "Maiden_Name", "MaidenLastName", "Maiden"])>

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

            <!--- ── Skip if already in local Users (match on first + last + grad year) ── --->
            <cfset biNameKey = lCase(biFirst) & "|" & lCase(biLast) & "|" & (isNumeric(biGradYr) ? toString(val(biGradYr)) : "")>
            <cfif structKeyExists(biLocalIndex, biNameKey)>
                <cfset arrayAppend(processResults, {
                    status    = "skipped",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    message   = "Already in Users table"
                })>
                <cfset skippedCount++>
                <cfcontinue>
            </cfif>

            <!--- ── API lookup ── --->
            <cfset biFoundPerson = {}>
            <cfset biApiError    = "">
            <cftry>
                <cfset biPeopleResp = biUhApi.getPeople(student=true, staff=false, faculty=false, department="H0113", q=trim(biLast))>
                <cfset biApiPeople  = []>
                <cfif left(biPeopleResp.statusCode, 3) EQ "200">
                    <cfset biRData = biPeopleResp.data ?: {}>
                    <cfif isStruct(biRData) AND structKeyExists(biRData, "data") AND isArray(biRData.data)>
                        <cfset biApiPeople = biRData.data>
                    <cfelseif isArray(biRData)>
                        <cfset biApiPeople = biRData>
                    </cfif>
                </cfif>
                <!--- Match by first+last or first+maiden --->
                <cfset biSearchFirst  = lCase(biFirst)>
                <cfset biSearchLast   = lCase(biLast)>
                <cfset biSearchMaiden = lCase(biMaiden)>
                <cfloop from="1" to="#arrayLen(biApiPeople)#" index="biap">
                    <cfset bip = biApiPeople[biap]>
                    <cfset bipFirst = lCase(trim(bip.first_name ?: bip.firstName ?: ""))>
                    <cfset bipLast  = lCase(trim(bip.last_name  ?: bip.lastName  ?: ""))>
                    <cfif bipFirst EQ biSearchFirst AND (bipLast EQ biSearchLast OR (len(biSearchMaiden) AND bipLast EQ biSearchMaiden))>
                        <cfset biFoundPerson = bip>
                        <cfbreak>
                    </cfif>
                </cfloop>
            <cfcatch>
                <cfset biApiError = cfcatch.message>
            </cfcatch>
            </cftry>

            <cfif len(biApiError)>
                <!--- API call itself failed --->
                <cfset arrayAppend(processResults, {
                    status    = "error",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    message   = "API error: " & biApiError
                })>
                <cfset errorCount++>
                <cfcontinue>
            </cfif>

            <cfif structIsEmpty(biFoundPerson)>
                <!--- ── Not found in API: insert into staging ── --->
                <cftry>
                    <cfset biStagingID = "NOTFOUND_" & selectedYear & "_" & createUUID()>
                    <cfset queryExecute(
                        "MERGE INTO UHApiPeopleStaging AS tgt
                         USING (SELECT :uhid AS UHApiID) AS src ON tgt.UHApiID = src.UHApiID
                         WHEN NOT MATCHED THEN
                         INSERT (UHApiID, FirstName, LastName, Reason)
                         VALUES (:uhid, :fn, :ln, :reason);",
                        {
                            uhid   = { value=biStagingID,                                                          cfsqltype="cf_sql_varchar" },
                            fn     = { value=biFirst,                                                              cfsqltype="cf_sql_varchar" },
                            ln     = { value=biLast,                                                               cfsqltype="cf_sql_varchar" },
                            reason = { value="User Not Found in API for Year " & selectedYear, cfsqltype="cf_sql_varchar" }
                        },
                        { datasource="UHCO_Directory", timeout=30 }
                    )>
                    <cfset arrayAppend(processResults, {
                        status    = "staged",
                        firstName = biFirst,
                        lastName  = biLast,
                        gradYear  = biGradYr,
                        message   = "Not found in API — added to staging"
                    })>
                    <cfset stagedCount++>
                <cfcatch>
                    <cfset arrayAppend(processResults, {
                        status    = "error",
                        firstName = biFirst,
                        lastName  = biLast,
                        gradYear  = biGradYr,
                        message   = "Staging insert failed: " & cfcatch.message
                    })>
                    <cfset errorCount++>
                </cfcatch>
                </cftry>
                <cfcontinue>
            </cfif>

            <!--- ── Found in API: create user + all associations ── --->
            <cfset biApiId   = trim(biFoundPerson.id ?: "")>
            <cfset biSteps   = []>
            <cfset biNewUID  = 0>
            <cfset biInsOK   = false>
            <cfset biInsMsg  = "">

            <!--- Step 1: create user --->
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
                    Title1         = "OD Student",
                    Title2         = "",
                    Title3         = "",
                    UH_API_ID      = biApiId
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

                <!--- Step 3: Academic / GradYear — fall back to selectedYear from query filter --->
                <cftry>
                    <cfset biEffectiveGradYr = (len(biGradYr) AND isNumeric(biGradYr) AND val(biGradYr) GT 0) ? biGradYr : selectedYear>
                    <cfset biAcadSvc.saveAcademicInfo(biNewUID, biEffectiveGradYr, "")>
                    <cfset arrayAppend(biSteps, "gradyr:ok:#biEffectiveGradYr#")>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "gradyr:err:#cfcatch.message#")>
                </cfcatch>
                </cftry>

                <!--- Step 4: Flag --->
                <cftry>
                    <cfif biCurrFlagID GT 0>
                        <cfset biFlagsService.addFlag(biNewUID, biCurrFlagID)>
                        <cfset arrayAppend(biSteps, "flag:ok")>
                    <cfelse>
                        <cfset arrayAppend(biSteps, "flag:notfound")>
                    </cfif>
                <cfcatch>
                    <cfset arrayAppend(biSteps, "flag:err")>
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

                <!--- Add to local index so duplicate legacy rows are skipped --->
                <cfset biLocalIndex[biNameKey] = true>
                <cfset insertedCount++>

                <cfset arrayAppend(processResults, {
                    status    = "inserted",
                    firstName = biFirst,
                    lastName  = biLast,
                    gradYear  = biGradYr,
                    userID    = biNewUID,
                    apiId     = biApiId,
                    steps     = biSteps,
                    message   = ""
                })>

            <cfelse>
                <!--- User create failed --->
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
<h1>CS Bulk Import</h1>
<p class="text-muted mb-4">Select a grad year to auto-import all matching students from the legacy AlumniStudent table. Records already in the Users table are skipped. Unmatched records are added to the staging table.</p>

<form method="post" class="d-flex align-items-center gap-3 mb-4">
    <label for="selectedYear" class="form-label mb-0 fw-semibold">Select Grad Year:</label>
    <select name="selectedYear" id="selectedYear" class="form-select" style="width:auto;">
        <option value="">-- Choose Year --</option>
        <option value="2026"#(selectedYear EQ 2026 ? " selected" : "")#>2026</option>
        <option value="2027"#(selectedYear EQ 2027 ? " selected" : "")#>2027</option>
        <option value="2028"#(selectedYear EQ 2028 ? " selected" : "")#>2028</option>
        <option value="2029"#(selectedYear EQ 2029 ? " selected" : "")#>2029</option>
    </select>
    <button type="submit" class="btn btn-primary">Run Import</button>
</form>

<cfif processed>
    <cfif len(globalError)>
        <div class="alert alert-danger"><strong>Error:</strong> #encodeForHTML(globalError)#</div>
    <cfelse>
        <div class="d-flex gap-3 mb-3 flex-wrap">
            <span class="badge bg-success fs-6 px-3 py-2"><i class="bi bi-person-plus-fill me-1"></i> #insertedCount# Inserted</span>
            <span class="badge bg-secondary fs-6 px-3 py-2"><i class="bi bi-skip-forward-fill me-1"></i> #skippedCount# Skipped (existing)</span>
            <span class="badge bg-warning text-dark fs-6 px-3 py-2"><i class="bi bi-hourglass-split me-1"></i> #stagedCount# Staged (not in API)</span>
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
                                    <cfelseif left(biSt,9) EQ "extids:ok">
                                        <span class="badge bg-success me-1">ext IDs</span>
                                    <cfelseif left(biSt,10) EQ "extids:err">
                                        <span class="badge bg-warning text-dark me-1">ext IDs!</span>
                                    <cfelseif left(biSt,8) EQ "gradyr:ok">
                                        <span class="badge bg-success me-1" title="Year ##listLast(biSt,':')##">grad yr</span>
                                    <cfelseif left(biSt,11) EQ "gradyr:skip">
                                        <span class="badge bg-secondary me-1">grad yr</span>
                                    <cfelseif left(biSt,10) EQ "gradyr:err">
                                        <span class="badge bg-warning text-dark me-1" title="#encodeForHTMLAttribute(listRest(biSt,':'))#">grad yr!</span>
                                    <cfelseif left(biSt,7) EQ "flag:ok">
                                        <span class="badge bg-success me-1">flag</span>
                                    <cfelseif left(biSt,13) EQ "flag:notfound">
                                        <span class="badge bg-danger me-1">flag?</span>
                                    <cfelseif left(biSt,8) EQ "flag:err">
                                        <span class="badge bg-warning text-dark me-1">flag!</span>
                                    <cfelseif left(biSt,7) EQ "orgs:ok">
                                        <span class="badge bg-success me-1">orgs(#listLast(biSt,':')#)</span>
                                    <cfelseif left(biSt,8) EQ "orgs:err">
                                        <span class="badge bg-warning text-dark me-1">orgs!</span>
                                    </cfif>
                                </cfloop>
                                <a href="/dir/admin/users/edit.cfm?userID=#biRow.userID#" class="btn btn-outline-success ms-1" style="font-size:0.75rem;padding:1px 6px;">Edit</a>
                            </td>
                        </tr>
                    <cfelseif biRow.status EQ "skipped">
                        <tr>
                            <td>#bir#</td>
                            <td><span class="badge bg-secondary">Skipped</span></td>
                            <td>#encodeForHTML(biRow.gradYear ?: "")#</td>
                            <td>#encodeForHTML(biRow.firstName)#</td>
                            <td>#encodeForHTML(biRow.lastName)#</td>
                            <td><small class="text-muted">#encodeForHTML(biRow.message)#</small></td>
                        </tr>
                    <cfelseif biRow.status EQ "staged">
                        <tr class="table-warning">
                            <td>#bir#</td>
                            <td><span class="badge bg-warning text-dark">Staged</span></td>
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
            <p class="text-muted">No records found for grad year #selectedYear#.</p>
        </cfif>
    </cfif>
</cfif>
</cfoutput></cfsavecontent>

<cfinclude template="/dir/admin/layout.cfm">
