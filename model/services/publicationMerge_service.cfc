component output="false" singleton {

    public any function init() {
        variables.publicationsDAO = createObject("component", "dao.publications_DAO").init();
        return this;
    }

    public struct function matchOrCreateCanonical(required numeric userID, required struct candidate) {
        var publicationID = 0;
        var wasCreated = false;

        publicationID = variables.publicationsDAO.findCanonicalPublicationID(arguments.candidate);
        if (publicationID LTE 0) {
            publicationID = variables.publicationsDAO.createCanonicalPublication({
                title = trim(arguments.candidate.title ?: "Untitled publication"),
                authors = trim(arguments.candidate.authors ?: ""),
                publicationYear = val(arguments.candidate.publicationYear ?: 0),
                journalOrSource = trim(arguments.candidate.journalOrSource ?: ""),
                doi = trim(arguments.candidate.doi ?: ""),
                pmid = trim(arguments.candidate.pmid ?: ""),
                pmcid = trim(arguments.candidate.pmcid ?: ""),
                primaryURL = trim(arguments.candidate.primaryURL ?: ""),
                citationText = trim(arguments.candidate.citationText ?: "")
            });
            wasCreated = publicationID GT 0;
        }

        return {
            success = publicationID GT 0,
            data = {
                publicationID = publicationID,
                matchStrategy = wasCreated ? "created" : "matched",
                wasCreated = wasCreated
            },
            message = publicationID GT 0 ? (wasCreated ? "Canonical publication created." : "Canonical publication matched.") : "Canonical publication could not be created."
        };
    }

}