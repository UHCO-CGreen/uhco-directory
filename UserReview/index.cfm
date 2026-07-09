<cfset userReviewAuth = structKeyExists(request, "userReviewAuth") ? request.userReviewAuth : createObject("component", "cfc.UserReviewAuthService").init()>

<cfif NOT userReviewAuth.isLoggedIn()>
    <cflocation url="/UserReview/login.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset currentUser = userReviewAuth.getSessionUser()>
<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset launchContext = structKeyExists(currentUser, "launchContext") AND isStruct(currentUser.launchContext) ? currentUser.launchContext : {}>
<cfset isDelegatedLaunch = structCount(launchContext) GT 0>
<cfset activeTargetUserID = (isDelegatedLaunch AND isNumeric(launchContext.targetUserId ?: "") AND val(launchContext.targetUserId) GT 0) ? val(launchContext.targetUserId) : currentUser.userID>
<cfset eligibility = userReviewService.getEligibilityResult(activeTargetUserID)>
<cfset settings = userReviewService.getSettings()>
<cfset formModel = userReviewService.getEditableFormModel(activeTargetUserID)>
<cfset livePublicationsModel = userReviewService.getLivePublicationsModel(activeTargetUserID)>
<cfset statusMessage = trim(url.msg ?: "")>
<cfset errorMessage = trim(url.error ?: "")>
<cfset seedAliasesJson = serializeJSON(formModel.general.NameAliases)>
<cfset seedAppointmentsJson = serializeJSON(formModel.general.Appointments)>
<cfset seedEmailsJson = serializeJSON(formModel.contact.emails)>
<cfset seedPhonesJson = serializeJSON(formModel.contact.phones)>
<cfset seedAddressesJson = serializeJSON(formModel.contact.addresses)>
<cfset latestReviewedSubmission = formModel.latestReviewedSubmission ?: {}>
<cfset latestReviewedStatus = trim(latestReviewedSubmission.STATUS ?: "")>
<cfset latestReviewedAlertClass = latestReviewedStatus EQ "approved" ? "success" : (latestReviewedStatus EQ "rejected" ? "danger" : "warning")>
<cfset hasPendingSubmission = structKeyExists(formModel.pendingSubmission, "SUBMISSIONID")>
<cfset launchSections = settings.editableSections>
<cfif isDelegatedLaunch AND structKeyExists(launchContext, "sections") AND isArray(launchContext.sections) AND arrayLen(launchContext.sections)>
    <cfset launchSections = launchContext.sections>
</cfif>
<cfset targetDisplayName = trim((eligibility.user.FIRSTNAME ?: "") & " " & (eligibility.user.LASTNAME ?: ""))>

<cfif NOT eligibility.success>
    <cfset content = "">
    <cfsavecontent variable="content">
    <cfoutput>
    <div class="card ur-card">
        <div class="card-body p-4">
            <div class="alert alert-warning mb-0">#encodeForHTML(eligibility.message)#</div>
        </div>
    </div>
    </cfoutput>
    </cfsavecontent>
    <cfset pageTitle = "UserReview">
    <cfinclude template="/UserReview/layout.cfm">
    <cfabort>
</cfif>

<cfset editableGeneral = arrayFindNoCase(settings.editableSections, "general") GT 0 AND arrayFindNoCase(launchSections, "general") GT 0>
<cfset editableContact = arrayFindNoCase(settings.editableSections, "contact") GT 0 AND arrayFindNoCase(launchSections, "contact") GT 0>
<cfset editableBio = arrayFindNoCase(settings.editableSections, "bioinfo") GT 0 AND arrayFindNoCase(launchSections, "bioinfo") GT 0>
<cfset showLivePublications = isBoolean(livePublicationsModel.isEligible ?: "") ? livePublicationsModel.isEligible : (val(livePublicationsModel.isEligible ?: 0) EQ 1)>
<cfset livePublicationProfilesByCode = isStruct(livePublicationsModel.publicationProfilesByCode ?: "") ? livePublicationsModel.publicationProfilesByCode : {}>
<cfset livePublicationFetchByCode = isStruct(livePublicationsModel.publicationFetchByCode ?: "") ? livePublicationsModel.publicationFetchByCode : {}>
<cfset liveUserPublications = isArray(livePublicationsModel.publications ?: "") ? livePublicationsModel.publications : []>
<cfset livePublicationMaxShowcased = val(livePublicationsModel.maxShowcasedPerUser ?: 10)>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<cfif len(statusMessage)>
    <div class="alert alert-success">#encodeForHTML(statusMessage)#</div>
