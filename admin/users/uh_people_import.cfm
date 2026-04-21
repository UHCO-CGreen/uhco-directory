<cfparam name="form.runImport" default="0">
<cfparam name="form.student" default="0">
<cfparam name="form.staff" default="1">
<cfparam name="form.faculty" default="0">
<cfparam name="form.viewStaging" default="1">
<cfparam name="form.deleteFromStaging" default="0">
<cfparam name="form.deleteUHApiID" default="">
<cfparam name="url.msg" default="">
<cfparam name="url.err" default="">
<cfparam name="url.importedName" default="">
<cfparam name="url.newUserID" default="">

<cfset datasource = request.datasource>
<cfset uhApiToken = structKeyExists(application, "uhApiToken") ? trim(application.uhApiToken ?: "") : "">
<cfset uhApiSecret = structKeyExists(application, "uhApiSecret") ? trim(application.uhApiSecret ?: "") : "">
<cfset selectedStudent = form.student EQ "1">
<cfset selectedStaff = form.staff EQ "1">
<cfset selectedFaculty = form.faculty EQ "1">
<cfset results = []>
<cfset insertedCount = 0>
<cfset skippedExistingDbCount = 0>
<cfset skippedExistingStageCount = 0>
<cfset processedCount = 0>
<cfset pageMessage = "">
<cfset pageMessageClass = "alert-info">
<cfset reasonApiOnly = "User in API but not in local Users table">

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

<cfset content = "">
<cfif url.msg EQ "imported">
    <cfset content &= "<div class='alert alert-success'><i class='bi bi-check-circle-fill'></i> <strong>#EncodeForHTML(url.importedName)#</strong> imported successfully as <a href='/admin/users/edit.cfm?userID=#EncodeForHTMLAttribute(url.newUserID)#'>User ##&thinsp;#EncodeForHTML(url.newUserID)#</a>.</div>">
<cfelseif len(url.err)>
    <cfset content &= "<div class='alert alert-danger'><strong>Import failed:</strong> #EncodeForHTML(url.err)#</div>">
</cfif>
<cfset content &= "
<h1>UH People Import</h1>
<p class='text-muted'>Pull people from the UH API, compare by first and last name against local users, and stage missing people for review.</p>
<div class='mb-3'>
    <a href='/admin/users/uh_people_db_not_in_api.cfm' class='btn btn-outline-dark btn-sm'>Open Reverse Compare</a>
</div>

<form method='post' class='card card-body mb-4'>
    <div class='row g-3 align-items-end'>
        <div class='col-md-8'>
            <label class='form-label d-block'>UH API Filters</label>
            <div class='form-check form-check-inline'>
                <input class='form-check-input' type='checkbox' name='student' id='student' value='1' " & (selectedStudent ? "checked" : "") & ">
                <label class='form-check-label' for='student'>Student</label>
            </div>
            <div class='form-check form-check-inline'>
                <input class='form-check-input' type='checkbox' name='staff' id='staff' value='1' " & (selectedStaff ? "checked" : "") & ">
                <label class='form-check-label' for='staff'>Staff</label>
            </div>
            <div class='form-check form-check-inline'>
                <input class='form-check-input' type='checkbox' name='faculty' id='faculty' value='1' " & (selectedFaculty ? "checked" : "") & ">
                <label class='form-check-label' for='faculty'>Faculty</label>
            </div>
        </div>
        <div class='col-md-4 text-md-end'>
            <button type='submit' name='runImport' value='1' class='btn btn-primary'>Run Import</button>
            <button type='submit' name='viewStaging' value='1' class='btn btn-outline-secondary'>View Staging</button>
        </div>
    </div>
</form>
" />

<cfif form.deleteFromStaging EQ "1" AND len(trim(form.deleteUHApiID))>
    <cfset deleteResult = queryExecute(
        "DELETE FROM UHApiPeopleStaging WHERE UHApiID = :uhApiID",
        {
            uhApiID = { value = form.deleteUHApiID, cfsqltype = "cf_sql_varchar" }
        },
        { datasource = datasource, timeout = 30 }
    )>
    <cfset content &= "<div class='alert alert-info'>Record removed from staging table.</div>">
</cfif>

