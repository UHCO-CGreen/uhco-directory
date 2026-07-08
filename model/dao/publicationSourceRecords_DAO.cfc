component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public array function getSourceRecordsByUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            "
            SELECT psr.PublicationSourceRecordID, psr.PublicationID, psr.UserID,
                   psr.PublicationServiceID, ps.ServiceCode, ps.ServiceName,
                   psr.SourceRecordKey, psr.SourceTitle, psr.SourceAuthorsText,
                   psr.SourcePublicationYear, psr.SourceJournalOrSource,
                   psr.SourceDOI, psr.SourcePMID, psr.SourcePMCID,
                   psr.SourceURL, psr.MatchConfidence, psr.MatchStatus,
                   psr.LastSeenAt, psr.CreatedAt, psr.UpdatedAt
            FROM PublicationSourceRecords psr
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = psr.PublicationServiceID
            WHERE psr.UserID = :uid
            ORDER BY ps.ServiceName, psr.SourcePublicationYear DESC, psr.SourceTitle
            ",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );

        return queryToArray(qry);
    }

    public void function upsertSourceRecord(
        required numeric userID,
        required string serviceCode,
        required string sourceRecordKey,
        struct sourceData = {}
    ) {
        executeQueryWithRetry(
            "
            DECLARE @PublicationServiceID INT;

            SELECT TOP 1 @PublicationServiceID = PublicationServiceID
            FROM PublicationServices
            WHERE ServiceCode = :serviceCode;

            IF @PublicationServiceID IS NULL
            BEGIN
                RAISERROR('Publication service not found.', 16, 1);
            END

            MERGE PublicationSourceRecords AS target
            USING (
                SELECT :uid AS UserID, @PublicationServiceID AS PublicationServiceID, :sourceRecordKey AS SourceRecordKey
            ) AS src
            ON target.UserID = src.UserID
               AND target.PublicationServiceID = src.PublicationServiceID
               AND target.SourceRecordKey = src.SourceRecordKey
            WHEN MATCHED THEN
                UPDATE SET
                    SourceTitle = :sourceTitle,
                    SourceAuthorsText = :sourceAuthorsText,
                    SourcePublicationYear = :sourcePublicationYear,
                    SourceJournalOrSource = :sourceJournalOrSource,
                    SourceDOI = :sourceDOI,
                    SourcePMID = :sourcePMID,
                    SourcePMCID = :sourcePMCID,
                    SourceURL = :sourceURL,
                    MatchConfidence = :matchConfidence,
                    MatchStatus = :matchStatus,
                    LastSeenAt = GETDATE(),
                    UpdatedAt = GETDATE()
            WHEN NOT MATCHED THEN
                INSERT (
                    UserID, PublicationServiceID, SourceRecordKey, SourceTitle, SourceAuthorsText,
                    SourcePublicationYear, SourceJournalOrSource, SourceDOI, SourcePMID,
                    SourcePMCID, SourceURL, MatchConfidence, MatchStatus, LastSeenAt, CreatedAt, UpdatedAt
                )
                VALUES (
                    :uid, @PublicationServiceID, :sourceRecordKey, :sourceTitle, :sourceAuthorsText,
                    :sourcePublicationYear, :sourceJournalOrSource, :sourceDOI, :sourcePMID,
                    :sourcePMCID, :sourceURL, :matchConfidence, :matchStatus, GETDATE(), GETDATE(), GETDATE()
                );
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" },
                sourceRecordKey = { value=trim(arguments.sourceRecordKey), cfsqltype="cf_sql_varchar" },
                sourceTitle = { value=trim(arguments.sourceData.sourceTitle ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.sourceData.sourceTitle ?: "")) },
                sourceAuthorsText = { value=trim(arguments.sourceData.sourceAuthorsText ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.sourceData.sourceAuthorsText ?: "")) },
                sourcePublicationYear = { value=val(arguments.sourceData.sourcePublicationYear ?: 0), cfsqltype="cf_sql_integer", null=!val(arguments.sourceData.sourcePublicationYear ?: 0) },
                sourceJournalOrSource = { value=trim(arguments.sourceData.sourceJournalOrSource ?: ""), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.sourceData.sourceJournalOrSource ?: "")) },
                sourceDOI = { value=trim(arguments.sourceData.sourceDOI ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.sourceData.sourceDOI ?: "")) },
                sourcePMID = { value=trim(arguments.sourceData.sourcePMID ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.sourceData.sourcePMID ?: "")) },
                sourcePMCID = { value=trim(arguments.sourceData.sourcePMCID ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.sourceData.sourcePMCID ?: "")) },
                sourceURL = { value=trim(arguments.sourceData.sourceURL ?: ""), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.sourceData.sourceURL ?: "")) },
                matchConfidence = { value=arguments.sourceData.matchConfidence ?: 0, cfsqltype="cf_sql_decimal", null=!structKeyExists(arguments.sourceData, "matchConfidence"), scale=2 },
                matchStatus = { value=trim(arguments.sourceData.matchStatus ?: "pending"), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public numeric function getSourceRecordID(required numeric userID, required string serviceCode, required string sourceRecordKey) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 psr.PublicationSourceRecordID
            FROM PublicationSourceRecords psr
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = psr.PublicationServiceID
            WHERE psr.UserID = :uid
              AND ps.ServiceCode = :serviceCode
              AND psr.SourceRecordKey = :sourceRecordKey
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" },
                sourceRecordKey = { value=trim(arguments.sourceRecordKey), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return qry.recordCount ? val(qry.PublicationSourceRecordID[1]) : 0;
    }

    public void function linkToCanonical(
        required numeric publicationSourceRecordID,
        required numeric publicationID,
        numeric matchConfidence = 100,
        string matchStatus = "matched"
    ) {
        executeQueryWithRetry(
            "
            UPDATE PublicationSourceRecords
            SET PublicationID = :publicationID,
                MatchConfidence = :matchConfidence,
                MatchStatus = :matchStatus,
                UpdatedAt = GETDATE(),
                LastSeenAt = GETDATE()
            WHERE PublicationSourceRecordID = :sourceRecordID
            ",
            {
                sourceRecordID = { value=arguments.publicationSourceRecordID, cfsqltype="cf_sql_integer" },
                publicationID = { value=arguments.publicationID, cfsqltype="cf_sql_integer" },
                matchConfidence = { value=arguments.matchConfidence, cfsqltype="cf_sql_decimal", scale=2 },
                matchStatus = { value=trim(arguments.matchStatus), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function insertSourcePayload(
        required numeric publicationSourceRecordID,
        required string payloadFormat,
        required string payloadText,
        string contentHash = ""
    ) {
        executeQueryWithRetry(
            "
            INSERT INTO PublicationSourcePayloads (
                PublicationSourceRecordID, PayloadFormat, PayloadText, FetchedAt, ContentHash
            )
            VALUES (:sourceRecordID, :payloadFormat, :payloadText, GETDATE(), :contentHash)
            ",
            {
                sourceRecordID = { value=arguments.publicationSourceRecordID, cfsqltype="cf_sql_integer" },
                payloadFormat = { value=trim(arguments.payloadFormat), cfsqltype="cf_sql_varchar" },
                payloadText = { value=arguments.payloadText, cfsqltype="cf_sql_nvarchar" },
                contentHash = { value=trim(arguments.contentHash), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.contentHash)) }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}