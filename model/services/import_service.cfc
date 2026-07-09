component output="false" singleton {

    public any function init() {
        variables.importDAO   = createObject("component", "dao.import_DAO").init();
        variables.usersSvc    = createObject("component", "cfc.users_service").init();
        variables.flagsSvc    = createObject("component", "cfc.flags_service").init();
        variables.orgsSvc     = createObject("component", "cfc.organizations_service").init();
        variables.studentSvc  = createObject("component", "cfc.studentProfile_service").init();
        variables.bulkImportSvc = createObject("component", "cfc.bulkImport_service").init();
        return this;
    }

    /* ================================================================
       Template definitions
       ================================================================ */

    public array function getTemplates() {
        var templates = [
            {
                key         = "users",
                label       = "Users",
                description = "Create new user records. Required: FirstName, LastName. Optional: EmailPrimary, Title1, Room, Building, Prefix, Suffix, Degrees, Campus, Division, DivisionName, Department, DepartmentName, Office_Mailing_Address, Mailcode.",
                requiredCols = ["FirstName","LastName"],
                optionalCols = ["EmailPrimary","Title1","Room","Building","Prefix","Suffix","Degrees","Campus","Division","DivisionName","Department","DepartmentName","Office_Mailing_Address","Mailcode"],
                icon         = "bi-person-plus",
                workflow     = "direct"
            },
            {
                key         = "flags",
                label       = "Flag Assignments",
                description = "Assign flags to existing users. Required: UserID, FlagID. Duplicates are automatically skipped.",
                requiredCols = ["UserID","FlagID"],
                optionalCols = [],
                icon         = "bi-flag",
                workflow     = "direct"
            },
            {
                key         = "orgs",
                label       = "Organization Assignments",
                description = "Assign users to organizations. Required: UserID, OrgID. Optional: RoleTitle, RoleOrder.",
                requiredCols = ["UserID","OrgID"],
                optionalCols = ["RoleTitle","RoleOrder"],
                icon         = "bi-diagram-3",
                workflow     = "direct"
            },
            {
                key         = "student_academic",
                label       = "Student Academic",
                description = "Update student profile data. Required: UserID. Optional: HometownCity, HometownState, FirstExternship, SecondExternship, DOB (MM/DD/YYYY), Gender, CommencementAge.",
                requiredCols = ["UserID"],
                optionalCols = ["HometownCity","HometownState","FirstExternship","SecondExternship","DOB","Gender","CommencementAge"],
                icon         = "bi-mortarboard",
                workflow     = "direct"
            }
        ];

        for (var bulkTemplate in variables.bulkImportSvc.getTemplates()) {
            arrayAppend(templates, bulkTemplate);
        }

        return templates;
    }

    /**
     * Get a template definition by key.
     */
    public struct function getTemplate(required string key) {
        var templates = getTemplates();
        for (var t in templates) {
            if (t.key == arguments.key) return t;
        }
        throw(type="ImportService.InvalidTemplate", message="Unknown import template: #arguments.key#");
    }

    /* ================================================================
       CSV parsing
       ================================================================ */

    /**
     * Parse a CSV file into an array of structs keyed by header names.
     * Returns { headers=[], rows=[], rawRowCount=n }.
     */
    public struct function parseCSV(required string filePath) {
        var content = fileRead(arguments.filePath, "utf-8");
        // Normalize line breaks
        content = replace(content, chr(13) & chr(10), chr(10), "all");
        content = replace(content, chr(13), chr(10), "all");
        var lines = listToArray(content, chr(10));

        if (arrayLen(lines) < 2) {
            throw(type="ImportService.EmptyFile", message="CSV file must have a header row and at least one data row.");
        }

        var headers = parseCSVLine(lines[1]);
        // Trim BOM from first header if present
        if (len(headers[1]) && left(headers[1], 1) == chr(65279)) {
            headers[1] = mid(headers[1], 2, len(headers[1]) - 1);
        }

        var rows = [];
        for (var i = 2; i <= arrayLen(lines); i++) {
            var line = trim(lines[i]);
            if (!len(line)) continue;
            var vals = parseCSVLine(line);
            var row = {};
            for (var h = 1; h <= arrayLen(headers); h++) {
                row[trim(headers[h])] = (h <= arrayLen(vals)) ? trim(vals[h]) : "";
            }
            arrayAppend(rows, row);
        }

        return { headers = headers, rows = rows, rawRowCount = arrayLen(rows) };
    }

    /**
     * Parse a single CSV line respecting quoted fields.
     */
    private array function parseCSVLine(required string line) {
        var fields = [];
        var current = "";
        var inQuotes = false;
        var chars = arguments.line.toCharArray();
        var i = 1;
        var length = arrayLen(chars);

        while (i <= length) {
            var c = chars[i];
            if (inQuotes) {
                if (c == '"') {
                    // Escaped quote ""
                    if (i < length && chars[i + 1] == '"') {
                        current &= '"';
                        i += 2;
                        continue;
                    }
                    inQuotes = false;
                } else {
                    current &= c;
                }
            } else {
                if (c == '"') {
                    inQuotes = true;
                } else if (c == ',') {
                    arrayAppend(fields, current);
                    current = "";
                } else {
                    current &= c;
                }
            }
            i++;
        }
        arrayAppend(fields, current);
        return fields;
    }

    /* ================================================================
       Validation
       ================================================================ */

    /**
     * Validate parsed rows against a template.
     * Returns { valid=bool, errors=[], missingHeaders=[], warnings=[] }.
     */
    public struct function validateImport(required string templateKey, required array headers, required array rows) {
        if (variables.bulkImportSvc.supportsTemplate(arguments.templateKey)) {
            return variables.bulkImportSvc.validateImport(argumentCollection = arguments);
        }

        var tpl = getTemplate(arguments.templateKey);
        var result = { valid = true, errors = [], missingHeaders = [], warnings = [] };

        // Normalize header names to lowercase for comparison
        var lcHeaders = [];
        for (var h in arguments.headers) arrayAppend(lcHeaders, lCase(trim(h)));

        // Check required columns
        for (var req in tpl.requiredCols) {
            if (!arrayFindNoCase(lcHeaders, lCase(req))) {
                arrayAppend(result.missingHeaders, req);
                result.valid = false;
            }
        }

        if (!result.valid) return result;

        // Per-row validation (first 100 errors max)
        for (var r = 1; r <= arrayLen(arguments.rows); r++) {
            if (arrayLen(result.errors) >= 100) {
                arrayAppend(result.warnings, "Validation stopped after 100 errors.");
                break;
            }
            var row = arguments.rows[r];
            var rowErrors = validateRow(arguments.templateKey, row, r);
            if (arrayLen(rowErrors)) {
                result.valid = false;
                for (var e in rowErrors) arrayAppend(result.errors, e);
            }
        }

        return result;
    }

    /**
     * Validate a single row. Returns array of error strings.
     */
    private array function validateRow(required string templateKey, required struct row, required numeric rowNum) {
        var errors = [];

        switch (arguments.templateKey) {
            case "users":
                if (!len(trim(row.FirstName ?: "")))
                    arrayAppend(errors, "Row #arguments.rowNum#: FirstName is required.");
                if (!len(trim(row.LastName ?: "")))
                    arrayAppend(errors, "Row #arguments.rowNum#: LastName is required.");
                if (len(trim(row.EmailPrimary ?: "")) && !isValid("email", trim(row.EmailPrimary)))
                    arrayAppend(errors, "Row #arguments.rowNum#: Invalid email '#row.EmailPrimary#'.");
                break;

            case "flags":
                if (!isNumeric(row.UserID ?: ""))
                    arrayAppend(errors, "Row #arguments.rowNum#: UserID must be numeric.");
                if (!isNumeric(row.FlagID ?: ""))
                    arrayAppend(errors, "Row #arguments.rowNum#: FlagID must be numeric.");
                break;

            case "orgs":
                if (!isNumeric(row.UserID ?: ""))
                    arrayAppend(errors, "Row #arguments.rowNum#: UserID must be numeric.");
                if (!isNumeric(row.OrgID ?: ""))
                    arrayAppend(errors, "Row #arguments.rowNum#: OrgID must be numeric.");
                break;

            case "student_academic":
                if (!isNumeric(row.UserID ?: ""))
                    arrayAppend(errors, "Row #arguments.rowNum#: UserID must be numeric.");
                if (len(trim(row.DOB ?: "")) && !isValid("date", trim(row.DOB)))
                    arrayAppend(errors, "Row #arguments.rowNum#: DOB must be a valid date.");
                if (len(trim(row.CommencementAge ?: "")) && !isNumeric(trim(row.CommencementAge)))
                    arrayAppend(errors, "Row #arguments.rowNum#: CommencementAge must be numeric.");
                break;
        }

        return errors;
    }

    /* ================================================================
       Import execution
       ================================================================ */

    /**
     * Execute an import. Returns the run_id.
     */
    public numeric function executeImport(
        required string templateKey,
        required array rows,
        required string fileName,
        required string startedBy
    ) {
        if (variables.bulkImportSvc.supportsTemplate(arguments.templateKey)) {
            return variables.bulkImportSvc.executeImport(argumentCollection = arguments);
        }

        var runID = variables.importDAO.createRun(
            templateKey = arguments.templateKey,
            fileName    = arguments.fileName,
            totalRows   = arrayLen(arguments.rows),
            startedBy   = arguments.startedBy
        );

        var successCount = 0;
        var skipCount    = 0;
        var errorCount   = 0;
        var runStatus    = "completed";

        for (var r = 1; r <= arrayLen(arguments.rows); r++) {
            var row = arguments.rows[r];
            var rowJSON = serializeJSON(row);
            try {
                var result = processRow(arguments.templateKey, row);
                if (result.status == "success") {
                    successCount++;
                } else if (result.status == "skipped") {
                    skipCount++;
                } else {
                    errorCount++;
                }
                variables.importDAO.addDetail(
                    runID     = runID,
                    rowNumber = r,
                    status    = result.status,
                    message   = result.message,
                    rowData   = rowJSON
                );
            } catch (any e) {
                errorCount++;
                variables.importDAO.addDetail(
                    runID     = runID,
                    rowNumber = r,
                    status    = "error",
                    message   = e.message,
                    rowData   = rowJSON
                );
            }
        }

        variables.importDAO.completeRun(
            runID        = runID,
            successCount = successCount,
            skipCount    = skipCount,
            errorCount   = errorCount,
            status       = runStatus
        );

        return runID;
    }

    /**
     * Process a single row according to the template.
     * Returns { status, message }.
     */
    private struct function processRow(required string templateKey, required struct row) {
        switch (arguments.templateKey) {

            case "users":
                var data = {
                    FirstName               = trim(row.FirstName ?: ""),
                    LastName                = trim(row.LastName ?: ""),
                    EmailPrimary            = trim(row.EmailPrimary ?: ""),
                    Title1                  = trim(row.Title1 ?: ""),
                    Room                    = trim(row.Room ?: ""),
                    Building                = trim(row.Building ?: ""),
                    Prefix                  = trim(row.Prefix ?: ""),
                    Suffix                  = trim(row.Suffix ?: ""),
                    Degrees                 = trim(row.Degrees ?: ""),
                    Campus                  = trim(row.Campus ?: ""),
                    Division                = trim(row.Division ?: ""),
                    DivisionName            = trim(row.DivisionName ?: ""),
                    Department              = trim(row.Department ?: ""),
                    DepartmentName          = trim(row.DepartmentName ?: ""),
                    Office_Mailing_Address  = trim(row.Office_Mailing_Address ?: ""),
                    Mailcode                = trim(row.Mailcode ?: "")
                };
                var res = variables.usersSvc.createUser(data);
                if (res.success)
                    return { status = "success", message = "Created user ID ##" & res.userID };
                return { status = "error", message = res.message };

            case "flags":
                var fRes = variables.flagsSvc.addFlag(
                    userID = val(row.UserID),
                    flagID = val(row.FlagID)
                );
                if (fRes.success)
                    return { status = "success", message = fRes.message };
                // "already assigned" → skip
                if (findNoCase("already", fRes.message))
                    return { status = "skipped", message = fRes.message };
                return { status = "error", message = fRes.message };

            case "orgs":
                var oRes = variables.orgsSvc.assignOrg(
                    userID    = val(row.UserID),
                    orgID     = val(row.OrgID),
                    roleTitle = trim(row.RoleTitle ?: ""),
                    roleOrder = val(row.RoleOrder ?: 0)
                );
                if (oRes.success)
                    return { status = "success", message = oRes.message };
                if (findNoCase("already", oRes.message))
                    return { status = "skipped", message = oRes.message };
                return { status = "error", message = oRes.message };

            case "student_academic":
                variables.studentSvc.saveImportedAcademicProfile(
                    userID          = val(row.UserID),
                    hometownCity    = trim(row.HometownCity ?: ""),
                    hometownState   = trim(row.HometownState ?: ""),
                    firstExternship = trim(row.FirstExternship ?: ""),
                    secondExternship = trim(row.SecondExternship ?: ""),
                    dob             = trim(row.DOB ?: ""),
                    gender          = trim(row.Gender ?: ""),
                    commencementAge = trim(row.CommencementAge ?: "")
                );
                return { status = "success", message = "Profile saved for user ##" & val(row.UserID) };

            default:
                return { status = "error", message = "Unknown template." };
        }
    }

    /* ================================================================
       History / audit
       ================================================================ */

    public array function getRecentRuns(string templateKey = "", numeric maxRows = 25) {
        return variables.importDAO.getRecentRuns(argumentCollection = arguments);
    }

    public struct function getRunSummary(required numeric runID) {
        var runs = variables.importDAO.getRun(arguments.runID);
        if (!arrayLen(runs)) throw(type="ImportService.NotFound", message="Import run not found.");
        return runs[1];
    }

    public array function getRunDetails(required numeric runID) {
        return variables.importDAO.getRunDetails(arguments.runID);
    }
}
