component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public array function getProfilesByUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            "
            SELECT upp.UserPublicationProfileID, upp.UserID, upp.PublicationServiceID,
                   ps.ServiceCode, ps.ServiceName,
                   upp.ProfileIdentifier, upp.ProfileURL, upp.SearchQuery,
                   upp.IsEnabled, upp.LastFetchAt, upp.LastSuccessfulFetchAt,
                   upp.LastFetchStatus, upp.LastFetchMessage,
                   upp.CreatedAt, upp.UpdatedAt
            FROM UserPublicationProfiles upp
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = upp.PublicationServiceID
            WHERE upp.UserID = :uid
            ORDER BY ps.ServiceName
            ",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=50 }
        );

        return queryToArray(qry);
    }

    public array function getConfiguredProfilesByUser(required numeric userID) {
        return getProfilesByUser(arguments.userID);
    }

    public array function getProfilesByServiceCode(required numeric userID, required string serviceCode) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 upp.UserPublicationProfileID, upp.UserID, upp.PublicationServiceID,
                   ps.ServiceCode, ps.ServiceName,
                   upp.ProfileIdentifier, upp.ProfileURL, upp.SearchQuery,
                   upp.IsEnabled, upp.LastFetchAt, upp.LastSuccessfulFetchAt,
                   upp.LastFetchStatus, upp.LastFetchMessage,
                   upp.CreatedAt, upp.UpdatedAt
            FROM UserPublicationProfiles upp
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = upp.PublicationServiceID
            WHERE upp.UserID = :uid
              AND ps.ServiceCode = :serviceCode
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return queryToArray(qry);
    }

    public struct function getProfileByServiceCode(required numeric userID, required string serviceCode) {
        var rows = getProfilesByServiceCode(arguments.userID, arguments.serviceCode);
        return arrayLen(rows) ? rows[1] : {};
    }

    public void function upsertProfile(
        required numeric userID,
        required string serviceCode,
        string profileIdentifier = "",
        string profileURL = "",
        string searchQuery = "",
        boolean isEnabled = true
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

            MERGE UserPublicationProfiles AS target
            USING (
                SELECT :uid AS UserID, @PublicationServiceID AS PublicationServiceID
            ) AS src
            ON target.UserID = src.UserID AND target.PublicationServiceID = src.PublicationServiceID
            WHEN MATCHED THEN
                UPDATE SET
                    ProfileIdentifier = :profileIdentifier,
                    ProfileURL = :profileURL,
                    SearchQuery = :searchQuery,
                    IsEnabled = :isEnabled,
                    UpdatedAt = GETDATE()
            WHEN NOT MATCHED THEN
                INSERT (UserID, PublicationServiceID, ProfileIdentifier, ProfileURL, SearchQuery, IsEnabled, CreatedAt, UpdatedAt)
                VALUES (:uid, @PublicationServiceID, :profileIdentifier, :profileURL, :searchQuery, :isEnabled, GETDATE(), GETDATE());
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" },
                profileIdentifier = { value=trim(arguments.profileIdentifier), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.profileIdentifier)) },
                profileURL = { value=trim(arguments.profileURL), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.profileURL)) },
                searchQuery = { value=trim(arguments.searchQuery), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.searchQuery)) },
                isEnabled = { value=arguments.isEnabled ? 1 : 0, cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateFetchStatus(
        required numeric userID,
        required string serviceCode,
        string lastFetchStatus = "",
        string lastFetchMessage = "",
        boolean wasSuccessful = false
    ) {
        executeQueryWithRetry(
            "
            UPDATE upp
            SET upp.LastFetchAt = GETDATE(),
                upp.LastFetchStatus = :lastFetchStatus,
                upp.LastFetchMessage = :lastFetchMessage,
                upp.LastSuccessfulFetchAt = CASE WHEN :wasSuccessful = 1 THEN GETDATE() ELSE upp.LastSuccessfulFetchAt END,
                upp.UpdatedAt = GETDATE()
            FROM UserPublicationProfiles upp
            INNER JOIN PublicationServices ps ON ps.PublicationServiceID = upp.PublicationServiceID
            WHERE upp.UserID = :uid
              AND ps.ServiceCode = :serviceCode
            ",
            {
                uid = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                serviceCode = { value=lCase(trim(arguments.serviceCode)), cfsqltype="cf_sql_varchar" },
                lastFetchStatus = { value=trim(arguments.lastFetchStatus), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.lastFetchStatus)) },
                lastFetchMessage = { value=trim(arguments.lastFetchMessage), cfsqltype="cf_sql_varchar", null=!len(trim(arguments.lastFetchMessage)) },
                wasSuccessful = { value=arguments.wasSuccessful ? 1 : 0, cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}