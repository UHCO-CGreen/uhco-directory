component output="false" singleton {

    public any function init() {
        variables.publicationProfilesDAO = createObject("component", "dao.publicationProfiles_DAO").init();
        variables.publicationsDAO = createObject("component", "dao.publications_DAO").init();
        variables.publicationSourceRecordsDAO = createObject("component", "dao.publicationSourceRecords_DAO").init();
        variables.publicationFetchRunsDAO = createObject("component", "dao.publicationFetchRuns_DAO").init();
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    public struct function getPublicationProfiles(required numeric userID) {
        return {
            success = true,
            data = variables.publicationProfilesDAO.getProfilesByUser(arguments.userID)
        };
    }

    public struct function getUserPublications(required numeric userID) {
        return {
            success = true,
            data = variables.publicationsDAO.getUserPublications(arguments.userID)
        };
    }

    public struct function getShowcasedPublications(required numeric userID) {
        return {
            success = true,
            data = variables.publicationsDAO.getUserPublications(arguments.userID, true)
        };
    }

    public struct function getFetchSummary(required numeric userID) {
        return {
            success = true,
            data = variables.publicationFetchRunsDAO.getRecentRunsByUser(arguments.userID)
        };
    }

    public struct function getPublicationConfig(required numeric userID) {
        return {
            success = true,
            data = {
                maxShowcasedPerUser = getMaxShowcasedPerUser(),
                isEligibleFaculty = isFacultyPublicationEligible(arguments.userID),
                allowedFlags = getAllowedFacultyFlags()
            }
        };
    }

    public numeric function getMaxShowcasedPerUser() {
        var configured = val(variables.appConfigService.getValue("publications.max_showcased_per_user", "10"));
        return configured GT 0 ? configured : 10;
    }

    public array function getAllowedFacultyFlags() {
        var configured = trim(variables.appConfigService.getValue("publications.faculty_flags", ""));
        return len(configured)
            ? listToArray(configured)
            : ["Faculty-Adjunct", "Faculty-Fulltime", "Professor-Emeritus", "Joint Faculty Appointment"];
    }

    public boolean function isFacultyPublicationEligible(required numeric userID) {
        var flagsService = createObject("component", "cfc.flags_service").init();
        var flagRows = flagsService.getUserFlags(arguments.userID).data;
        var allowedFlags = getAllowedFacultyFlags();
        var row = {};

        for (row in flagRows) {
            if (listFindNoCase(arrayToList(allowedFlags), trim(row.FLAGNAME ?: ""))) {
                return true;
            }
        }

        return false;
    }

}