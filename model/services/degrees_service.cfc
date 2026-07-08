component output="false" singleton {

    public any function init() {
        variables.DegreesDAO  = createObject("component", "dao.degrees_DAO").init();
        variables.AcademicDAO = createObject("component", "dao.academic_DAO").init();
        variables.combinedDegreeWhitelist = {};
        return this;
    }

    public struct function getDegrees( required numeric userID ) {
        return { success=true, data=variables.DegreesDAO.getDegrees( userID ) };
    }

    public void function replaceDegrees( required numeric userID, required array degrees ) {
        variables.DegreesDAO.replaceDegrees( userID, degrees );
        // Auto-update the composite Degrees field on the Users table
        var compositeStr = buildDegreesString( userID );
        var usersDAO = createObject("component", "dao.users_DAO").init();
        usersDAO.updateDegreesField( userID, compositeStr );
    }

    /**
     * Build the comma-separated Degrees string from the UserDegrees table.
     * Only whitelist-approved degrees are included. UHCO degrees are excluded while
     * a user is currently enrolled.
     */
    public string function buildDegreesString( required numeric userID ) {
        var rows  = variables.DegreesDAO.getDegrees( userID );
        var names = [];
        var seenLabels = {};
        var label = "";
        var labelKey = "";

        for ( var r in rows ) {
            label = resolveCombinedDegreeLabel(r);
            if ( !len(label) ) {
                continue;
            }
            labelKey = normalizeCombinedDegreeKey(label);
            if ( structKeyExists(seenLabels, labelKey) ) {
                continue;
            }
            seenLabels[labelKey] = true;
            arrayAppend( names, label );
        }

        return arrayToList( names, ", " );
    }

    private string function resolveCombinedDegreeLabel( required struct degreeRow ) {
        var degreeName = trim(arguments.degreeRow.DEGREENAME ?: "");
        var whitelist = getCombinedDegreeWhitelist();
        var whitelistKey = "";

        if ( !len(degreeName) ) {
            return "";
        }

        if ( isDegreeCurrentlyEnrolledUHCO(arguments.degreeRow) ) {
            return "";
        }

        whitelistKey = normalizeCombinedDegreeKey(degreeName);
        if ( !structKeyExists(whitelist, whitelistKey) ) {
            return "";
        }

        return whitelist[whitelistKey];
    }

    private boolean function isDegreeCurrentlyEnrolledUHCO( required struct degreeRow ) {
        return isTruthy(arguments.degreeRow.ISUHCO ?: "") AND isTruthy(arguments.degreeRow.ISENROLLED ?: "");
    }

    private struct function getCombinedDegreeWhitelist() {
        var whitelistPath = "";
        var rawJson = "";
        var parsed = {};
        var entries = [];
        var entry = {};
        var alias = "";
        var displayValue = "";
        var normalizedKey = "";

        if ( structCount(variables.combinedDegreeWhitelist) ) {
            return variables.combinedDegreeWhitelist;
        }

        whitelistPath = expandPath("/model/includes/degree_composite_whitelist.json");
        if ( !fileExists(whitelistPath) ) {
            return variables.combinedDegreeWhitelist;
        }

        rawJson = trim(fileRead(whitelistPath, "utf-8"));
        if ( !len(rawJson) ) {
            return variables.combinedDegreeWhitelist;
        }

        parsed = deserializeJSON(rawJson);
        entries = (isStruct(parsed) AND structKeyExists(parsed, "degrees") AND isArray(parsed.degrees)) ? parsed.degrees : [];

        for ( entry in entries ) {
            displayValue = trim(entry.display ?: "");
            if ( !len(displayValue) ) {
                continue;
            }

            normalizedKey = normalizeCombinedDegreeKey(displayValue);
            if ( len(normalizedKey) ) {
                variables.combinedDegreeWhitelist[normalizedKey] = displayValue;
            }

            if ( structKeyExists(entry, "aliases") AND isArray(entry.aliases) ) {
                for ( alias in entry.aliases ) {
                    normalizedKey = normalizeCombinedDegreeKey(alias);
                    if ( len(normalizedKey) ) {
                        variables.combinedDegreeWhitelist[normalizedKey] = displayValue;
                    }
                }
            }
        }

        return variables.combinedDegreeWhitelist;
    }

    private string function normalizeCombinedDegreeKey( required string value ) {
        return uCase(reReplace(trim(arguments.value ?: ""), "[^A-Za-z0-9]+", "", "all"));
    }

    private boolean function isTruthy( any value = "" ) {
        if ( isBoolean(arguments.value) ) {
            return arguments.value;
        }

        if ( isNumeric(arguments.value ?: "") ) {
            return val(arguments.value) EQ 1;
        }

        return listFindNoCase("true,yes,y,on", trim(arguments.value ?: "")) GT 0;
    }

    /**
     * Return the active enrolled UHCO degree row for a user, or an empty struct if none.
     * "Active" means IsUHCO=1 AND IsEnrolled=1. Excludes Residency rows.
     */
    public struct function getActiveUHCODegree( required numeric userID ) {
        var rows = variables.DegreesDAO.getDegrees( userID );
        for ( var r in rows ) {
            if ( isBoolean(r.ISUHCO ?: false)    AND r.ISUHCO
              && isBoolean(r.ISENROLLED ?: false) AND r.ISENROLLED
              && uCase(trim(r.PROGRAM ?: "")) NEQ "RESIDENCY" ) {
                return r;
            }
        }
        return {};
    }

    /**
     * Batch-build a map of userID (string) -> "DEGREE - YEAR" summary string
     * for all UHCO degrees across the given list of users.
     * For enrolled degrees the ExpectedGradYear is used; for graduated degrees
     * GraduationYear is used. Returns a struct keyed by string(UserID).
     */
    public struct function buildUHCODegreesSummaryMap(required array userIDs) {
        var summaryMap = {};
        var uhcoDegrees = [];
        var userKey = "";
        var degreeLabel = "";
        var yearValue = "";
        var gradYearStr = "";
        var entry = "";

        if (!arrayLen(arguments.userIDs)) {
            return summaryMap;
        }

        // getUHCODegreesForUsers batches in groups of 1000, avoiding the SQL Server
        // 2100-parameter limit that getDegreesMap would hit with large alumni cohorts.
        uhcoDegrees = variables.DegreesDAO.getUHCODegreesForUsers(arguments.userIDs);

        for (var row in uhcoDegrees) {
            userKey = toString(val(row.USERID ?: 0));
            if (!len(userKey) OR val(userKey) EQ 0) {
                continue;
            }
            degreeLabel = trim(row.PROGRAM ?: "");
            if (!len(degreeLabel)) {
                continue;
            }
            yearValue = "";
            if (isTruthy(row.ISENROLLED ?: "")) {
                if (isNumeric(row.EXPECTEDGRADYEAR ?: "") AND val(row.EXPECTEDGRADYEAR) GT 0) {
                    yearValue = toString(val(row.EXPECTEDGRADYEAR));
                }
            } else {
                gradYearStr = trim(toString(row.GRADUATIONYEAR ?: ""));
                if (len(gradYearStr) AND isNumeric(gradYearStr) AND val(gradYearStr) GT 0) {
                    yearValue = gradYearStr;
                }
            }
            entry = len(yearValue) ? degreeLabel & " - " & yearValue : degreeLabel;
            if (structKeyExists(summaryMap, userKey)) {
                summaryMap[userKey] &= ", " & entry;
            } else {
                summaryMap[userKey] = entry;
            }
        }

        return summaryMap;
    }

    /**
     * Return the effective graduation year for a user.
     * Priority:
     *   1. ExpectedGradYear of the active enrolled UHCO degree
     *   2. GraduationYear of the most recent (highest) UHCO degree
     *   3. UserAcademicInfo.CurrentGradYear (legacy fallback)
     *   Returns 0 if none found.
     */
    public numeric function getEffectiveGradYear( required numeric userID ) {
        var rows = variables.DegreesDAO.getDegrees( userID );

        // Priority 1: active enrolled UHCO degree expected year
        for ( var r in rows ) {
            if ( isBoolean(r.ISUHCO ?: false)    AND r.ISUHCO
              && isBoolean(r.ISENROLLED ?: false) AND r.ISENROLLED
              && val(r.EXPECTEDGRADYEAR ?: 0) GT 0 ) {
                return val(r.EXPECTEDGRADYEAR);
            }
        }

        // Priority 2: most recent UHCO graduation year
        var bestYear = 0;
        for ( var r in rows ) {
            if ( isBoolean(r.ISUHCO ?: false) AND r.ISUHCO ) {
                var yr = val(r.GRADUATIONYEAR ?: 0);
                if ( yr GT bestYear ) bestYear = yr;
            }
        }
        if ( bestYear GT 0 ) return bestYear;

        // Priority 3: legacy UserAcademicInfo fallback
        var academic = variables.AcademicDAO.getAcademicInfo( arguments.userID );
        return val( academic.CURRENTGRADYEAR ?: 0 );
    }
}
