component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    // ── Origins ──────────────────────────────────────────────────────────

    public array function getActiveOrigins() {
        var qry = executeQueryWithRetry(
            "SELECT OriginID, OriginPattern, MatchType, Description FROM CORSAllowedOrigins WHERE IsActive = 1 ORDER BY OriginPattern",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    public array function getAllOrigins() {
        var qry = executeQueryWithRetry(
            "SELECT OriginID, OriginPattern, MatchType, Description, IsActive, CreatedAt, UpdatedAt FROM CORSAllowedOrigins ORDER BY CreatedAt DESC",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    public struct function getOriginByID(required numeric originID) {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 OriginID, OriginPattern, MatchType, Description, IsActive, CreatedAt, UpdatedAt FROM CORSAllowedOrigins WHERE OriginID = :originID",
            {
                originID = { value=arguments.originID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        if (!qry.recordCount) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public numeric function createOrigin(required string originPattern, required string matchType, string description="") {
        var qry = executeQueryWithRetry(
            "INSERT INTO CORSAllowedOrigins (OriginPattern, MatchType, Description) OUTPUT INSERTED.OriginID VALUES (:originPattern, :matchType, :description)",
            {
                originPattern = { value=trim(arguments.originPattern), cfsqltype="cf_sql_varchar" },
                matchType     = { value=trim(arguments.matchType), cfsqltype="cf_sql_varchar" },
                description   = { value=trim(arguments.description), cfsqltype="cf_sql_varchar", null=(!len(trim(arguments.description))) }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return qry.recordCount ? val(qry.OriginID[1]) : 0;
    }

    public void function updateOrigin(required numeric originID, required string originPattern, required string matchType, string description="", required boolean isActive) {
        executeQueryWithRetry(
            "UPDATE CORSAllowedOrigins SET OriginPattern = :originPattern, MatchType = :matchType, Description = :description, IsActive = :isActive, UpdatedAt = SYSUTCDATETIME() WHERE OriginID = :originID",
            {
                originPattern = { value=trim(arguments.originPattern), cfsqltype="cf_sql_varchar" },
                matchType     = { value=trim(arguments.matchType), cfsqltype="cf_sql_varchar" },
                description   = { value=trim(arguments.description), cfsqltype="cf_sql_varchar", null=(!len(trim(arguments.description))) },
                isActive      = { value=(arguments.isActive ? 1 : 0), cfsqltype="cf_sql_bit" },
                originID      = { value=arguments.originID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteOrigin(required numeric originID) {
        executeQueryWithRetry(
            "DELETE FROM CORSAllowedOrigins WHERE OriginID = :originID",
            {
                originID = { value=arguments.originID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    // ── IP Ranges ────────────────────────────────────────────────────────

    public array function getActiveIPRanges() {
        var qry = executeQueryWithRetry(
            "SELECT RangeID, CIDR, Description FROM CORSAllowedIPRanges WHERE IsActive = 1 ORDER BY CIDR",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    public array function getAllIPRanges() {
        var qry = executeQueryWithRetry(
            "SELECT RangeID, CIDR, Description, IsActive, CreatedAt, UpdatedAt FROM CORSAllowedIPRanges ORDER BY CreatedAt DESC",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );
        return queryToArray(qry);
    }

    public struct function getIPRangeByID(required numeric rangeID) {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 RangeID, CIDR, Description, IsActive, CreatedAt, UpdatedAt FROM CORSAllowedIPRanges WHERE RangeID = :rangeID",
            {
                rangeID = { value=arguments.rangeID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        if (!qry.recordCount) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public numeric function createIPRange(required string cidr, string description="") {
        var qry = executeQueryWithRetry(
            "INSERT INTO CORSAllowedIPRanges (CIDR, Description) OUTPUT INSERTED.RangeID VALUES (:cidr, :description)",
            {
                cidr        = { value=trim(arguments.cidr), cfsqltype="cf_sql_varchar" },
                description = { value=trim(arguments.description), cfsqltype="cf_sql_varchar", null=(!len(trim(arguments.description))) }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return qry.recordCount ? val(qry.RangeID[1]) : 0;
    }

    public void function updateIPRange(required numeric rangeID, required string cidr, string description="", required boolean isActive) {
        executeQueryWithRetry(
            "UPDATE CORSAllowedIPRanges SET CIDR = :cidr, Description = :description, IsActive = :isActive, UpdatedAt = SYSUTCDATETIME() WHERE RangeID = :rangeID",
            {
                cidr        = { value=trim(arguments.cidr), cfsqltype="cf_sql_varchar" },
                description = { value=trim(arguments.description), cfsqltype="cf_sql_varchar", null=(!len(trim(arguments.description))) },
                isActive    = { value=(arguments.isActive ? 1 : 0), cfsqltype="cf_sql_bit" },
                rangeID     = { value=arguments.rangeID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteIPRange(required numeric rangeID) {
        executeQueryWithRetry(
            "DELETE FROM CORSAllowedIPRanges WHERE RangeID = :rangeID",
            {
                rangeID = { value=arguments.rangeID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
