<cfsetting requesttimeout="600">
<!---
    run_uh_sync_report.cfm
    Compares local user records against the UH Directory API and stores results.

    Can be triggered:
      - Manually via the "Run Now" button on uh_sync_report.cfm
      - By the ColdFusion Scheduler (GET ?triggeredBy=scheduled)
      - Programmatically with ?format=json for a JSON response

    Logic:
      1. Fetch all local users that have a UH_API_ID (and do NOT carry "No UH" flag)
      2. Fetch all staff + faculty from the UH API for our division/campus
      3. For each local user:
           - Not found in API  →  record as gone
           - Found in API      →  compare key fields, record any diffs
      4. For each API person whose ID is not in the local DB  →  record as new
      5. Persist results to UHSyncRuns / UHSyncDiffs / UHSyncGone / UHSyncNew
--->

<!--- ── Triggered-by source ── --->
<cfset triggeredBy = "manual">
<cfif structKeyExists(url, "triggeredBy") AND len(trim(url.triggeredBy))>
    <cfset triggeredBy = trim(url.triggeredBy)>
<cfelseif structKeyExists(form, "triggeredBy") AND len(trim(form.triggeredBy))>
    <cfset triggeredBy = trim(form.triggeredBy)>
</cfif>

<cfinclude template="/admin/settings/scheduled-tasks/tasks/_scheduled_task_auth.cfm">

<cfset returnJson = structKeyExists(url, "format") AND trim(url.format) EQ "json">

<!--- ── API credentials ── --->
<cfset uhApiCredentials = request.runtimeSecretPolicy.getUHApiCredentials()>
<cfset uhApiToken = trim(uhApiCredentials.token ?: "")>
<cfset uhApiSecret = trim(uhApiCredentials.secret ?: "")>

<!--- ── State variables ── --->
<cfset runID          = 0>
<cfset totalCompared  = 0>
<cfset totalDiffs     = 0>
<cfset totalGone      = 0>
<cfset totalNew       = 0>
<cfset success        = false>
<cfset errorMsg       = "">
<cfset runDurationMs  = 0>
<cfset runStartedAt   = 0>

<cfif uhApiToken EQ "" OR uhApiSecret EQ "">
    <cfset errorMsg = "UH API credentials are not configured. Set UH_API_TOKEN and UH_API_SECRET.">
