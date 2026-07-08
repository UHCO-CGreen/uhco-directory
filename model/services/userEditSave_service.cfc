component output="false" singleton {

    public any function init() {
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.flagsService = createObject("component", "cfc.flags_service").init();
        variables.organizationsService = createObject("component", "cfc.organizations_service").init();
        variables.externalIDService = createObject("component", "cfc.externalID_service").init();
        variables.emailsService = createObject("component", "cfc.emails_service").init();
        variables.phoneService = createObject("component", "cfc.phone_service").init();
        variables.addressesService = createObject("component", "cfc.addresses_service").init();
        variables.degreesService = createObject("component", "cfc.degrees_service").init();
        variables.aliasesService = createObject("component", "cfc.aliases_service").init();
        variables.academicService = createObject("component", "cfc.academic_service").init();
        variables.studentProfileService = createObject("component", "cfc.studentProfile_service").init();
        variables.bioService = createObject("component", "cfc.bio_service").init();
        variables.publicationAdminService = createObject("component", "cfc.publicationAdmin_service").init();
        return this;
    }

    public struct function handle(required string section, required numeric userID, required struct formData) {
        var normalizedSection = lCase(trim(arguments.section ?: ""));

        // Sections tracked by the change log (publications handled separately by its own system)
        var trackedSections = "emails,general,flags,orgs,extids,phones,aliases,awards,residencies,degrees,addresses,addaddress,uh,bioinfo,studentprofile,bio,tabdegrees,addldapemailifmissing,addldapaliasifmissing";
        var useChangeLog    = listFindNoCase(trackedSections, normalizedSection) GT 0
            AND structKeyExists(application, "changeLogSvc")
            AND isObject(application.changeLogSvc);

        var changeLogGroupID = "";
        var beforeSnapshot   = {};

        if (useChangeLog) {
            try {
                var sectionLabel = application.changeLogSvc.getSectionLabel(normalizedSection);
                changeLogGroupID = application.changeLogSvc.beginGroup(
                    entityType  = "user",
                    entityID    = toString(arguments.userID),
                    section     = sectionLabel,
                    description = "Admin save: #sectionLabel# for user #arguments.userID#"
                );
                beforeSnapshot = application.changeLogSvc.snapshotUserSection(arguments.userID, normalizedSection);
            } catch (any logErr) {
                // Never let change log setup break an edit save
                changeLogGroupID = "";
            }
        }

        var result = {};
        switch (normalizedSection) {
            case "emails":
                result = saveEmails(arguments.userID, arguments.formData);
                break;
            case "general":
                result = saveGeneral(arguments.userID, arguments.formData);
                break;
            case "flags":
                result = saveFlags(arguments.userID, arguments.formData);
                break;
            case "orgs":
                result = saveOrganizations(arguments.userID, arguments.formData);
                break;
            case "extids":
                result = saveExternalIDs(arguments.userID, arguments.formData);
                break;
            case "publications":
                result = savePublications(arguments.userID, arguments.formData);
                break;
            case "phones":
                result = savePhones(arguments.userID, arguments.formData);
                break;
            case "aliases":
                result = saveAliases(arguments.userID, arguments.formData);
                break;
            case "awards":
                result = saveAwards(arguments.userID, arguments.formData);
                break;
            case "residencies":
                result = saveResidencies(arguments.userID, arguments.formData);
                break;
            case "degrees":
                result = saveDegrees(arguments.userID, arguments.formData);
                break;
            case "addresses":
                result = saveAddresses(arguments.userID, arguments.formData);
                break;
            case "addaddress":
                result = addAddress(arguments.userID, arguments.formData);
                break;
            case "uh":
                result = saveUHFields(arguments.userID, arguments.formData);
                break;
            case "bioinfo":
                result = saveBiographicalInfo(arguments.userID, arguments.formData);
                break;
            case "studentprofile":
                result = saveStudentProfile(arguments.userID, arguments.formData);
                break;
            case "bio":
                result = saveBio(arguments.userID, arguments.formData);
                break;
            case "tabdegrees":
                result = saveTabDegrees(arguments.userID, arguments.formData);
                break;
            case "addldapemailifmissing":
                result = addLdapEmailIfMissing(arguments.userID, arguments.formData);
                break;
            case "addldapaliasifmissing":
                result = addLdapAliasIfMissing(arguments.userID, arguments.formData);
                break;
            default:
                return failure(400, "Unknown section: #normalizedSection#", ["section is not supported"]);
        }

        // Finalize the change log entry only when the save succeeded
        if (useChangeLog AND len(changeLogGroupID) AND (result.success ?: false)) {
            try {
                application.changeLogSvc.finalizeGroupWithUserSection(
                    groupID        = changeLogGroupID,
                    userID         = arguments.userID,
                    section        = normalizedSection,
                    beforeSnapshot = beforeSnapshot
                );
            } catch (any logErr) {
                // Never let change log finalize break an edit save
            }
        }

        return result;
    }

    public struct function saveEmails(required numeric userID, required struct formData) {
        var emailCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var primaryIdx = structKeyExists(arguments.formData, "primary_idx") ? val(arguments.formData.primary_idx) : -1;
        var emailsToSave = [];
        var i = 0;
        var emailAddress = "";
        var emailType = "";

        for (i = 0; i <= emailCount - 1; i++) {
            emailAddress = structKeyExists(arguments.formData, "addr_#i#") ? trim(arguments.formData["addr_#i#"]) : "";
            emailType = structKeyExists(arguments.formData, "type_#i#") ? trim(arguments.formData["type_#i#"]) : "";
            if (len(emailAddress) AND NOT reFindNoCase('@uh\.edu$', emailAddress)) {
                arrayAppend(emailsToSave, { address = emailAddress, type = emailType, isPrimary = (i EQ primaryIdx) });
            }
        }

        variables.emailsService.replaceEmails(arguments.userID, emailsToSave);
        return success("Emails saved.");
    }

    public struct function saveGeneral(required numeric userID, required struct formData) {
        var existingResult = variables.usersService.getUser(arguments.userID);
        var existing = {};
        var firstName = "";
        var middleName = "";
        var lastName = "";
        var overrides = {};
        var userData = {};
        var updateResult = {};

        if (!existingResult.success) {
            return failure(400, existingResult.message ?: "User not found.", ["userID was not found"]);
        }

        existing = existingResult.data;
        firstName = structKeyExists(arguments.formData, "FirstName") ? toProperName(arguments.formData.FirstName) : (existing.FIRSTNAME ?: "");
        middleName = structKeyExists(arguments.formData, "MiddleName") ? toProperName(arguments.formData.MiddleName) : (existing.MIDDLENAME ?: "");
        if (len(trim(middleName)) EQ 1 AND reFind("^[A-Za-z]$", trim(middleName))) {
            middleName = trim(middleName) & ".";
        }
        lastName = structKeyExists(arguments.formData, "LastName") ? toProperName(arguments.formData.LastName) : (existing.LASTNAME ?: "");

        overrides = {
            FirstName = firstName,
            MiddleName = middleName,
            LastName = lastName,
            Prefix = structKeyExists(arguments.formData, "Prefix") ? trim(arguments.formData.Prefix) : (existing.PREFIX ?: ""),
            Suffix = structKeyExists(arguments.formData, "Suffix") ? trim(arguments.formData.Suffix) : (existing.SUFFIX ?: ""),
            Pronouns = structKeyExists(arguments.formData, "Pronouns") ? trim(arguments.formData.Pronouns) : (existing.PRONOUNS ?: ""),
            Title1 = structKeyExists(arguments.formData, "Title1") ? trim(arguments.formData.Title1) : (existing.TITLE1 ?: ""),
            Title2 = structKeyExists(arguments.formData, "Title2") ? trim(arguments.formData.Title2) : (existing.TITLE2 ?: ""),
            Title3 = structKeyExists(arguments.formData, "Title3") ? trim(arguments.formData.Title3) : (existing.TITLE3 ?: "")
        };

        userData = buildUserData(existing, overrides);
        updateResult = variables.usersService.updateUser(arguments.userID, userData);
        if (!updateResult.success) {
            return failure(400, updateResult.message ?: "General info could not be saved.", [updateResult.message ?: "General info could not be saved."]);
        }

        return success("General info saved.");
    }

    public struct function saveFlags(required numeric userID, required struct formData) {
        var currentFlagsResult = variables.flagsService.getUserFlags(arguments.userID);
        var currentFlags = currentFlagsResult.data;
        var currentFlagIDs = [];
        var submittedFlagIDs = [];
        var flagList = [];
        var i = 0;

        for (i = 1; i <= arrayLen(currentFlags); i++) {
            arrayAppend(currentFlagIDs, val(currentFlags[i].FLAGID));
        }

        if (structKeyExists(arguments.formData, "flagIDs") AND len(trim(arguments.formData.flagIDs))) {
            flagList = listToArray(arguments.formData.flagIDs);
            for (i = 1; i <= arrayLen(flagList); i++) {
                arrayAppend(submittedFlagIDs, val(trim(flagList[i])));
            }
        }

        for (i = 1; i <= arrayLen(currentFlagIDs); i++) {
            if (arrayFindNoCase(submittedFlagIDs, currentFlagIDs[i]) EQ 0) {
                variables.flagsService.removeFlag(arguments.userID, val(currentFlagIDs[i]));
            }
        }

        for (i = 1; i <= arrayLen(submittedFlagIDs); i++) {
            if (arrayFindNoCase(currentFlagIDs, submittedFlagIDs[i]) EQ 0) {
                variables.flagsService.addFlag(arguments.userID, val(submittedFlagIDs[i]));
            }
        }

        return success("Flags saved.");
    }

    public struct function saveOrganizations(required numeric userID, required struct formData) {
        var currentOrgsResult = variables.organizationsService.getUserOrgs(arguments.userID);
        var currentOrgs = currentOrgsResult.data;
        var currentOrgIDs = [];
        var currentOrgMap = {};
        var submittedOrgIDs = [];
        var submittedOrgMap = {};
        var orgList = [];
        var i = 0;
        var orgID = 0;
        var roleTitle = "";
        var roleOrder = 0;

        for (i = 1; i <= arrayLen(currentOrgs); i++) {
            arrayAppend(currentOrgIDs, val(currentOrgs[i].ORGID));
            currentOrgMap[val(currentOrgs[i].ORGID)] = true;
        }

        if (structKeyExists(arguments.formData, "orgIDs") AND len(trim(arguments.formData.orgIDs))) {
            orgList = listToArray(arguments.formData.orgIDs);
            for (i = 1; i <= arrayLen(orgList); i++) {
                orgID = val(trim(orgList[i]));
                arrayAppend(submittedOrgIDs, orgID);
                submittedOrgMap[orgID] = true;
            }
        }

        for (i = 1; i <= arrayLen(currentOrgIDs); i++) {
            if (!structKeyExists(submittedOrgMap, currentOrgIDs[i])) {
                variables.organizationsService.removeOrg(arguments.userID, val(currentOrgIDs[i]));
            }
        }

        for (i = 1; i <= arrayLen(submittedOrgIDs); i++) {
            orgID = val(submittedOrgIDs[i]);
            roleTitle = structKeyExists(arguments.formData, "roleTitle_" & orgID) ? trim(arguments.formData["roleTitle_" & orgID]) : "";
            roleOrder = (structKeyExists(arguments.formData, "roleOrder_" & orgID) AND isNumeric(arguments.formData["roleOrder_" & orgID])) ? val(arguments.formData["roleOrder_" & orgID]) : 0;
            if (!structKeyExists(currentOrgMap, orgID)) {
                variables.organizationsService.assignOrg(arguments.userID, orgID, roleTitle, roleOrder);
            } else {
                variables.organizationsService.updateOrgAssignment(arguments.userID, orgID, roleTitle, roleOrder);
            }
        }

        return success("Organizations saved.");
    }

    public struct function saveExternalIDs(required numeric userID, required struct formData) {
        var allSystemsResult = variables.externalIDService.getSystems();
        var extSystems = allSystemsResult.data;
        var sys = {};
        var fieldName = "";
        var i = 0;

        for (i = 1; i <= arrayLen(extSystems); i++) {
            sys = extSystems[i];
            fieldName = "extID_" & sys.SYSTEMID;
            if (structKeyExists(arguments.formData, fieldName) AND len(trim(arguments.formData[fieldName]))) {
                variables.externalIDService.setExternalID(arguments.userID, sys.SYSTEMID, trim(arguments.formData[fieldName]));
            }
        }

        return success("External IDs saved.");
    }

    public struct function savePublications(required numeric userID, required struct formData) {
        var saveResult = variables.publicationAdminService.saveProfiles(arguments.userID, arguments.formData);

        if (!saveResult.success) {
            return failure(
                structKeyExists(saveResult, "statusCode") ? val(saveResult.statusCode) : 400,
                saveResult.message ?: "Publications could not be saved.",
                structKeyExists(saveResult, "errors") ? saveResult.errors : []
            );
        }

        return success(
            saveResult.message ?: "Publications saved.",
            structKeyExists(saveResult, "data") ? saveResult.data : {}
        );
    }

    public struct function savePhones(required numeric userID, required struct formData) {
        var phoneCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var primaryIdx = structKeyExists(arguments.formData, "primary_idx") ? val(arguments.formData.primary_idx) : -1;
        var phonesToSave = [];
        var i = 0;
        var phoneNumber = "";
        var phoneType = "";

        for (i = 0; i <= phoneCount - 1; i++) {
            phoneNumber = structKeyExists(arguments.formData, "number_#i#") ? trim(arguments.formData["number_#i#"]) : "";
            phoneType = structKeyExists(arguments.formData, "type_#i#") ? trim(arguments.formData["type_#i#"]) : "";
            if (len(phoneNumber)) {
                arrayAppend(phonesToSave, { number = phoneNumber, type = phoneType, isPrimary = (i EQ primaryIdx) });
            }
        }

        variables.phoneService.replacePhones(arguments.userID, phonesToSave);
        return success("Phones saved.");
    }

    public struct function saveAliases(required numeric userID, required struct formData) {
        var aliasCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var aliasesToSave = [];
        var i = 0;
        var aFirst = "";
        var aMiddle = "";
        var aLast = "";
        var aType = "";
        var aSource = "";
        var aActive = 0;
        var aPrimary = 0;

        for (i = 0; i <= aliasCount - 1; i++) {
            aFirst = structKeyExists(arguments.formData, "first_#i#") ? trim(arguments.formData["first_#i#"]) : "";
            aMiddle = structKeyExists(arguments.formData, "middle_#i#") ? trim(arguments.formData["middle_#i#"]) : "";
            aLast = structKeyExists(arguments.formData, "last_#i#") ? trim(arguments.formData["last_#i#"]) : "";
            aType = structKeyExists(arguments.formData, "type_#i#") ? trim(arguments.formData["type_#i#"]) : "";
            aSource = structKeyExists(arguments.formData, "source_#i#") ? trim(arguments.formData["source_#i#"]) : "";
            aActive = structKeyExists(arguments.formData, "active_#i#") ? val(arguments.formData["active_#i#"]) : 0;
            aPrimary = structKeyExists(arguments.formData, "primary_#i#") ? val(arguments.formData["primary_#i#"]) : 0;
            if (len(aType) AND (len(aFirst) OR len(aMiddle) OR len(aLast))) {
                arrayAppend(aliasesToSave, {
                    firstName = aFirst,
                    middleName = aMiddle,
                    lastName = aLast,
                    aliasType = aType,
                    sourceSystem = aSource,
                    isActive = aActive,
                    isPrimary = aPrimary
                });
            }
        }

        variables.aliasesService.replaceAliases(arguments.userID, aliasesToSave);
        return success("Aliases saved.");
    }

    public struct function saveAwards(required numeric userID, required struct formData) {
        var awardCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var awardsToSave = [];
        var i = 0;
        var awardName = "";
        var awardType = "";

        for (i = 0; i <= awardCount - 1; i++) {
            awardName = structKeyExists(arguments.formData, "name_#i#") ? trim(arguments.formData["name_#i#"]) : "";
            awardType = structKeyExists(arguments.formData, "type_#i#") ? trim(arguments.formData["type_#i#"]) : "";
            if (len(awardName)) {
                arrayAppend(awardsToSave, { name = awardName, type = awardType });
            }
        }

        variables.studentProfileService.replaceAwards(arguments.userID, awardsToSave);
        return success("Awards saved.");
    }

    public struct function saveResidencies(required numeric userID, required struct formData) {
        var residencyCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var residenciesToSave = [];
        var i = 0;
        var residencyLocation = "";
        var residencySpecialty = "";
        var residencyStartingYear = "";
        var residencyIsUHCO = false;
        var residencyIsCurrent = false;

        for (i = 0; i <= residencyCount - 1; i++) {
            residencyLocation = structKeyExists(arguments.formData, "location_#i#") ? trim(arguments.formData["location_#i#"]) : "";
            residencySpecialty = structKeyExists(arguments.formData, "specialty_#i#") ? trim(arguments.formData["specialty_#i#"]) : "";
            residencyStartingYear = structKeyExists(arguments.formData, "startingyear_#i#") ? trim(arguments.formData["startingyear_#i#"]) : "";
            residencyIsUHCO = structKeyExists(arguments.formData, "isuhco_#i#") ? (val(arguments.formData["isuhco_#i#"]) EQ 1) : false;
            residencyIsCurrent = structKeyExists(arguments.formData, "iscurrent_#i#") ? (val(arguments.formData["iscurrent_#i#"]) EQ 1) : false;
            if (len(residencyLocation) OR len(residencySpecialty) OR len(residencyStartingYear)) {
                arrayAppend(residenciesToSave, {
                    location = residencyLocation,
                    specialty = residencySpecialty,
                    startingYear = residencyStartingYear,
                    isUHCO = residencyIsUHCO,
                    isCurrent = residencyIsCurrent
                });
            }
        }

        variables.studentProfileService.replaceResidencies(arguments.userID, residenciesToSave);
        return success("Residencies saved.");
    }

    public struct function saveDegrees(required numeric userID, required struct formData) {
        var degreesToSave = buildDegreesRows(arguments.formData, "count", "");
        var compositeStr = "";

        variables.degreesService.replaceDegrees(arguments.userID, degreesToSave);
        compositeStr = variables.degreesService.buildDegreesString(arguments.userID);
        return success("Degrees saved.", { composite = compositeStr });
    }

    public struct function saveAddresses(required numeric userID, required struct formData) {
        var addrCount = (structKeyExists(arguments.formData, "count") AND isNumeric(arguments.formData.count)) ? val(arguments.formData.count) : 0;
        var addressesToSave = [];
        var i = 0;
        var aType = "";
        var aAddr1 = "";
        var aAddr2 = "";
        var aCity = "";
        var aState = "";
        var aZip = "";
        var aBuilding = "";
        var aRoom = "";
        var aMailcode = "";
        var aPrimary = 0;

        for (i = 0; i <= addrCount - 1; i++) {
            aType = structKeyExists(arguments.formData, "type_#i#") ? trim(arguments.formData["type_#i#"]) : "";
            aAddr1 = structKeyExists(arguments.formData, "addr1_#i#") ? trim(arguments.formData["addr1_#i#"]) : "";
            aAddr2 = structKeyExists(arguments.formData, "addr2_#i#") ? trim(arguments.formData["addr2_#i#"]) : "";
            aCity = structKeyExists(arguments.formData, "city_#i#") ? trim(arguments.formData["city_#i#"]) : "";
            aState = structKeyExists(arguments.formData, "state_#i#") ? trim(arguments.formData["state_#i#"]) : "";
            aZip = structKeyExists(arguments.formData, "zip_#i#") ? trim(arguments.formData["zip_#i#"]) : "";
            aBuilding = structKeyExists(arguments.formData, "building_#i#") ? trim(arguments.formData["building_#i#"]) : "";
            aRoom = structKeyExists(arguments.formData, "room_#i#") ? trim(arguments.formData["room_#i#"]) : "";
            aMailcode = structKeyExists(arguments.formData, "mailcode_#i#") ? trim(arguments.formData["mailcode_#i#"]) : "";
            aPrimary = structKeyExists(arguments.formData, "primary_#i#") ? val(arguments.formData["primary_#i#"]) : 0;
            if (len(aType)) {
                arrayAppend(addressesToSave, {
                    AddressType = { value = aType, cfsqltype = "cf_sql_varchar" },
                    Address1 = { value = aAddr1, cfsqltype = "cf_sql_varchar" },
                    Address2 = { value = aAddr2, cfsqltype = "cf_sql_varchar" },
                    City = { value = aCity, cfsqltype = "cf_sql_varchar" },
                    State = { value = aState, cfsqltype = "cf_sql_varchar" },
                    Zipcode = { value = aZip, cfsqltype = "cf_sql_varchar" },
                    Building = { value = aBuilding, cfsqltype = "cf_sql_varchar" },
                    Room = { value = aRoom, cfsqltype = "cf_sql_varchar" },
                    MailCode = { value = aMailcode, cfsqltype = "cf_sql_varchar" },
                    isPrimary = { value = aPrimary, cfsqltype = "cf_sql_bit" }
                });
            }
        }

        variables.addressesService.replaceAddresses(arguments.userID, addressesToSave);
        syncStudentProfileHometownFromAddresses(arguments.userID, addressesToSave);
        return success("Addresses saved.");
    }

    public struct function addAddress(required numeric userID, required struct formData) {
        var addrData = {
            UserID = { value = arguments.userID, cfsqltype = "cf_sql_integer" },
            AddressType = { value = trim(arguments.formData.type ?: ""), cfsqltype = "cf_sql_varchar" },
            Address1 = { value = trim(arguments.formData.addr1 ?: ""), cfsqltype = "cf_sql_varchar" },
            Address2 = { value = trim(arguments.formData.addr2 ?: ""), cfsqltype = "cf_sql_varchar" },
            City = { value = trim(arguments.formData.city ?: ""), cfsqltype = "cf_sql_varchar" },
            State = { value = trim(arguments.formData.state ?: ""), cfsqltype = "cf_sql_varchar" },
            Zipcode = { value = trim(arguments.formData.zip ?: ""), cfsqltype = "cf_sql_varchar" },
            Building = { value = trim(arguments.formData.building ?: ""), cfsqltype = "cf_sql_varchar" },
            Room = { value = trim(arguments.formData.room ?: ""), cfsqltype = "cf_sql_varchar" },
            MailCode = { value = trim(arguments.formData.mailcode ?: ""), cfsqltype = "cf_sql_varchar" },
            isPrimary = { value = val(arguments.formData.primary ?: 0), cfsqltype = "cf_sql_bit" }
        };
        var result = {};

        result = variables.addressesService.addAddress(addrData);
        if (compareNoCase(trim(arguments.formData.type ?: ""), "Hometown") EQ 0) {
            syncStudentProfileHometownFromAddresses(arguments.userID, [addrData]);
        }

        return success("Address added.", { addressID = result.addressID });
    }

    public struct function saveUHFields(required numeric userID, required struct formData) {
        var existingResult = variables.usersService.getUser(arguments.userID);
        var existing = {};
        var overrides = {};
        var userData = {};
        var updateResult = {};

        if (!existingResult.success) {
            return failure(400, existingResult.message ?: "User not found.", ["userID was not found"]);
        }

        existing = existingResult.data;
        overrides = {
            EmailPrimary = structKeyExists(arguments.formData, "EmailPrimary") ? trim(arguments.formData.EmailPrimary) : (existing.EMAILPRIMARY ?: ""),
            UH_API_ID = structKeyExists(arguments.formData, "UH_API_ID") ? trim(arguments.formData.UH_API_ID) : (existing.UH_API_ID ?: ""),
            Room = structKeyExists(arguments.formData, "Room") ? trim(arguments.formData.Room) : (existing.ROOM ?: ""),
            Building = structKeyExists(arguments.formData, "Building") ? trim(arguments.formData.Building) : (existing.BUILDING ?: ""),
            Campus = structKeyExists(arguments.formData, "Campus") ? trim(arguments.formData.Campus) : (existing.CAMPUS ?: ""),
            Division = structKeyExists(arguments.formData, "Division") ? trim(arguments.formData.Division) : (existing.DIVISION ?: ""),
            DivisionName = structKeyExists(arguments.formData, "DivisionName") ? trim(arguments.formData.DivisionName) : (existing.DIVISIONNAME ?: ""),
            Department = structKeyExists(arguments.formData, "Department") ? trim(arguments.formData.Department) : (existing.DEPARTMENT ?: ""),
            DepartmentName = structKeyExists(arguments.formData, "DepartmentName") ? trim(arguments.formData.DepartmentName) : (existing.DEPARTMENTNAME ?: ""),
            Office_Mailing_Address = structKeyExists(arguments.formData, "Office_Mailing_Address") ? trim(arguments.formData.Office_Mailing_Address) : (existing.OFFICE_MAILING_ADDRESS ?: ""),
            Mailcode = structKeyExists(arguments.formData, "Mailcode") ? trim(arguments.formData.Mailcode) : (existing.MAILCODE ?: ""),
            Notes = structKeyExists(arguments.formData, "Notes") ? trim(arguments.formData.Notes) : (existing.NOTES ?: "")
        };

        userData = buildUserData(existing, overrides);
        updateResult = variables.usersService.updateUser(arguments.userID, userData);
        if (!updateResult.success) {
            return failure(400, updateResult.message ?: "UH fields could not be saved.", [updateResult.message ?: "UH fields could not be saved."]);
        }

        return success("UH fields saved.");
    }

    public struct function saveBiographicalInfo(required numeric userID, required struct formData) {
        var existingResult = variables.usersService.getUser(arguments.userID);
        var existing = {};
        var overrides = {};
        var userData = {};
        var updateResult = {};

        if (!existingResult.success) {
            return failure(400, existingResult.message ?: "User not found.", ["userID was not found"]);
        }

        existing = existingResult.data;
        overrides = {
            DOB = structKeyExists(arguments.formData, "DOB") ? trim(arguments.formData.DOB) : (existing.DOB ?: ""),
            Gender = structKeyExists(arguments.formData, "Gender") ? trim(arguments.formData.Gender) : (existing.GENDER ?: "")
        };

        userData = buildUserData(existing, overrides);
        updateResult = variables.usersService.updateUser(arguments.userID, userData);
        if (!updateResult.success) {
            return failure(400, updateResult.message ?: "Biographical info could not be saved.", [updateResult.message ?: "Biographical info could not be saved."]);
        }

        variables.academicService.saveAcademicInfo(
            arguments.userID,
            structKeyExists(arguments.formData, "CurrentGradYear") ? trim(arguments.formData.CurrentGradYear) : "",
            structKeyExists(arguments.formData, "OriginalGradYear") ? trim(arguments.formData.OriginalGradYear) : ""
        );

        variables.studentProfileService.saveProfile(
            arguments.userID,
            structKeyExists(arguments.formData, "sp_first_externship") ? trim(arguments.formData.sp_first_externship) : "",
            structKeyExists(arguments.formData, "sp_second_externship") ? trim(arguments.formData.sp_second_externship) : "",
            structKeyExists(arguments.formData, "sp_commencement_age") ? trim(arguments.formData.sp_commencement_age) : "",
            structKeyExists(arguments.formData, "sp_dissertation_thesis") ? trim(arguments.formData.sp_dissertation_thesis) : ""
        );

        if (structKeyExists(arguments.formData, "bioContent")) {
            variables.bioService.saveBio(arguments.userID, arguments.formData.bioContent ?: "");
        }

        return success("Biographical info saved.");
    }

    public struct function saveStudentProfile(required numeric userID, required struct formData) {
        var spDegCount = (structKeyExists(arguments.formData, "sp_degree_count") AND isNumeric(arguments.formData.sp_degree_count)) ? val(arguments.formData.sp_degree_count) : 0;
        var degreesToSave = [];

        variables.academicService.saveAcademicInfo(
            arguments.userID,
            structKeyExists(arguments.formData, "CurrentGradYear") ? trim(arguments.formData.CurrentGradYear) : "",
            structKeyExists(arguments.formData, "OriginalGradYear") ? trim(arguments.formData.OriginalGradYear) : ""
        );

        variables.studentProfileService.saveProfile(
            arguments.userID,
            structKeyExists(arguments.formData, "sp_first_externship") ? trim(arguments.formData.sp_first_externship) : "",
            structKeyExists(arguments.formData, "sp_second_externship") ? trim(arguments.formData.sp_second_externship) : "",
            structKeyExists(arguments.formData, "sp_commencement_age") ? trim(arguments.formData.sp_commencement_age) : "",
            structKeyExists(arguments.formData, "sp_dissertation_thesis") ? trim(arguments.formData.sp_dissertation_thesis) : ""
        );

        if (spDegCount GT 0) {
            degreesToSave = buildDegreesRows(arguments.formData, "sp_degree_count", "sp_deg_");
            variables.degreesService.replaceDegrees(arguments.userID, degreesToSave);
        }

        return success("Student profile saved.");
    }

    public struct function saveBio(required numeric userID, required struct formData) {
        variables.bioService.saveBio(arguments.userID, structKeyExists(arguments.formData, "bioContent") ? arguments.formData.bioContent : "");
        return success("Bio saved.");
    }

    public struct function saveTabDegrees(required numeric userID, required struct formData) {
        var prefix = structKeyExists(arguments.formData, "prefix") ? lCase(trim(arguments.formData.prefix)) : "";
        var degreesToSave = [];
        var compositeStr = "";

        if (!listFindNoCase("fac,emer,res", prefix)) {
            return failure(400, "Invalid degree prefix.", ["prefix must be one of fac, emer, or res"]);
        }

        degreesToSave = buildDegreesRows(arguments.formData, prefix & "_degree_count", prefix & "_deg_");
        variables.degreesService.replaceDegrees(arguments.userID, degreesToSave);
        compositeStr = variables.degreesService.buildDegreesString(arguments.userID);
        return success("Degrees saved.", { composite = compositeStr });
    }

    public struct function addLdapEmailIfMissing(required numeric userID, required struct formData) {
        var ldapEmail = structKeyExists(arguments.formData, "email") ? trim(arguments.formData.email) : "";
        var ldapEmailType = "@Cougarnet";
        var wasInserted = false;

        if (!len(ldapEmail)) {
            return failure(400, "Missing email.", ["email is required"]);
        }

        if (reFindNoCase("@central", ldapEmail)) {
            ldapEmailType = "@Central";
        }

        wasInserted = variables.emailsService.addEmailIfMissing(
            userID = arguments.userID,
            emailAddress = ldapEmail,
            emailType = ldapEmailType
        );

        if (wasInserted) {
            return success("Email added.", { inserted = true });
        }

        return success("Email already exists.", { inserted = false });
    }

    public struct function addLdapAliasIfMissing(required numeric userID, required struct formData) {
        var ldapDisplayName = structKeyExists(arguments.formData, "displayName") ? trim(arguments.formData.displayName) : "";
        var aliasTypeCode = "SOURCE_VARIANT";
        var sourceSystem = "LDAP";
        var parsed = {};
        var existingAliases = [];
        var aliasesToSave = [];
        var existing = {};
        var alreadyExists = false;

        if (!len(ldapDisplayName)) {
            return failure(400, "Missing displayName.", ["displayName is required"]);
        }

        parsed = parseDisplayNameParts(ldapDisplayName);
        if (!len(parsed.firstName) AND !len(parsed.middleName) AND !len(parsed.lastName)) {
            return failure(400, "Could not parse displayName into alias parts.", ["displayName could not be parsed"]);
        }

        existingAliases = variables.aliasesService.getAliases(arguments.userID).data;
        for (existing in existingAliases) {
            if (
                lCase(trim(existing.ALIASTYPE ?: "")) EQ lCase(aliasTypeCode)
                AND lCase(trim(existing.SOURCESYSTEM ?: "")) EQ lCase(sourceSystem)
                AND lCase(trim(existing.FIRSTNAME ?: "")) EQ lCase(parsed.firstName)
                AND lCase(trim(existing.MIDDLENAME ?: "")) EQ lCase(parsed.middleName)
                AND lCase(trim(existing.LASTNAME ?: "")) EQ lCase(parsed.lastName)
            ) {
                alreadyExists = true;
                break;
            }
        }

        if (alreadyExists) {
            return success("Alias already exists.", { inserted = false });
        }

        for (existing in existingAliases) {
            arrayAppend(aliasesToSave, {
                firstName = trim(existing.FIRSTNAME ?: ""),
                middleName = trim(existing.MIDDLENAME ?: ""),
                lastName = trim(existing.LASTNAME ?: ""),
                aliasType = trim(existing.ALIASTYPE ?: ""),
                sourceSystem = trim(existing.SOURCESYSTEM ?: ""),
                isActive = val(existing.ISACTIVE ?: 0),
                isPrimary = val(existing.ISPRIMARY ?: 0)
            });
        }

        arrayAppend(aliasesToSave, {
            firstName = parsed.firstName,
            middleName = parsed.middleName,
            lastName = parsed.lastName,
            aliasType = aliasTypeCode,
            sourceSystem = sourceSystem,
            isActive = 1,
            isPrimary = 0
        });

        variables.aliasesService.replaceAliases(arguments.userID, aliasesToSave);
        return success("Alias added.", { inserted = true });
    }

    private struct function success(required string message, any data = {}) {
        return {
            success = true,
            statusCode = 200,
            message = trim(arguments.message ?: ""),
            errors = [],
            data = arguments.data
        };
    }

    private void function syncStudentProfileHometownFromAddresses(required numeric userID, required array addresses) {
        var addressRow = {};
        var hometownCity = "";
        var hometownState = "";

        if (!isStudentHometownSyncUser(arguments.userID)) {
            return;
        }

        for (addressRow in arguments.addresses) {
            if (compareNoCase(getFieldValue(addressRow.AddressType ?: ""), "Hometown") EQ 0) {
                hometownCity = getFieldValue(addressRow.City ?: "");
                hometownState = getFieldValue(addressRow.State ?: "");
            }
        }

        variables.studentProfileService.syncHometown(arguments.userID, hometownCity, hometownState);
    }

    private boolean function isStudentHometownSyncUser(required numeric userID) {
        var userFlags = variables.flagsService.getUserFlags(arguments.userID).data;
        var userFlag = {};

        for (userFlag in userFlags) {
            if (listFindNoCase("current-student,current student,alumni", trim(userFlag.FLAGNAME ?: "")) GT 0) {
                return true;
            }
        }

        return false;
    }

    private string function getFieldValue(required any value) {
        if (isStruct(arguments.value) AND structKeyExists(arguments.value, "value")) {
            return trim(arguments.value.value ?: "");
        }

        return trim(arguments.value ?: "");
    }

    private array function buildDegreesRows(required struct formData, required string countKey, required string fieldPrefix) {
        var countValue = (structKeyExists(arguments.formData, arguments.countKey) AND isNumeric(arguments.formData[arguments.countKey])) ? val(arguments.formData[arguments.countKey]) : 0;
        var degreesToSave = [];
        var i = 0;
        var dName = "";
        var dUniv = "";
        var dYear = "";
        var dIsUHCO = false;
        var dIsEnrolled = false;
        var dHasChange = false;
        var dOrigExpGrad = "";
        var dExpGrad = "";
        var dProgram = "";
        var prefix = arguments.fieldPrefix;

        for (i = 0; i <= countValue - 1; i++) {
            dName = structKeyExists(arguments.formData, prefix & "name_" & i) ? trim(arguments.formData[prefix & "name_" & i]) : "";
            dUniv = structKeyExists(arguments.formData, prefix & "univ_" & i) ? trim(arguments.formData[prefix & "univ_" & i]) : "";
            dYear = structKeyExists(arguments.formData, prefix & "year_" & i) ? trim(arguments.formData[prefix & "year_" & i]) : "";
            dIsUHCO = structKeyExists(arguments.formData, prefix & "isuhco_" & i) ? (val(arguments.formData[prefix & "isuhco_" & i]) EQ 1) : false;
            dIsEnrolled = structKeyExists(arguments.formData, prefix & "enrolled_" & i) ? (val(arguments.formData[prefix & "enrolled_" & i]) EQ 1) : false;
            if (!structKeyExists(arguments.formData, prefix & "enrolled_" & i)) {
                dIsEnrolled = structKeyExists(arguments.formData, prefix & "isenrolled_" & i) ? (val(arguments.formData[prefix & "isenrolled_" & i]) EQ 1) : false;
            }
            dHasChange = structKeyExists(arguments.formData, prefix & "haschange_" & i) ? (val(arguments.formData[prefix & "haschange_" & i]) EQ 1) : false;
            dOrigExpGrad = "";
            if (structKeyExists(arguments.formData, prefix & "origexpgrad_" & i) AND isNumeric(trim(arguments.formData[prefix & "origexpgrad_" & i]))) {
                dOrigExpGrad = val(arguments.formData[prefix & "origexpgrad_" & i]);
            }
            dExpGrad = "";
            if (structKeyExists(arguments.formData, prefix & "expgrad_" & i) AND isNumeric(trim(arguments.formData[prefix & "expgrad_" & i]))) {
                dExpGrad = val(arguments.formData[prefix & "expgrad_" & i]);
            }
            dProgram = structKeyExists(arguments.formData, prefix & "program_" & i) ? trim(arguments.formData[prefix & "program_" & i]) : "";
            if (len(dName)) {
                arrayAppend(degreesToSave, {
                    name = dName,
                    university = dUniv,
                    year = dYear,
                    isUHCO = dIsUHCO,
                    isEnrolled = dIsEnrolled,
                    hasYearChange = dHasChange,
                    originalExpectedGradYear = dOrigExpGrad,
                    expectedGradYear = dExpGrad,
                    program = dProgram
                });
            }
        }

        return degreesToSave;
    }

    private struct function failure(required numeric statusCode, required string message, any errors = [], any data = {}) {
        return {
            success = false,
            statusCode = arguments.statusCode,
            message = trim(arguments.message ?: ""),
            errors = arguments.errors,
            data = arguments.data
        };
    }

    private string function toProperName(required string input) {
        var raw = trim(arguments.input);
        var words = [];
        var result = [];
        var w = "";
        var hParts = [];
        var hResult = [];
        var h = "";
        var part = "";

        if (!len(raw)) {
            return "";
        }

        words = listToArray(raw, " ");
        for (w in words) {
            hParts = listToArray(w, "-");
            hResult = [];
            for (h in hParts) {
                part = lCase(h);
                if (len(part) GT 2 AND left(part, 2) EQ "mc") {
                    part = "Mc" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3);
                } else if (len(part) GT 2 AND left(part, 2) EQ "o'") {
                    part = "O'" & uCase(mid(part, 3, 1)) & mid(part, 4, len(part) - 3);
                } else {
                    part = uCase(left(part, 1)) & mid(part, 2, len(part) - 1);
                }
                arrayAppend(hResult, part);
            }
            arrayAppend(result, arrayToList(hResult, "-"));
        }

        return arrayToList(result, " ");
    }

    private struct function parseDisplayNameParts(required string displayName) {
        var nameRaw = trim(arguments.displayName);
        var cleaned = "";
        var parts = [];
        var structOut = { firstName = "", middleName = "", lastName = "" };
        var firstMiddle = "";
        var firstParts = [];

        if (!len(nameRaw)) {
            return structOut;
        }

        cleaned = rereplace(nameRaw, "\s+", " ", "all");
        if (find(",", cleaned) GT 0) {
            structOut.lastName = toProperName(trim(listFirst(cleaned, ",")));
            firstMiddle = trim(listRest(cleaned, ","));
            if (len(firstMiddle)) {
                firstParts = listToArray(firstMiddle, " ");
                if (arrayLen(firstParts) GTE 1) {
                    structOut.firstName = toProperName(trim(firstParts[1]));
                }
                if (arrayLen(firstParts) GTE 2) {
                    structOut.middleName = toProperName(trim(arrayToList(arraySlice(firstParts, 2, arrayLen(firstParts) - 1), " ")));
                }
            }
            return structOut;
        }

        parts = listToArray(cleaned, " ");
        if (arrayLen(parts) EQ 1) {
            structOut.firstName = toProperName(trim(parts[1]));
        } else if (arrayLen(parts) EQ 2) {
            structOut.firstName = toProperName(trim(parts[1]));
            structOut.lastName = toProperName(trim(parts[2]));
        } else {
            structOut.firstName = toProperName(trim(parts[1]));
            structOut.lastName = toProperName(trim(parts[arrayLen(parts)]));
            structOut.middleName = toProperName(trim(arrayToList(arraySlice(parts, 2, arrayLen(parts) - 2), " ")));
        }

        return structOut;
    }

    private struct function buildUserData(required struct existing, struct overrides = {}) {
        var e = arguments.existing;
        var o = arguments.overrides;
        var ud = {
            FirstName = structKeyExists(o, "FirstName") ? o.FirstName : (e.FIRSTNAME ?: ""),
            MiddleName = structKeyExists(o, "MiddleName") ? o.MiddleName : (e.MIDDLENAME ?: ""),
            LastName = structKeyExists(o, "LastName") ? o.LastName : (e.LASTNAME ?: ""),
            Prefix = structKeyExists(o, "Prefix") ? o.Prefix : (e.PREFIX ?: ""),
            Suffix = structKeyExists(o, "Suffix") ? o.Suffix : (e.SUFFIX ?: ""),
            Pronouns = structKeyExists(o, "Pronouns") ? o.Pronouns : (e.PRONOUNS ?: ""),
            Title1 = structKeyExists(o, "Title1") ? o.Title1 : (e.TITLE1 ?: ""),
            Title2 = structKeyExists(o, "Title2") ? o.Title2 : (e.TITLE2 ?: ""),
            Title3 = structKeyExists(o, "Title3") ? o.Title3 : (e.TITLE3 ?: ""),
            EmailPrimary = structKeyExists(o, "EmailPrimary") ? o.EmailPrimary : (e.EMAILPRIMARY ?: ""),
            Phone = structKeyExists(o, "Phone") ? o.Phone : (e.PHONE ?: ""),
            Room = structKeyExists(o, "Room") ? o.Room : (e.ROOM ?: ""),
            Building = structKeyExists(o, "Building") ? o.Building : (e.BUILDING ?: ""),
            UH_API_ID = structKeyExists(o, "UH_API_ID") ? o.UH_API_ID : (e.UH_API_ID ?: ""),
            Degrees = structKeyExists(o, "Degrees") ? o.Degrees : (e.DEGREES ?: ""),
            Campus = structKeyExists(o, "Campus") ? o.Campus : (e.CAMPUS ?: ""),
            Division = structKeyExists(o, "Division") ? o.Division : (e.DIVISION ?: ""),
            DivisionName = structKeyExists(o, "DivisionName") ? o.DivisionName : (e.DIVISIONNAME ?: ""),
            Department = structKeyExists(o, "Department") ? o.Department : (e.DEPARTMENT ?: ""),
            DepartmentName = structKeyExists(o, "DepartmentName") ? o.DepartmentName : (e.DEPARTMENTNAME ?: ""),
            Office_Mailing_Address = structKeyExists(o, "Office_Mailing_Address") ? o.Office_Mailing_Address : (e.OFFICE_MAILING_ADDRESS ?: ""),
            Mailcode = structKeyExists(o, "Mailcode") ? o.Mailcode : (e.MAILCODE ?: ""),
            Notes = structKeyExists(o, "Notes") ? o.Notes : (e.NOTES ?: ""),
            Active = val(e.ACTIVE ?: 1)
        };
        var dobVal = structKeyExists(o, "DOB") ? o.DOB : (e.DOB ?: "");
        var genVal = structKeyExists(o, "Gender") ? o.Gender : (e.GENDER ?: "");

        ud.DOB = { value = (len(dobVal) ? dobVal : ""), cfsqltype = "cf_sql_date", null = (NOT len(dobVal)) };
        ud.Gender = { value = genVal, cfsqltype = "cf_sql_nvarchar", null = (NOT len(genVal)) };
        return ud;
    }
}