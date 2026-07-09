component output="false" singleton {

    public any function init() {
        variables.directoryService = createObject("component", "cfc.directory_service").init();
        variables.flagsService = createObject("component", "cfc.flags_service").init();
        variables.organizationsService = createObject("component", "cfc.organizations_service").init();
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.externalIDService = createObject("component", "cfc.externalID_service").init();
        variables.emailsService = createObject("component", "cfc.emails_service").init();
        variables.phoneService = createObject("component", "cfc.phone_service").init();
        variables.addressesService = createObject("component", "cfc.addresses_service").init();
        variables.aliasesService = createObject("component", "cfc.aliases_service").init();
        variables.degreesService = createObject("component", "cfc.degrees_service").init();
        variables.studentProfileService = createObject("component", "cfc.studentProfile_service").init();
        variables.academicService = createObject("component", "cfc.academic_service").init();
        variables.bioService = createObject("component", "cfc.bio_service").init();
        variables.importDAO = createObject("component", "dao.import_DAO").init();
        return this;
    }

    public array function getTemplates() {
        return [
            {
                key = "bulk_emails",
                label = "Bulk User Emails",
                description = "Generate a filtered CSV for user email rows, then upload it to insert or replace emails.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["EmailAddress", "EmailType", "IsPrimary"],
                icon = "bi-envelope",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_phones",
                label = "Bulk User Phones",
                description = "Generate a filtered CSV for user phone rows, then upload it to insert or replace phones.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["PhoneNumber", "PhoneType", "IsPrimary"],
                icon = "bi-telephone",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_addresses",
                label = "Bulk User Addresses",
                description = "Generate a filtered CSV for user address rows, then upload it to insert or replace addresses.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["AddressType", "Address1", "Address2", "City", "State", "Zipcode", "Building", "Room", "MailCode", "IsPrimary"],
                icon = "bi-geo-alt",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_aliases",
                label = "Bulk User Aliases",
                description = "Generate a filtered CSV for user alias rows, then upload it to insert or replace aliases.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["AliasFirstName", "AliasMiddleName", "AliasLastName", "AliasDisplayName", "AliasType", "SourceSystem", "IsActive"],
                icon = "bi-person-badge",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_degrees",
                label = "Bulk User Degrees",
                description = "Generate a filtered CSV for user degree rows, then upload it to insert or replace degrees.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["DegreeName", "University", "DegreeYear"],
                icon = "bi-mortarboard",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_awards",
                label = "Bulk User Awards",
                description = "Generate a filtered CSV for user award rows, then upload it to insert or replace awards.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["AwardName", "AwardType"],
                icon = "bi-award",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = true
            },
            {
                key = "bulk_profile",
                label = "Bulk Profile Fields",
                description = "Generate a filtered CSV for one-row profile and academic updates such as titles, bio, externships, commencement age, DOB, gender, and grad years.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = ["Title1", "DOB", "Gender", "BioContent", "FirstExternship", "SecondExternship", "CommencementAge", "CurrentGradYear", "OriginalGradYear"],
                icon = "bi-pencil-square",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = false
            },
            {
                key = "bulk_external_ids",
                label = "Bulk External IDs",
                description = "Generate a filtered CSV for one-row external ID updates across all configured external systems.",
                requiredCols = ["UserID", "FirstName", "LastName", "ImportMode"],
                optionalCols = _getExternalSystemHeaders(),
                icon = "bi-person-vcard",
                workflow = "generated",
                isGeneratedTemplate = true,
                isRepeatable = false
            }
        ];
    }

    public boolean function supportsTemplate(required string templateKey) {
        for (var templateDef in getTemplates()) {
            if (templateDef.key EQ arguments.templateKey) {
                return true;
            }
        }

        return false;
    }

    public struct function getTemplate(required string key) {
        for (var templateDef in getTemplates()) {
            if (templateDef.key EQ arguments.key) {
                return duplicate(templateDef);
            }
        }

        throw(type="BulkImport.InvalidTemplate", message="Unknown bulk import template: #arguments.key#");
    }

    public struct function getFilterOptions() {
        return {
            flags = variables.flagsService.getAllFlags().data,
            organizations = variables.organizationsService.getAllOrgs().data
        };
    }

    public boolean function flagSupportsGradYear(string flagName = "") {
        var normalizedFlag = lCase(trim(arguments.flagName));
        return listFindNoCase("alumni,current student,current-student", normalizedFlag) GT 0;
    }

    public struct function generateTemplate(
        required string templateKey,
        string filterFlag = "",
        string filterOrg = "",
        string filterClass = "",
        boolean includeExistingData = true
    ) {
        var templateDef = getTemplate(arguments.templateKey);
        var users = _loadFilteredUsers(arguments.filterFlag, arguments.filterOrg, arguments.filterClass);
        var csvRows = [];
        var addUHCODegrees = flagSupportsGradYear(arguments.filterFlag);
        var uhcoDegreesSummaryMap = {};
        var csvHeaders = _getTemplateHeaders(arguments.templateKey, addUHCODegrees);

        if (!arrayLen(users)) {
            throw(type="BulkImport.NoUsers", message="No matching users were found for the selected filters.");
        }

        if (addUHCODegrees) {
            var allUserIDs = [];
            for (var u in users) {
                arrayAppend(allUserIDs, val(u.USERID));
            }
            uhcoDegreesSummaryMap = variables.degreesService.buildUHCODegreesSummaryMap(allUserIDs);
        }

        for (var user in users) {
            var userIDKey = toString(val(user.USERID));
            var uhcoDegSummary = structKeyExists(uhcoDegreesSummaryMap, userIDKey) ? uhcoDegreesSummaryMap[userIDKey] : "";
            var templateRows = _buildTemplateRows(templateDef, user, arguments.includeExistingData, uhcoDegSummary);
            for (var row in templateRows) {
                arrayAppend(csvRows, row);
            }
        }

        return {
            fileName = _buildExportFileName(templateDef, arguments.filterFlag, arguments.filterOrg, arguments.filterClass),
            csvContent = _buildCsv(csvHeaders, csvRows),
            userCount = arrayLen(users),
            rowCount = arrayLen(csvRows),
            template = templateDef,
            importMode = arguments.includeExistingData ? "replace" : "merge"
        };
    }

    public struct function validateImport(required string templateKey, required array headers, required array rows) {
        var templateDef = getTemplate(arguments.templateKey);
        var result = { valid = true, errors = [], missingHeaders = [], warnings = [] };
        var requiredHeaders = ["UserID", "FirstName", "LastName", "ImportMode"];
        var lcHeaders = [];
        var groupedModes = {};
        var groupedCounts = {};

        for (var headerName in arguments.headers) {
            arrayAppend(lcHeaders, lCase(trim(headerName)));
        }

        for (var reqHeader in requiredHeaders) {
            if (!arrayFindNoCase(lcHeaders, lCase(reqHeader))) {
                arrayAppend(result.missingHeaders, reqHeader);
            }
        }

        if (arrayLen(result.missingHeaders)) {
            result.valid = false;
            return result;
        }

        if (arguments.templateKey EQ "bulk_external_ids") {
            for (var externalHeader in _getExternalSystemHeaders()) {
                if (!arrayFindNoCase(lcHeaders, lCase(trim(externalHeader)))) {
                    arrayAppend(result.missingHeaders, externalHeader);
                }
            }

            if (arrayLen(result.missingHeaders)) {
                result.valid = false;
                return result;
            }
        }

        for (var rowIndex = 1; rowIndex <= arrayLen(arguments.rows); rowIndex++) {
            if (arrayLen(result.errors) GTE 100) {
                arrayAppend(result.warnings, "Validation stopped after 100 errors.");
                break;
            }

            var row = arguments.rows[rowIndex];
            var rowErrors = _validateRow(templateDef, row, rowIndex);
            if (arrayLen(rowErrors)) {
                result.valid = false;
                for (var rowError in rowErrors) {
                    arrayAppend(result.errors, rowError);
                }
            }

            if (isNumeric(trim(row.UserID ?: ""))) {
                var userKey = trim(row.UserID);
                var modeKey = lCase(trim(row.ImportMode ?: ""));
                groupedCounts[userKey] = (groupedCounts[userKey] ?: 0) + 1;

                if (!structKeyExists(groupedModes, userKey)) {
                    groupedModes[userKey] = modeKey;
                } else if (groupedModes[userKey] NEQ modeKey) {
                    result.valid = false;
                    arrayAppend(result.errors, "Row #rowIndex#: UserID #userKey# mixes import modes within the same file.");
                }
            }
        }

        if (!templateDef.isRepeatable) {
            for (var userIDKey in groupedCounts) {
                if (groupedCounts[userIDKey] GT 1) {
                    result.valid = false;
                    arrayAppend(result.errors, "UserID #userIDKey# appears multiple times in a single-row profile import.");
                }
            }
        }

        return result;
    }

    public numeric function executeImport(
        required string templateKey,
        required array rows,
        required string fileName,
        required string startedBy
    ) {
        var templateDef = getTemplate(arguments.templateKey);
        var groupedRows = _groupRowsByUser(arguments.rows);
        var runID = variables.importDAO.createRun(
            templateKey = arguments.templateKey,
            fileName = arguments.fileName,
            totalRows = arrayLen(groupedRows),
            startedBy = arguments.startedBy
        );
        var successCount = 0;
        var skipCount = 0;
        var errorCount = 0;

        for (var userGroup in groupedRows) {
            try {
                var groupResult = _processUserGroup(templateDef, userGroup);
                if (groupResult.status EQ "success") {
                    successCount++;
                } else if (groupResult.status EQ "skipped") {
                    skipCount++;
                } else {
                    errorCount++;
                }

                variables.importDAO.addDetail(
                    runID = runID,
                    rowNumber = userGroup.rowNumbers[1],
                    status = groupResult.status,
                    message = groupResult.message,
                    rowData = serializeJSON(userGroup.rows)
                );
            } catch (any err) {
                errorCount++;
                variables.importDAO.addDetail(
                    runID = runID,
                    rowNumber = userGroup.rowNumbers[1],
                    status = "error",
                    message = err.message,
                    rowData = serializeJSON(userGroup.rows)
                );
            }
        }

        variables.importDAO.completeRun(
            runID = runID,
            successCount = successCount,
            skipCount = skipCount,
            errorCount = errorCount,
            status = "completed"
        );

        return runID;
    }

    private array function _loadFilteredUsers(string filterFlag = "", string filterOrg = "", string filterClass = "") {
        var normalizedClass = flagSupportsGradYear(arguments.filterFlag) ? trim(arguments.filterClass) : "";
        var loadedUsers = [];
        var pageSize = 500;
        var startRow = 1;
        var searchResult = {};

        if (!len(trim(arguments.filterFlag)) AND !len(trim(arguments.filterOrg)) AND !len(normalizedClass)) {
            throw(type="BulkImport.MissingFilters", message="Choose at least one filter before generating a bulk template.");
        }

        if (len(trim(arguments.filterClass)) AND !flagSupportsGradYear(arguments.filterFlag)) {
            throw(type="BulkImport.InvalidGradYearFilter", message="Grad year filtering is only available for Alumni or Current Student selections.");
        }

        do {
            searchResult = variables.directoryService.searchUsers(
                filterFlag = trim(arguments.filterFlag),
                filterOrg = trim(arguments.filterOrg),
                filterClass = normalizedClass,
                maxRows = pageSize,
                startRow = startRow
            );

            for (var userRow in searchResult.data) {
                arrayAppend(loadedUsers, userRow);
            }

            startRow += pageSize;
        } while (arrayLen(loadedUsers) LT (searchResult.totalCount ?: 0));

        return loadedUsers;
    }

    private array function _getTemplateHeaders(required string templateKey, boolean includeUHCODegrees = false) {
        var headers = [];
        var infoColumns = ["PrimaryFirstName", "PrimaryLastName", "PrimaryEmail"];
        if (arguments.includeUHCODegrees) {
            arrayAppend(infoColumns, "UHCODegrees");
        }

        switch (arguments.templateKey) {
            case "bulk_emails":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "EmailAddress", "EmailType", "IsPrimary"];
                break;
            case "bulk_phones":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "PhoneNumber", "PhoneType", "IsPrimary"];
                break;
            case "bulk_addresses":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "AddressType", "Address1", "Address2", "City", "State", "Zipcode", "Building", "Room", "MailCode", "IsPrimary"];
                break;
            case "bulk_aliases":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "AliasFirstName", "AliasMiddleName", "AliasLastName", "AliasDisplayName", "AliasType", "SourceSystem", "IsActive"];
                break;
            case "bulk_degrees":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "DegreeName", "University", "DegreeYear"];
                break;
            case "bulk_awards":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "AwardName", "AwardType"];
                break;
            case "bulk_profile":
                headers = ["UserID", "FirstName", "LastName", "ImportMode", "Title1", "DOB", "Gender", "BioContent", "FirstExternship", "SecondExternship", "CommencementAge", "CurrentGradYear", "OriginalGradYear"];
                break;
            case "bulk_external_ids":
                headers = ["UserID", "FirstName", "LastName", "ImportMode"];
                arrayAppend(headers, _getExternalSystemHeaders(), true);
                break;
            default:
                headers = ["UserID", "FirstName", "LastName", "ImportMode"];
        }

        arrayAppend(headers, infoColumns, true);
        return headers;
    }

    private array function _buildTemplateRows(required struct templateDef, required struct user, required boolean includeExistingData, string uhcoDegreesSummary = "") {
        var modeValue = arguments.includeExistingData ? "replace" : "merge";
        var baseRow = {
            UserID = arguments.user.USERID,
            FirstName = trim(arguments.user.FIRSTNAME ?: ""),
            LastName = trim(arguments.user.LASTNAME ?: ""),
            ImportMode = modeValue
        };
        var displayInfo = _getPrimaryDisplayInfo(val(arguments.user.USERID));
        baseRow.PrimaryFirstName = displayInfo.primaryFirstName;
        baseRow.PrimaryLastName  = displayInfo.primaryLastName;
        baseRow.PrimaryEmail     = displayInfo.primaryEmail;
        baseRow.UHCODegrees      = arguments.uhcoDegreesSummary;
        var rows = [];
        var existingItems = [];
        var itemRow = {};

        if (arguments.templateDef.key EQ "bulk_profile") {
            var fullProfile = variables.directoryService.getFullProfile(val(arguments.user.USERID));
            itemRow = duplicate(baseRow);
            itemRow.Title1 = trim(fullProfile.user.TITLE1 ?: "");
            itemRow.DOB = _formatDateForCsv(fullProfile.user.DOB ?: "");
            itemRow.Gender = trim(fullProfile.user.GENDER ?: "");
            itemRow.BioContent = trim(fullProfile.bio.BIOCONTENT ?: "");
            itemRow.FirstExternship = trim(fullProfile.studentProfile.FIRSTEXTERNSHIP ?: "");
            itemRow.SecondExternship = trim(fullProfile.studentProfile.SECONDEXTERNSHIP ?: "");
            itemRow.CommencementAge = trim(fullProfile.studentProfile.COMMENCEMENTAGE ?: "");
            itemRow.CurrentGradYear = trim(fullProfile.academic.CURRENTGRADYEAR ?: "");
            itemRow.OriginalGradYear = trim(fullProfile.academic.ORIGINALGRADYEAR ?: "");

            if (!arguments.includeExistingData) {
                for (var profileField in _getTemplateHeaders(arguments.templateDef.key)) {
                    if (!listFindNoCase("UserID,FirstName,LastName,ImportMode,PrimaryFirstName,PrimaryLastName,PrimaryEmail", profileField)) {
                        itemRow[profileField] = "";
                    }
                }
            }

            arrayAppend(rows, itemRow);
            return rows;
        }

        if (arguments.templateDef.key EQ "bulk_external_ids") {
            itemRow = duplicate(baseRow);

            for (var externalHeader in _getExternalSystemHeaders()) {
                itemRow[externalHeader] = "";
            }

            if (arguments.includeExistingData) {
                var externalIdsByHeader = _getExternalIDsByHeader(val(arguments.user.USERID));
                for (var headerName in externalIdsByHeader) {
                    itemRow[headerName] = externalIdsByHeader[headerName];
                }
            }

            arrayAppend(rows, itemRow);
            return rows;
        }

        existingItems = arguments.includeExistingData ? _getExistingItems(arguments.templateDef.key, val(arguments.user.USERID)) : [];
        if (!arrayLen(existingItems)) {
            arrayAppend(rows, _buildBlankRepeatableRow(arguments.templateDef.key, baseRow));
            return rows;
        }

        for (var item in existingItems) {
            itemRow = duplicate(baseRow);
            switch (arguments.templateDef.key) {
                case "bulk_emails":
                    itemRow.EmailAddress = trim(item.EMAILADDRESS ?: item.address ?: "");
                    itemRow.EmailType = trim(item.EMAILTYPE ?: item.type ?: "");
                    itemRow.IsPrimary = _booleanToCsv(item.ISPRIMARY ?: item.isPrimary ?: 0);
                    break;
                case "bulk_phones":
                    itemRow.PhoneNumber = trim(item.PHONENUMBER ?: item.number ?: "");
                    itemRow.PhoneType = trim(item.PHONETYPE ?: item.type ?: "");
                    itemRow.IsPrimary = _booleanToCsv(item.ISPRIMARY ?: item.isPrimary ?: 0);
                    break;
                case "bulk_addresses":
                    itemRow.AddressType = trim(item.ADDRESSTYPE ?: "");
                    itemRow.Address1 = trim(item.ADDRESS1 ?: "");
                    itemRow.Address2 = trim(item.ADDRESS2 ?: "");
                    itemRow.City = trim(item.CITY ?: "");
                    itemRow.State = trim(item.STATE ?: "");
                    itemRow.Zipcode = trim(item.ZIPCODE ?: "");
                    itemRow.Building = trim(item.BUILDING ?: "");
                    itemRow.Room = trim(item.ROOM ?: "");
                    itemRow.MailCode = trim(item.MAILCODE ?: "");
                    itemRow.IsPrimary = _booleanToCsv(item.ISPRIMARY ?: 0);
                    break;
                case "bulk_aliases":
                    itemRow.AliasFirstName = trim(item.FIRSTNAME ?: item.firstName ?: "");
                    itemRow.AliasMiddleName = trim(item.MIDDLENAME ?: item.middleName ?: "");
                    itemRow.AliasLastName = trim(item.LASTNAME ?: item.lastName ?: "");
                    itemRow.AliasDisplayName = trim(item.DISPLAYNAME ?: item.displayName ?: "");
                    itemRow.AliasType = trim(item.ALIASTYPE ?: item.aliasType ?: "");
                    itemRow.SourceSystem = trim(item.SOURCESYSTEM ?: item.sourceSystem ?: "");
                    itemRow.IsActive = _booleanToCsv(item.ISACTIVE ?: item.isActive ?: 0);
                    break;
                case "bulk_degrees":
                    itemRow.DegreeName = trim(item.DEGREENAME ?: item.name ?: "");
                    itemRow.University = trim(item.UNIVERSITY ?: item.university ?: "");
                    itemRow.DegreeYear = trim(item.DEGREEYEAR ?: item.year ?: "");
                    break;
                case "bulk_awards":
                    itemRow.AwardName = trim(item.AWARDNAME ?: item.name ?: "");
                    itemRow.AwardType = trim(item.AWARDTYPE ?: item.type ?: "");
                    break;
            }
            arrayAppend(rows, itemRow);
        }

        return rows;
    }

    private struct function _buildBlankRepeatableRow(required string templateKey, required struct baseRow) {
        var blankRow = duplicate(arguments.baseRow);

        for (var headerName in _getTemplateHeaders(arguments.templateKey)) {
            if (!structKeyExists(blankRow, headerName)) {
                blankRow[headerName] = "";
            }
        }

        return blankRow;
    }

    private array function _getExistingItems(required string templateKey, required numeric userID) {
        switch (arguments.templateKey) {
            case "bulk_emails":
                return variables.emailsService.getEmails(arguments.userID).data;
            case "bulk_phones":
                return variables.phoneService.getPhones(arguments.userID).data;
            case "bulk_addresses":
                return variables.addressesService.getAddresses(arguments.userID).data;
            case "bulk_aliases":
                return variables.aliasesService.getAliases(arguments.userID).data;
            case "bulk_degrees":
                return variables.degreesService.getDegrees(arguments.userID).data;
            case "bulk_awards":
                return variables.studentProfileService.getAwards(arguments.userID).data;
        }

        return [];
    }

    private string function _buildExportFileName(required struct templateDef, string filterFlag = "", string filterOrg = "", string filterClass = "") {
        var parts = [arguments.templateDef.key];
        if (len(trim(arguments.filterFlag))) {
            arrayAppend(parts, _slugify(arguments.filterFlag));
        }
        if (len(trim(arguments.filterOrg))) {
            arrayAppend(parts, _slugify(arguments.filterOrg));
        }
        if (len(trim(arguments.filterClass))) {
            arrayAppend(parts, _slugify(arguments.filterClass));
        }
        arrayAppend(parts, dateFormat(now(), "yyyymmdd"));
        return arrayToList(parts, "_") & ".csv";
    }

    private string function _buildCsv(required array headers, required array rows) {
        var lines = [];
        var currentValues = [];

        currentValues = [];
        for (var headerName in arguments.headers) {
            arrayAppend(currentValues, _escapeCsvCell(headerName));
        }
        arrayAppend(lines, arrayToList(currentValues, ","));

        for (var row in arguments.rows) {
            currentValues = [];
            for (var exportHeader in arguments.headers) {
                arrayAppend(currentValues, _escapeCsvCell(toString(row[exportHeader] ?: "")));
            }
            arrayAppend(lines, arrayToList(currentValues, ","));
        }

        return arrayToList(lines, chr(13) & chr(10));
    }

    private string function _escapeCsvCell(required string value) {
        return '"' & replace(arguments.value, '"', '""', 'all') & '"';
    }

    private string function _slugify(required string value) {
        var slug = lCase(trim(arguments.value));
        slug = reReplace(slug, "[^a-z0-9]+", "_", "all");
        slug = reReplace(slug, "_{2,}", "_", "all");
        slug = reReplace(slug, "^_|_$", "", "all");
        return slug;
    }

    private string function _formatDateForCsv(any value) {
        if (isDate(arguments.value)) {
            return dateFormat(arguments.value, "mm/dd/yyyy");
        }
        return trim(arguments.value ?: "");
    }

    private array function _validateRow(required struct templateDef, required struct row, required numeric rowIndex) {
        var errors = [];
        var modeValue = lCase(trim(arguments.row.ImportMode ?: ""));

        if (!isNumeric(trim(arguments.row.UserID ?: ""))) {
            arrayAppend(errors, "Row #arguments.rowIndex#: UserID must be numeric.");
        }

        if (!listFindNoCase("replace,merge", modeValue)) {
            arrayAppend(errors, "Row #arguments.rowIndex#: ImportMode must be replace or merge.");
        }

        switch (arguments.templateDef.key) {
            case "bulk_emails":
                if (len(trim(arguments.row.EmailAddress ?: "")) AND !isValid("email", trim(arguments.row.EmailAddress))) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: EmailAddress is not a valid email.");
                }
                if (len(trim(arguments.row.IsPrimary ?: "")) AND !_isBooleanLike(arguments.row.IsPrimary)) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: IsPrimary must be true/false or 1/0.");
                }
                break;
            case "bulk_phones":
                if (len(trim(arguments.row.IsPrimary ?: "")) AND !_isBooleanLike(arguments.row.IsPrimary)) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: IsPrimary must be true/false or 1/0.");
                }
                break;
            case "bulk_addresses":
                if (len(trim(arguments.row.IsPrimary ?: "")) AND !_isBooleanLike(arguments.row.IsPrimary)) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: IsPrimary must be true/false or 1/0.");
                }
                break;
            case "bulk_aliases":
                if (len(trim(arguments.row.IsActive ?: "")) AND !_isBooleanLike(arguments.row.IsActive)) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: IsActive must be true/false or 1/0.");
                }
                break;
            case "bulk_profile":
                if (len(trim(arguments.row.DOB ?: "")) AND !isValid("date", trim(arguments.row.DOB))) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: DOB must be a valid date.");
                }
                if (len(trim(arguments.row.CommencementAge ?: "")) AND !isNumeric(trim(arguments.row.CommencementAge))) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: CommencementAge must be numeric.");
                }
                if (len(trim(arguments.row.CurrentGradYear ?: "")) AND !isNumeric(trim(arguments.row.CurrentGradYear))) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: CurrentGradYear must be numeric.");
                }
                if (len(trim(arguments.row.OriginalGradYear ?: "")) AND !isNumeric(trim(arguments.row.OriginalGradYear))) {
                    arrayAppend(errors, "Row #arguments.rowIndex#: OriginalGradYear must be numeric.");
                }
                break;
        }

        return errors;
    }

    private array function _groupRowsByUser(required array rows) {
        var groups = [];
        var groupIndex = {};

        for (var rowIndex = 1; rowIndex <= arrayLen(arguments.rows); rowIndex++) {
            var row = arguments.rows[rowIndex];
            var userKey = trim(row.UserID ?: "");
            if (!structKeyExists(groupIndex, userKey)) {
                groupIndex[userKey] = arrayLen(groups) + 1;
                arrayAppend(groups, {
                    userID = val(userKey),
                    importMode = lCase(trim(row.ImportMode ?: "replace")),
                    rowNumbers = [rowIndex],
                    rows = [row]
                });
            } else {
                var existingIndex = groupIndex[userKey];
                arrayAppend(groups[existingIndex].rowNumbers, rowIndex);
                arrayAppend(groups[existingIndex].rows, row);
            }
        }

        return groups;
    }

    private struct function _processUserGroup(required struct templateDef, required struct userGroup) {
        if (arguments.templateDef.isRepeatable) {
            return _processRepeatableGroup(arguments.templateDef, arguments.userGroup);
        }

        if (arguments.templateDef.key EQ "bulk_external_ids") {
            return _processExternalIDsGroup(arguments.userGroup);
        }

        return _processProfileGroup(arguments.userGroup);
    }

    private struct function _processRepeatableGroup(required struct templateDef, required struct userGroup) {
        var items = [];
        var existingItems = _normalizeExistingItems(arguments.templateDef.key, arguments.userGroup.userID);
        var rowItem = {};
        var mergedItems = [];

        for (var row in arguments.userGroup.rows) {
            rowItem = _parseRepeatableRow(arguments.templateDef.key, row);
            if (!_isBlankRepeatableItem(arguments.templateDef.key, rowItem)) {
                arrayAppend(items, rowItem);
            }
        }

        if (arguments.userGroup.importMode EQ "merge") {
            mergedItems = _mergeRepeatableItems(arguments.templateDef.key, existingItems, items);
            if (arrayLen(mergedItems) EQ arrayLen(existingItems) AND arrayLen(items)) {
                return { status = "skipped", message = "No new rows were added for user ##" & arguments.userGroup.userID };
            }
            if (!arrayLen(items)) {
                return { status = "skipped", message = "No data rows were provided for user ##" & arguments.userGroup.userID };
            }
            _saveRepeatableItems(arguments.templateDef.key, arguments.userGroup.userID, mergedItems);
            return { status = "success", message = "Merged #arrayLen(items)# row(s) for user ##" & arguments.userGroup.userID };
        }

        _saveRepeatableItems(arguments.templateDef.key, arguments.userGroup.userID, items);
        if (arrayLen(items)) {
            return { status = "success", message = "Saved #arrayLen(items)# row(s) for user ##" & arguments.userGroup.userID };
        }

        return { status = "success", message = "Cleared existing rows for user ##" & arguments.userGroup.userID };
    }

    private struct function _processProfileGroup(required struct userGroup) {
        var row = arguments.userGroup.rows[1];
        var fullProfile = variables.directoryService.getFullProfile(arguments.userGroup.userID);
        var currentUser = duplicate(fullProfile.user);
        var userUpdate = duplicate(currentUser);
        var modeValue = arguments.userGroup.importMode;
        var userChanged = false;
        var profileChanged = false;
        var academicChanged = false;
        var bioChanged = false;
        var dobValue = trim(row.DOB ?: "");
        var genderValue = trim(row.Gender ?: "");
        var currentGradYear = trim(row.CurrentGradYear ?: "");
        var originalGradYear = trim(row.OriginalGradYear ?: "");
        var firstExternship = _resolveProfileValue(trim(row.FirstExternship ?: ""), trim(fullProfile.studentProfile.FIRSTEXTERNSHIP ?: ""), modeValue);
        var secondExternship = _resolveProfileValue(trim(row.SecondExternship ?: ""), trim(fullProfile.studentProfile.SECONDEXTERNSHIP ?: ""), modeValue);
        var commencementAge = _resolveProfileValue(trim(row.CommencementAge ?: ""), trim(fullProfile.studentProfile.COMMENCEMENTAGE ?: ""), modeValue);
        var bioContent = _resolveProfileValue(trim(row.BioContent ?: ""), trim(fullProfile.bio.BIOCONTENT ?: ""), modeValue);

        userUpdate.Title1 = _resolveProfileValue(trim(row.Title1 ?: ""), trim(currentUser.TITLE1 ?: ""), modeValue);

        if (modeValue EQ "replace") {
            userUpdate.DOB = len(dobValue) ? { value=parseDateTime(dobValue), cfsqltype="cf_sql_date", null=false } : { value="", cfsqltype="cf_sql_date", null=true };
            userUpdate.Gender = len(genderValue) ? { value=genderValue, cfsqltype="cf_sql_nvarchar", null=false } : { value="", cfsqltype="cf_sql_nvarchar", null=true };
        } else {
            if (len(dobValue)) {
                userUpdate.DOB = { value=parseDateTime(dobValue), cfsqltype="cf_sql_date", null=false };
            }
            if (len(genderValue)) {
                userUpdate.Gender = { value=genderValue, cfsqltype="cf_sql_nvarchar", null=false };
            }
        }

        userChanged = _stringValuesDiffer(userUpdate.Title1, currentUser.TITLE1 ?: "")
            OR len(dobValue)
            OR len(genderValue)
            OR modeValue EQ "replace";

        if (userChanged) {
            variables.usersService.updateUser(arguments.userGroup.userID, userUpdate);
        }

        profileChanged = _stringValuesDiffer(firstExternship, fullProfile.studentProfile.FIRSTEXTERNSHIP ?: "")
            OR _stringValuesDiffer(secondExternship, fullProfile.studentProfile.SECONDEXTERNSHIP ?: "")
            OR _stringValuesDiffer(commencementAge, fullProfile.studentProfile.COMMENCEMENTAGE ?: "")
            OR modeValue EQ "replace";
        if (profileChanged) {
            variables.studentProfileService.saveProfile(arguments.userGroup.userID, firstExternship, secondExternship, commencementAge);
        }

        academicChanged = len(currentGradYear) OR len(originalGradYear) OR modeValue EQ "replace";
        if (academicChanged) {
            var savedCurrentGradYear = modeValue EQ "replace" ? currentGradYear : (len(currentGradYear) ? currentGradYear : trim(fullProfile.academic.CURRENTGRADYEAR ?: ""));
            var savedOriginalGradYear = modeValue EQ "replace" ? originalGradYear : (len(originalGradYear) ? originalGradYear : trim(fullProfile.academic.ORIGINALGRADYEAR ?: ""));
            variables.academicService.saveAcademicInfo(arguments.userGroup.userID, savedCurrentGradYear, savedOriginalGradYear);
            // Bridge: if a numeric grad year was provided, also update any enrolled UHCO degree row
            if (len(savedCurrentGradYear) AND isNumeric(savedCurrentGradYear) AND val(savedCurrentGradYear) GT 0) {
                try {
                    var degDAO = createObject("component", "dao.degrees_DAO").init();
                    degDAO.syncExpectedGradYearFromLegacy(arguments.userGroup.userID, val(savedCurrentGradYear));
                } catch (any degEx) { /* non-fatal: legacy row still updated */ }
            }
        }

        bioChanged = _stringValuesDiffer(bioContent, fullProfile.bio.BIOCONTENT ?: "") OR modeValue EQ "replace";
        if (bioChanged) {
            variables.bioService.saveBio(arguments.userGroup.userID, bioContent);
        }

        if (userChanged OR profileChanged OR academicChanged OR bioChanged) {
            return { status = "success", message = "Updated profile fields for user ##" & arguments.userGroup.userID };
        }

        return { status = "skipped", message = "No profile changes detected for user ##" & arguments.userGroup.userID };
    }

    private struct function _processExternalIDsGroup(required struct userGroup) {
        var row = arguments.userGroup.rows[1];
        var systems = _getExternalSystems();
        var existingRows = variables.externalIDService.getExternalIDs(arguments.userGroup.userID).data;
        var existingBySystemId = {};
        var systemKey = "";
        var submittedValue = "";
        var existingValue = "";
        var changes = 0;

        for (var existingRow in existingRows) {
            systemKey = toString(val(existingRow.SYSTEMID ?: 0));
            if (len(systemKey)) {
                existingBySystemId[systemKey] = trim(existingRow.EXTERNALVALUE ?: "");
            }
        }

        for (var systemRow in systems) {
            systemKey = toString(val(systemRow.SYSTEMID ?: 0));
            if (!len(systemKey)) {
                continue;
            }

            submittedValue = trim(_getRowValueByHeader(row, trim(systemRow.SYSTEMNAME ?: "")));
            existingValue = structKeyExists(existingBySystemId, systemKey) ? existingBySystemId[systemKey] : "";

            if (arguments.userGroup.importMode EQ "merge") {
                if (len(submittedValue) AND submittedValue NEQ existingValue) {
                    variables.externalIDService.setExternalID(arguments.userGroup.userID, val(systemKey), submittedValue);
                    changes++;
                }
            } else {
                if (len(submittedValue)) {
                    if (submittedValue NEQ existingValue) {
                        variables.externalIDService.setExternalID(arguments.userGroup.userID, val(systemKey), submittedValue);
                        changes++;
                    }
                } else if (len(existingValue)) {
                    variables.externalIDService.deleteExternalID(arguments.userGroup.userID, val(systemKey));
                    changes++;
                }
            }
        }

        if (changes GT 0) {
            return { status = "success", message = "Updated external IDs for user ##" & arguments.userGroup.userID };
        }

        return { status = "skipped", message = "No external ID changes detected for user ##" & arguments.userGroup.userID };
    }

    private string function _resolveProfileValue(required string submittedValue, required string existingValue, required string importMode) {
        if (arguments.importMode EQ "replace") {
            return arguments.submittedValue;
        }

        return len(arguments.submittedValue) ? arguments.submittedValue : arguments.existingValue;
    }

    private boolean function _stringValuesDiffer(any leftValue, any rightValue) {
        return trim(toString(arguments.leftValue ?: "")) NEQ trim(toString(arguments.rightValue ?: ""));
    }

    private array function _getExternalSystems() {
        var systemsResult = variables.externalIDService.getSystems();
        if (structKeyExists(systemsResult, "success") AND systemsResult.success AND isArray(systemsResult.data)) {
            return systemsResult.data;
        }

        return [];
    }

    private array function _getExternalSystemHeaders() {
        var headers = [];

        for (var systemRow in _getExternalSystems()) {
            if (len(trim(systemRow.SYSTEMNAME ?: ""))) {
                arrayAppend(headers, trim(systemRow.SYSTEMNAME));
            }
        }

        return headers;
    }

    private struct function _getExternalIDsByHeader(required numeric userID) {
        var externalRows = variables.externalIDService.getExternalIDs(arguments.userID).data;
        var valuesByHeader = {};

        for (var externalRow in externalRows) {
            if (len(trim(externalRow.SYSTEMNAME ?: ""))) {
                valuesByHeader[trim(externalRow.SYSTEMNAME)] = trim(externalRow.EXTERNALVALUE ?: "");
            }
        }

        return valuesByHeader;
    }

    private string function _getRowValueByHeader(required struct row, required string headerName) {
        for (var currentKey in arguments.row) {
            if (compareNoCase(trim(currentKey), trim(arguments.headerName)) EQ 0) {
                return trim(arguments.row[currentKey] ?: "");
            }
        }

        return "";
    }

    private array function _normalizeExistingItems(required string templateKey, required numeric userID) {
        var normalized = [];
        for (var existingRow in _getExistingItems(arguments.templateKey, arguments.userID)) {
            switch (arguments.templateKey) {
                case "bulk_emails":
                    arrayAppend(normalized, {
                        address = trim(existingRow.EMAILADDRESS ?: ""),
                        type = trim(existingRow.EMAILTYPE ?: ""),
                        isPrimary = _toBoolean(existingRow.ISPRIMARY ?: 0)
                    });
                    break;
                case "bulk_phones":
                    arrayAppend(normalized, {
                        number = trim(existingRow.PHONENUMBER ?: ""),
                        type = trim(existingRow.PHONETYPE ?: ""),
                        isPrimary = _toBoolean(existingRow.ISPRIMARY ?: 0)
                    });
                    break;
                case "bulk_addresses":
                    arrayAppend(normalized, {
                        addressType = trim(existingRow.ADDRESSTYPE ?: ""),
                        address1 = trim(existingRow.ADDRESS1 ?: ""),
                        address2 = trim(existingRow.ADDRESS2 ?: ""),
                        city = trim(existingRow.CITY ?: ""),
                        state = trim(existingRow.STATE ?: ""),
                        zipcode = trim(existingRow.ZIPCODE ?: ""),
                        building = trim(existingRow.BUILDING ?: ""),
                        room = trim(existingRow.ROOM ?: ""),
                        mailCode = trim(existingRow.MAILCODE ?: ""),
                        isPrimary = _toBoolean(existingRow.ISPRIMARY ?: 0)
                    });
                    break;
                case "bulk_aliases":
                    arrayAppend(normalized, {
                        firstName = trim(existingRow.FIRSTNAME ?: ""),
                        middleName = trim(existingRow.MIDDLENAME ?: ""),
                        lastName = trim(existingRow.LASTNAME ?: ""),
                        displayName = trim(existingRow.DISPLAYNAME ?: ""),
                        aliasType = trim(existingRow.ALIASTYPE ?: ""),
                        sourceSystem = trim(existingRow.SOURCESYSTEM ?: ""),
                        isActive = _toBoolean(existingRow.ISACTIVE ?: 0)
                    });
                    break;
                case "bulk_degrees":
                    arrayAppend(normalized, {
                        name = trim(existingRow.DEGREENAME ?: ""),
                        university = trim(existingRow.UNIVERSITY ?: ""),
                        year = trim(existingRow.DEGREEYEAR ?: "")
                    });
                    break;
                case "bulk_awards":
                    arrayAppend(normalized, {
                        name = trim(existingRow.AWARDNAME ?: ""),
                        type = trim(existingRow.AWARDTYPE ?: "")
                    });
                    break;
            }
        }

        return normalized;
    }

    private struct function _parseRepeatableRow(required string templateKey, required struct row) {
        switch (arguments.templateKey) {
            case "bulk_emails":
                return {
                    address = trim(arguments.row.EmailAddress ?: ""),
                    type = trim(arguments.row.EmailType ?: ""),
                    isPrimary = _toBoolean(arguments.row.IsPrimary ?: "0")
                };
            case "bulk_phones":
                return {
                    number = trim(arguments.row.PhoneNumber ?: ""),
                    type = trim(arguments.row.PhoneType ?: ""),
                    isPrimary = _toBoolean(arguments.row.IsPrimary ?: "0")
                };
            case "bulk_addresses":
                return {
                    addressType = trim(arguments.row.AddressType ?: ""),
                    address1 = trim(arguments.row.Address1 ?: ""),
                    address2 = trim(arguments.row.Address2 ?: ""),
                    city = trim(arguments.row.City ?: ""),
                    state = trim(arguments.row.State ?: ""),
                    zipcode = trim(arguments.row.Zipcode ?: ""),
                    building = trim(arguments.row.Building ?: ""),
                    room = trim(arguments.row.Room ?: ""),
                    mailCode = trim(arguments.row.MailCode ?: ""),
                    isPrimary = _toBoolean(arguments.row.IsPrimary ?: "0")
                };
            case "bulk_aliases":
                return {
                    firstName = trim(arguments.row.AliasFirstName ?: ""),
                    middleName = trim(arguments.row.AliasMiddleName ?: ""),
                    lastName = trim(arguments.row.AliasLastName ?: ""),
                    displayName = trim(arguments.row.AliasDisplayName ?: ""),
                    aliasType = trim(arguments.row.AliasType ?: ""),
                    sourceSystem = trim(arguments.row.SourceSystem ?: ""),
                    isActive = _toBoolean(arguments.row.IsActive ?: "1")
                };
            case "bulk_degrees":
                return {
                    name = trim(arguments.row.DegreeName ?: ""),
                    university = trim(arguments.row.University ?: ""),
                    year = trim(arguments.row.DegreeYear ?: "")
                };
            case "bulk_awards":
                return {
                    name = trim(arguments.row.AwardName ?: ""),
                    type = trim(arguments.row.AwardType ?: "")
                };
        }

        return {};
    }

    private boolean function _isBlankRepeatableItem(required string templateKey, required struct item) {
        switch (arguments.templateKey) {
            case "bulk_emails":
                return !len(arguments.item.address) AND !len(arguments.item.type);
            case "bulk_phones":
                return !len(arguments.item.number) AND !len(arguments.item.type);
            case "bulk_addresses":
                return !len(arguments.item.addressType) AND !len(arguments.item.address1) AND !len(arguments.item.city) AND !len(arguments.item.state) AND !len(arguments.item.zipcode);
            case "bulk_aliases":
                return !len(arguments.item.firstName) AND !len(arguments.item.middleName) AND !len(arguments.item.lastName) AND !len(arguments.item.displayName) AND !len(arguments.item.aliasType);
            case "bulk_degrees":
                return !len(arguments.item.name) AND !len(arguments.item.university) AND !len(arguments.item.year);
            case "bulk_awards":
                return !len(arguments.item.name) AND !len(arguments.item.type);
        }

        return true;
    }

    private array function _mergeRepeatableItems(required string templateKey, required array existingItems, required array submittedItems) {
        var merged = [];
        var seen = {};
        var itemSignature = "";

        for (var existingItem in arguments.existingItems) {
            itemSignature = _buildItemSignature(arguments.templateKey, existingItem);
            if (!structKeyExists(seen, itemSignature)) {
                seen[itemSignature] = true;
                arrayAppend(merged, existingItem);
            }
        }

        for (var submittedItem in arguments.submittedItems) {
            itemSignature = _buildItemSignature(arguments.templateKey, submittedItem);
            if (!structKeyExists(seen, itemSignature)) {
                seen[itemSignature] = true;
                arrayAppend(merged, submittedItem);
            }
        }

        return merged;
    }

    private string function _buildItemSignature(required string templateKey, required struct item) {
        switch (arguments.templateKey) {
            case "bulk_emails":
                return lCase(arguments.item.type) & "|" & lCase(arguments.item.address);
            case "bulk_phones":
                return lCase(arguments.item.type) & "|" & lCase(arguments.item.number);
            case "bulk_addresses":
                return lCase(arguments.item.addressType) & "|" & lCase(arguments.item.address1) & "|" & lCase(arguments.item.address2) & "|" & lCase(arguments.item.city) & "|" & lCase(arguments.item.state) & "|" & lCase(arguments.item.zipcode) & "|" & lCase(arguments.item.building) & "|" & lCase(arguments.item.room) & "|" & lCase(arguments.item.mailCode);
            case "bulk_aliases":
                return lCase(arguments.item.aliasType) & "|" & lCase(arguments.item.firstName) & "|" & lCase(arguments.item.middleName) & "|" & lCase(arguments.item.lastName) & "|" & lCase(arguments.item.displayName) & "|" & lCase(arguments.item.sourceSystem);
            case "bulk_degrees":
                return lCase(arguments.item.name) & "|" & lCase(arguments.item.university) & "|" & lCase(arguments.item.year);
            case "bulk_awards":
                return lCase(arguments.item.name) & "|" & lCase(arguments.item.type);
        }

        return serializeJSON(arguments.item);
    }

    private void function _saveRepeatableItems(required string templateKey, required numeric userID, required array items) {
        switch (arguments.templateKey) {
            case "bulk_emails":
                variables.emailsService.replaceEmails(arguments.userID, arguments.items);
                break;
            case "bulk_phones":
                variables.phoneService.replacePhones(arguments.userID, arguments.items);
                break;
            case "bulk_addresses":
                variables.addressesService.replaceAddresses(arguments.userID, _toAddressSaveRows(arguments.items));
                break;
            case "bulk_aliases":
                variables.aliasesService.replaceAliases(arguments.userID, arguments.items);
                break;
            case "bulk_degrees":
                variables.degreesService.replaceDegrees(arguments.userID, arguments.items);
                break;
            case "bulk_awards":
                variables.studentProfileService.replaceAwards(arguments.userID, arguments.items);
                break;
        }
    }

    private array function _toAddressSaveRows(required array items) {
        var rows = [];
        for (var item in arguments.items) {
            arrayAppend(rows, {
                AddressType = { value=item.addressType, cfsqltype="cf_sql_nvarchar", null=!len(item.addressType) },
                Address1 = { value=item.address1, cfsqltype="cf_sql_nvarchar", null=!len(item.address1) },
                Address2 = { value=item.address2, cfsqltype="cf_sql_nvarchar", null=!len(item.address2) },
                City = { value=item.city, cfsqltype="cf_sql_nvarchar", null=!len(item.city) },
                State = { value=item.state, cfsqltype="cf_sql_nvarchar", null=!len(item.state) },
                Zipcode = { value=item.zipcode, cfsqltype="cf_sql_nvarchar", null=!len(item.zipcode) },
                Building = { value=item.building, cfsqltype="cf_sql_nvarchar", null=!len(item.building) },
                Room = { value=item.room, cfsqltype="cf_sql_nvarchar", null=!len(item.room) },
                MailCode = { value=item.mailCode, cfsqltype="cf_sql_nvarchar", null=!len(item.mailCode) },
                isPrimary = { value=(item.isPrimary ? 1 : 0), cfsqltype="cf_sql_bit" }
            });
        }
        return rows;
    }

    private struct function _getPrimaryDisplayInfo(required numeric userID) {
        var result = { primaryFirstName = "", primaryLastName = "", primaryEmail = "" };
        var items = [];

        try {
            items = variables.aliasesService.getAliases(arguments.userID).data;
            for (var alias in items) {
                if (_toBoolean(alias.ISPRIMARY ?: 0)) {
                    result.primaryFirstName = trim(alias.FIRSTNAME ?: "");
                    result.primaryLastName  = trim(alias.LASTNAME  ?: "");
                    break;
                }
            }
            if (!len(result.primaryFirstName) AND !len(result.primaryLastName) AND arrayLen(items)) {
                result.primaryFirstName = trim(items[1].FIRSTNAME ?: "");
                result.primaryLastName  = trim(items[1].LASTNAME  ?: "");
            }
        } catch (any e) {}

        try {
            items = variables.emailsService.getEmails(arguments.userID).data;
            for (var email in items) {
                if (_toBoolean(email.ISPRIMARY ?: 0)) {
                    result.primaryEmail = trim(email.EMAILADDRESS ?: "");
                    break;
                }
            }
            if (!len(result.primaryEmail) AND arrayLen(items)) {
                result.primaryEmail = trim(items[1].EMAILADDRESS ?: "");
            }
        } catch (any e) {}

        return result;
    }

    private boolean function _isBooleanLike(any value) {
        return listFindNoCase("1,0,true,false,yes,no,y,n", trim(arguments.value ?: "")) GT 0;
    }

    private boolean function _toBoolean(any value) {
        if (isBoolean(arguments.value)) {
            return arguments.value;
        }

        return listFindNoCase("1,true,yes,y,on", trim(arguments.value ?: "")) GT 0;
    }

    private string function _booleanToCsv(any value) {
        return _toBoolean(arguments.value) ? "1" : "0";
    }

}