<cfelse>
<cfset runStartedAt = getTickCount()>
<cftry>

    <!--- ── Initialise DAOs ── --->
    <cfset uhSyncDAO = createObject("component", "dao.uhSync_DAO").init()>

    <!--- ── Create the run record first ── --->
    <cfset runID = uhSyncDAO.createRun(triggeredBy)>

    <!--- ── Load all local users with a UH_API_ID ---
         Exclude users flagged "No UH" (they deliberately have no UH record)  --->
    <cfset localUsersQry = queryExecute(
        "
        SELECT u.UserID,
               ISNULL(u.UH_API_ID,'')                   AS UH_API_ID,
               ISNULL(u.FirstName,'')                   AS FirstName,
               ISNULL(u.LastName,'')                    AS LastName,
               ISNULL(u.EmailPrimary,'')                AS EmailPrimary,
               ISNULL(u.Phone,'')                       AS Phone,
               ISNULL(u.Room,'')                        AS Room,
               ISNULL(u.Building,'')                    AS Building,
               ISNULL(u.Title1,'')                      AS Title1,
               ISNULL(u.Division,'')                    AS Division,
               ISNULL(u.DivisionName,'')                AS DivisionName,
               ISNULL(u.Campus,'')                      AS Campus,
               ISNULL(u.Department,'')                  AS Department,
               ISNULL(u.DepartmentName,'')              AS DepartmentName,
               ISNULL(u.Office_Mailing_Address,'')      AS Office_Mailing_Address,
               ISNULL(u.Mailcode,'')                    AS Mailcode
        FROM Users u
        WHERE ISNULL(u.UH_API_ID,'') <> ''
          AND NOT EXISTS (
              SELECT 1 FROM UserFlagAssignments ufa
              INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
              WHERE ufa.UserID = u.UserID
                AND UPPER(LTRIM(RTRIM(uf.FlagName))) = 'NO UH'
          )
        ",
        {},
        { datasource="#request.datasource#", timeout=60 }
    )>

    <!--- Build lookup maps of local users --->
    <cfset localByApiId = {}>       <!--- lcase(UH_API_ID) → row struct --->
    <cfset localApiIdSet = {}>      <!--- lcase(UH_API_ID) → true (for "new" detection) --->

    <cfloop query="localUsersQry">
        <cfset mapKey = lCase(trim(localUsersQry.UH_API_ID))>
        <cfif len(mapKey)>
            <cfset localByApiId[mapKey]  = localUsersQry.getRow(localUsersQry.currentRow)>
            <cfset localApiIdSet[mapKey] = true>
        </cfif>
    </cfloop>

    <!--- ── Call UH API — get all staff and faculty ── --->
    <cfset uhApi       = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
    <cfset apiResponse = uhApi.getPeople(staff=true, faculty=true)>

    <cfif left(apiResponse.statusCode, 3) NEQ "200">
        <cfthrow type="Application"
                 message="UH API returned status #apiResponse.statusCode# for getPeople.">
    </cfif>

    <!--- Parse API people array --->
    <cfset apiPeopleRaw = apiResponse.data ?: {}>
    <cfset apiPeople    = []>

    <cfif isStruct(apiPeopleRaw) AND structKeyExists(apiPeopleRaw, "data") AND isArray(apiPeopleRaw.data)>
        <cfset apiPeople = apiPeopleRaw.data>
    <cfelseif isArray(apiPeopleRaw)>
        <cfset apiPeople = apiPeopleRaw>
    </cfif>

    <!--- ── Helper: get a value from a person struct trying multiple key names ── --->
    <!--- (inline function so it's available without a CFC dependency)            --->
    <cfscript>
        function uhSyncNormalizeOfficeMailingAddress(any value="") {
            var normalized = toString(arguments.value ?: "");

            normalized = reReplace(normalized, "[\r\n\t]+", " ", "all");
            normalized = reReplace(normalized, "\s{2,}", " ", "all");

            return trim(normalized);
        }

        function uhSyncFindValueByKeyDeep(any node="", required string keyName) {
            var keys = [];
            var currentKey = "";
            var foundValue = "";
            var index = 1;

            if (isNull(arguments.node)) {
                return "";
            }

            if (isStruct(arguments.node)) {
                keys = structKeyArray(arguments.node);

                for (index = 1; index <= arrayLen(keys); index++) {
                    currentKey = keys[index];
                    if (compareNoCase(currentKey, arguments.keyName) EQ 0) {
                        if (isSimpleValue(arguments.node[currentKey])) {
                            return toString(arguments.node[currentKey] ?: "");
                        }
                        if (isBoolean(arguments.node[currentKey])) {
                            return arguments.node[currentKey] ? "true" : "false";
                        }
                    }
                }

                for (index = 1; index <= arrayLen(keys); index++) {
                    foundValue = uhSyncFindValueByKeyDeep(arguments.node[keys[index]], arguments.keyName);
                    if (len(trim(toString(foundValue)))) {
                        return foundValue;
                    }
                }
            } else if (isArray(arguments.node)) {
                for (index = 1; index <= arrayLen(arguments.node); index++) {
                    foundValue = uhSyncFindValueByKeyDeep(arguments.node[index], arguments.keyName);
                    if (len(trim(toString(foundValue)))) {
                        return foundValue;
                    }
                }
            }

            return "";
        }

        function uhSyncGetVal(required struct person, required string keysCsv) {
            var names = listToArray(arguments.keysCsv);
            var i = 1;
            var v = "";

            for (i = 1; i <= arrayLen(names); i++) {
                v = uhSyncFindValueByKeyDeep(arguments.person, trim(names[i]));
                if (len(trim(toString(v)))) {
                    return trim(toString(v));
                }
            }

            return "";
        }
    </cfscript>

    <!--- ── Build apiIdSet from getPeople() — used only for "new in UH" detection ── --->
    <!--- NOTE: We do NOT use getPeople() for gone/comparison detection because the  --->
    <!--- bulk endpoint can return a scoped/filtered subset (see uh_people_db_not_in_api.cfm). --->
    <!--- False "gone" flags result when a user exists in the API but wasn't in the   --->
    <!--- bulklist. We use getPerson() individually instead (same approach as the per-user sync comparison logic). --->
    <cfset apiIdSet = {}>

    <cfloop from="1" to="#arrayLen(apiPeople)#" index="p">
        <cfset ap = apiPeople[p]>
        <cfif isStruct(ap)>
            <cfset apId = lCase(trim(uhSyncGetVal(ap, "id")))>
            <cfif len(apId)>
                <cfset apiIdSet[apId] = true>
            </cfif>
        </cfif>
    </cfloop>

    <!--- Cache for individual getPerson() results: lCase(uhApiId) → struct OR false --->
    <cfset personCache = {}>

    <!--- ── Field mapping: local column → CSV of API key names to try ── --->
    <cfset fieldMap = [
        { localCol="FirstName",              apiKeys="first_name,firstName"                                  },
        { localCol="LastName",               apiKeys="last_name,lastName"                                    },
        { localCol="EmailPrimary",           apiKeys="email,emailAddress"                                    },
        { localCol="Phone",                  apiKeys="phone,phoneNumber"                                     },
        { localCol="Room",                   apiKeys="room"                                                  },
        { localCol="Building",               apiKeys="building"                                              },
        { localCol="Title1",                 apiKeys="title"                                                 },
        { localCol="Division",               apiKeys="division"                                              },
        { localCol="DivisionName",           apiKeys="division_name,divisionName"                            },
        { localCol="Campus",                 apiKeys="campus"                                                },
        { localCol="Department",             apiKeys="department"                                            },
        { localCol="DepartmentName",         apiKeys="department_name,departmentName"                        },
        { localCol="Office_Mailing_Address", apiKeys="office_mailing_address,officeMailingAddress"          },
        { localCol="Mailcode",               apiKeys="mailcode,mail_code"                                   }
    ]>

    <!--- ── Compare each local user against the API via getPerson() ── --->
    <cfloop query="localUsersQry">
        <cfset mapKey = lCase(trim(localUsersQry.UH_API_ID))>
        <cfset totalCompared++>
        <cfset apPerson    = {}>
        <cfset personFound = false>

        <cfif structKeyExists(personCache, mapKey)>
            <!--- Already fetched this person during this run --->
            <cfif isStruct(personCache[mapKey])>
                <cfset personFound = true>
                <cfset apPerson    = personCache[mapKey]>
            </cfif>
        <cfelse>
            <!---
                Verify existence via getPerson() — NOT getPeople().
                getPeople() returns a scoped/filtered list that can omit valid users,
                producing false "gone" flags. getPerson() is authoritative per-user.
            --->
            <cfset personResp  = uhApi.getPerson(localUsersQry.UH_API_ID)>
            <cfset personFound = left(personResp.statusCode ?: "", 3) EQ "200">

            <cfif personFound>
                    <!--- Unwrap the nested person struct (same logic as the per-user sync comparison code).
                      Guard every branch with isStruct() — rawPD.data can be an array
                      or simple value in some API responses, which would pass apPerson
                      as a non-struct and crash uhSyncGetVal. --->
                <cfset rawPD    = personResp.data ?: {}>
                <cfset apPerson = {}>   <!--- default: empty struct --->

                <cfif isStruct(rawPD)>
                    <cfif structKeyExists(rawPD, "data") AND isStruct(rawPD.data)>
                        <cfif structKeyExists(rawPD.data, "person") AND isStruct(rawPD.data.person)>
                            <cfset apPerson = rawPD.data.person>
                        <cfelse>
                            <cfset apPerson = rawPD.data>
                        </cfif>
                    <cfelseif structKeyExists(rawPD, "person") AND isStruct(rawPD.person)>
                        <cfset apPerson = rawPD.person>
                    <cfelse>
                        <cfset apPerson = rawPD>
                    </cfif>
                </cfif>

                <!--- If we still ended up with an empty or non-usable struct,
                      treat as not found so we don't write bogus diffs. --->
                <cfif NOT isStruct(apPerson) OR structIsEmpty(apPerson)>
                    <cfset personFound = false>
                    <cfset personCache[mapKey] = false>
                <cfelse>
                    <cfset personCache[mapKey] = apPerson>
                </cfif>
            <cfelse>
                <cfset personCache[mapKey] = false>
            </cfif>
        </cfif>

        <cfif NOT personFound>
            <!--- User not found in API → gone --->
            <cfset uhSyncDAO.insertGone(runID, localUsersQry.UserID)>
            <cfset totalGone++>
        <cfelse>
            <!--- User found — compare individual fields --->
            <cfset localRow = localByApiId[mapKey]>

            <cfloop from="1" to="#arrayLen(fieldMap)#" index="fi">
                <cfset fm       = fieldMap[fi]>
                <cfset localVal = trim(toString(localRow[fm.localCol] ?: ""))>
                <cfset apiVal   = uhSyncGetVal(apPerson, fm.apiKeys)>

                <cfif fm.localCol EQ "Office_Mailing_Address">
                    <cfset localVal = uhSyncNormalizeOfficeMailingAddress(localVal)>
                    <cfset apiVal = uhSyncNormalizeOfficeMailingAddress(apiVal)>
                </cfif>

                <!--- Only flag a diff when:
                      (a) the API returned a non-empty value, AND
                      (b) that value differs from the local value (case-insensitive for email) --->
                <cfif len(apiVal)>
                    <cfset isDiff = false>
                    <cfif fm.localCol EQ "EmailPrimary">
                        <cfset isDiff = (lCase(localVal) NEQ lCase(apiVal))>
                    <cfelse>
                        <cfset isDiff = (localVal NEQ apiVal)>
                    </cfif>

                    <cfif isDiff>
                        <cfset uhSyncDAO.insertDiff(runID, localUsersQry.UserID, fm.localCol, localVal, apiVal)>
                        <cfset totalDiffs++>
                    </cfif>
                </cfif>
            </cfloop>
        </cfif>
    </cfloop>

    <!--- ── Detect API users not in local DB ── --->
    <cfloop from="1" to="#arrayLen(apiPeople)#" index="p">
        <cfset ap   = apiPeople[p]>
        <cfif NOT isStruct(ap)><cfcontinue></cfif>

        <cfset apId = lCase(trim(uhSyncGetVal(ap, "id")))>
        <cfif NOT len(apId)><cfcontinue></cfif>

        <cfif NOT structKeyExists(localApiIdSet, apId)>
            <!--- This API person has no matching local record --->
            <cfset newFirst = uhSyncGetVal(ap, "first_name,firstName")>
            <cfset newLast  = uhSyncGetVal(ap, "last_name,lastName")>
            <cfset newEmail = uhSyncGetVal(ap, "email,emailAddress")>
            <cfset newTitle = uhSyncGetVal(ap, "title")>
            <cfset newDept  = uhSyncGetVal(ap, "department")>
            <cfset newPhone = uhSyncGetVal(ap, "phone,phoneNumber")>

            <!---
                Only record new users that belong to UHCO.
                Division : H0412
                Department: H0113 or H0115
                Campus   : HR730
                Anyone outside these is from a different unit and should be ignored.
            --->
            <cfset newDivision = uCase(trim(uhSyncGetVal(ap, "division")))>
            <cfset newDept     = uCase(trim(newDept))>
            <cfset newCampus   = uCase(trim(uhSyncGetVal(ap, "campus")))>
            <cfset isUHCO = (
                newDivision EQ "H0412"
                AND listFindNoCase("H0113,H0115", newDept)
                AND newCampus   EQ "HR730"
            )>
            <cfif NOT isUHCO><cfcontinue></cfif>

            <cftry>
                <cfset rawJson = serializeJSON(ap)>
            <cfcatch>
                <cfset rawJson = "">
            </cfcatch>
            </cftry>

            <cfset uhSyncDAO.insertNew(
                runID      = runID,
                uhApiID    = uhSyncGetVal(ap, "id"),
                firstName  = newFirst,
                lastName   = newLast,
                email      = newEmail,
                title      = newTitle,
                department = newDept,
                phone      = newPhone,
                rawJson    = rawJson
            )>
            <cfset totalNew++>
        </cfif>
    </cfloop>

    <!--- ── Persist totals ── --->
    <cfset runDurationMs = max(0, getTickCount() - runStartedAt)>
    <cfset uhSyncDAO.updateRunTotals(runID, totalCompared, totalDiffs, totalGone, totalNew, runDurationMs)>
    <cfset success = true>

<cfcatch type="any">
    <cfif runStartedAt GT 0>
        <cfset runDurationMs = max(0, getTickCount() - runStartedAt)>
    </cfif>
    <cfif runID GT 0>
        <cftry>
            <cfset uhSyncDAO.updateRunTotals(runID, totalCompared, totalDiffs, totalGone, totalNew, runDurationMs)>
        <cfcatch></cfcatch>
        </cftry>
    </cfif>
    <cfset errorMsg = cfcatch.message & " — " & cfcatch.detail>
</cfcatch>
</cftry>
</cfif>

<!--- ── Respond ── --->
<cfif returnJson>
    <cfcontent type="application/json; charset=utf-8">
    <cfoutput>#serializeJSON({
        success       : success,
        runID         : runID,
        totalCompared : totalCompared,
        totalDiffs    : totalDiffs,
        totalGone     : totalGone,
        totalNew      : totalNew,
        durationMs    : runDurationMs,
        triggeredBy   : triggeredBy,
        error         : errorMsg
    })#</cfoutput>
    <cfabort>
</cfif>

<cfif success>
    <cflocation url="#request.webRoot#/admin/reporting/uh_sync_report.cfm?msg=ran&runID=#runID#" addtoken="false">
<cfelse>
    <cflocation url="#request.webRoot#/admin/reporting/uh_sync_report.cfm?msg=error&err=#urlEncodedFormat(errorMsg)#" addtoken="false">
</cfif>