<cfif form.viewStaging EQ "1">
    <cfset stagingRecords = queryExecute(
        "SELECT StagingID, UHApiID, FirstName, LastName, Reason, CreatedAt
         FROM UHApiPeopleStaging
         WHERE Reason IS NULL OR Reason <> :excludedReason
         ORDER BY CreatedAt",
        {
            excludedReason = { value = "User in local Users table but not in API", cfsqltype = "cf_sql_varchar" }
        },
        { datasource = datasource, timeout = 30 }
    )>

    <cfset content &= "<h3>Staging Table Records</h3>">
    <cfif stagingRecords.recordCount GT 0>
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

        <cfloop query="stagingRecords">
            <cfset content &= "
                    <tr>
                        <td>#EncodeForHTML(stagingRecords.firstName)#</td>
                        <td>#EncodeForHTML(stagingRecords.lastName)#</td>
                        <td>#EncodeForHTML(stagingRecords.uhApiId)#</td>
                        <td>#EncodeForHTML(stagingRecords.reason ?: "")#</td>
                        <td>#dateformat(stagingRecords.createdAt, 'yyyy-mm-dd')# #timeformat(stagingRecords.createdAt, 'HH:mm')#</td>
                        <td class='text-nowrap'>
                            <a href='/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(stagingRecords.uhApiId)#' class='btn btn-sm btn-outline-primary'>Review</a>
                            <cfif (stagingRecords.reason ?: "") EQ reasonApiOnly>
                                <a href='/admin/users/quick_import_person.cfm?uhApiId=#urlEncodedFormat(stagingRecords.uhApiId)#&returnTo=#urlEncodedFormat(cgi.SCRIPT_NAME)#'
                                   class='btn btn-sm btn-success ms-1'>Quick Import</a>
                            </cfif>
                            <form method='post' class='admin-inline-form'>
                                <input type='hidden' name='deleteFromStaging' value='1'>
                                <input type='hidden' name='deleteUHApiID' value='#stagingRecords.uhApiId#'>
                                <button type='submit' class='btn btn-sm btn-outline-danger ms-1' onclick='return confirm(&quot;Remove from staging?&quot;);'>Delete</button>
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
        <cfset content &= "<p class='text-muted'>No records in staging table.</p>">
    </cfif>
</cfif>