</cfif>
<cfif len(errorMessage)>
    <div class="alert alert-danger">#encodeForHTML(errorMessage)#</div>
</cfif>

<cfif isDelegatedLaunch>
    <div class="alert alert-info mb-4">
        <div><strong>Delegated edit session:</strong> you are preparing a staged profile edit for #encodeForHTML(len(targetDisplayName) ? targetDisplayName : ("User ID " & activeTargetUserID))#.</div>
        <div class="small mt-2">Allowed sections: #encodeForHTML(arrayToList(launchSections, ", "))#</div>
    </div>
</cfif>

<cfif NOT hasPendingSubmission AND structCount(latestReviewedSubmission) AND len(latestReviewedStatus)>
    <div class="alert alert-#latestReviewedAlertClass# mb-4">
        <div><strong>Review update:</strong> Changes submitted on #dateTimeFormat(latestReviewedSubmission.SUBMITTEDAT, "mmm d, yyyy h:nn tt")# were #encodeForHTML(replace(latestReviewedStatus, "_", " ", "all"))#<cfif isDate(latestReviewedSubmission.REVIEWEDAT ?: "")> on #dateTimeFormat(latestReviewedSubmission.REVIEWEDAT, "mmm d, yyyy h:nn tt")#</cfif>.</div>
        <cfif listFindNoCase("rejected,partially_approved", latestReviewedStatus) AND len(trim(latestReviewedSubmission.REVIEWNOTE ?: ""))>
            <div class="mt-2"><strong>Reason:</strong></div>
            <pre class="small bg-white border rounded p-3 mt-2 mb-0">#encodeForHTML(latestReviewedSubmission.REVIEWNOTE)#</pre>
        </cfif>
    </div>
</cfif>

<div class="card ur-card mb-4">
    <div class="card-body p-4">
        <div class="d-flex justify-content-between align-items-start gap-3 flex-wrap">
            <div>
                <h2 class="h4 mb-2">#encodeForHTML(isDelegatedLaunch ? "Delegated Profile Review" : "Profile Review")#</h2>
                <p class="text-muted mb-0">#encodeForHTML(isDelegatedLaunch ? "Changes from this session are submitted as a staged delegated review for the selected user." : "Your changes are submitted as a staged review. Nothing updates live until an admin approves it.")#</p>
            </div>
            <div class="text-end">
                <div class="small text-muted">Eligible audiences</div>
                <div class="fw-semibold text-capitalize">#encodeForHTML(arrayToList(eligibility.audiences, ", "))#</div>
            </div>
        </div>

        <cfif structKeyExists(formModel.pendingSubmission, "SUBMISSIONID")>
            <div class="alert alert-warning mt-4 mb-0">
                <strong>Pending submission:</strong>
                submitted #dateTimeFormat(formModel.pendingSubmission.SUBMITTEDAT, "mmm d, yyyy h:nn tt")#.
                #encodeForHTML(isDelegatedLaunch ? "A new delegated save will replace the currently pending staged changes for this user." : "A new save will replace the currently pending staged changes.")#
            </div>
        </cfif>
    </div>
</div>

