component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public void function insertEvent(
        required string source,
        required string eventType,
        numeric adminUserID = 0,
        string username     = "",
        string ipAddress    = "",
        string userAgent    = "",
        string details      = ""
    ) {
        var safeAdminUserID = val(arguments.adminUserID) GT 0 ? val(arguments.adminUserID) : javaCast("null", "");

        executeQueryWithRetry(
            sql = "
                INSERT INTO dbo.AuthAuditLog
                    (Source, EventType, AdminUserID, Username, IPAddress, UserAgent, Details)
                VALUES
                    (:source, :eventType, :adminUserID, :username, :ipAddress, :userAgent, :details)
            ",
            params = {
                source      = { value = left(trim(arguments.source & ""),    20),  cfsqltype = "cf_sql_varchar"  },
                eventType   = { value = left(trim(arguments.eventType & ""), 30),  cfsqltype = "cf_sql_varchar"  },
                adminUserID = { value = safeAdminUserID, cfsqltype = "cf_sql_integer", null = isNull(safeAdminUserID) },
                username    = { value = left(trim(arguments.username & ""),    50),  cfsqltype = "cf_sql_nvarchar" },
                ipAddress   = { value = left(trim(arguments.ipAddress & ""),   50),  cfsqltype = "cf_sql_varchar"  },
                userAgent   = { value = left(trim(arguments.userAgent & ""),  500),  cfsqltype = "cf_sql_nvarchar" },
                details     = { value = left(trim(arguments.details & ""),    500),  cfsqltype = "cf_sql_nvarchar" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public array function getRecentEvents(numeric maxRows = 100) {
        var safeMax = max(1, min(val(arguments.maxRows), 1000));
        var qry = executeQueryWithRetry(
            sql = "
                SELECT TOP (#safeMax#)
                    LogID, Source, EventType, AdminUserID, Username,
                    EventAt, IPAddress, UserAgent, Details
                FROM dbo.AuthAuditLog
                ORDER BY EventAt DESC
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

}
