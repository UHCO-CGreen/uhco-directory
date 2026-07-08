component output="false" singleton {

    public any function init() {
        variables.ProfileDAO = createObject("component", "dao.studentProfile_DAO").init();
        variables.usersService = createObject("component", "cfc.users_service").init();
        variables.hometownStateCodeMap = {
            "alabama" = "AL", "alaska" = "AK", "arizona" = "AZ", "arkansas" = "AR",
            "california" = "CA", "colorado" = "CO", "connecticut" = "CT", "delaware" = "DE",
            "district of columbia" = "DC", "florida" = "FL", "georgia" = "GA", "hawaii" = "HI",
            "idaho" = "ID", "illinois" = "IL", "indiana" = "IN", "iowa" = "IA", "kansas" = "KS",
            "kentucky" = "KY", "louisiana" = "LA", "maine" = "ME", "maryland" = "MD",
            "massachusetts" = "MA", "michigan" = "MI", "minnesota" = "MN", "mississippi" = "MS",
            "missouri" = "MO", "montana" = "MT", "nebraska" = "NE", "nevada" = "NV",
            "new hampshire" = "NH", "new jersey" = "NJ", "new mexico" = "NM", "new york" = "NY",
            "north carolina" = "NC", "north dakota" = "ND", "ohio" = "OH", "oklahoma" = "OK",
            "oregon" = "OR", "pennsylvania" = "PA", "rhode island" = "RI", "south carolina" = "SC",
            "south dakota" = "SD", "tennessee" = "TN", "texas" = "TX", "utah" = "UT",
            "vermont" = "VT", "virginia" = "VA", "washington" = "WA", "west virginia" = "WV",
            "wisconsin" = "WI", "wyoming" = "WY",
            "alberta" = "AB", "british columbia" = "BC", "manitoba" = "MB", "new brunswick" = "NB",
            "newfoundland" = "NL", "newfoundland and labrador" = "NL", "nova scotia" = "NS",
            "nunavut" = "NU", "ontario" = "ON", "prince edward island" = "PE", "quebec" = "QC",
            "saskatchewan" = "SK", "northwest territories" = "NT", "yukon" = "YT",
            "france" = "FR", "mexico" = "MX", "england" = "EN", "scotland" = "SC",
            "ireland" = "IE", "india" = "IN", "china" = "CN", "vietnam" = "VN"
        };
        return this;
    }

    public struct function getProfile( required numeric userID ) {
        return { success=true, data=variables.ProfileDAO.getProfile( userID ) };
    }

    public struct function getAwards( required numeric userID ) {
        return { success=true, data=variables.ProfileDAO.getAwards( userID ) };
    }

    public struct function getResidencies( required numeric userID ) {
        return { success=true, data=variables.ProfileDAO.getResidencies( userID ) };
    }

    public void function saveProfile(
        required numeric userID,
        required string  firstExternship,
        required string  secondExternship,
        required string  commencementAge,
        string dissertationThesis = ""
    ) {
        variables.ProfileDAO.saveProfile( userID, {
            FirstExternship  = trim( firstExternship ),
            SecondExternship = trim( secondExternship ),
            CommencementAge  = { value=(len(trim(commencementAge)) AND isNumeric(trim(commencementAge)) ? val(trim(commencementAge)) : ""), cfsqltype="cf_sql_integer", null=(!len(trim(commencementAge)) OR !isNumeric(trim(commencementAge))) },
            DissertationThesis = { value=trim(arguments.dissertationThesis), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.dissertationThesis)) }
        });
    }

    public void function saveImportedAcademicProfile(
        required numeric userID,
        string hometownCity = "",
        string hometownState = "",
        string firstExternship = "",
        string secondExternship = "",
        string dob = "",
        string gender = "",
        string commencementAge = ""
    ) {
        variables.ProfileDAO.saveProfile( arguments.userID, {
            FirstExternship = trim(arguments.firstExternship),
            SecondExternship = trim(arguments.secondExternship),
            CommencementAge = {
                value=(len(trim(arguments.commencementAge)) AND isNumeric(trim(arguments.commencementAge)) ? val(trim(arguments.commencementAge)) : ""),
                cfsqltype="cf_sql_integer",
                null=(!len(trim(arguments.commencementAge)) OR !isNumeric(trim(arguments.commencementAge)))
            },
            HometownCity = {
                value=trim(arguments.hometownCity),
                cfsqltype="cf_sql_nvarchar",
                null=!len(trim(arguments.hometownCity))
            },
            HometownState = {
                value=normalizeHometownState(arguments.hometownState),
                cfsqltype="cf_sql_nvarchar",
                null=!len(trim(arguments.hometownState))
            }
        } );

        variables.usersService.updateDemographics(
            userID = arguments.userID,
            dob = trim(arguments.dob),
            gender = trim(arguments.gender)
        );
    }

    public void function syncHometown( required numeric userID, string hometownCity = "", string hometownState = "" ) {
        variables.ProfileDAO.saveHometown(
            userID,
            trim(arguments.hometownCity),
            normalizeHometownState(arguments.hometownState)
        );
    }

    public struct function syncMissingHometownsFromAddresses() {
        var candidates = variables.ProfileDAO.getMissingHometownSyncCandidates();
        var updatedProfiles = 0;
        var insertedProfiles = 0;

        for ( var candidate in candidates ) {
            syncHometown(
                candidate.USERID,
                trim(candidate.CITY ?: ""),
                candidate.STATE ?: ""
            );

            if ( javacast("boolean", candidate.HASPROFILE ?: false) ) {
                updatedProfiles++;
            } else {
                insertedProfiles++;
            }
        }

        return {
            success = true,
            totalCandidates = arrayLen(candidates),
            updatedProfiles = updatedProfiles,
            insertedProfiles = insertedProfiles,
            totalSynced = updatedProfiles + insertedProfiles,
            message = arrayLen(candidates)
                ? "Synced missing hometown profile values from Hometown addresses."
                : "No missing hometown profile values needed syncing."
        };
    }

    private string function normalizeHometownState( string hometownState = "" ) {
        var rawValue = trim(arguments.hometownState);
        var normalizedKey = "";
        var letterOnlyValue = "";

        if ( !len(rawValue) ) {
            return "";
        }

        if ( len(rawValue) LTE 2 ) {
            return uCase(rawValue);
        }

        normalizedKey = lCase(trim(reReplace(rawValue, "[^A-Za-z ]", "", "all")));
        normalizedKey = reReplace(normalizedKey, "\s+", " ", "all");
        if ( structKeyExists(variables.hometownStateCodeMap, normalizedKey) ) {
            return variables.hometownStateCodeMap[normalizedKey];
        }

        letterOnlyValue = uCase(reReplace(rawValue, "[^A-Za-z]", "", "all"));
        return len(letterOnlyValue) GTE 2 ? left(letterOnlyValue, 2) : "";
    }

    public void function replaceAwards( required numeric userID, required array awards ) {
        variables.ProfileDAO.replaceAwards( userID, awards );
    }

    public void function replaceResidencies( required numeric userID, required array residencies ) {
        variables.ProfileDAO.replaceResidencies( userID, residencies );
    }

}