<form method="post" action="/UserReview/save.cfm">
    <cfif editableGeneral>
    <div class="card ur-card mb-4">
        <div class="card-body p-4">
            <h3 class="h5 mb-3">General Information</h3>
            <div class="row g-3">
                <div class="col-md-4">
                    <label class="form-label">Prefix</label>
                    <input class="form-control" name="Prefix" value="#encodeForHTMLAttribute(formModel.general.Prefix)#">
                </div>
                <div class="col-md-4">
                    <label class="form-label">Suffix</label>
                    <input class="form-control" name="Suffix" value="#encodeForHTMLAttribute(formModel.general.Suffix)#">
                </div>
                <div class="col-md-4">
                    <label class="form-label">Pronouns</label>
                    <input class="form-control" name="Pronouns" value="#encodeForHTMLAttribute(formModel.general.Pronouns)#">
                </div>
                <div class="col-12">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <h4 class="h6 mb-0">Name Aliases</h4>
                        <button type="button" class="btn btn-sm btn-outline-primary" data-add-row="alias">Add Alias</button>
                    </div>
                    <div id="aliasRows"></div>
                    <input type="hidden" id="aliasCount" name="aliasCount" value="0">
                    <div class="form-text">Aliases sourced from LDAP or UH API are shown for reference and cannot be removed here.</div>
                </div>
                <div class="col-md-6">
                    <label class="form-label">Title 1</label>
                    <input class="form-control" value="#encodeForHTMLAttribute(formModel.general.Title1)#" readonly disabled>
                    <div class="form-text">This title is your Official UH title and is shown for reference and cannot be changed here.</div>
                </div>
                <div class="col-12">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <h4 class="h6 mb-0">Appointments</h4>
                        <button type="button" class="btn btn-sm btn-outline-primary" data-add-row="appointment">Add Appointment</button>
                    </div>
                    <div id="appointmentRows"></div>
                    <input type="hidden" id="appointmentCount" name="appointmentCount" value="0">
                </div>
            </div>
        </div>
    </div>
    </cfif>

    <cfif editableContact>
    <div class="card ur-card mb-4">
        <div class="card-body p-4">
            <h3 class="h5 mb-3">Contact Information</h3>

            <div class="mb-4">
                <div class="row g-3 mb-3">
                    <div class="col-md-8 col-lg-6">
                        <label class="form-label">Primary UH Email</label>
                        <input class="form-control" value="#encodeForHTMLAttribute(formModel.contact.EmailPrimary)#" readonly disabled>
                        <div class="form-text">Your primary UH email is managed separately and cannot be changed here.  If no emails listed below are set to Primary, this email will be used as the primary contact.</div>
                    </div>
                </div>
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Email Addresses</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-row="email">Add Email</button>
                </div>
                <div id="emailRows"></div>
                <input type="hidden" id="emailCount" name="emailCount" value="0">
                <div class="form-text">@uh.edu addresses are managed separately and are not editable here. Email type @cougarnet cannot be removed here.</div>
            </div>

            <div class="mb-4">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Phone Numbers</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-row="phone">Add Phone</button>
                </div>
                <div id="phoneRows"></div>
                <input type="hidden" id="phoneCount" name="phoneCount" value="0">
            </div>

            <div>
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Addresses</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" data-add-row="address">Add Address</button>
                </div>
                <div id="addressRows"></div>
                <input type="hidden" id="addressCount" name="addressCount" value="0">
            </div>
        </div>
    </div>
    </cfif>

    <cfif editableBio>
    <div class="card ur-card mb-4">
        <div class="card-body p-4">
            <h3 class="h5 mb-3">Biographical Information</h3>
            <div class="row g-3">
                <div class="col-md-4">
                    <label class="form-label">Date of Birth</label>
                    <input type="date" class="form-control" name="DOB" value="#encodeForHTMLAttribute(formModel.bioinfo.DOB)#">
                </div>
                <div class="col-md-4">
                    <label class="form-label">Gender</label>
                    <select class="form-select" name="Gender">
                        <option value="">--</option>
                        <option value="Male" #(formModel.bioinfo.Gender EQ "Male" ? "selected" : "")#>Male</option>
                        <option value="Female" #(formModel.bioinfo.Gender EQ "Female" ? "selected" : "")#>Female</option>
                    </select>
                </div>
            </div>
        </div>
    </div>
    </cfif>

    <div class="d-flex justify-content-end">
        <button type="submit" class="btn btn-primary btn-lg">Submit For Review</button>
    </div>
</form>

