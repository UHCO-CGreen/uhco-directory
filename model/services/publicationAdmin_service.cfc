component output="false" singleton {

    public any function init() {
        variables.publicationsService = createObject("component", "cfc.publications_service").init();
        variables.publicationProfilesDAO = createObject("component", "dao.publicationProfiles_DAO").init();
        variables.publicationsDAO = createObject("component", "dao.publications_DAO").init();
        return this;
    }

    public struct function saveProfiles(required numeric userID, required struct formData) {
        if (!variables.publicationsService.isFacultyPublicationEligible(arguments.userID)) {
            return failure("Publications are only available for eligible faculty users.");
        }

        if (len(trim(arguments.formData.orcid_identifier ?: "")) AND !reFind("^\d{4}-\d{4}-\d{4}-[\dX]{4}$", trim(arguments.formData.orcid_identifier ?: ""))) {
            return failure("ORCID iD must use the format 0000-0000-0000-0000.");
        }

        variables.publicationProfilesDAO.upsertProfile(
            userID = arguments.userID,
            serviceCode = "orcid",
            profileIdentifier = trim(arguments.formData.orcid_identifier ?: ""),
            profileURL = _normalizeOrcidUrl(
                trim(arguments.formData.orcid_identifier ?: ""),
                trim(arguments.formData.orcid_url ?: "")
            ),
            searchQuery = "",
            isEnabled = _toBoolean(arguments.formData.orcid_enabled ?: "1")
        );

        if (
            structKeyExists(arguments.formData, "pubmed_query") OR
            structKeyExists(arguments.formData, "pubmed_url") OR
            structKeyExists(arguments.formData, "pubmed_enabled")
        ) {
            variables.publicationProfilesDAO.upsertProfile(
                userID = arguments.userID,
                serviceCode = "pubmed",
                profileIdentifier = "",
                profileURL = trim(arguments.formData.pubmed_url ?: ""),
                searchQuery = trim(arguments.formData.pubmed_query ?: ""),
                isEnabled = _toBoolean(arguments.formData.pubmed_enabled ?: "1")
            );
        }

        try {
            _saveShowcasedSelection(arguments.userID, arguments.formData);
        } catch (any e) {
            return failure(e.message ?: "Showcased publication selection could not be saved.");
        }

        return {
            success = true,
            message = "Publications saved.",
            data = {
                maxShowcasedPerUser = variables.publicationsService.getMaxShowcasedPerUser()
            }
        };
    }

    private void function _saveShowcasedSelection(required numeric userID, required struct formData) {
        var selectedIDs = [];
        var rawIds = trim(arguments.formData.showcased_publication_ids ?: "");
        var orderMap = {};
        var rawOrderMap = trim(arguments.formData.publication_display_order_json ?: "");
        var item = "";

        if (len(rawIds)) {
            for (item in listToArray(rawIds)) {
                if (isNumeric(trim(item))) {
                    arrayAppend(selectedIDs, val(trim(item)));
                }
            }
        }

        if (arrayLen(selectedIDs) GT variables.publicationsService.getMaxShowcasedPerUser()) {
            throw(message="Too many showcased publications selected.");
        }

        if (len(rawOrderMap) AND isJSON(rawOrderMap)) {
            orderMap = deserializeJSON(rawOrderMap);
        }

        variables.publicationsDAO.replaceShowcasedSelection(arguments.userID, selectedIDs);
        if (isStruct(orderMap) AND NOT structIsEmpty(orderMap)) {
            variables.publicationsDAO.updateDisplayOrder(arguments.userID, orderMap);
        }
    }

    private boolean function _toBoolean(any value) {
        var normalized = lCase(trim(toString(arguments.value ?: "")));
        return listFindNoCase("1,true,yes,on", normalized) GT 0;
    }

    private string function _normalizeOrcidUrl(string orcidIdentifier = "", string providedUrl = "") {
        var identifier = trim(arguments.orcidIdentifier ?: "");
        if (len(identifier)) {
            return "https://orcid.org/" & identifier;
        }
        return "https://orcid.org/";
    }

    private struct function failure(required string message) {
        return {
            success = false,
            statusCode = 400,
            message = arguments.message,
            errors = [arguments.message]
        };
    }

}