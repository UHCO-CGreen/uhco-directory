component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public numeric function createRun(
        required numeric userID,
        required string serviceCode,
        numeric triggeredByAdminUserID = 0,
        string runMode = "manual"
    ) {
        var qry = executeQueryWithRetry(
            "
            DECLARE @PublicationServiceID INT;

            SELECT TOP 1 @PublicationServiceID = PublicationServiceID
            FROM PublicationServices
            WHERE ServiceCode = :serviceCode;

            IF @PublicationServiceID IS NULL
            BEGIN
                RAISERROR('Publication service not found.', 16, 1);
            END

            INSERT INTO PublicationFetchRuns (
                UserID, PublicationServiceID, TriggeredByAdminUserID, RunMode, StartedAt, Status
            )
            OUTPUT INSERTED.PublicationFetchRunID
            VALUES (
                :uid, @PublicationServiceID, :triggeredByAdminUserID, :runMode, GETDATE(), 'running'
            )
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" },
                triggeredByAdminUserID = { value=arguments.triggeredByAdminUserID, cfsqltype="cf_sql_integer", null=arguments.triggeredByAdminUserID LTE 0 },
                runMode = { value=trim(arguments.runMode), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return qry.recordCount ? val(qry.PublicationFetchRunID[1]) : 0;
    }

    public void function completeRun(
        required numeric publicationFetchRunID,
        required string status,
        string message = "",
        numeric recordsFetched = 0,
        numeric recordsMatched = 0,
        numeric recordsInserted = 0,
        numeric recordsUpdated = 0
    ) {
        executeQueryWithRetry(
            "
            UPDATE PublicationFetchRuns
            SET CompletedAt = GETDATE(),
                Status = :status,
                Message = :message,
                RecordsFetched = :recordsFetched,
                RecordsMatched = :recordsMatched,
                RecordsInserted = :recordsInserted,
                RecordsUpdated = :recordsUpdated
            WHERE PublicationFetchRunID = :runID
            ",
            {
                runID = { value=arguments.publicationFetchRunID, cfsqltype="cf_sql_integer" },
                status = { value=trim(arguments.status), cfsqltype="cf_sql_varchar" },
                message = { value=trim(arguments.message), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.message)) },
                recordsFetched = { value=arguments.recordsFetched, cfsqltype="cf_sql_integer" },
                recordsMatched = { value=arguments.recordsMatched, cfsqltype="cf_sql_integer" },
                recordsInserted = { value=arguments.recordsInserted, cfsqltype="cf_sql_integer" },
                recordsUpdated = { value=arguments.recordsUpdated, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getRecentRunsByUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            "
            SELECT pfr.PublicationFetchRunID, pfr.UserID, pfr.PublicationServiceID,
                   ps.ServiceCode, ps.ServiceName,
                   pfr.TriggeredByAdminUserID, pfr.RunMode,
                   pfr.StartedAt, pfr.CompletedAt, pfr.Status, pfr.Message,
                   pfr.RecordsFetched, pfr.RecordsMatched, pfr.RecordsInserted, pfr.RecordsUpdated
            FROM PublicationFetchRuns pfr
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = pfr.PublicationServiceID
            WHERE pfr.UserID = :uid
            ORDER BY pfr.StartedAt DESC
            ",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=50 }
        );

        return queryToArray(qry);
    }

}