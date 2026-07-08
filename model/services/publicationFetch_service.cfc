component output="false" singleton {

    public any function init() {
        variables.publicationFetchRunsDAO = createObject("component", "dao.publicationFetchRuns_DAO").init();
        variables.publicationProfilesDAO = createObject("component", "dao.publicationProfiles_DAO").init();
        variables.publicationSourceRecordsDAO = createObject("component", "dao.publicationSourceRecords_DAO").init();
        variables.publicationsDAO = createObject("component", "dao.publications_DAO").init();
        variables.publicationMergeService = createObject("component", "cfc.publicationMerge_service").init();
        variables.orcidProvider = createObject("component", "cfc.publicationProvider_orcid").init();
        variables.pubmedProvider = createObject("component", "cfc.publicationProvider_pubmed").init();
        return this;
    }

    public struct function fetchForUser(required numeric userID, required string serviceCode, boolean limitRecentYears = true, numeric triggeredByAdminUserID = 0) {
        var normalizedServiceCode = lCase(trim(arguments.serviceCode));
        var runID = variables.publicationFetchRunsDAO.createRun(
            userID = arguments.userID,
            serviceCode = normalizedServiceCode,
            triggeredByAdminUserID = arguments.triggeredByAdminUserID,
            runMode = "manual"
        );
        var profile = variables.publicationProfilesDAO.getProfileByServiceCode(arguments.userID, normalizedServiceCode);
        var providerResult = {};
        var recordsFetched = 0;
        var recordsMatched = 0;
        var recordsInserted = 0;
        var recordsUpdated = 0;
        var candidate = {};
        var candidates = [];
        var sourceRecordID = 0;
        var mergeResult = {};
        var serviceLabel = _getServiceLabel(normalizedServiceCode);

        if (!listFindNoCase("orcid,pubmed", normalizedServiceCode)) {
            variables.publicationFetchRunsDAO.completeRun(
                publicationFetchRunID = runID,
                status = "not_implemented",
                message = "Provider fetch has not been implemented yet.",
                recordsFetched = 0,
                recordsMatched = 0,
                recordsInserted = 0,
                recordsUpdated = 0
            );

            variables.publicationProfilesDAO.updateFetchStatus(
                userID = arguments.userID,
                serviceCode = normalizedServiceCode,
                lastFetchStatus = "not_implemented",
                lastFetchMessage = "Provider fetch has not been implemented yet.",
                wasSuccessful = false
            );

            return {
                success = false,
                statusCode = 501,
                message = "Publication fetch is not implemented yet for " & normalizedServiceCode,
                errors = ["provider fetch is not implemented yet"],
                data = {
                    publicationFetchRunID = runID,
                    serviceCode = normalizedServiceCode,
                    recordsFetched = 0,
                    recordsMatched = 0,
                    recordsInserted = 0,
                    recordsUpdated = 0
                }
            };
        }

        if (structIsEmpty(profile)) {
            variables.publicationFetchRunsDAO.completeRun(
                publicationFetchRunID = runID,
                status = "failed",
                message = "No saved " & serviceLabel & " profile exists for this user.",
                recordsFetched = 0,
                recordsMatched = 0,
                recordsInserted = 0,
                recordsUpdated = 0
            );

            return {
                success = false,
                statusCode = 400,
                message = normalizedServiceCode EQ "orcid" ? "Save ORCID profile information before fetching." : "Save PubMed query information before fetching.",
                errors = ["missing " & normalizedServiceCode & " profile"],
                data = { publicationFetchRunID = runID, serviceCode = normalizedServiceCode }
            };
        }

        providerResult = normalizedServiceCode EQ "orcid"
            ? variables.orcidProvider.fetchForUser(arguments.userID, profile)
            : variables.pubmedProvider.fetchForUser(arguments.userID, profile);
        if (!providerResult.success) {
            variables.publicationFetchRunsDAO.completeRun(
                publicationFetchRunID = runID,
                status = "failed",
                message = providerResult.message ?: (serviceLabel & " fetch failed."),
                recordsFetched = 0,
                recordsMatched = 0,
                recordsInserted = 0,
                recordsUpdated = 0
            );

            variables.publicationProfilesDAO.updateFetchStatus(
                userID = arguments.userID,
                serviceCode = normalizedServiceCode,
                lastFetchStatus = "failed",
                lastFetchMessage = providerResult.message ?: (serviceLabel & " fetch failed."),
                wasSuccessful = false
            );

            return providerResult;
        }

        candidates = providerResult.data.candidates ?: [];
        if (arguments.limitRecentYears) {
            candidates = _filterCandidatesToRecentYears(candidates, 5);
        }

        recordsFetched = arrayLen(candidates);

        for (candidate in candidates) {
            variables.publicationSourceRecordsDAO.upsertSourceRecord(
                userID = arguments.userID,
                serviceCode = normalizedServiceCode,
                sourceRecordKey = candidate.sourceRecordKey,
                sourceData = {
                    sourceTitle = candidate.sourceTitle,
                    sourceAuthorsText = candidate.sourceAuthorsText,
                    sourcePublicationYear = candidate.sourcePublicationYear,
                    sourceJournalOrSource = candidate.sourceJournalOrSource,
                    sourceDOI = candidate.sourceDOI,
                    sourcePMID = candidate.sourcePMID,
                    sourcePMCID = candidate.sourcePMCID,
                    sourceURL = candidate.sourceURL,
                    matchConfidence = 0,
                    matchStatus = "pending"
                }
            );

            sourceRecordID = variables.publicationSourceRecordsDAO.getSourceRecordID(arguments.userID, normalizedServiceCode, candidate.sourceRecordKey);
            if (sourceRecordID GT 0) {
                variables.publicationSourceRecordsDAO.insertSourcePayload(
                    publicationSourceRecordID = sourceRecordID,
                    payloadFormat = "json",
                    payloadText = serializeJSON(candidate.rawPayload ?: {}),
                    contentHash = hash(serializeJSON(candidate.rawPayload ?: {}))
                );
            }

            mergeResult = variables.publicationMergeService.matchOrCreateCanonical(arguments.userID, candidate);
            if (mergeResult.success) {
                variables.publicationsDAO.ensureUserPublicationLink(arguments.userID, val(mergeResult.data.publicationID ?: 0));
                if (sourceRecordID GT 0) {
                    variables.publicationSourceRecordsDAO.linkToCanonical(
                        publicationSourceRecordID = sourceRecordID,
                        publicationID = val(mergeResult.data.publicationID ?: 0),
                        matchConfidence = val(mergeResult.data.wasCreated ?: false) ? 100 : 100,
                        matchStatus = "matched"
                    );
                }

                recordsMatched++;
                if (structKeyExists(mergeResult.data, "wasCreated") AND mergeResult.data.wasCreated) {
                    recordsInserted++;
                } else {
                    recordsUpdated++;
                }
            }
        }

        variables.publicationFetchRunsDAO.completeRun(
            publicationFetchRunID = runID,
            status = "success",
            message = serviceLabel & " fetch complete.",
            recordsFetched = recordsFetched,
            recordsMatched = recordsMatched,
            recordsInserted = recordsInserted,
            recordsUpdated = recordsUpdated
        );

        variables.publicationProfilesDAO.updateFetchStatus(
            userID = arguments.userID,
            serviceCode = normalizedServiceCode,
            lastFetchStatus = "success",
            lastFetchMessage = serviceLabel & " fetch complete.",
            wasSuccessful = true
        );

        return {
            success = true,
            statusCode = 200,
            message = serviceLabel & " fetch complete.",
            errors = [],
            data = {
                publicationFetchRunID = runID,
                serviceCode = normalizedServiceCode,
                recordsFetched = recordsFetched,
                recordsMatched = recordsMatched,
                recordsInserted = recordsInserted,
                recordsUpdated = recordsUpdated
            }
        };
    }

    private string function _getServiceLabel(required string serviceCode) {
        switch (lCase(trim(arguments.serviceCode))) {
            case "orcid":
                return "ORCID";
            case "pubmed":
                return "PubMed";
            default:
                return uCase(arguments.serviceCode);
        }
    }

    private array function _filterCandidatesToRecentYears(required array candidates, numeric yearWindow = 5) {
        var filtered = [];
        var candidate = {};
        var publicationYear = 0;
        var minimumYear = year(now()) - (arguments.yearWindow - 1);

        for (candidate in arguments.candidates) {
            publicationYear = val(candidate.publicationYear ?: candidate.sourcePublicationYear ?: 0);
            if (publicationYear GTE minimumYear) {
                arrayAppend(filtered, candidate);
            }
        }

        return filtered;
    }

}