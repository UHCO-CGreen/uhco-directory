<cfif NOT application.userReviewAuthService.isLoggedIn()>
    <cflocation url="/UserReview/login.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset currentUser = application.userReviewAuthService.getSessionUser()>
<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset eligibility = userReviewService.getEligibilityResult(currentUser.userID)>
<cfset settings = userReviewService.getSettings()>
<cfset formModel = userReviewService.getEditableFormModel(currentUser.userID)>
<cfset statusMessage = trim(url.msg ?: "")>
<cfset errorMessage = trim(url.error ?: "")>
<cfset seedEmailsJson = serializeJSON(formModel.contact.emails)>
<cfset seedPhonesJson = serializeJSON(formModel.contact.phones)>
<cfset seedAddressesJson = serializeJSON(formModel.contact.addresses)>
<cfset latestReviewedSubmission = formModel.latestReviewedSubmission ?: {}>
<cfset latestReviewedStatus = trim(latestReviewedSubmission.STATUS ?: "")>
<cfset latestReviewedAlertClass = latestReviewedStatus EQ "approved" ? "success" : (latestReviewedStatus EQ "rejected" ? "danger" : "warning")>
<cfset hasPendingSubmission = structKeyExists(formModel.pendingSubmission, "SUBMISSIONID")>

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

<cfset editableGeneral = arrayFindNoCase(settings.editableSections, "general") GT 0>
<cfset editableContact = arrayFindNoCase(settings.editableSections, "contact") GT 0>
<cfset editableBio = arrayFindNoCase(settings.editableSections, "bioinfo") GT 0>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<cfif len(statusMessage)>
    <div class="alert alert-success">#encodeForHTML(statusMessage)#</div>
</cfif>
<cfif len(errorMessage)>
    <div class="alert alert-danger">#encodeForHTML(errorMessage)#</div>
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
                <h2 class="h4 mb-2">Profile Review</h2>
                <p class="text-muted mb-0">Your changes are submitted as a staged review. Nothing updates live until an admin approves it.</p>
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
                A new save will replace the currently pending staged changes.
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
                <div class="col-md-4">
                    <label class="form-label">First Name</label>
                    <input class="form-control" name="FirstName" value="#encodeForHTMLAttribute(formModel.general.FirstName)#" required>
                </div>
                <div class="col-md-4">
                    <label class="form-label">Middle Name</label>
                    <input class="form-control" name="MiddleName" value="#encodeForHTMLAttribute(formModel.general.MiddleName)#">
                </div>
                <div class="col-md-4">
                    <label class="form-label">Last Name</label>
                    <input class="form-control" name="LastName" value="#encodeForHTMLAttribute(formModel.general.LastName)#" required>
                </div>
                <div class="col-md-6">
                    <label class="form-label">Title 1</label>
                    <input class="form-control" value="#encodeForHTMLAttribute(formModel.general.Title1)#" readonly disabled>
                    <div class="form-text">This title is your Official UH title and is shown for reference and cannot be changed here.</div>
                </div>
                <div class="col-md-6">
                    <label class="form-label">Title 2</label>
                    <input class="form-control" name="Title2" value="#encodeForHTMLAttribute(formModel.general.Title2)#">
                </div>
                <div class="col-md-6">
                    <label class="form-label">Title 3</label>
                    <input class="form-control" name="Title3" value="#encodeForHTMLAttribute(formModel.general.Title3)#">
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
                        <div class="form-text">Your primary UH email is managed separately and cannot be changed here.</div>
                    </div>
                </div>
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Email Addresses</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" onclick="addEmailRow()">Add Email</button>
                </div>
                <div id="emailRows"></div>
                <input type="hidden" id="emailCount" name="emailCount" value="0">
                <div class="form-text">@uh.edu addresses are managed separately and are not editable here.</div>
            </div>

            <div class="mb-4">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Phone Numbers</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" onclick="addPhoneRow()">Add Phone</button>
                </div>
                <div id="phoneRows"></div>
                <input type="hidden" id="phoneCount" name="phoneCount" value="0">
            </div>

            <div>
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <h4 class="h6 mb-0">Addresses</h4>
                    <button type="button" class="btn btn-sm btn-outline-primary" onclick="addAddressRow()">Add Address</button>
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

</cfoutput>