<cfif showLivePublications>
<div class="card ur-card mb-4" id="userReviewPublicationsCard">
    <div class="card-body p-4">
        <div class="d-flex justify-content-between align-items-start gap-3 flex-wrap mb-3">
            <div>
                <h3 class="h5 mb-2">ORCID Publications</h3>
                <p class="text-muted mb-0">Changes in this section apply live immediately. They are not routed through the staged UserReview approval flow.</p>
            </div>
            <div class="small text-muted">Showcase limit: #livePublicationMaxShowcased#</div>
        </div>

        <div id="userReviewPublicationsStatus" class="small mb-3"></div>

        <div class="row g-3 mb-4">
            <div class="col-12 col-lg-6">
                <label class="form-label" for="userReviewOrcidIdentifier">ORCID iD</label>
                <input class="form-control" id="userReviewOrcidIdentifier" value="#encodeForHTMLAttribute(structKeyExists(livePublicationProfilesByCode, "orcid") ? (livePublicationProfilesByCode["orcid"].PROFILEIDENTIFIER ?: "") : "")#" placeholder="0000-0000-0000-0000">
            </div>
            <div class="col-12 col-lg-6">
                <label class="form-label" for="userReviewOrcidUrl">ORCID URL</label>
                <input class="form-control" id="userReviewOrcidUrl" value="#encodeForHTMLAttribute((structKeyExists(livePublicationProfilesByCode, "orcid") AND len(trim(livePublicationProfilesByCode["orcid"].PROFILEURL ?: ""))) ? livePublicationProfilesByCode["orcid"].PROFILEURL : "https://orcid.org/")#" placeholder="https://orcid.org/" readonly disabled>
            </div>
            <div class="col-12 d-flex align-items-center gap-2 flex-wrap">
                <div class="form-check mb-0">
                    <input class="form-check-input" type="checkbox" id="userReviewLimitRecentYears" checked>
                    <label class="form-check-label" for="userReviewLimitRecentYears">Limit imported publications to the past 5 years</label>
                </div>
            </div>
            <div class="col-12 d-flex align-items-center gap-2 flex-wrap">
                <button type="button" class="btn btn-primary" id="userReviewSaveOrcidBtn">Save ORCID</button>
                <button type="button" class="btn btn-outline-primary" id="userReviewFetchOrcidBtn">Fetch ORCID Publications</button>
                <span class="small text-muted">Last fetch: #encodeForHTML(structKeyExists(livePublicationFetchByCode, "orcid") ? (livePublicationFetchByCode["orcid"].STARTEDAT ?: "Never") : "Never")#</span>
            </div>
        </div>

        <div class="row g-3" id="userReviewPublicationsPanels" data-max-showcased="#livePublicationMaxShowcased#">
            <div class="col-12 col-xl-7">
                <div class="border rounded p-3 h-100 bg-white">
                    <div class="d-flex justify-content-between align-items-center gap-2 mb-3">
                        <h4 class="h6 mb-0">All Imported Publications</h4>
                        <span class="small text-muted">Use the right arrow to showcase a publication.</span>
                    </div>
                    <cfif arrayLen(liveUserPublications) GT 0>
                        <div class="row g-3">
                            <cfloop from="1" to="#arrayLen(liveUserPublications)#" index="local.pubIndex">
                                <cfset local.pub = liveUserPublications[local.pubIndex]>
                                <cfset local.sourceLabel = listFindNoCase(local.pub.SOURCESERVICES ?: "", "ORCID") ? "ORCID" : "Imported source">
                                <div class="col-12">
                                    <div class="border rounded p-3" data-publication-card="#val(local.pub.PUBLICATIONID)#">
                                        <div class="d-flex align-items-start justify-content-between gap-3 flex-wrap">
                                            <div>
                                                <div class="fw-semibold">#encodeForHTML(local.pub.CANONICALTITLE ?: "Untitled publication")#</div>
                                                <div class="small text-muted">#encodeForHTML(local.pub.CANONICALAUTHORSTEXT ?: "")#</div>
                                                <div class="small text-muted">#encodeForHTML(local.pub.PUBLICATIONYEAR ?: "")# #encodeForHTML(local.pub.JOURNALORSOURCE ?: "")#</div>
                                                <div class="small text-muted">Source: #encodeForHTML(local.sourceLabel)#</div>
                                            </div>
                                            <div>
                                                <cfif val(local.pub.ISSHOWCASED ?: 0) EQ 1>
                                                    <span class="badge text-bg-success">Showcased</span>
                                                <cfelse>
                                                    <button type="button" class="btn btn-sm btn-outline-primary userreview-publication-move-btn" data-direction="add" data-publication-id="#val(local.pub.PUBLICATIONID)#">&rarr;</button>
                                                </cfif>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </cfloop>
                        </div>
                    <cfelse>
                        <p class="text-muted mb-0">No publications have been imported yet. Save your ORCID iD, then fetch your ORCID publications.</p>
                    </cfif>
                </div>
            </div>
            <div class="col-12 col-xl-5">
                <div class="border rounded p-3 h-100 bg-white">
                    <div class="d-flex justify-content-between align-items-center gap-2 mb-3">
                        <h4 class="h6 mb-0">Showcased Publications</h4>
                        <span class="small text-muted">Only live showcased publications appear here.</span>
                    </div>
                    <cfif arrayLen(liveUserPublications) GT 0>
                        <cfset local.liveShowcasedCount = 0>
                        <div class="row g-3" id="userReviewShowcasedPublicationsList">
                            <cfloop from="1" to="#arrayLen(liveUserPublications)#" index="local.pubIndex">
                                <cfset local.pub = liveUserPublications[local.pubIndex]>
                                <cfif val(local.pub.ISSHOWCASED ?: 0) EQ 1>
                                    <cfset local.liveShowcasedCount++>
                                    <div class="col-12 userreview-showcased-publication-item" data-publication-id="#val(local.pub.PUBLICATIONID)#">
                                        <div class="border rounded p-3 bg-light">
                                            <div class="d-flex align-items-start justify-content-between gap-3 flex-wrap">
                                                <div>
                                                    <div class="fw-semibold">#encodeForHTML(local.pub.CANONICALTITLE ?: "Untitled publication")#</div>
                                                    <div class="small text-muted">#encodeForHTML(local.pub.CANONICALAUTHORSTEXT ?: "")#</div>
                                                    <div class="small text-muted">Display order: #val(local.pub.DISPLAYORDER ?: local.pubIndex)#</div>
                                                </div>
                                                <button type="button" class="btn btn-sm btn-outline-secondary userreview-publication-move-btn" data-direction="remove" data-publication-id="#val(local.pub.PUBLICATIONID)#">&larr;</button>
                                            </div>
                                        </div>
                                    </div>
                                </cfif>
                            </cfloop>
                        </div>
                        <cfif local.liveShowcasedCount EQ 0>
                            <p class="text-muted mb-0">No publications are currently showcased.</p>
                        </cfif>
                    <cfelse>
                        <p class="text-muted mb-0">No publications are currently showcased.</p>
                    </cfif>
                </div>
            </div>
        </div>
    </div>
