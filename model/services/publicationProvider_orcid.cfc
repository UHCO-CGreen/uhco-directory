component output="false" singleton {

    public any function init() {
        variables.baseUrl = "https://pub.orcid.org/v3.0/";
        return this;
    }

    public struct function fetchForUser(required numeric userID, required struct profile) {
        var orcidID = trim(arguments.profile.PROFILEIDENTIFIER ?: "");
        var endpoint = "";
        var httpResp = {};
        var parsed = {};
        var candidates = [];
        var groupItem = {};
        var summaryItem = {};

        if (!len(orcidID)) {
            return failure(400, "ORCID iD is required before fetch.", ["missing ORCID iD"]);
        }

        if (!reFind("^\d{4}-\d{4}-\d{4}-[\dX]{4}$", orcidID)) {
            return failure(400, "ORCID iD format is invalid.", ["invalid ORCID iD format"]);
        }

        endpoint = variables.baseUrl & encodeForURL(orcidID) & "/works";

        cfhttp(url=endpoint, method="get", timeout="20", result="httpResp") {
            cfhttpparam(type="header", name="Accept", value="application/json");
        }

        if (left(httpResp.statusCode ?: "", 3) NEQ "200") {
            return failure(502, "ORCID request failed with status " & (httpResp.statusCode ?: "Unknown") & ".", []);
        }

        try {
            parsed = deserializeJSON(httpResp.fileContent ?: "{}");
        } catch (any e) {
            return failure(502, "ORCID returned unreadable JSON.", [e.message ?: "JSON parse failed"]);
        }

        if (!structKeyExists(parsed, "group") OR !isArray(parsed.group)) {
            return {
                success = true,
                message = "ORCID returned no works.",
                data = {
                    recordsFetched = 0,
                    candidates = []
                }
            };
        }

        for (groupItem in parsed.group) {
            if (structKeyExists(groupItem, "work-summary") AND isArray(groupItem["work-summary"])) {
                for (summaryItem in groupItem["work-summary"]) {
                    arrayAppend(candidates, normalizeCandidate(summaryItem, groupItem));
                }
            }
        }

        return {
            success = true,
            message = "ORCID works fetched.",
            data = {
                recordsFetched = arrayLen(candidates),
                candidates = candidates
            }
        };
    }

    private struct function normalizeCandidate(required struct summaryItem, struct groupItem = {}) {
        var externalIds = getExternalIDMap(arguments.summaryItem);
        var titleText = _safePath(arguments.summaryItem, "title.title.value");
        var journalTitle = _safePath(arguments.summaryItem, "journal-title.value");
        var publicationYear = val(_safePath(arguments.summaryItem, "publication-date.year.value"));
        var publicationMonth = val(_safePath(arguments.summaryItem, "publication-date.month.value"));
        var sourceURL = _safePath(arguments.summaryItem, "url.value");
        var putCode = trim(toString(arguments.summaryItem["put-code"] ?: ""));

        return {
            sourceRecordKey = len(putCode) ? putCode : hash(serializeJSON(arguments.summaryItem)),
            sourceTitle = titleText,
            sourceAuthorsText = "",
            sourcePublicationYear = publicationYear,
            sourcePublicationMonth = publicationMonth,
            sourceJournalOrSource = journalTitle,
            sourceDOI = trim(externalIds.doi ?: ""),
            sourcePMID = trim(externalIds.pmid ?: ""),
            sourcePMCID = trim(externalIds.pmcid ?: ""),
            sourceURL = sourceURL,
            matchConfidence = 0,
            matchStatus = "pending",
            title = titleText,
            authors = "",
            publicationYear = publicationYear,
            journalOrSource = journalTitle,
            doi = trim(externalIds.doi ?: ""),
            pmid = trim(externalIds.pmid ?: ""),
            pmcid = trim(externalIds.pmcid ?: ""),
            primaryURL = sourceURL,
            citationText = "",
            rawPayload = arguments.summaryItem
        };
    }

    private struct function getExternalIDMap(required struct summaryItem) {
        var result = {};
        var extContainer = arguments.summaryItem["external-ids"] ?: {};
        var extRows = [];
        var extRow = {};
        var extType = "";
        var extValue = "";

        if (isStruct(extContainer) AND structKeyExists(extContainer, "external-id") AND isArray(extContainer["external-id"])) {
            extRows = extContainer["external-id"];
        }

        for (extRow in extRows) {
            extType = lCase(trim(_safePath(extRow, "external-id-type")));
            extValue = trim(_safePath(extRow, "external-id-value"));
            if (len(extType) AND len(extValue)) {
                result[extType] = extValue;
            }
        }

        return result;
    }

    private string function _safePath(required any source, required string path) {
        var current = arguments.source;
        var token = "";

        for (token in listToArray(arguments.path, ".")) {
            if (isStruct(current) AND structKeyExists(current, token)) {
                current = current[token];
            } else {
                return "";
            }
        }

        return isSimpleValue(current) ? trim(toString(current ?: "")) : "";
    }

    private struct function failure(required numeric statusCode, required string message, array errors = []) {
        return {
            success = false,
            statusCode = arguments.statusCode,
            message = arguments.message,
            errors = arguments.errors,
            data = {}
        };
    }

}