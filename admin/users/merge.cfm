<!--- Duplicate merge workspace (phase 2: decision capture + status update). --->
<cfif NOT application.authService.hasRole("SUPER_ADMIN") AND NOT request.hasPermission("reporting.duplicate_users.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset pairID = (isNumeric(url.pairID ?: "") AND val(url.pairID) GT 0) ? val(url.pairID) : 0>
<cfset duplicateSvc = createObject("component", "cfc.duplicateUsers_service").init()>
<cfset msgParam = trim(url.msg ?: "")>
<cfset errParam = trim(url.err ?: "")>
<cfset warnParam = trim(url.warn ?: "")>
<cfset deepType = lCase(trim(url.deep ?: ""))>
<cfif NOT listFindNoCase("profile,aliases,emails,phones,addresses,flags,organizations,external_ids,bio,academic,degrees,awards,student_profile,review_submissions,images", deepType)>
    <cfset deepType = "">
</cfif>
<cfset pair = {}>
<cfset latestMerge = {}>
<cfset latestMergeChoices = {}>
<cfset mergeSummary = {}>
<cfset mergeWarnings = []>
<cfset quickSignals = []>
<cfset deepScanResult = {}>
<cfset deepRowsA = []>
<cfset deepRowsB = []>

<cfif cgi.request_method EQ "POST">
    <cfset action = trim(form.action ?: "")>
    <cfif action EQ "mergePair" AND isNumeric(form.pairID ?: "") AND isNumeric(form.primaryUserID ?: "")>
        <cfset submittedPairID = val(form.pairID)>
        <cfset submittedPrimaryUserID = val(form.primaryUserID)>
        <cfset adminUserID = (structKeyExists(session, "user") AND isStruct(session.user) AND isNumeric(session.user.adminUserID ?: "")) ? val(session.user.adminUserID) : 0>
        <cfset result = duplicateSvc.mergePair(
            pairID = submittedPairID,
            primaryUserID = submittedPrimaryUserID,
            mergedByAdminUserID = adminUserID,
            notes = trim(form.notes ?: "")
        )>

        <cfif result.success>
            <cfset successWarn = "">
            <cfset successRedirectUrl = request.webRoot & "/admin/users/merge.cfm?pairID=" & urlEncodedFormat(submittedPairID) & "&msg=merged">
            <cfif structKeyExists(result, "warnings") AND isArray(result.warnings) AND arrayLen(result.warnings)>
                <cfset successWarn = result.warnings[1]>
            </cfif>
            <cfif len(successWarn)>
                <cfset successRedirectUrl &= "&warn=" & urlEncodedFormat(successWarn)>
            </cfif>
            <cflocation url="#successRedirectUrl#" addtoken="false">
        <cfelse>
            <cflocation url="#request.webRoot#/admin/users/merge.cfm?pairID=#urlEncodedFormat(submittedPairID)#&msg=error&err=#urlEncodedFormat(result.message ?: 'Merge failed.')#" addtoken="false">
        </cfif>
    <cfelseif action EQ "ignorePair" AND isNumeric(form.pairID ?: "")>
        <cfset duplicateSvc.ignorePair(val(form.pairID), trim(form.reason ?: "Marked as not a duplicate."))>
        <cflocation url="#request.webRoot#/admin/users/merge.cfm?pairID=#urlEncodedFormat(val(form.pairID))#&msg=ignored" addtoken="false">
    <cfelseif action EQ "unignorePair" AND isNumeric(form.pairID ?: "")>
        <cfset duplicateSvc.unignorePair(val(form.pairID))>
        <cflocation url="#request.webRoot#/admin/users/merge.cfm?pairID=#urlEncodedFormat(val(form.pairID))#&msg=restored" addtoken="false">
    </cfif>
</cfif>

<cfif pairID GT 0>
    <cfset pair = duplicateSvc.getPairByID(pairID)>
    <cfset latestMerge = duplicateSvc.getLatestMergeByPairID(pairID)>
    <cfif NOT structIsEmpty(pair)>
        <cfset quickSignals = duplicateSvc.parseSignalsJSON(pair.MATCHSIGNALS ?: "[]")>
    </cfif>

    <cfif NOT structIsEmpty(pair) AND len(deepType)>
        <cfset deepScanResult = duplicateSvc.getPairDeepScan(pairID=pairID, scanType=deepType)>
        <cfif deepScanResult.success>
            <cfset deepRowsA = deepScanResult.data.userA.rows>
            <cfset deepRowsB = deepScanResult.data.userB.rows>
        </cfif>
    </cfif>

    <cfif NOT structIsEmpty(latestMerge) AND isJSON(latestMerge.MERGECHOICES ?: "")>
        <cfset latestMergeChoices = deserializeJSON(latestMerge.MERGECHOICES)>
        <cfif isStruct(latestMergeChoices) AND structKeyExists(latestMergeChoices, "dataMigrationSummary") AND isStruct(latestMergeChoices.dataMigrationSummary)>
            <cfset mergeSummary = latestMergeChoices.dataMigrationSummary>
        </cfif>
        <cfif isStruct(latestMergeChoices) AND structKeyExists(latestMergeChoices, "warnings") AND isArray(latestMergeChoices.warnings)>
            <cfset mergeWarnings = latestMergeChoices.warnings>
        </cfif>
    </cfif>
</cfif>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>
<h1 class="mb-1">Review Duplicate Pair</h1>
<p class="text-muted">Review quick signals, run deep scan comparisons for this pair, then merge or ignore from this page.</p>

<cfif msgParam EQ "merged">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Pair was marked as merged successfully.</div>
<cfelseif msgParam EQ "ignored">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Pair was marked ignored.</div>
<cfelseif msgParam EQ "restored">
    <div class="alert alert-success mt-3"><i class="bi bi-check-circle-fill"></i> Pair was restored to pending.</div>
<cfelseif msgParam EQ "error">
    <div class="alert alert-danger mt-3"><strong>Merge failed:</strong> #encodeForHTML(errParam ?: "Unknown error")#</div>
</cfif>

<cfif len(warnParam)>
    <div class="alert alert-warning mt-3"><strong>Merge note:</strong> #encodeForHTML(warnParam)#</div>
</cfif>

<cfif pairID LTE 0>
    <div class="alert alert-warning">Missing or invalid pair ID.</div>
<cfelseif structIsEmpty(pair)>
    <div class="alert alert-warning">Pair not found.</div>
<cfelse>
    <cfset pairStatus = lCase(trim(pair.STATUS ?: "pending"))>
    <cfset isMerged = pairStatus EQ "merged">

    <cfif isMerged>
        <div class="alert alert-info">
            This pair is already merged.
            <cfif NOT structIsEmpty(latestMerge)>
                Primary user ## #val(latestMerge.PRIMARYUSERID ?: 0)#, secondary user ## #val(latestMerge.SECONDARYUSERID ?: 0)#.
            </cfif>
        </div>

        <cfif arrayLen(mergeWarnings)>
            <div class="alert alert-warning">
                <strong>Merge warnings:</strong>
                <ul class="mb-0 mt-2">
                    <cfloop from="1" to="#arrayLen(mergeWarnings)#" index="wIdx">
                        <li>#encodeForHTML(mergeWarnings[wIdx] ?: "")#</li>
                    </cfloop>
                </ul>
            </div>
        </cfif>

        <cfif structCount(mergeSummary)>
            <div class="card card-body mt-3">
                <h5 class="mb-2">Merge Result Summary</h5>
                <div class="table-responsive">
                    <table class="table table-sm align-middle mb-0">
                        <thead>
                            <tr>
                                <th>Area</th>
                                <th class="text-end">Moved</th>
                                <th class="text-end">Deduped</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td>Emails</td><td class="text-end">#val(mergeSummary.EMAILSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.EMAILSDEDUPED ?: 0)#</td></tr>
                            <tr><td>Phones</td><td class="text-end">#val(mergeSummary.PHONESMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.PHONESDEDUPED ?: 0)#</td></tr>
                            <tr><td>Addresses</td><td class="text-end">#val(mergeSummary.ADDRESSESMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.ADDRESSESDEDUPED ?: 0)#</td></tr>
                            <tr><td>Flags</td><td class="text-end">#val(mergeSummary.FLAGSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.FLAGSDEDUPED ?: 0)#</td></tr>
                            <tr><td>Organizations</td><td class="text-end">#val(mergeSummary.ORGANIZATIONSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.ORGANIZATIONSDEDUPED ?: 0)#</td></tr>
                            <tr><td>Access Assignments</td><td class="text-end">#val(mergeSummary.ACCESSASSIGNMENTSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.ACCESSASSIGNMENTSDEDUPED ?: 0)#</td></tr>
                            <tr><td>External IDs</td><td class="text-end">#val(mergeSummary.EXTERNALIDSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.EXTERNALIDSDEDUPED ?: 0)#</td></tr>
                            <tr><td>Aliases</td><td class="text-end">#val(mergeSummary.ALIASESMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.ALIASESDEDUPED ?: 0)#</td></tr>
                            <tr><td>Degrees</td><td class="text-end">#val(mergeSummary.DEGREESMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.DEGREESDEDUPED ?: 0)#</td></tr>
                            <tr><td>Awards</td><td class="text-end">#val(mergeSummary.AWARDSMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.AWARDSDEDUPED ?: 0)#</td></tr>
                            <tr><td>Images</td><td class="text-end">#val(mergeSummary.IMAGESMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.IMAGESDEDUPED ?: 0)#</td></tr>
                            <tr><td>Review Submissions</td><td class="text-end">#val(mergeSummary.REVIEWSUBMISSIONSMOVED ?: 0)#</td><td class="text-end">0</td></tr>
                            <tr><td>Academic Info</td><td class="text-end">#val(mergeSummary.ACADEMICINFOMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.ACADEMICINFOMERGED ?: 0)#</td></tr>
                            <tr><td>Bio</td><td class="text-end">#val(mergeSummary.BIOMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.BIOMERGED ?: 0)#</td></tr>
                            <tr><td>Student Profile</td><td class="text-end">#val(mergeSummary.STUDENTPROFILEMOVED ?: 0)#</td><td class="text-end">#val(mergeSummary.STUDENTPROFILEMERGED ?: 0)#</td></tr>
                            <tr><td>Secondary Deactivated</td><td class="text-end">#val(mergeSummary.SECONDARYDEACTIVATED ?: 0)#</td><td class="text-end">0</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </cfif>
    <cfelse>
        <div class="alert alert-warning">This operation reassigns non-duplicate child records (emails, phones, addresses, flags, organizations, access, external IDs, aliases, degrees, awards, images, review submissions), merges singleton profile data where primary fields are empty, and deactivates the secondary user.</div>
    </cfif>

    <div class="row g-3">
        <div class="col-md-6">
            <div class="card card-body h-100">
                <h5 class="mb-2">User A (#pair.USERID_A#)</h5>
                <div><strong>Name:</strong> #encodeForHTML(trim((pair.USERAFIRSTNAME ?: "") & " " & (pair.USERALASTNAME ?: "")))#</div>
                <div><strong>Email:</strong> #encodeForHTML(pair.USERAEMAIL ?: "")#</div>
                <div><strong>Flags:</strong> #encodeForHTML(pair.USERAFLAGS ?: "none")#</div>
                <div><strong>Grad Year:</strong> #val(pair.USERAGRADYEAR ?: 0)#</div>
            </div>
        </div>
        <div class="col-md-6">
            <div class="card card-body h-100">
                <h5 class="mb-2">User B (#pair.USERID_B#)</h5>
                <div><strong>Name:</strong> #encodeForHTML(trim((pair.USERBFIRSTNAME ?: "") & " " & (pair.USERBLASTNAME ?: "")))#</div>
                <div><strong>Email:</strong> #encodeForHTML(pair.USERBEMAIL ?: "")#</div>
                <div><strong>Flags:</strong> #encodeForHTML(pair.USERBFLAGS ?: "none")#</div>
                <div><strong>Grad Year:</strong> #val(pair.USERBGRADYEAR ?: 0)#</div>
            </div>
        </div>
    </div>

    <div class="card card-body mt-3">
        <h5 class="mb-2">Quick Scan Signals</h5>
        <cfif arrayLen(quickSignals) EQ 0>
            <div class="text-muted">No quick-scan signals saved for this pair.</div>
        <cfelse>
            <div class="d-flex flex-wrap gap-2">
                <cfloop from="1" to="#arrayLen(quickSignals)#" index="sigIdx">
                    <cfset s = quickSignals[sigIdx]>
                    <span class="badge bg-light text-dark border">#encodeForHTML(duplicateSvc.signalLabel(s.type ?: "", s.value ?: ""))#</span>
                </cfloop>
            </div>
        </cfif>
    </div>

    <div class="card card-body mt-3">
        <h5 class="mb-2">Deep Scan (Per Pair)</h5>
        <p class="text-muted mb-2">Choose one data area to compare User A vs User B.</p>
        <div class="d-flex flex-wrap gap-2 mb-3">
            <a class="btn btn-sm #deepType EQ 'profile' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=profile">Profile</a>
            <a class="btn btn-sm #deepType EQ 'aliases' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=aliases">Aliases</a>
            <a class="btn btn-sm #deepType EQ 'emails' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=emails">Emails</a>
            <a class="btn btn-sm #deepType EQ 'phones' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=phones">Phones</a>
            <a class="btn btn-sm #deepType EQ 'addresses' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=addresses">Addresses</a>
            <a class="btn btn-sm #deepType EQ 'flags' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=flags">Flags</a>
            <a class="btn btn-sm #deepType EQ 'organizations' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=organizations">Orgs</a>
            <a class="btn btn-sm #deepType EQ 'external_ids' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=external_ids">External IDs</a>
            <a class="btn btn-sm #deepType EQ 'bio' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=bio">Bio</a>
            <a class="btn btn-sm #deepType EQ 'academic' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=academic">Academic</a>
            <a class="btn btn-sm #deepType EQ 'degrees' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=degrees">Degrees</a>
            <a class="btn btn-sm #deepType EQ 'awards' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=awards">Awards</a>
            <a class="btn btn-sm #deepType EQ 'student_profile' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=student_profile">Student Profile</a>
            <a class="btn btn-sm #deepType EQ 'review_submissions' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=review_submissions">Review Submissions</a>
            <a class="btn btn-sm #deepType EQ 'images' ? 'btn-ui-filter' : 'btn-ui-go'#" href="?pairID=#pairID#&deep=images">Images</a>
        </div>

        <cfif NOT len(deepType)>
            <div class="text-muted">Select a deep-scan category above.</div>
        <cfelse>
            <div class="row g-3">
                <div class="col-md-6">
                    <h6>User A (#pair.USERID_A#)</h6>
                    <pre class="small bg-light border p-2 mb-0" style="max-height: 420px; overflow:auto;">#encodeForHTML(serializeJSON(deepRowsA, true))#</pre>
                </div>
                <div class="col-md-6">
                    <h6>User B (#pair.USERID_B#)</h6>
                    <pre class="small bg-light border p-2 mb-0" style="max-height: 420px; overflow:auto;">#encodeForHTML(serializeJSON(deepRowsB, true))#</pre>
                </div>
            </div>
        </cfif>
    </div>

    <cfif pairStatus EQ "pending">
        <form method="post" class="card card-body mt-3">
            <input type="hidden" name="action" value="mergePair">
            <input type="hidden" name="pairID" value="#pairID#">

            <h5 class="mb-2">Merge Decision</h5>
            <p class="text-muted mb-2">Choose the user profile to keep as the primary account. Duplicate child rows are skipped and the secondary account is set inactive.</p>

            <div class="form-check mb-1">
                <input class="form-check-input" type="radio" name="primaryUserID" id="keepUserA" value="#val(pair.USERID_A)#" checked>
                <label class="form-check-label" for="keepUserA">Keep User A as Primary (## #val(pair.USERID_A)#)</label>
            </div>
            <div class="form-check mb-3">
                <input class="form-check-input" type="radio" name="primaryUserID" id="keepUserB" value="#val(pair.USERID_B)#">
                <label class="form-check-label" for="keepUserB">Keep User B as Primary (## #val(pair.USERID_B)#)</label>
            </div>

            <label for="mergeNotes" class="form-label">Notes (optional)</label>
            <textarea id="mergeNotes" name="notes" class="form-control" rows="3" maxlength="500" placeholder="Why this primary user was selected"></textarea>

            <div class="mt-3 d-flex gap-2">
                <button type="submit" class="btn btn-ui-save">Confirm Merge</button>
                <a href="/admin/reporting/duplicate_users_report.cfm" class="btn btn-ui-cancel">Cancel</a>
            </div>
        </form>

        <form method="post" class="card card-body mt-3">
            <input type="hidden" name="action" value="ignorePair">
            <input type="hidden" name="pairID" value="#pairID#">
            <input type="hidden" name="reason" value="Marked as not a duplicate during pair review.">
            <div class="d-flex gap-2 align-items-center">
                <div class="text-muted">Ignore this pair when it is not a true duplicate.</div>
                <button type="submit" class="btn btn-ui-warning btn-sm">Ignore Pair</button>
            </div>
        </form>
    <cfelseif pairStatus EQ "ignored">
        <form method="post" class="card card-body mt-3">
            <input type="hidden" name="action" value="unignorePair">
            <input type="hidden" name="pairID" value="#pairID#">
            <div class="d-flex gap-2 align-items-center">
                <div class="text-muted">This pair is currently ignored.</div>
                <button type="submit" class="btn btn-ui-go btn-sm">Restore To Pending</button>
            </div>
        </form>
    <cfelse>
        <div class="card card-body mt-3">
            <div class="text-muted">No actions are available for this merged pair.</div>
        </div>
    </cfif>
</cfif>

<div class="mt-3">
    <a href="/admin/reporting/duplicate_users_report.cfm" class="btn btn-ui-cancel">Back to Duplicate Report</a>
</div>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