</div>
</cfif>

</cfoutput>

<cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>
    const seedAliases = <cfoutput>#seedAliasesJson#</cfoutput>;
    const seedAppointments = <cfoutput>#seedAppointmentsJson#</cfoutput>;
    const seedEmails = <cfoutput>#seedEmailsJson#</cfoutput>;
    const seedPhones = <cfoutput>#seedPhonesJson#</cfoutput>;
    const seedAddresses = <cfoutput>#seedAddressesJson#</cfoutput>;

    function getSeedValue(source, keys, fallback = '') {
        for (const key of keys) {
            if (source && source[key] !== undefined && source[key] !== null) {
                return source[key];
            }
        }
        return fallback;
    }

    function normalizeEmailSeed(data = {}) {
        return {
            address: getSeedValue(data, ['address', 'ADDRESS', 'EmailAddress', 'EMAILADDRESS']),
            type: getSeedValue(data, ['type', 'TYPE', 'EmailType', 'EMAILTYPE']),
            isPrimary: Number(getSeedValue(data, ['isPrimary', 'ISPRIMARY', 'IsPrimary'], 0)),
            isProtected: Number(getSeedValue(data, ['isProtected', 'ISPROTECTED', 'IsProtected'], 0))
        };
    }

    function normalizeAliasSeed(data = {}) {
        return {
            firstName: getSeedValue(data, ['firstName', 'FIRSTNAME', 'FirstName']),
            middleName: getSeedValue(data, ['middleName', 'MIDDLENAME', 'MiddleName']),
            lastName: getSeedValue(data, ['lastName', 'LASTNAME', 'LastName']),
            aliasType: getSeedValue(data, ['aliasType', 'ALIASTYPE', 'AliasType']),
            sourceSystem: getSeedValue(data, ['sourceSystem', 'SOURCESYSTEM', 'SourceSystem']),
            isActive: Number(getSeedValue(data, ['isActive', 'ISACTIVE', 'IsActive'], 1)),
            isPrimary: Number(getSeedValue(data, ['isPrimary', 'ISPRIMARY', 'IsPrimary'], 0)),
            isProtected: Number(getSeedValue(data, ['isProtected', 'ISPROTECTED', 'IsProtected'], 0))
        };
    }

    function normalizeAppointmentSeed(data = {}) {
        return {
            appointmentName: getSeedValue(data, ['appointmentName', 'APPOINTMENTNAME', 'AppointmentName']),
            appointmentType: getSeedValue(data, ['appointmentType', 'APPOINTMENTTYPE', 'AppointmentType'])
        };
    }

    function normalizePhoneSeed(data = {}) {
        return {
            number: getSeedValue(data, ['number', 'NUMBER', 'PhoneNumber', 'PHONENUMBER']),
            type: getSeedValue(data, ['type', 'TYPE', 'PhoneType', 'PHONETYPE']),
            isPrimary: Number(getSeedValue(data, ['isPrimary', 'ISPRIMARY', 'IsPrimary'], 0))
        };
    }

    function normalizeAddressSeed(data = {}) {
        return {
            type: getSeedValue(data, ['type', 'TYPE', 'AddressType', 'ADDRESSTYPE']),
            addr1: getSeedValue(data, ['addr1', 'ADDR1', 'Address1', 'ADDRESS1']),
            addr2: getSeedValue(data, ['addr2', 'ADDR2', 'Address2', 'ADDRESS2']),
            city: getSeedValue(data, ['city', 'CITY', 'City']),
            state: getSeedValue(data, ['state', 'STATE', 'State']),
            zip: getSeedValue(data, ['zip', 'ZIP', 'ZipCode', 'ZIPCODE']),
            building: getSeedValue(data, ['building', 'BUILDING', 'Building']),
            room: getSeedValue(data, ['room', 'ROOM', 'Room']),
            mailcode: getSeedValue(data, ['mailcode', 'MAILCODE', 'MailCode']),
            isPrimary: Number(getSeedValue(data, ['isPrimary', 'ISPRIMARY', 'IsPrimary'], 0))
        };
    }

    function syncIndexes(containerId, prefix) {
        const rows = document.querySelectorAll('#' + containerId + ' [data-row]');
        rows.forEach((row, index) => {
            row.querySelectorAll('[data-name]').forEach((input) => {
                input.name = prefix + '_' + input.dataset.name + '_' + index;
            });
            const radio = row.querySelector('input[type="radio"]');
            if (radio) {
                radio.value = index;
            }
        });
        const countField = document.getElementById(prefix + 'Count');
        if (countField) {
            countField.value = rows.length;
        }
    }

    // Row management functions (addAliasRow, addEmailRow, addPhoneRow, addAddressRow,
    // removeRow delegated handler) now live in /assets/js/userreview/userreview-shell.js
    seedAliases.map(normalizeAliasSeed).forEach(window.addAliasRow);
    seedAppointments.map(normalizeAppointmentSeed).forEach(window.addAppointmentRow);
    seedEmails.map(normalizeEmailSeed).forEach(window.addEmailRow);
    seedPhones.map(normalizePhoneSeed).forEach(window.addPhoneRow);
    seedAddresses.map(normalizeAddressSeed).forEach(window.addAddressRow);
    if (seedAliases.length === 0) window.addAliasRow();

    if (seedEmails.length === 0) window.addEmailRow();
    if (seedPhones.length === 0) window.addPhoneRow();
    if (seedAddresses.length === 0) window.addAddressRow();

    function setUserReviewPublicationsStatus(message, tone) {
        const el = document.getElementById('userReviewPublicationsStatus');
        if (!el) return;
        el.className = 'small mb-3';
        if (tone === 'error') {
            el.classList.add('text-danger');
        } else if (tone === 'success') {
            el.classList.add('text-success');
        } else {
            el.classList.add('text-muted');
        }
        el.textContent = message || '';
    }

    function getUserReviewPublicationsBody(showcasedIDs) {
        const body = new URLSearchParams();
        const identifierEl = document.getElementById('userReviewOrcidIdentifier');
        const urlEl = document.getElementById('userReviewOrcidUrl');
        const enabledValue = '1';
        const orderMap = {};

        body.append('orcid_identifier', identifierEl ? identifierEl.value : '');
        body.append('orcid_url', urlEl ? urlEl.value : 'https://orcid.org/');
        body.append('orcid_enabled', enabledValue);
        body.append('showcased_publication_ids', showcasedIDs.join(','));
        showcasedIDs.forEach(function (publicationID, index) {
            orderMap[String(publicationID)] = String(index + 1);
        });
        body.append('publication_display_order_json', JSON.stringify(orderMap));
        return body;
    }

    function getUserReviewShowcasedIDs() {
        const showcased = [];
        document.querySelectorAll('.userreview-showcased-publication-item').forEach(function (item) {
            showcased.push(item.getAttribute('data-publication-id'));
        });
        return showcased;
    }

    function postUserReviewPublications(url, body, successMessage) {
        setUserReviewPublicationsStatus('Saving...', 'info');
        return fetch(url, {
            method: 'POST',
            body: body,
            credentials: 'same-origin'
        })
        .then(function (r) { return r.json(); })
        .then(function (data) {
            if (!data.success) {
                throw new Error(data.message || 'Request failed.');
            }
            setUserReviewPublicationsStatus(successMessage || data.message || 'Saved.', 'success');
            window.location.reload();
            return data;
        })
        .catch(function (err) {
            setUserReviewPublicationsStatus(err && err.message ? err.message : 'Request failed.', 'error');
        });
    }

    const userReviewSaveOrcidBtn = document.getElementById('userReviewSaveOrcidBtn');
    const userReviewFetchOrcidBtn = document.getElementById('userReviewFetchOrcidBtn');
    const userReviewPublicationsCard = document.getElementById('userReviewPublicationsCard');
    const userReviewOrcidIdentifier = document.getElementById('userReviewOrcidIdentifier');

    function syncUserReviewFetchState() {
        if (!userReviewFetchOrcidBtn || !userReviewOrcidIdentifier) {
            return;
        }
        userReviewFetchOrcidBtn.disabled = !(userReviewOrcidIdentifier.value || '').trim();
    }

    if (userReviewOrcidIdentifier) {
        syncUserReviewFetchState();
        userReviewOrcidIdentifier.addEventListener('input', syncUserReviewFetchState);
    }

    if (userReviewSaveOrcidBtn) {
        userReviewSaveOrcidBtn.addEventListener('click', function () {
            postUserReviewPublications('/UserReview/savePublications.cfm', getUserReviewPublicationsBody(getUserReviewShowcasedIDs()), 'ORCID publications saved.');
        });
    }

    if (userReviewFetchOrcidBtn) {
        userReviewFetchOrcidBtn.addEventListener('click', function () {
            const body = getUserReviewPublicationsBody(getUserReviewShowcasedIDs());
            const limitRecentEl = document.getElementById('userReviewLimitRecentYears');
            body.append('limitRecentYears', limitRecentEl && limitRecentEl.checked ? '1' : '0');
            postUserReviewPublications('/UserReview/fetchPublications.cfm', body, 'ORCID publications fetched.');
        });
    }

    if (userReviewPublicationsCard) {
        userReviewPublicationsCard.addEventListener('click', function (event) {
            const moveBtn = event.target.closest('.userreview-publication-move-btn');
            const panels = document.getElementById('userReviewPublicationsPanels');
            let showcasedIDs = getUserReviewShowcasedIDs();
            const publicationID = moveBtn ? (moveBtn.getAttribute('data-publication-id') || '') : '';
            const maxCount = panels ? (parseInt(panels.getAttribute('data-max-showcased') || '10', 10) || 10) : 10;

            if (!moveBtn) {
                return;
            }

            if (moveBtn.getAttribute('data-direction') === 'add') {
                if (showcasedIDs.indexOf(publicationID) === -1) {
                    if (maxCount > 0 && showcasedIDs.length >= maxCount) {
                        setUserReviewPublicationsStatus('You can showcase at most ' + maxCount + ' publications.', 'error');
                        return;
                    }
                    showcasedIDs.push(publicationID);
                }
            } else {
                showcasedIDs = showcasedIDs.filter(function (id) { return id !== publicationID; });
            }

            postUserReviewPublications('/UserReview/savePublications.cfm', getUserReviewPublicationsBody(showcasedIDs), 'Showcased publications updated.');
        });
    }
</script>

<cfoutput>
</cfoutput>
</cfsavecontent>

<cfset pageTitle = "UserReview">
<cfinclude template="/UserReview/layout.cfm">