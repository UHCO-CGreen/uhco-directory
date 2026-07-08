component output="false" singleton {

    variables.largeSubsetThreshold = 1500;

    public any function init() {
        variables.AcademicDAO = createObject("component", "dao.academic_DAO").init();
        variables.DegreesDAO  = createObject("component", "dao.degrees_DAO").init();
        return this;
    }


    public struct function getAcademicInfo( required numeric userID ) {
        return {
            success=true,
            data=variables.AcademicDAO.getAcademicInfo( userID )
        };
    }

    /**
     * Returns a map keyed by UserID string with legacy grad year fields plus
     * EFFECTIVEGRADYEAR (derived from UserDegrees UHCO rows first, then legacy fallback).
     */
    public struct function getAllAcademicInfoMap() {
        return getAllAcademicMaps().academicInfoMap;
    }

    /**
     * Returns a map keyed by UserID string for grad-year filtering/display.
     * Primary source is UHCO UserDegrees; CURRENTGRADYEAR is fallback when no usable degree years exist.
     */
    public struct function getAllGradYearMap() {
        return getAllAcademicMaps().gradYearMap;
    }

    public string function buildGradYearDisplay(struct gradYearData={}) {
        var years = isArray(arguments.gradYearData.YEARS ?: "") ? arguments.gradYearData.YEARS : [];
        var yearProgramMap = isStruct(arguments.gradYearData.YEARPROGRAMMAP ?: {}) ? arguments.gradYearData.YEARPROGRAMMAP : {};
        var pairDisplay = [];
        var idx = 0;
        var pairYear = 0;
        var programText = "";
        var programs = [];
        var programKey = "";

        if (arrayLen(years) LTE 0) {
            return "";
        }

        for (idx = 1; idx LTE arrayLen(years); idx++) {
            pairYear = val(years[idx]);
            programText = "";
            programs = [];

            if (structKeyExists(yearProgramMap, toString(pairYear))) {
                for (programKey in yearProgramMap[toString(pairYear)]) {
                    arrayAppend(programs, programKey);
                }

                if (arrayLen(programs) GT 1) {
                    arraySort(programs, "textnocase", "asc");
                }

                programText = arrayToList(programs, "/");
            }

            if (len(programText)) {
                arrayAppend(pairDisplay, toString(pairYear) & " : " & programText);
            } else {
                arrayAppend(pairDisplay, toString(pairYear));
            }
        }

        return arrayLen(pairDisplay) GT 1
            ? "(" & arrayToList(pairDisplay, " | ") & ")"
            : (arrayLen(pairDisplay) EQ 1 ? pairDisplay[1] : "");
    }

    public struct function getAllAcademicMaps( array userIDs = [], boolean includeProgramMap = true ) {
        var normalizedUserIDs = _normalizeUserIDs(arguments.userIDs);
        var requestedIDLookup = _toIDLookup(normalizedUserIDs);
        var hasUserFilter = arrayLen(normalizedUserIDs) GT 0;
        var useFullLoadForSubset = hasUserFilter AND arrayLen(normalizedUserIDs) GTE variables.largeSubsetThreshold;
        var cacheKey = "academicServiceAllMaps:" & (hasUserFilter ? arrayToList(normalizedUserIDs, ",") : "all") & ":programs=" & (arguments.includeProgramMap ? "1" : "0");

        if ( structKeyExists(request, cacheKey) AND isStruct(request[cacheKey] ?: {}) ) {
            return request[cacheKey];
        }

        var rows = (hasUserFilter AND !useFullLoadForSubset)
            ? variables.AcademicDAO.getAcademicInfoForUsers(normalizedUserIDs)
            : variables.AcademicDAO.getAllAcademicInfo();
        var academicInfoMap = {};
        var gradYearMap = {};

        for ( var row in rows ) {
            var uid = toString( row.USERID );

            if ( hasUserFilter AND useFullLoadForSubset AND !structKeyExists(requestedIDLookup, uid) ) {
                continue;
            }

            academicInfoMap[ uid ] = {
                CURRENTGRADYEAR  = row.CURRENTGRADYEAR,
                ORIGINALGRADYEAR = row.ORIGINALGRADYEAR,
                EFFECTIVEGRADYEAR = val(row.CURRENTGRADYEAR ?: 0)
            };
            gradYearMap[ uid ] = {
                YEARS = [],
                YEARLOOKUP = {},
                LEGACYYEAR = val(row.CURRENTGRADYEAR ?: 0),
                YEARPROGRAMMAP = arguments.includeProgramMap ? {} : {}
            };
        }

        var degreeRows = (hasUserFilter AND !useFullLoadForSubset)
            ? variables.DegreesDAO.getUHCODegreesForUsers(normalizedUserIDs)
            : variables.DegreesDAO.getAllUHCODegrees();
        var enrolledByUser = {};
        var graduatedByUser = {};

        for ( var d in degreeRows ) {
            var uid = toString( d.USERID );
            if ( hasUserFilter AND !structKeyExists(requestedIDLookup, uid) ) {
                continue;
            }

            if ( !structKeyExists(gradYearMap, uid) ) {
                gradYearMap[ uid ] = {
                    YEARS = [],
                    YEARLOOKUP = {},
                    LEGACYYEAR = 0,
                    YEARPROGRAMMAP = arguments.includeProgramMap ? {} : {}
                };
            }

            var expectedYear = val(d.EXPECTEDGRADYEAR ?: 0);
            var graduationYear = val(d.GRADUATIONYEAR ?: 0);
            var programLabel = uCase(trim(d.PROGRAM ?: ""));

            if ( isBoolean(d.ISENROLLED ?: false) AND d.ISENROLLED AND expectedYear GT 0 ) {
                enrolledByUser[ uid ] = expectedYear;
            } else if ( !structKeyExists(enrolledByUser, uid) AND graduationYear GT val(graduatedByUser[ uid ] ?: 0) ) {
                graduatedByUser[ uid ] = graduationYear;
            }

            if ( expectedYear GT 0 ) {
                if ( !structKeyExists(gradYearMap[uid].YEARLOOKUP, toString(expectedYear)) ) {
                    gradYearMap[uid].YEARLOOKUP[ toString(expectedYear) ] = true;
                    arrayAppend(gradYearMap[uid].YEARS, expectedYear);
                }
                if ( arguments.includeProgramMap AND len(programLabel) ) {
                    if ( !structKeyExists(gradYearMap[uid].YEARPROGRAMMAP, toString(expectedYear)) ) {
                        gradYearMap[uid].YEARPROGRAMMAP[toString(expectedYear)] = {};
                    }
                    gradYearMap[uid].YEARPROGRAMMAP[toString(expectedYear)][programLabel] = true;
                }
            }

            if ( graduationYear GT 0 ) {
                if ( !structKeyExists(gradYearMap[uid].YEARLOOKUP, toString(graduationYear)) ) {
                    gradYearMap[uid].YEARLOOKUP[ toString(graduationYear) ] = true;
                    arrayAppend(gradYearMap[uid].YEARS, graduationYear);
                }
                if ( arguments.includeProgramMap AND len(programLabel) ) {
                    if ( !structKeyExists(gradYearMap[uid].YEARPROGRAMMAP, toString(graduationYear)) ) {
                        gradYearMap[uid].YEARPROGRAMMAP[toString(graduationYear)] = {};
                    }
                    gradYearMap[uid].YEARPROGRAMMAP[toString(graduationYear)][programLabel] = true;
                }
            }
        }

        for ( var uid in enrolledByUser ) {
            if ( structKeyExists(academicInfoMap, uid) ) {
                academicInfoMap[ uid ].EFFECTIVEGRADYEAR = enrolledByUser[ uid ];
            } else {
                academicInfoMap[ uid ] = { CURRENTGRADYEAR="", ORIGINALGRADYEAR="", EFFECTIVEGRADYEAR=enrolledByUser[ uid ] };
            }
        }

        for ( var uid in graduatedByUser ) {
            if ( structKeyExists(academicInfoMap, uid) AND academicInfoMap[uid].EFFECTIVEGRADYEAR EQ val(academicInfoMap[uid].CURRENTGRADYEAR ?: 0) ) {
                academicInfoMap[ uid ].EFFECTIVEGRADYEAR = graduatedByUser[ uid ];
            }
        }

        for ( var uid in gradYearMap ) {
            if ( !arrayLen(gradYearMap[uid].YEARS) AND val(gradYearMap[uid].LEGACYYEAR) GT 0 ) {
                gradYearMap[uid].YEARLOOKUP[ toString(val(gradYearMap[uid].LEGACYYEAR)) ] = true;
                arrayAppend(gradYearMap[uid].YEARS, val(gradYearMap[uid].LEGACYYEAR));
            }

            if ( arrayLen(gradYearMap[uid].YEARS) ) {
                arraySort(gradYearMap[uid].YEARS, "numeric", "asc");
            }
        }

        request[cacheKey] = {
            academicInfoMap = academicInfoMap,
            gradYearMap = gradYearMap
        };

        return request[cacheKey];
    }

    public struct function updateAcademicInfo( required numeric userID, required struct data ) {

        // Validation: grad year must be realistic
        if ( data.OriginalGradYear lt 1900 OR data.OriginalGradYear gt year( now() ) + 1 ) {
            return { success=false, message="Invalid OriginalGradYear" };
        }

        variables.AcademicDAO.updateAcademicInfo( userID, data );

        return { success=true, message="Academic info updated." };
    }

    public struct function saveAcademicInfo(
        required numeric userID,
        required string  currentGradYear,
        required string  originalGradYear
    ) {
        var currYear = val( trim( arguments.currentGradYear  ) );
        var origYear = val( trim( arguments.originalGradYear ) );

        // Server-side guard: origYear requires currYear
        if ( origYear GT 0 AND currYear EQ 0 ) {
            return { success=false, message="Original Grad Year requires a Current Grad Year." };
        }

        var existing = variables.AcademicDAO.getAcademicInfo( arguments.userID );

        var dataParams = {
            CurrentGradYear  = { value=currYear, cfsqltype="cf_sql_integer", null=(currYear  EQ 0) },
            OriginalGradYear = { value=origYear, cfsqltype="cf_sql_integer", null=(origYear EQ 0) }
        };

        if ( structIsEmpty( existing ) ) {
            if ( currYear EQ 0 AND origYear EQ 0 ) {
                return { success=true };
            }
            dataParams.UserID = { value=arguments.userID, cfsqltype="cf_sql_integer" };
            variables.AcademicDAO.createAcademicInfo( dataParams );
        } else {
            variables.AcademicDAO.updateAcademicInfo( arguments.userID, dataParams );
        }

        return { success=true, message="Academic info saved." };
    }

    private array function _normalizeUserIDs( required array userIDs ) {
        var normalized = [];
        var seen = {};
        var rawUserID = "";
        var numericUserID = 0;
        var userKey = "";

        for ( rawUserID in arguments.userIDs ) {
            if ( isNumeric(rawUserID) ) {
                numericUserID = val(rawUserID);
                userKey = toString(numericUserID);

                if ( numericUserID GT 0 AND !structKeyExists(seen, userKey) ) {
                    seen[userKey] = true;
                    arrayAppend(normalized, numericUserID);
                }
            }
        }

        if ( arrayLen(normalized) GT 1 ) {
            arraySort(normalized, "numeric", "asc");
        }

        return normalized;
    }

    private struct function _toIDLookup( required array userIDs ) {
        var lookup = {};
        var userID = 0;

        for ( userID in arguments.userIDs ) {
            lookup[toString(val(userID))] = true;
        }

        return lookup;
    }

}