<script>
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
            isPrimary: Number(getSeedValue(data, ['isPrimary', 'ISPRIMARY', 'IsPrimary'], 0))
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

    function removeRow(button, containerId, prefix) {
        button.closest('[data-row]').remove();
        syncIndexes(containerId, prefix);
    }

    function addEmailRow(data = {}) {
        const container = document.getElementById('emailRows');
        const row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'email';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-6">' +
                    '<label class="form-label">Email</label>' +
                    '<input class="form-control" data-name="address" value="' + escapeHtml(data.address || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '">' +
                '</div>' +
                '<div class="col-md-2 d-flex gap-2 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="email_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    '<button type="button" class="btn btn-outline-danger btn-sm mt-4" onclick="removeRow(this, \'emailRows\', \'email\')">Remove</button>' +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('emailRows', 'email');
    }

    function addPhoneRow(data = {}) {
        const container = document.getElementById('phoneRows');
        const row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'phone';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-6">' +
                    '<label class="form-label">Number</label>' +
                    '<input class="form-control" data-name="number" value="' + escapeHtml(data.number || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '">' +
                '</div>' +
                '<div class="col-md-2 d-flex gap-2 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="phone_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    '<button type="button" class="btn btn-outline-danger btn-sm mt-4" onclick="removeRow(this, \'phoneRows\', \'phone\')">Remove</button>' +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('phoneRows', 'phone');
    }

    function addAddressRow(data = {}) {
        const container = document.getElementById('addressRows');
        const row = document.createElement('div');
        row.className = 'row-card mb-3';
        row.dataset.row = 'address';
        row.innerHTML =
            '<div class="row g-3 align-items-end">' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Type</label>' +
                    '<input class="form-control" data-name="type" value="' + escapeHtml(data.type || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Address 1</label>' +
                    '<input class="form-control" data-name="addr1" value="' + escapeHtml(data.addr1 || '') + '">' +
                '</div>' +
                '<div class="col-md-4">' +
                    '<label class="form-label">Address 2</label>' +
                    '<input class="form-control" data-name="addr2" value="' + escapeHtml(data.addr2 || '') + '">' +
                '</div>' +
                '<div class="col-md-3">' +
                    '<label class="form-label">City</label>' +
                    '<input class="form-control" data-name="city" value="' + escapeHtml(data.city || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">State</label>' +
                    '<input class="form-control" data-name="state" value="' + escapeHtml(data.state || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Zip</label>' +
                    '<input class="form-control" data-name="zip" value="' + escapeHtml(data.zip || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Building</label>' +
                    '<input class="form-control" data-name="building" value="' + escapeHtml(data.building || '') + '">' +
                '</div>' +
                '<div class="col-md-1">' +
                    '<label class="form-label">Room</label>' +
                    '<input class="form-control" data-name="room" value="' + escapeHtml(data.room || '') + '">' +
                '</div>' +
                '<div class="col-md-2">' +
                    '<label class="form-label">Mailcode</label>' +
                    '<input class="form-control" data-name="mailcode" value="' + escapeHtml(data.mailcode || '') + '">' +
                '</div>' +
                '<div class="col-md-4 d-flex gap-3 align-items-center">' +
                    '<div class="form-check mt-4">' +
                        '<input class="form-check-input" type="radio" name="address_primary" ' + (Number(data.isPrimary || 0) ? 'checked' : '') + '>' +
                        '<label class="form-check-label">Primary</label>' +
                    '</div>' +
                    '<button type="button" class="btn btn-outline-danger btn-sm mt-4" onclick="removeRow(this, \'addressRows\', \'address\')">Remove</button>' +
                '</div>' +
            '</div>';
        container.appendChild(row);
        syncIndexes('addressRows', 'address');
    }

    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/\"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    seedEmails.map(normalizeEmailSeed).forEach(addEmailRow);
    seedPhones.map(normalizePhoneSeed).forEach(addPhoneRow);
    seedAddresses.map(normalizeAddressSeed).forEach(addAddressRow);

    if (seedEmails.length === 0) addEmailRow();
    if (seedPhones.length === 0) addPhoneRow();
    if (seedAddresses.length === 0) addAddressRow();
</script>

<cfoutput>
</cfoutput>
</cfsavecontent>

<cfset pageTitle = "UserReview">
<cfinclude template="/UserReview/layout.cfm">