<cfif form.runImport EQ "1">
    <cfif NOT (selectedStudent OR selectedStaff OR selectedFaculty)>
        <cfset pageMessage = "Select at least one UH API filter before running the import.">
        <cfset pageMessageClass = "alert-warning">
    <cfelse>
        <cfset usersService = createObject("component", "cfc.users_service").init()>
        <cfset localUsers = usersService.listUsers()>
        <cfset localNameIndex = {}>

        <cfloop from="1" to="#arrayLen(localUsers)#" index="u">
            <cfset dbFirstName = lCase(trim(localUsers[u].FIRSTNAME ?: ""))>
            <cfset dbLastName = lCase(trim(localUsers[u].LASTNAME ?: ""))>
            <cfif dbFirstName NEQ "" OR dbLastName NEQ "">
                <cfset localNameIndex[dbFirstName & "|" & dbLastName] = true>
            </cfif>
        </cfloop>

        <cfsilent>
            <cfset uhApi = createObject("component", "cfc.uh_api").init(apiToken=uhApiToken, apiSecret=uhApiSecret)>
            <cfset peopleResponse = uhApi.getPeople(student=selectedStudent, staff=selectedStaff, faculty=selectedFaculty)>
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

                <cfset apiFirstName = trim(person.first_name ?: person.firstName ?: "")>
                <cfset apiLastName = trim(person.last_name ?: person.lastName ?: "")>
                <cfset apiId = trim(person.id ?: "")>

                <cfif apiFirstName EQ "" OR apiLastName EQ "" OR apiId EQ "">
                    <cfcontinue>
                </cfif>

                <cfset processedCount++>
                <cfset nameKey = lCase(apiFirstName) & "|" & lCase(apiLastName)>

                <cfif structKeyExists(localNameIndex, nameKey)>
                    <cfset skippedExistingDbCount++>
                    <cfset arrayAppend(results, {
                        firstName = apiFirstName,
                        lastName = apiLastName,
                        uhApiId = apiId,
                        action = "Skipped",
                        reason = "Already exists in Users table"
                    })>
                <cfelse>
                    <cfset stageCheck = queryExecute(
                        "SELECT TOP 1 StagingID FROM UHApiPeopleStaging WHERE UHApiID = :uhApiID",
                        {
                            uhApiID = { value = apiId, cfsqltype = "cf_sql_varchar" }
                        },
                        { datasource = datasource, timeout = 30 }
                    )>

                    <cfif stageCheck.recordCount GT 0>
                        <cfset skippedExistingStageCount++>
                        <cfset arrayAppend(results, {
                            firstName = apiFirstName,
                            lastName = apiLastName,
                            uhApiId = apiId,
                            action = "Skipped",
                            reason = "Already exists in staging table"
                        })>
                    <cfelse>
                        <cfset queryExecute(
                            "
                            INSERT INTO UHApiPeopleStaging (UHApiID, FirstName, LastName, Reason)
                            VALUES (:uhApiID, :firstName, :lastName, :reason)
                            ",
                            {
                                uhApiID = { value = apiId, cfsqltype = "cf_sql_varchar" },
                                firstName = { value = apiFirstName, cfsqltype = "cf_sql_varchar" },
                                lastName = { value = apiLastName, cfsqltype = "cf_sql_varchar" },
                                reason = { value = reasonApiOnly, cfsqltype = "cf_sql_varchar" }
                            },
                            { datasource = datasource, timeout = 30 }
                        )>

                        <cfset insertedCount++>
                        <cfset arrayAppend(results, {
                            firstName = apiFirstName,
                            lastName = apiLastName,
                            uhApiId = apiId,
                            action = "Inserted",
                            reason = "Added to staging table"
                        })>
                    </cfif>
                </cfif>
            </cfloop>

            <cfset pageMessage = "Processed #processedCount# UH API people. Inserted #insertedCount#, skipped existing users #skippedExistingDbCount#, skipped already staged #skippedExistingStageCount#.">
            <cfset pageMessageClass = "alert-success">
        <cfelse>
            <cfset pageMessage = "UH API request failed with status #EncodeForHTML(statusCode)#.">
            <cfset pageMessageClass = "alert-danger">
        </cfif>
    </cfif>

    <cfset content &= "<div class='alert #pageMessageClass#'>#EncodeForHTML(pageMessage)#</div>">

    <cfif arrayLen(results) GT 0>
        <cfset content &= "
        <div class='table-responsive'>
            <table class='table table-sm table-bordered align-middle'>
                <thead class='table-light'>
                    <tr>
                        <th>First Name</th>
                        <th>Last Name</th>
                        <th>UH API ID</th>
                        <th>Result</th>
                        <th>Reason</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
        ">

        <cfloop from="1" to="#arrayLen(results)#" index="r">
            <cfset row = results[r]>
            <cfset content &= "
                    <tr>
                        <td>#EncodeForHTML(row.firstName)#</td>
                        <td>#EncodeForHTML(row.lastName)#</td>
                        <td>#EncodeForHTML(row.uhApiId)#</td>
                        <td>#EncodeForHTML(row.action)#</td>
                        <td>#EncodeForHTML(row.reason)#</td>
                        <td class='text-nowrap'>
                            <a href='/admin/users/uh_person.cfm?uhApiId=#urlEncodedFormat(row.uhApiId)#' class='btn btn-sm btn-outline-primary'>Review</a>
            ">
            <cfif row.action EQ "Inserted">
                <cfset content &= "
                                <a href='/admin/users/quick_import_person.cfm?uhApiId=#urlEncodedFormat(row.uhApiId)#&returnTo=#urlEncodedFormat(cgi.SCRIPT_NAME)#'
                                   class='btn btn-sm btn-success ms-1'>Quick Import</a>
                                <form method='post' class='admin-inline-form'>
                                    <input type='hidden' name='deleteFromStaging' value='1'>
                                    <input type='hidden' name='deleteUHApiID' value='#row.uhApiId#'>
                                    <button type='submit' class='btn btn-sm btn-outline-danger ms-1' onclick='return confirm(&quot;Remove from staging?&quot;);'>Delete</button>
                                </form>
                ">
            </cfif>
            <cfset content &= "
                        </td>
                    </tr>
            ">
        </cfloop>

        <cfset content &= "
                </tbody>
            </table>
        </div>
        ">
    </cfif>
</cfif>

<cfinclude template="/admin/layout.cfm">