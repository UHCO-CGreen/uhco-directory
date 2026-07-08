component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public array function getUserPublications(required numeric userID, boolean showcasedOnly = false) {
        var qry = executeQueryWithRetry(
            "
            SELECT up.UserPublicationID, up.UserID, up.PublicationID, up.DisplayOrder,
                   up.IsShowcased, up.IsHidden, up.FirstImportedAt, up.LastSeenAt,
                   p.CanonicalTitle, p.CanonicalAuthorsText, p.PublicationYear,
                   p.JournalOrSource, p.DOI, p.PMID, p.PMCID, p.PrimaryURL,
                                     p.CitationText, p.IsActive,
                                     SourceServices = STUFF((
                                             SELECT DISTINCT ', ' + ps2.ServiceName
                                             FROM PublicationSourceRecords psr2
                                             INNER JOIN PublicationServices ps2 ON ps2.PublicationServiceID = psr2.PublicationServiceID
                                             WHERE psr2.UserID = up.UserID
                                                 AND psr2.PublicationID = up.PublicationID
                                             FOR XML PATH(''), TYPE
                                     ).value('.', 'nvarchar(max)'), 1, 2, '')
            FROM UserPublications up
            INNER JOIN Publications p ON p.PublicationID = up.PublicationID
            WHERE up.UserID = :uid
              AND (:showcasedOnly = 0 OR up.IsShowcased = 1)
            ORDER BY up.DisplayOrder, p.PublicationYear DESC, p.CanonicalTitle
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                showcasedOnly = { value=arguments.showcasedOnly ? 1 : 0, cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );

        return queryToArray(qry);
    }

    public numeric function getShowcasedCount(required numeric userID) {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(1) AS ItemCount FROM UserPublications WHERE UserID = :uid AND IsShowcased = 1",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return qry.recordCount ? val(qry.ItemCount[1]) : 0;
    }

    public void function replaceShowcasedSelection(required numeric userID, required array publicationIDs) {
        var pubID = 0;

        executeQueryWithRetry(
            "UPDATE UserPublications SET IsShowcased = 0, UpdatedAt = GETDATE() WHERE UserID = :uid",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );

        for (pubID in arguments.publicationIDs) {
            executeQueryWithRetry(
                "
                UPDATE UserPublications
                SET IsShowcased = 1,
                    UpdatedAt = GETDATE()
                WHERE UserID = :uid AND PublicationID = :pubID
                ",
                {
                    uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                    pubID = { value=val(pubID), cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    public void function updateDisplayOrder(required numeric userID, required struct orderMap) {
        var publicationID = "";

        for (publicationID in arguments.orderMap) {
            executeQueryWithRetry(
                "
                UPDATE UserPublications
                SET DisplayOrder = :displayOrder,
                    UpdatedAt = GETDATE()
                WHERE UserID = :uid AND PublicationID = :pubID
                ",
                {
                    uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                    pubID = { value=val(publicationID), cfsqltype="cf_sql_integer" },
                    displayOrder = { value=val(arguments.orderMap[publicationID]), cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    public numeric function createCanonicalPublication(required struct publicationData) {
        var qry = executeQueryWithRetry(
            "
            INSERT INTO Publications (
                CanonicalTitle, CanonicalAuthorsText, PublicationYear, JournalOrSource,
                DOI, PMID, PMCID, PrimaryURL, CitationText, IsActive, CreatedAt, UpdatedAt
            )
            OUTPUT INSERTED.PublicationID
            VALUES (
                :title, :authors, :publicationYear, :journalOrSource,
                :doi, :pmid, :pmcid, :primaryURL, :citationText, 1, GETDATE(), GETDATE()
            )
            ",
            {
                title = { value=trim(arguments.publicationData.title ?: ""), cfsqltype="cf_sql_nvarchar" },
                authors = { value=trim(arguments.publicationData.authors ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.publicationData.authors ?: "")) },
                publicationYear = { value=val(arguments.publicationData.publicationYear ?: 0), cfsqltype="cf_sql_integer", null=!val(arguments.publicationData.publicationYear ?: 0) },
                journalOrSource = { value=trim(arguments.publicationData.journalOrSource ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.publicationData.journalOrSource ?: "")) },
                doi = { value=trim(arguments.publicationData.doi ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.publicationData.doi ?: "")) },
                pmid = { value=trim(arguments.publicationData.pmid ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.publicationData.pmid ?: "")) },
                pmcid = { value=trim(arguments.publicationData.pmcid ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.publicationData.pmcid ?: "")) },
                primaryURL = { value=trim(arguments.publicationData.primaryURL ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.publicationData.primaryURL ?: "")) },
                citationText = { value=trim(arguments.publicationData.citationText ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.publicationData.citationText ?: "")) }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return qry.recordCount ? val(qry.PublicationID[1]) : 0;
    }

    public numeric function findCanonicalPublicationID(required struct candidate) {
        var qry = "";
        var title = trim(arguments.candidate.title ?: "");
        var doi = trim(arguments.candidate.doi ?: "");
        var pmid = trim(arguments.candidate.pmid ?: "");
        var pmcid = trim(arguments.candidate.pmcid ?: "");
        var publicationYear = val(arguments.candidate.publicationYear ?: 0);

        if (len(doi)) {
            qry = executeQueryWithRetry(
                "SELECT TOP 1 PublicationID FROM Publications WHERE DOI = :doi ORDER BY PublicationID",
                { doi = { value=doi, cfsqltype="cf_sql_varchar" } },
                { datasource=variables.datasource, timeout=30, fetchSize=1 }
            );
            if (qry.recordCount) { return val(qry.PublicationID[1]); }
        }

        if (len(pmid)) {
            qry = executeQueryWithRetry(
                "SELECT TOP 1 PublicationID FROM Publications WHERE PMID = :pmid ORDER BY PublicationID",
                { pmid = { value=pmid, cfsqltype="cf_sql_varchar" } },
                { datasource=variables.datasource, timeout=30, fetchSize=1 }
            );
            if (qry.recordCount) { return val(qry.PublicationID[1]); }
        }

        if (len(pmcid)) {
            qry = executeQueryWithRetry(
                "SELECT TOP 1 PublicationID FROM Publications WHERE PMCID = :pmcid ORDER BY PublicationID",
                { pmcid = { value=pmcid, cfsqltype="cf_sql_varchar" } },
                { datasource=variables.datasource, timeout=30, fetchSize=1 }
            );
            if (qry.recordCount) { return val(qry.PublicationID[1]); }
        }

        if (len(title) AND publicationYear GT 0) {
            qry = executeQueryWithRetry(
                "
                SELECT TOP 1 PublicationID
                FROM Publications
                WHERE PublicationYear = :publicationYear
                  AND LOWER(LTRIM(RTRIM(CanonicalTitle))) = LOWER(LTRIM(RTRIM(:title)))
                ORDER BY PublicationID
                ",
                {
                    publicationYear = { value=publicationYear, cfsqltype="cf_sql_integer" },
                    title = { value=title, cfsqltype="cf_sql_nvarchar" }
                },
                { datasource=variables.datasource, timeout=30, fetchSize=1 }
            );
            if (qry.recordCount) { return val(qry.PublicationID[1]); }
        }

        return 0;
    }

    public void function ensureUserPublicationLink(required numeric userID, required numeric publicationID) {
        executeQueryWithRetry(
            "
            IF NOT EXISTS (
                SELECT 1 FROM UserPublications WHERE UserID = :uid AND PublicationID = :publicationID
            )
            BEGIN
                INSERT INTO UserPublications (
                    UserID, PublicationID, DisplayOrder, IsShowcased, IsHidden,
                    FirstImportedAt, LastSeenAt, CreatedAt, UpdatedAt
                )
                VALUES (
                    :uid, :publicationID, 0, 0, 0,
                    GETDATE(), GETDATE(), GETDATE(), GETDATE()
                )
            END
            ELSE
            BEGIN
                UPDATE UserPublications
                SET LastSeenAt = GETDATE(),
                    UpdatedAt = GETDATE()
                WHERE UserID = :uid AND PublicationID = :publicationID
            END
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                publicationID = { value=arguments.publicationID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}