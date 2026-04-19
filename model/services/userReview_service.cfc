component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.UserReview_DAO").init();
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.directoryService = createObject("component", "cfc.directory_service").init();
        variables.flagsService = createObject("component", "cfc.flags_service").init();
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        variables.emailsService = createObject("component", "cfc.emails_service").init();
        variables.phoneService = createObject("component", "cfc.phone_service").init();
        variables.addressesService = createObject("component", "cfc.addresses_service").init();
        return this;
    }

    public struct function getSettings() {
        var editableSections = _normalizeSections(
            variables.appConfigService.getValue("user_review.editable_sections", "general,contact,bioinfo")
        );

        return {
            enabled = _configBool("user_review.enabled", true),
            allowFaculty = _configBool("user_review.allow_faculty", true),
            allowStaff = _configBool("user_review.allow_staff", true),
            allowCurrentStudents = _configBool("user_review.allow_current_students", false),
            allowAlumni = _configBool("user_review.allow_alumni", false),
            editableSections = editableSections,
            editableSectionList = arrayToList(editableSections),
            externalAuthToken = variables.appConfigService.getValue("user_review.external_auth_token", "")
        };
    }

    public struct function getUserByCougarnet(required string cougarnetID) {
        return variables.usersService.getUserByCougarnet(lCase(trim(arguments.cougarnetID)));
    }

    public struct function getEligibilityResult(required numeric userID) {
        var settings = getSettings();
        var userResult = variables.usersService.getUser(arguments.userID);
        var flagsResult = variables.flagsService.getUserFlags(arguments.userID);
        var matchedAudiences = [];
        var flagRows = flagsResult.data ?: [];

        if (NOT settings.enabled) {
            return {
                success = false,
                message = "UserReview is currently disabled.",
                audiences = [],
                user = userResult.data ?: {},
                flags = flagRows
            };
        }

        if (NOT userResult.success) {
            return {
                success = false,
                message = "User record not found.",
                audiences = [],
                user = {},
                flags = flagRows
            };
        }

        if (val(userResult.data.ACTIVE ?: 1) EQ 0) {
            return {
                success = false,
                message = "Your profile is inactive and cannot be reviewed here.",
                audiences = [],
                user = userResult.data,
                flags = flagRows
            };
        }

        for (var flagRow in flagRows) {
            var flagName = lCase(trim(flagRow.FLAGNAME ?: ""));
            if (settings.allowFaculty AND listFindNoCase("faculty-adjunct,faculty-fulltime,joint faculty appointment", flagName)) {
                if (arrayFindNoCase(matchedAudiences, "faculty") EQ 0) {
                    arrayAppend(matchedAudiences, "faculty");
                }
            }
            if (settings.allowStaff AND flagName EQ "staff") {
                if (arrayFindNoCase(matchedAudiences, "staff") EQ 0) {
                    arrayAppend(matchedAudiences, "staff");
                }
            }
            if (settings.allowCurrentStudents AND flagName EQ "current-student") {
                if (arrayFindNoCase(matchedAudiences, "current-student") EQ 0) {
                    arrayAppend(matchedAudiences, "current-student");
                }
            }
            if (settings.allowAlumni AND flagName EQ "alumni") {
                if (arrayFindNoCase(matchedAudiences, "alumni") EQ 0) {
                    arrayAppend(matchedAudiences, "alumni");
                }
            }
        }

        if (NOT arrayLen(matchedAudiences)) {
            return {
                success = false,
                message = "Your profile is not currently eligible for UserReview.",
                audiences = matchedAudiences,
                user = userResult.data,
                flags = flagRows
            };
        }

        return {
            success = true,
            message = "Eligible",
            audiences = matchedAudiences,
            user = userResult.data,
            flags = flagRows
        };
    }

    public struct function getReviewProfile(required numeric userID) {
        return variables.directoryService.getFullProfile(arguments.userID);
    }

    public struct function getOpenSubmissionForUser(required numeric userID) {
        var submission = variables.dao.getOpenSubmissionForUser(arguments.userID);
        if (structCount(submission)) {
            submission.fields = variables.dao.getFieldsForSubmission(val(submission.SUBMISSIONID));
            return submission;
        }
        return {};
    }

    public struct function getLatestReviewedSubmissionForUser(required numeric userID) {
        return variables.dao.getLatestReviewedSubmissionForUser(arguments.userID);
    }

    public struct function getEditableFormModel(required numeric userID) {
        var profile = getReviewProfile(arguments.userID);
        var pending = getOpenSubmissionForUser(arguments.userID);
        var latestReviewedSubmission = getLatestReviewedSubmissionForUser(arguments.userID);
        var model = {
            general = {
                Prefix = trim(profile.user.PREFIX ?: ""),
                Suffix = trim(profile.user.SUFFIX ?: ""),
                Pronouns = trim(profile.user.PRONOUNS ?: ""),
                FirstName = trim(profile.user.FIRSTNAME ?: ""),
                MiddleName = trim(profile.user.MIDDLENAME ?: ""),
                LastName = trim(profile.user.LASTNAME ?: ""),
                Title1 = trim(profile.user.TITLE1 ?: ""),
                Title2 = trim(profile.user.TITLE2 ?: ""),
                Title3 = trim(profile.user.TITLE3 ?: "")
            },
            bioinfo = {
                DOB = isDate(profile.user.DOB ?: "") ? dateFormat(profile.user.DOB, "yyyy-mm-dd") : "",
                Gender = trim(profile.user.GENDER ?: "")
            },
            contact = {
                EmailPrimary = trim(profile.user.EMAILPRIMARY ?: ""),
                emails = _extractContactEmails(profile.emails ?: [], profile.user.EMAILPRIMARY ?: ""),
                phones = _extractContactPhones(profile.user, profile.phones ?: []),
                addresses = _extractContactAddresses(profile.addresses ?: [])
            },
            pendingSubmission = pending,
            latestReviewedSubmission = latestReviewedSubmission
        };

        if (structKeyExists(pending, "fields") AND arrayLen(pending.fields)) {
            for (var fieldRow in pending.fields) {
                if (len(trim(fieldRow.RESOLUTION ?: ""))) {
                    continue;
                }
                if (fieldRow.SECTIONKEY EQ "general" OR fieldRow.SECTIONKEY EQ "bioinfo") {
                    model[fieldRow.SECTIONKEY][fieldRow.FIELDNAME] = fieldRow.PROPOSEDVALUE ?: "";
                } else if (fieldRow.SECTIONKEY EQ "contact") {
                    if (fieldRow.FIELDNAME EQ "emails") {
                        model.contact.emails = _deserializeJsonArray(fieldRow.PROPOSEDVALUE);
                    } else if (fieldRow.FIELDNAME EQ "phones") {
                        model.contact.phones = _deserializeJsonArray(fieldRow.PROPOSEDVALUE);
                    } else if (fieldRow.FIELDNAME EQ "addresses") {
                        model.contact.addresses = _deserializeJsonArray(fieldRow.PROPOSEDVALUE);
                    }
                }
            }
        }

        return model;
    }

    public struct function saveSubmission(required struct actor, required struct formScope) {
        var eligibility = getEligibilityResult(arguments.actor.userID);
        var settings = getSettings();
        var fieldRows = [];
        var profile = {};
        var pending = {};
        var submissionID = 0;
        var sortOrder = 0;

        if (NOT eligibility.success) {
            return { success = false, message = eligibility.message };
        }

        profile = getReviewProfile(arguments.actor.userID);

        if (arrayFindNoCase(settings.editableSections, "general")) {
            var generalFields = [
                { name = "Prefix", label = "Prefix", currentValue = trim(profile.user.PREFIX ?: ""), proposedValue = trim(arguments.formScope.Prefix ?: "") },
                { name = "Suffix", label = "Suffix", currentValue = trim(profile.user.SUFFIX ?: ""), proposedValue = trim(arguments.formScope.Suffix ?: "") },
                { name = "Pronouns", label = "Pronouns", currentValue = trim(profile.user.PRONOUNS ?: ""), proposedValue = trim(arguments.formScope.Pronouns ?: "") },
                { name = "FirstName", label = "First Name", currentValue = trim(profile.user.FIRSTNAME ?: ""), proposedValue = trim(arguments.formScope.FirstName ?: "") },
                { name = "MiddleName", label = "Middle Name", currentValue = trim(profile.user.MIDDLENAME ?: ""), proposedValue = trim(arguments.formScope.MiddleName ?: "") },
                { name = "LastName", label = "Last Name", currentValue = trim(profile.user.LASTNAME ?: ""), proposedValue = trim(arguments.formScope.LastName ?: "") },
                { name = "Title2", label = "Title 2", currentValue = trim(profile.user.TITLE2 ?: ""), proposedValue = trim(arguments.formScope.Title2 ?: "") },
                { name = "Title3", label = "Title 3", currentValue = trim(profile.user.TITLE3 ?: ""), proposedValue = trim(arguments.formScope.Title3 ?: "") }
            ];

            for (var generalField in generalFields) {
                if (_valuesDiffer(generalField.currentValue, generalField.proposedValue)) {
                    sortOrder++;
                    arrayAppend(fieldRows, {
                        sectionKey = "general",
                        fieldName = generalField.name,
                        fieldLabel = generalField.label,
                        currentValue = generalField.currentValue,
                        proposedValue = generalField.proposedValue,
                        sortOrder = sortOrder
                    });
                }
            }
        }

        if (arrayFindNoCase(settings.editableSections, "contact")) {
            var currentEmails = _extractContactEmails(profile.emails ?: [], profile.user.EMAILPRIMARY ?: "");
            var currentPhones = _extractContactPhones(profile.user, profile.phones ?: []);
            var currentAddresses = _extractContactAddresses(profile.addresses ?: []);
            var proposedEmails = _parseEmailRows(arguments.formScope, profile.user.EMAILPRIMARY ?: "");
            var proposedPhones = _parsePhoneRows(arguments.formScope);
            var proposedAddresses = _parseAddressRows(arguments.formScope);

            if (_contactValuesDiffer("emails", currentEmails, proposedEmails)) {
                sortOrder++;
                arrayAppend(fieldRows, {
                    sectionKey = "contact",
                    fieldName = "emails",
                    fieldLabel = "Email Addresses",
                    currentValue = _toJson(currentEmails),
                    proposedValue = _toJson(proposedEmails),
                    sortOrder = sortOrder
                });
            }

            if (_contactValuesDiffer("phones", currentPhones, proposedPhones)) {
                sortOrder++;
                arrayAppend(fieldRows, {
                    sectionKey = "contact",
                    fieldName = "phones",
                    fieldLabel = "Phone Numbers",
                    currentValue = _toJson(currentPhones),
                    proposedValue = _toJson(proposedPhones),
                    sortOrder = sortOrder
                });
            }

            if (_contactValuesDiffer("addresses", currentAddresses, proposedAddresses)) {
                sortOrder++;
                arrayAppend(fieldRows, {
                    sectionKey = "contact",
                    fieldName = "addresses",
                    fieldLabel = "Addresses",
                    currentValue = _toJson(currentAddresses),
                    proposedValue = _toJson(proposedAddresses),
                    sortOrder = sortOrder
                });
            }
        }

        if (arrayFindNoCase(settings.editableSections, "bioinfo")) {
            var bioFields = [
                { name = "DOB", label = "Date of Birth", currentValue = isDate(profile.user.DOB ?: "") ? dateFormat(profile.user.DOB, "yyyy-mm-dd") : "", proposedValue = trim(arguments.formScope.DOB ?: "") },
                { name = "Gender", label = "Gender", currentValue = trim(profile.user.GENDER ?: ""), proposedValue = trim(arguments.formScope.Gender ?: "") }
            ];

            for (var bioField in bioFields) {
                if (_valuesDiffer(bioField.currentValue, bioField.proposedValue)) {
                    sortOrder++;
                    arrayAppend(fieldRows, {
                        sectionKey = "bioinfo",
                        fieldName = bioField.name,
                        fieldLabel = bioField.label,
                        currentValue = bioField.currentValue,
                        proposedValue = bioField.proposedValue,
                        sortOrder = sortOrder
                    });
                }
            }
        }

        if (NOT arrayLen(fieldRows)) {
            return { success = false, message = "No changes were detected to submit for review." };
        }

        transaction {
            pending = variables.dao.getOpenSubmissionForUser(arguments.actor.userID);
            if (structCount(pending)) {
                variables.dao.deleteSubmission(val(pending.SUBMISSIONID));
            }

            submissionID = variables.dao.createSubmission(
                userID = arguments.actor.userID,
                cougarnetID = trim(arguments.actor.username ?: arguments.actor.cougarnetID ?: ""),
                displayName = trim(arguments.actor.displayName ?: ""),
                sectionList = arrayToList(settings.editableSections)
            );

            for (var fieldRow in fieldRows) {
                variables.dao.insertSubmissionField(
                    submissionID = submissionID,
                    sectionKey = fieldRow.sectionKey,
                    fieldName = fieldRow.fieldName,
                    fieldLabel = fieldRow.fieldLabel,
                    currentValue = fieldRow.currentValue,
                    proposedValue = fieldRow.proposedValue,
                    sortOrder = fieldRow.sortOrder
                );
            }
        }

        return { success = true, message = "Your changes were submitted for review.", submissionID = submissionID };
    }

    public array function listSubmissions(string statusList = "pending,approved,partially_approved,rejected") {
        return variables.dao.listSubmissions(arguments.statusList);
    }

    public struct function getSubmissionDetail(required numeric submissionID) {
        var submission = variables.dao.getSubmissionByID(arguments.submissionID);
        if (NOT structCount(submission)) {
            return { success = false, message = "Submission not found.", submission = {}, fields = [] };
        }

        return {
            success = true,
            message = "",
            submission = submission,
            fields = variables.dao.getFieldsForSubmission(arguments.submissionID)
        };
    }

    public struct function approveField(
        required numeric submissionFieldID,
        required numeric adminUserID,
        required string reviewerCougarnetID,
        string reviewNote = ""
    ) {
        var fieldRow = variables.dao.getFieldByID(arguments.submissionFieldID);
        if (NOT structCount(fieldRow)) {
            return { success = false, message = "Field submission not found." };
        }
        if (len(trim(fieldRow.RESOLUTION ?: ""))) {
            return { success = false, message = "This field has already been reviewed." };
        }

        transaction {
            _applyProposedFieldValue(fieldRow);
            variables.dao.resolveField(
                submissionFieldID = arguments.submissionFieldID,
                resolution = "approved",
                resolvedByAdminUserID = arguments.adminUserID,
                resolvedByCougarnetID = arguments.reviewerCougarnetID,
                resolvedValue = fieldRow.PROPOSEDVALUE ?: ""
            );
            _finalizeSubmissionStatus(val(fieldRow.SUBMISSIONID), arguments.adminUserID, arguments.reviewerCougarnetID);
        }

        return { success = true, message = "Field approved.", submissionID = val(fieldRow.SUBMISSIONID) };
    }

    public struct function discardField(
        required numeric submissionFieldID,
        required numeric adminUserID,
        required string reviewerCougarnetID,
        string reviewNote = ""
    ) {
        var fieldRow = variables.dao.getFieldByID(arguments.submissionFieldID);
        if (NOT structCount(fieldRow)) {
            return { success = false, message = "Field submission not found." };
        }
        if (len(trim(fieldRow.RESOLUTION ?: ""))) {
            return { success = false, message = "This field has already been reviewed." };
        }
        if (NOT len(trim(arguments.reviewNote))) {
            return { success = false, message = "A reason for rejection is required when discarding a field." };
        }

        transaction {
            variables.dao.resolveField(
                submissionFieldID = arguments.submissionFieldID,
                resolution = "discarded",
                resolvedByAdminUserID = arguments.adminUserID,
                resolvedByCougarnetID = arguments.reviewerCougarnetID,
                resolvedValue = fieldRow.CURRENTVALUE ?: ""
            );
            _appendSubmissionReviewNote(
                val(fieldRow.SUBMISSIONID),
                arguments.reviewerCougarnetID,
                arguments.reviewNote,
                "Discarded " & trim(fieldRow.FIELDLABEL ?: fieldRow.FIELDNAME ?: "field")
            );
            _finalizeSubmissionStatus(val(fieldRow.SUBMISSIONID), arguments.adminUserID, arguments.reviewerCougarnetID);
        }

        return { success = true, message = "Field discarded.", submissionID = val(fieldRow.SUBMISSIONID) };
    }

    public struct function approveSubmission(
        required numeric submissionID,
        required numeric adminUserID,
        required string reviewerCougarnetID,
        string reviewNote = ""
    ) {
        var fields = variables.dao.getFieldsForSubmission(arguments.submissionID);
        if (NOT arrayLen(fields)) {
            return { success = false, message = "Submission has no fields to review." };
        }

        transaction {
            for (var fieldRow in fields) {
                if (len(trim(fieldRow.RESOLUTION ?: ""))) {
                    continue;
                }
                _applyProposedFieldValue(fieldRow);
                variables.dao.resolveField(
                    submissionFieldID = val(fieldRow.SUBMISSIONFIELDID),
                    resolution = "approved",
                    resolvedByAdminUserID = arguments.adminUserID,
                    resolvedByCougarnetID = arguments.reviewerCougarnetID,
                    resolvedValue = fieldRow.PROPOSEDVALUE ?: ""
                );
            }

            _finalizeSubmissionStatus(arguments.submissionID, arguments.adminUserID, arguments.reviewerCougarnetID);
        }

        return { success = true, message = "Submission approved.", submissionID = arguments.submissionID };
    }

    public struct function discardSubmission(
        required numeric submissionID,
        required numeric adminUserID,
        required string reviewerCougarnetID,
        string reviewNote = ""
    ) {
        var fields = variables.dao.getFieldsForSubmission(arguments.submissionID);
        if (NOT arrayLen(fields)) {
            return { success = false, message = "Submission has no fields to review." };
        }
        if (NOT len(trim(arguments.reviewNote))) {
            return { success = false, message = "A reason for rejection is required when discarding a submission." };
        }

        transaction {
            for (var fieldRow in fields) {
                if (len(trim(fieldRow.RESOLUTION ?: ""))) {
                    continue;
                }
                variables.dao.resolveField(
                    submissionFieldID = val(fieldRow.SUBMISSIONFIELDID),
                    resolution = "discarded",
                    resolvedByAdminUserID = arguments.adminUserID,
                    resolvedByCougarnetID = arguments.reviewerCougarnetID,
                    resolvedValue = fieldRow.CURRENTVALUE ?: ""
                );
            }

            _appendSubmissionReviewNote(
                arguments.submissionID,
                arguments.reviewerCougarnetID,
                arguments.reviewNote,
                "Submission rejected"
            );
            _finalizeSubmissionStatus(arguments.submissionID, arguments.adminUserID, arguments.reviewerCougarnetID);
        }

        return { success = true, message = "Submission discarded.", submissionID = arguments.submissionID };
    }

    private boolean function _configBool(required string key, required boolean defaultValue) {
        var rawValue = lCase(trim(variables.appConfigService.getValue(arguments.key, arguments.defaultValue ? "1" : "0")));
        return listFindNoCase("1,true,yes,on", rawValue) GT 0;
    }

    private array function _normalizeSections(required string sectionList) {
        var allowed = ["general", "contact", "bioinfo"];
        var result = [];
        for (var sectionName in listToArray(arguments.sectionList)) {
            sectionName = lCase(trim(sectionName));
            if (arrayFindNoCase(allowed, sectionName) AND arrayFindNoCase(result, sectionName) EQ 0) {
                arrayAppend(result, sectionName);
            }
        }
        if (NOT arrayLen(result)) {
            result = ["general", "contact", "bioinfo"];
        }
        return result;
    }

    private boolean function _valuesDiffer(required string currentValue, required string proposedValue) {
        return trim(arguments.currentValue) NEQ trim(arguments.proposedValue);
    }

    private string function _toJson(required any value) {
        return serializeJSON(arguments.value);
    }

    private boolean function _contactValuesDiffer(required string contactType, required array currentRows, required array proposedRows) {
        return _contactSignature(arguments.contactType, arguments.currentRows) NEQ _contactSignature(arguments.contactType, arguments.proposedRows);
    }

    private string function _contactSignature(required string contactType, required array rows) {
        var normalizedRows = [];

        for (var row in arguments.rows) {
            switch (lCase(arguments.contactType)) {
                case "emails":
                    arrayAppend(normalizedRows,
                        lCase(trim(row.address ?: "")) & "|" &
                        lCase(trim(row.type ?: "")) & "|" &
                        val(row.isPrimary ?: 0)
                    );
                    break;

                case "phones":
                    arrayAppend(normalizedRows,
                        trim(row.number ?: "") & "|" &
                        lCase(trim(row.type ?: "")) & "|" &
                        val(row.isPrimary ?: 0)
                    );
                    break;

                case "addresses":
                    arrayAppend(normalizedRows,
                        lCase(trim(row.type ?: "")) & "|" &
                        lCase(trim(row.addr1 ?: "")) & "|" &
                        lCase(trim(row.addr2 ?: "")) & "|" &
                        lCase(trim(row.city ?: "")) & "|" &
                        lCase(trim(row.state ?: "")) & "|" &
                        lCase(trim(row.zip ?: "")) & "|" &
                        lCase(trim(row.building ?: "")) & "|" &
                        lCase(trim(row.room ?: "")) & "|" &
                        lCase(trim(row.mailcode ?: "")) & "|" &
                        val(row.isPrimary ?: 0)
                    );
                    break;
            }
        }

        arraySort(normalizedRows, "textnocase");
        return arrayToList(normalizedRows, "||");
    }

    private array function _deserializeJsonArray(any rawValue = "") {
        if (NOT len(trim(arguments.rawValue ?: ""))) {
            return [];
        }
        try {
            var parsed = deserializeJSON(arguments.rawValue);
            if (isArray(parsed)) {
                return parsed;
            }
        } catch (any ignore) {}
        return [];
    }

    private array function _extractContactEmails(required array emailRows, string primaryEmail = "") {
        var result = [];
        var normalizedPrimaryEmail = lCase(trim(arguments.primaryEmail));
        for (var emailRow in arguments.emailRows) {
            var address = lCase(trim(emailRow.EMAILADDRESS ?: ""));
            if (
                NOT len(address)
                OR (len(normalizedPrimaryEmail) AND address EQ normalizedPrimaryEmail)
                OR reFindNoCase("^[^@]+@uh\.edu$", address)
            ) {
                continue;
            }
            arrayAppend(result, {
                address = address,
                type = trim(emailRow.EMAILTYPE ?: ""),
                isPrimary = val(emailRow.ISPRIMARY ?: 0)
            });
        }
        return result;
    }

    private array function _extractContactPhones(required struct userRecord, required array phoneRows) {
        var result = [];
        for (var phoneRow in arguments.phoneRows) {
            arrayAppend(result, {
                number = trim(phoneRow.PHONENUMBER ?: ""),
                type = trim(phoneRow.PHONETYPE ?: ""),
                isPrimary = val(phoneRow.ISPRIMARY ?: 0)
            });
        }
        return result;
    }

    private array function _extractContactAddresses(required array addressRows) {
        var result = [];
        for (var addressRow in arguments.addressRows) {
            arrayAppend(result, {
                type = trim(addressRow.ADDRESSTYPE ?: ""),
                addr1 = trim(addressRow.ADDRESS1 ?: ""),
                addr2 = trim(addressRow.ADDRESS2 ?: ""),
                city = trim(addressRow.CITY ?: ""),
                state = trim(addressRow.STATE ?: ""),
                zip = trim(addressRow.ZIPCODE ?: ""),
                building = trim(addressRow.BUILDING ?: ""),
                room = trim(addressRow.ROOM ?: ""),
                mailcode = trim(addressRow.MAILCODE ?: ""),
                isPrimary = val(addressRow.ISPRIMARY ?: 0)
            });
        }
        return result;
    }

    private array function _parseEmailRows(required struct formScope, string primaryEmail = "") {
        var result = [];
        var normalizedPrimaryEmail = lCase(trim(arguments.primaryEmail));
        var count = (structKeyExists(arguments.formScope, "emailCount") AND isNumeric(arguments.formScope.emailCount)) ? val(arguments.formScope.emailCount) : 0;
        for (var i = 0; i LT count; i++) {
            var address = lCase(trim(arguments.formScope["email_address_" & i] ?: ""));
            var emailType = trim(arguments.formScope["email_type_" & i] ?: "");
            var isPrimary = structKeyExists(arguments.formScope, "email_primary") AND val(arguments.formScope.email_primary) EQ i;
            if (
                len(address)
                AND (NOT len(normalizedPrimaryEmail) OR address NEQ normalizedPrimaryEmail)
                AND NOT reFindNoCase("^[^@]+@uh\.edu$", address)
            ) {
                arrayAppend(result, {
                    address = address,
                    type = emailType,
                    isPrimary = isPrimary ? 1 : 0
                });
            }
        }
        return result;
    }

    private array function _parsePhoneRows(required struct formScope) {
        var result = [];
        var count = (structKeyExists(arguments.formScope, "phoneCount") AND isNumeric(arguments.formScope.phoneCount)) ? val(arguments.formScope.phoneCount) : 0;
        for (var i = 0; i LT count; i++) {
            var number = trim(arguments.formScope["phone_number_" & i] ?: "");
            var phoneType = trim(arguments.formScope["phone_type_" & i] ?: "");
            var isPrimary = structKeyExists(arguments.formScope, "phone_primary") AND val(arguments.formScope.phone_primary) EQ i;
            if (len(number)) {
                arrayAppend(result, {
                    number = number,
                    type = phoneType,
                    isPrimary = isPrimary ? 1 : 0
                });
            }
        }
        return result;
    }

    private array function _parseAddressRows(required struct formScope) {
        var result = [];
        var count = (structKeyExists(arguments.formScope, "addressCount") AND isNumeric(arguments.formScope.addressCount)) ? val(arguments.formScope.addressCount) : 0;
        for (var i = 0; i LT count; i++) {
            var addressType = trim(arguments.formScope["address_type_" & i] ?: "");
            if (NOT len(addressType)) {
                continue;
            }
            arrayAppend(result, {
                type = addressType,
                addr1 = trim(arguments.formScope["address_addr1_" & i] ?: ""),
                addr2 = trim(arguments.formScope["address_addr2_" & i] ?: ""),
                city = trim(arguments.formScope["address_city_" & i] ?: ""),
                state = trim(arguments.formScope["address_state_" & i] ?: ""),
                zip = trim(arguments.formScope["address_zip_" & i] ?: ""),
                building = trim(arguments.formScope["address_building_" & i] ?: ""),
                room = trim(arguments.formScope["address_room_" & i] ?: ""),
                mailcode = trim(arguments.formScope["address_mailcode_" & i] ?: ""),
                isPrimary = (structKeyExists(arguments.formScope, "address_primary") AND val(arguments.formScope.address_primary) EQ i) ? 1 : 0
            });
        }
        return result;
    }

    private void function _applyProposedFieldValue(required struct fieldRow) {
        if (arguments.fieldRow.SECTIONKEY EQ "general" OR arguments.fieldRow.SECTIONKEY EQ "bioinfo") {
            _applyScalarFieldValue(arguments.fieldRow);
            return;
        }

        if (arguments.fieldRow.SECTIONKEY EQ "contact") {
            if (arguments.fieldRow.FIELDNAME EQ "emails") {
                variables.emailsService.replaceEmails(val(_getSubmissionUserID(arguments.fieldRow)), _deserializeJsonArray(arguments.fieldRow.PROPOSEDVALUE));
            } else if (arguments.fieldRow.FIELDNAME EQ "phones") {
                variables.phoneService.replacePhones(val(_getSubmissionUserID(arguments.fieldRow)), _deserializeJsonArray(arguments.fieldRow.PROPOSEDVALUE));
            } else if (arguments.fieldRow.FIELDNAME EQ "addresses") {
                variables.addressesService.replaceAddresses(val(_getSubmissionUserID(arguments.fieldRow)), _normalizeAddressSaveRows(_deserializeJsonArray(arguments.fieldRow.PROPOSEDVALUE)));
            }
        }
    }

    private void function _applyScalarFieldValue(required struct fieldRow) {
        var submission = variables.dao.getSubmissionByID(val(arguments.fieldRow.SUBMISSIONID));
        var currentUserResult = variables.usersService.getUser(val(submission.USERID));
        var currentUser = currentUserResult.data;
        var userData = {
            FirstName = currentUser.FIRSTNAME ?: "",
            MiddleName = currentUser.MIDDLENAME ?: "",
            LastName = currentUser.LASTNAME ?: "",
            Pronouns = currentUser.PRONOUNS ?: "",
            EmailPrimary = currentUser.EMAILPRIMARY ?: "",
            Phone = currentUser.PHONE ?: "",
            Room = currentUser.ROOM ?: "",
            Building = currentUser.BUILDING ?: "",
            UH_API_ID = currentUser.UH_API_ID ?: "",
            Title1 = currentUser.TITLE1 ?: "",
            Title2 = currentUser.TITLE2 ?: "",
            Title3 = currentUser.TITLE3 ?: "",
            Degrees = currentUser.DEGREES ?: "",
            Prefix = currentUser.PREFIX ?: "",
            Suffix = currentUser.SUFFIX ?: "",
            Campus = currentUser.CAMPUS ?: "",
            Division = currentUser.DIVISION ?: "",
            DivisionName = currentUser.DIVISIONNAME ?: "",
            Department = currentUser.DEPARTMENT ?: "",
            DepartmentName = currentUser.DEPARTMENTNAME ?: "",
            Office_Mailing_Address = currentUser.OFFICE_MAILING_ADDRESS ?: "",
            Mailcode = currentUser.MAILCODE ?: "",
            Active = val(currentUser.ACTIVE ?: 1),
            DOB = {
                value = isDate(currentUser.DOB ?: "") ? currentUser.DOB : "",
                cfsqltype = "cf_sql_date",
                null = NOT isDate(currentUser.DOB ?: "")
            },
            Gender = {
                value = currentUser.GENDER ?: "",
                cfsqltype = "cf_sql_nvarchar",
                null = NOT len(trim(currentUser.GENDER ?: ""))
            }
        };

        switch (arguments.fieldRow.FIELDNAME) {
            case "Prefix": userData.Prefix = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "Suffix": userData.Suffix = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "Pronouns": userData.Pronouns = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "FirstName": userData.FirstName = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "MiddleName": userData.MiddleName = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "LastName": userData.LastName = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "Title2": userData.Title2 = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "Title3": userData.Title3 = arguments.fieldRow.PROPOSEDVALUE ?: ""; break;
            case "DOB":
                userData.DOB = {
                    value = arguments.fieldRow.PROPOSEDVALUE ?: "",
                    cfsqltype = "cf_sql_date",
                    null = NOT len(trim(arguments.fieldRow.PROPOSEDVALUE ?: ""))
                };
                break;
            case "Gender":
                userData.Gender = {
                    value = arguments.fieldRow.PROPOSEDVALUE ?: "",
                    cfsqltype = "cf_sql_nvarchar",
                    null = NOT len(trim(arguments.fieldRow.PROPOSEDVALUE ?: ""))
                };
                break;
        }

        variables.usersService.updateUser(val(submission.USERID), userData);
    }

    private numeric function _getSubmissionUserID(required struct fieldRow) {
        var submission = variables.dao.getSubmissionByID(val(arguments.fieldRow.SUBMISSIONID));
        return val(submission.USERID ?: 0);
    }

    private void function _appendSubmissionReviewNote(
        required numeric submissionID,
        required string reviewerCougarnetID,
        required string reviewNote,
        string prefix = ""
    ) {
        var submission = variables.dao.getSubmissionByID(arguments.submissionID);
        var existingNote = trim(submission.REVIEWNOTE ?: "");
        var prefixText = len(trim(arguments.prefix)) ? trim(arguments.prefix) & ": " : "";
        var entry = dateTimeFormat(now(), "mmm d, yyyy h:nn tt") & " - " & trim(arguments.reviewerCougarnetID) & " - " & prefixText & trim(arguments.reviewNote);
        var separator = chr(13) & chr(10) & chr(13) & chr(10);
        var updatedNote = len(existingNote) ? existingNote & separator & entry : entry;

        variables.dao.updateSubmissionReviewNote(arguments.submissionID, updatedNote);
    }

    private array function _normalizeAddressSaveRows(required array addressRows) {
        var result = [];
        for (var row in arguments.addressRows) {
            arrayAppend(result, {
                AddressType = { value = trim(row.type ?: ""), cfsqltype = "cf_sql_varchar" },
                Address1 = { value = trim(row.addr1 ?: ""), cfsqltype = "cf_sql_varchar" },
                Address2 = { value = trim(row.addr2 ?: ""), cfsqltype = "cf_sql_varchar" },
                City = { value = trim(row.city ?: ""), cfsqltype = "cf_sql_varchar" },
                State = { value = trim(row.state ?: ""), cfsqltype = "cf_sql_varchar" },
                Zipcode = { value = trim(row.zip ?: ""), cfsqltype = "cf_sql_varchar" },
                Building = { value = trim(row.building ?: ""), cfsqltype = "cf_sql_varchar" },
                Room = { value = trim(row.room ?: ""), cfsqltype = "cf_sql_varchar" },
                MailCode = { value = trim(row.mailcode ?: ""), cfsqltype = "cf_sql_varchar" },
                isPrimary = { value = val(row.isPrimary ?: 0), cfsqltype = "cf_sql_bit" }
            });
        }
        return result;
    }

    private void function _finalizeSubmissionStatus(
        required numeric submissionID,
        required numeric adminUserID,
        required string reviewerCougarnetID
    ) {
        var counts = variables.dao.getResolutionCounts(arguments.submissionID);
        var status = "pending";

        if (counts.UNRESOLVED_COUNT GT 0) {
            status = "pending";
        } else if (counts.APPROVED_COUNT GT 0 AND counts.DISCARDED_COUNT GT 0) {
            status = "partially_approved";
        } else if (counts.APPROVED_COUNT GT 0) {
            status = "approved";
        } else {
            status = "rejected";
        }

        variables.dao.updateSubmissionStatus(
            submissionID = arguments.submissionID,
            status = status,
            reviewedByAdminUserID = arguments.adminUserID,
            reviewedByCougarnetID = arguments.reviewerCougarnetID,
            preserveReviewNote = true
        );
    }
}