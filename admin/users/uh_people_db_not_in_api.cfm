<cfparam name="form.runCompare" default="0">
<cfparam name="form.testMode" default="0">
<cfparam name="form.viewStaging" default="0">
<cfparam name="form.ignoreFromStaging" default="0">
<cfparam name="form.deleteFromStaging" default="0">
<cfparam name="form.stagingID" default="0">
<cfparam name="form.userID" default="0">

<cfset datasource = request.datasource>
<cfset reasonDbOnly = "User in local Users table but not in API">
<cfset reasonApiOnly = "User in API but not in local Users table">
<cfset uhApiToken = structKeyExists(application, "uhApiToken") ? trim(application.uhApiToken ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">
<cfset selectedTestMode = form.testMode EQ "1">
<cfset results = []>
<cfset insertedCount = 0>
<cfset wouldInsertCount = 0>
<cfset skippedExistingStageCount = 0>
<cfset processedCount = 0>
<cfset excludedNoUhCount = 0>
<cfset pageMessage = "">
<cfset pageMessageClass = "alert-info">

<cfset usersService = createObject("component", "cfc.users_service").init()>
<cfset localUsersForActions = usersService.listUsers()>
<cfset userByApiId = {}>
<cfset userByName = {}>
<cfset noUhUserMap = {}>

<cfloop from="1" to="#arrayLen(localUsersForActions)#" index="u">
    <cfset mapUserID = val(localUsersForActions[u].USERID ?: 0)>
    <cfset mapApiId = lCase(trim(localUsersForActions[u].UH_API_ID ?: ""))>
    <cfset mapNameKey = lCase(trim(localUsersForActions[u].FIRSTNAME ?: "")) & "|" & lCase(trim(localUsersForActions[u].LASTNAME ?: ""))>
    <cfif len(mapApiId)>
        <cfset userByApiId[mapApiId] = mapUserID>
    </cfif>
    <cfif mapNameKey NEQ "|">
        <cfset userByName[mapNameKey] = mapUserID>
    </cfif>
</cfloop>

<cfset noUhAssignments = queryExecute(
    "
    SELECT ufa.UserID
    FROM UserFlagAssignments ufa
    INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
    WHERE UPPER(LTRIM(RTRIM(uf.FlagName))) = 'NO UH'
    ",
    {},
    { datasource = datasource, timeout = 30 }
)>

<cfloop query="noUhAssignments">
    <cfset noUhUserMap[toString(noUhAssignments.UserID)] = true>
</cfloop>

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

<cfif form.ignoreFromStaging EQ "1" AND isNumeric(form.stagingID) AND val(form.stagingID) GT 0>
    <cfset queryExecute(
        "DELETE FROM UHApiPeopleStaging WHERE StagingID = :stagingID",
        {
            stagingID = { value = val(form.stagingID), cfsqltype = "cf_sql_integer" }
        },
        { datasource = datasource, timeout = 30 }
    )>
    <cfset pageMessage = "Staging record ignored and removed.">
    <cfset pageMessageClass = "alert-info">
</cfif>

<cfif form.deleteFromStaging EQ "1" AND isNumeric(form.stagingID) AND val(form.stagingID) GT 0>
    <cfset targetUserID = isNumeric(form.userID) ? val(form.userID) : 0>
    <cfset deletedUser = false>

    <cfif targetUserID GT 0>
        <cfset deleteUserResult = usersService.deleteUser(targetUserID)>
        <cfif structKeyExists(deleteUserResult, "success") AND deleteUserResult.success>
            <cfset deletedUser = true>
        <cfelse>
            <cfset pageMessage = "Could not delete user record: " & (deleteUserResult.message ?: "Unknown error")>
            <cfset pageMessageClass = "alert-danger">
        </cfif>
    <cfelse>
        <cfset pageMessage = "No matching local user was found; only staging record was removed.">
        <cfset pageMessageClass = "alert-warning">
    </cfif>

    <cfif pageMessageClass NEQ "alert-danger">
        <cfset queryExecute(
            "DELETE FROM UHApiPeopleStaging WHERE StagingID = :stagingID",
            {
                stagingID = { value = val(form.stagingID), cfsqltype = "cf_sql_integer" }
            },
            { datasource = datasource, timeout = 30 }
        )>

        <cfif deletedUser>
            <cfset pageMessage = "User permanently deleted from Users table and staging record removed.">
            <cfset pageMessageClass = "alert-success">
        </cfif>
    </cfif>
</cfif>

<cfif form.runCompare EQ "1">
    <cfset localUsers = usersService.listUsers()>
    <cfset apiIdIndex = {}>
    <cfset apiNameIndex = {}>
    <cfset apiPersonExistsCache = {}>

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

            <cfloop from="1" to="#arrayLen(peopleArray)#" index="i">
                <cfset person = peopleArray[i]>
                <cfif NOT isStruct(person)>
                    <cfcontinue>
                </cfif>

                <cfset apiFirstName = lCase(trim(person.first_name ?: person.firstName ?: ""))>
                <cfset apiLastName = lCase(trim(person.last_name ?: person.lastName ?: ""))>
                <cfset apiId = lCase(trim(person.id ?: ""))>

                <cfif len(apiId)>
                    <cfset apiIdIndex[apiId] = true>
                </cfif>
                <cfif apiFirstName NEQ "" OR apiLastName NEQ "">
                    <cfset apiNameIndex[apiFirstName & "|" & apiLastName] = true>
                </cfif>
            </cfloop>

            <cfloop from="1" to="#arrayLen(localUsers)#" index="u">
                <cfset dbUser = localUsers[u]>
                <cfset dbUserID = val(dbUser.USERID ?: 0)>
                <cfset dbFirstName = trim(dbUser.FIRSTNAME ?: "")>
                <cfset dbLastName = trim(dbUser.LASTNAME ?: "")>
                <cfset dbApiId = trim(dbUser.UH_API_ID ?: "")>
                <cfset dbApiIdKey = lCase(dbApiId)>
                <cfset dbNameKey = lCase(dbFirstName) & "|" & lCase(dbLastName)>
                <cfset foundInApi = false>
                <cfset stageApiId = "">
                <cfset hasNoUhFlag = structKeyExists(noUhUserMap, toString(dbUserID))>

                <cfif dbUserID LTE 0>
                    <cfcontinue>
                </cfif>

                <cfif hasNoUhFlag>
                    <cfset excludedNoUhCount++>
                    <cfcontinue>
                </cfif>

                <cfset processedCount++>

                <cfif len(dbApiIdKey)>
                    <!---
                        For records with UH_API_ID, validate directly against the person endpoint.
                        This avoids false negatives when people list responses are scoped/filtered.
                    --->
                    <cfif structKeyExists(apiPersonExistsCache, dbApiIdKey)>
                        <cfset foundInApi = apiPersonExistsCache[dbApiIdKey]>
                    <cfelse>
                        <cfsilent>
                            <cfset personCheck = uhApi.getPerson(dbApiId)>
                        </cfsilent>
                        <cfset personExists = left(personCheck.statusCode ?: "", 3) EQ "200">
                        <cfset apiPersonExistsCache[dbApiIdKey] = personExists>
                        <cfset foundInApi = personExists>
                    </cfif>
                <cfelseif (dbFirstName NEQ "" OR dbLastName NEQ "") AND structKeyExists(apiNameIndex, dbNameKey)>
                    <cfset foundInApi = true>
                </cfif>

                <cfif NOT foundInApi>
                    <cfset stageApiId = len(dbApiId) ? dbApiId : "DBONLY:" & dbUserID>

                    <cfset stageCheck = queryExecute(
                        "
                        SELECT TOP 1 StagingID
                        FROM UHApiPeopleStaging
                        WHERE UHApiID = :uhApiID
                          AND Reason = :reason
                        ",
                        {
                            uhApiID = { value = stageApiId, cfsqltype = "cf_sql_varchar" },
                            reason = { value = reasonDbOnly, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = datasource, timeout = 30 }
                    )>

                    <cfif stageCheck.recordCount GT 0>
                        <cfset skippedExistingStageCount++>
                        <cfset arrayAppend(results, {
                            userID = dbUserID,
                            firstName = dbFirstName,
                            lastName = dbLastName,
                            uhApiId = stageApiId,
                            action = "Skipped",
                            reason = "Already in staging"
                        })>
                    <cfelse>
                        <cfif selectedTestMode>
                            <cfset wouldInsertCount++>
                            <cfset arrayAppend(results, {
                                userID = dbUserID,
                                firstName = dbFirstName,
                                lastName = dbLastName,
                                uhApiId = stageApiId,
                                action = "Would Insert (Test Mode)",
                                reason = reasonDbOnly
                            })>
                        <cfelse>
                            <cfset queryExecute(
                                "
                                INSERT INTO UHApiPeopleStaging (UHApiID, FirstName, LastName, Reason)
                                VALUES (:uhApiID, :firstName, :lastName, :reason)
                                ",
                                {
                                    uhApiID = { value = stageApiId, cfsqltype = "cf_sql_varchar" },
                                    firstName = { value = dbFirstName, cfsqltype = "cf_sql_varchar" },
                                    lastName = { value = dbLastName, cfsqltype = "cf_sql_varchar" },
                                    reason = { value = reasonDbOnly, cfsqltype = "cf_sql_varchar" }
                                },
                                { datasource = datasource, timeout = 30 }
                            )>

                            <cfset insertedCount++>
                            <cfset arrayAppend(results, {
                                userID = dbUserID,
                                firstName = dbFirstName,
                                lastName = dbLastName,
                                uhApiId = stageApiId,
                                action = "Inserted",
                                reason = reasonDbOnly
                            })>
                        </cfif>
                    </cfif>
                </cfif>
            </cfloop>

        <cfif selectedTestMode>
            <cfset pageMessage = "TEST MODE: Processed #processedCount# local users. Would insert #wouldInsertCount#, skipped already staged #skippedExistingStageCount#, excluded by No UH flag #excludedNoUhCount#. No rows were inserted into staging.">
        <cfelse>
            <cfset pageMessage = "Processed #processedCount# local users. Inserted #insertedCount#, skipped already staged #skippedExistingStageCount#, excluded by No UH flag #excludedNoUhCount#.">
        </cfif>
        <cfset pageMessageClass = "alert-success">
    <cfelse>
        <cfset pageMessage = "UH API request failed with status #EncodeForHTML(statusCode)#.">
        <cfset pageMessageClass = "alert-danger">
    </cfif>
</cfif>

<cfset content = "
<h1>UH Reverse Comparison</h1>
<p class='text-muted'>Compare local Users against UH API and stage records found in local DB but not in API.</p>

<form method='post' class='card card-body mb-4'>
    <input type='hidden' name='runCompare' value='1'>
    <div class='row g-3 align-items-end'>
        <div class='col-md-8'>
            <label class='form-label d-block'>Comparison Mode</label>
            <div class='form-check form-check-inline ms-2'>
                <input class='form-check-input' type='checkbox' name='testMode' id='testMode' value='1' " & (selectedTestMode ? "checked" : "") & ">
                <label class='form-check-label' for='testMode'>Test Mode (no staging inserts)</label>
            </div>
        </div>
        <div class='col-md-4 text-md-end'>
            <button type='submit' class='btn btn-primary'>Run Reverse Compare</button>
            <button type='submit' name='viewStaging' value='1' class='btn btn-outline-secondary'>View DB-Not-API Staging</button>
        </div>
    </div>
</form>
" />

<cfif pageMessage NEQ "">
    <cfset content &= "<div class='alert #pageMessageClass#'>#EncodeForHTML(pageMessage)#</div>">
</cfif>

<cfif form.runCompare EQ "1" AND arrayLen(results) GT 0>
    <cfset content &= "
    <div class='table-responsive'>
        <table class='table table-sm table-bordered align-middle'>
            <thead class='table-light'>
                <tr>
                    <th>UserID</th>
                    <th>First Name</th>
                    <th>Last Name</th>
                    <th>UH API ID</th>
                    <th>Result</th>
                    <th>Reason</th>
                </tr>
            </thead>
            <tbody>
    ">

    <cfloop from="1" to="#arrayLen(results)#" index="r">
        <cfset row = results[r]>
        <cfset content &= "
                <tr>
                    <td>#EncodeForHTML(row.userID)#</td>
                    <td>#EncodeForHTML(row.firstName)#</td>
                    <td>#EncodeForHTML(row.lastName)#</td>
                    <td>#EncodeForHTML(row.uhApiId)#</td>
                    <td>#EncodeForHTML(row.action)#</td>
                    <td>#EncodeForHTML(row.reason)#</td>
                </tr>
        ">
    </cfloop>

    <cfset content &= "
            </tbody>
        </table>
    </div>
    ">
</cfif>

<cfif form.viewStaging EQ "1">
    <cfset stagingDbOnly = queryExecute(
        "
        SELECT StagingID, UHApiID, FirstName, LastName, Reason, CreatedAt
        FROM UHApiPeopleStaging
        WHERE Reason = :reasonDbOnly
        ORDER BY LastName, FirstName
        ",
        {
            reasonDbOnly = { value = reasonDbOnly, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = datasource, timeout = 30 }
    )>

    <cfset content &= "<h3>Staged: In Users Table but Not in API</h3>">

    <cfif stagingDbOnly.recordCount GT 0>
        <cfset content &= "
        <div class='table-responsive'>
            <table class='table table-sm table-bordered align-middle'>
                <thead class='table-light'>
                    <tr>
                        <th>First Name</th>
                        <th>Last Name</th>
                        <th>UH API ID</th>
                        <th>Reason</th>
                        <th>Staged On</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
        ">

        <cfloop query="stagingDbOnly">
            <cfset resolvedUserID = 0>
            <cfset stageApiIdLower = lCase(trim(stagingDbOnly.UHApiID ?: ""))>
            <cfset stageNameKey = lCase(trim(stagingDbOnly.FirstName ?: "")) & "|" & lCase(trim(stagingDbOnly.LastName ?: ""))>

            <cfif left(stageApiIdLower, 7) EQ "dbonly:">
                <cfset parsedID = val(reReplace(stageApiIdLower, "^dbonly:", "", "all"))>
                <cfif parsedID GT 0>
                    <cfset resolvedUserID = parsedID>
                </cfif>
            <cfelseif structKeyExists(userByApiId, stageApiIdLower)>
                <cfset resolvedUserID = val(userByApiId[stageApiIdLower] ?: 0)>
            <cfelseif structKeyExists(userByName, stageNameKey)>
                <cfset resolvedUserID = val(userByName[stageNameKey] ?: 0)>
            </cfif>

            <cfset content &= "
                    <tr>
                        <td>#EncodeForHTML(stagingDbOnly.FirstName ?: "")#</td>
                        <td>#EncodeForHTML(stagingDbOnly.LastName ?: "")#</td>
                        <td>#EncodeForHTML(stagingDbOnly.UHApiID ?: "")#</td>
                        <td>#EncodeForHTML(stagingDbOnly.Reason ?: "")#</td>
                        <td>#dateformat(stagingDbOnly.CreatedAt, 'yyyy-mm-dd')# #timeformat(stagingDbOnly.CreatedAt, 'HH:mm')#</td>
                        <td>
                            <form method='post' class='admin-inline-form'>
                                <input type='hidden' name='viewStaging' value='1'>
                                <input type='hidden' name='ignoreFromStaging' value='1'>
                                <input type='hidden' name='stagingID' value='#stagingDbOnly.StagingID#'>
                                <button type='submit' class='btn btn-sm btn-outline-secondary'>Ignore</button>
                            </form>
                            <form method='post' class='admin-inline-form'>
                                <input type='hidden' name='viewStaging' value='1'>
                                <input type='hidden' name='deleteFromStaging' value='1'>
                                <input type='hidden' name='stagingID' value='#stagingDbOnly.StagingID#'>
                                <input type='hidden' name='userID' value='#resolvedUserID#'>
                                <button type='submit' class='btn btn-sm btn-outline-danger' onclick='return confirm(""This permanently deletes the user from the Users table and removes the staging record. Continue?"");'>Delete</button>
                            </form>
                        </td>
                    </tr>
            ">
        </cfloop>

        <cfset content &= "
                </tbody>
            </table>
        </div>
        ">
    <cfelse>
        <cfset content &= "<p class='text-muted'>No records staged for local-users-not-in-API.</p>">
    </cfif>
</cfif>

<cfinclude template="/admin/layout.cfm">
