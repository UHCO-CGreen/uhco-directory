component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // RUN MANAGEMENT
    // ──────────────────────────────────────────────────────────────────────────

    /** Insert a new run record and return its RunID. */
    public numeric function createRun( required string triggeredBy ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO UHSyncRuns (TriggeredBy) OUTPUT INSERTED.RunID VALUES (:by)",
            { by = { value=arguments.triggeredBy, cfsqltype="cf_sql_nvarchar" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.RunID;
    }

    /** Update totals after the run completes. */
    public void function updateRunTotals(
        required numeric runID,
        required numeric totalCompared,
        required numeric totalDiffs,
        required numeric totalGone,
        required numeric totalNew
    ) {
        executeQueryWithRetry(
            "UPDATE UHSyncRuns
             SET TotalCompared = :c, TotalDiffs = :d, TotalGone = :g, TotalNew = :n
             WHERE RunID = :id",
            {
                id = { value=runID,            cfsqltype="cf_sql_integer" },
                c  = { value=totalCompared,    cfsqltype="cf_sql_integer" },
                d  = { value=totalDiffs,       cfsqltype="cf_sql_integer" },
                g  = { value=totalGone,        cfsqltype="cf_sql_integer" },
                n  = { value=totalNew,         cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Return the most recent N runs. */
    public array function getRecentRuns( numeric maxRuns=10 ) {
        // Inline the TOP value as a safe literal — SQL Server JDBC does not reliably
        // support TOP as a bound parameter placeholder ("TOP ?").
        var topN = val(arguments.maxRuns) > 0 ? val(arguments.maxRuns) : 10;
        var qry = executeQueryWithRetry(
            "SELECT TOP #topN# RunID, RunAt, TriggeredBy, TotalCompared, TotalDiffs, TotalGone, TotalNew
             FROM UHSyncRuns
             ORDER BY RunID DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /** Return a single run record by RunID (as struct, empty if not found). */
    public struct function getRunByID( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT RunID, RunAt, TriggeredBy, TotalCompared, TotalDiffs, TotalGone, TotalNew
             FROM UHSyncRuns WHERE RunID = :id",
            { id = { value=runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    /** Return the latest run record (empty struct if none). */
    public struct function getLatestRun() {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 RunID, RunAt, TriggeredBy, TotalCompared, TotalDiffs, TotalGone, TotalNew
             FROM UHSyncRuns
             ORDER BY RunID DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DIFF INSERTS
    // ──────────────────────────────────────────────────────────────────────────

    /** Insert one field-level diff; returns the new DiffID. */
    public numeric function insertDiff(
        required numeric runID,
        required numeric userID,
        required string  fieldName,
        required string  localValue,
        required string  apiValue
    ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO UHSyncDiffs (RunID, UserID, FieldName, LocalValue, ApiValue)
             OUTPUT INSERTED.DiffID
             VALUES (:run, :user, :field, :local, :api)",
            {
                run   = { value=runID,              cfsqltype="cf_sql_integer"  },
                user  = { value=userID,             cfsqltype="cf_sql_integer"  },
                field = { value=fieldName,          cfsqltype="cf_sql_nvarchar" },
                local = { value=localValue,         cfsqltype="cf_sql_nvarchar" },
                api   = { value=apiValue,           cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.DiffID;
    }

    /** Insert a "gone" record (local user absent from API); returns new GoneID. */
    public numeric function insertGone(
        required numeric runID,
        required numeric userID
    ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO UHSyncGone (RunID, UserID)
             OUTPUT INSERTED.GoneID
             VALUES (:run, :user)",
            {
                run  = { value=runID,  cfsqltype="cf_sql_integer" },
                user = { value=userID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.GoneID;
    }

    /** Insert a "new" record (API user not in local DB); returns new NewID. */
    public numeric function insertNew(
        required numeric runID,
        required string  uhApiID,
        required string  firstName,
        required string  lastName,
        required string  email,
        required string  title,
        required string  department,
        required string  phone,
        required string  rawJson
    ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO UHSyncNew (RunID, UHApiID, FirstName, LastName, Email, Title, Department, Phone, RawJson)
             OUTPUT INSERTED.NewID
             VALUES (:run, :apiId, :first, :last, :email, :title, :dept, :phone, :raw)",
            {
                run   = { value=runID,              cfsqltype="cf_sql_integer"  },
                apiId = { value=uhApiID,            cfsqltype="cf_sql_nvarchar" },
                first = { value=firstName,          cfsqltype="cf_sql_nvarchar" },
                last  = { value=lastName,           cfsqltype="cf_sql_nvarchar" },
                email = { value=email,              cfsqltype="cf_sql_nvarchar" },
                title = { value=title,              cfsqltype="cf_sql_nvarchar" },
                dept  = { value=department,         cfsqltype="cf_sql_nvarchar" },
                phone = { value=phone,              cfsqltype="cf_sql_nvarchar" },
                raw   = { value=rawJson,            cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.NewID;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // REPORT READS
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Return all unresolved diffs for a run, joined to user info.
     * Optionally filter by FieldName.
     */
    public array function getDiffsByRun(
        required numeric runID,
        string filterField = ""
    ) {
        var sql = "
            SELECT d.DiffID, d.UserID, d.FieldName, d.LocalValue, d.ApiValue,
                   COALESCE(pa.FirstName, u.FirstName) AS FirstName,
                   COALESCE(pa.LastName, u.LastName) AS LastName,
                   u.EmailPrimary, u.UH_API_ID
            FROM UHSyncDiffs d
            INNER JOIN Users u ON u.UserID = d.UserID
            OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                ORDER BY
                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                    CASE WHEN ISNULL(ua.IsActive, 0) = 1 THEN 0 ELSE 1 END,
                    ISNULL(ua.SortOrder, 2147483647),
                    ua.AliasID
            ) pa
            WHERE d.RunID = :run
              AND d.Resolution IS NULL
        ";
        var params = { run = { value=runID, cfsqltype="cf_sql_integer" } };
        if (len(trim(arguments.filterField))) {
            sql &= " AND d.FieldName = :field";
            params["field"] = { value=trim(arguments.filterField), cfsqltype="cf_sql_nvarchar" };
        }
        sql &= " ORDER BY COALESCE(pa.LastName, u.LastName), COALESCE(pa.FirstName, u.FirstName), d.FieldName";
        var qry = executeQueryWithRetry(sql, params, { datasource=variables.datasource, timeout=60 });
        return queryToArray(qry);
    }

    /**
     * Return a per-field summary count for a run (unresolved diffs only).
     * Returns array of { FieldName, DiffCount }.
     */
    public array function getDiffSummaryByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT FieldName, COUNT(*) AS DiffCount
             FROM UHSyncDiffs
             WHERE RunID = :run AND Resolution IS NULL
             GROUP BY FieldName
             ORDER BY DiffCount DESC, FieldName",
            { run = { value=runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /** Return all unresolved gone records for a run, joined to user info. */
    public array function getGoneByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT g.GoneID, g.UserID,
                    COALESCE(pa.FirstName, u.FirstName) AS FirstName,
                    COALESCE(pa.LastName, u.LastName) AS LastName,
                    u.EmailPrimary, u.UH_API_ID,
                    u.Title1, u.Department
             FROM UHSyncGone g
             INNER JOIN Users u ON u.UserID = g.UserID
             OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                ORDER BY
                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                    CASE WHEN ISNULL(ua.IsActive, 0) = 1 THEN 0 ELSE 1 END,
                    ISNULL(ua.SortOrder, 2147483647),
                    ua.AliasID
             ) pa
             WHERE g.RunID = :run AND g.Resolution IS NULL
             ORDER BY COALESCE(pa.LastName, u.LastName), COALESCE(pa.FirstName, u.FirstName)",
            { run = { value=runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=60 }
        );
        return queryToArray(qry);
    }

    /** Return all unresolved new API users for a run. */
    public array function getNewByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT NewID, UHApiID, FirstName, LastName, Email, Title, Department, Phone
             FROM UHSyncNew
             WHERE RunID = :run AND Resolution IS NULL
             ORDER BY LastName, FirstName",
            { run = { value=runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=60 }
        );
        return queryToArray(qry);
    }

    /**
     * Return unresolved diffs for a specific user from their most recent run.
     * Used on the Edit User page.
     */
    public array function getUnresolvedDiffsForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT d.DiffID, d.RunID, d.FieldName, d.LocalValue, d.ApiValue
             FROM UHSyncDiffs d
             WHERE d.UserID = :uid
               AND d.Resolution IS NULL
               AND d.RunID = (
                   SELECT MAX(d2.RunID)
                   FROM UHSyncDiffs d2
                   WHERE d2.UserID = :uid AND d2.Resolution IS NULL
               )
             ORDER BY d.FieldName",
            { uid = { value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // RESOLUTION
    // ──────────────────────────────────────────────────────────────────────────

    /** Mark a diff as resolved. resolution must be 'synced' or 'discarded'. */
    public void function resolveDiff(
        required numeric diffID,
        required string  resolution
    ) {
        var allowedResolutions = ["synced", "discarded"];
        if (!arrayFindNoCase(allowedResolutions, trim(arguments.resolution))) {
            throw(type="Application", message="Invalid diff resolution value.");
        }
        executeQueryWithRetry(
            "UPDATE UHSyncDiffs
             SET Resolution = :res, ResolvedAt = SYSUTCDATETIME()
             WHERE DiffID = :id",
            {
                id  = { value=diffID,               cfsqltype="cf_sql_integer"  },
                res = { value=trim(resolution),     cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Mark all pending diffs for a user/run as resolved (used by Sync All). */
    public void function resolveAllDiffsForUser(
        required numeric userID,
        required numeric runID,
        required string  resolution
    ) {
        var allowedResolutions = ["synced", "discarded"];
        if (!arrayFindNoCase(allowedResolutions, trim(arguments.resolution))) {
            throw(type="Application", message="Invalid diff resolution value.");
        }
        executeQueryWithRetry(
            "UPDATE UHSyncDiffs
             SET Resolution = :res, ResolvedAt = SYSUTCDATETIME()
             WHERE UserID = :uid AND RunID = :rid AND Resolution IS NULL",
            {
                uid = { value=userID,           cfsqltype="cf_sql_integer"  },
                rid = { value=runID,            cfsqltype="cf_sql_integer"  },
                res = { value=trim(resolution), cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Mark a gone record as resolved. resolution must be 'deleted' or 'kept'. */
    public void function resolveGone(
        required numeric goneID,
        required string  resolution
    ) {
        var allowedResolutions = ["deleted", "kept"];
        if (!arrayFindNoCase(allowedResolutions, trim(arguments.resolution))) {
            throw(type="Application", message="Invalid gone resolution value.");
        }
        executeQueryWithRetry(
            "UPDATE UHSyncGone
             SET Resolution = :res, ResolvedAt = SYSUTCDATETIME()
             WHERE GoneID = :id",
            {
                id  = { value=goneID,           cfsqltype="cf_sql_integer"  },
                res = { value=trim(resolution), cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Mark a new-user record as resolved. resolution must be 'imported' or 'ignored'. */
    public void function resolveNew(
        required numeric newID,
        required string  resolution
    ) {
        var allowedResolutions = ["imported", "ignored"];
        if (!arrayFindNoCase(allowedResolutions, trim(arguments.resolution))) {
            throw(type="Application", message="Invalid new-user resolution value.");
        }
        executeQueryWithRetry(
            "UPDATE UHSyncNew
             SET Resolution = :res, ResolvedAt = SYSUTCDATETIME()
             WHERE NewID = :id",
            {
                id  = { value=newID,            cfsqltype="cf_sql_integer"  },
                res = { value=trim(resolution), cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Return a single diff row by DiffID (as struct). */
    public struct function getDiffByID( required numeric diffID ) {
        var qry = executeQueryWithRetry(
            "SELECT DiffID, RunID, UserID, FieldName, LocalValue, ApiValue, Resolution
             FROM UHSyncDiffs WHERE DiffID = :id",
            { id = { value=diffID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    /** Return a single gone row by GoneID (as struct). */
    public struct function getGoneByID( required numeric goneID ) {
        var qry = executeQueryWithRetry(
            "SELECT GoneID, RunID, UserID, Resolution
             FROM UHSyncGone WHERE GoneID = :id",
            { id = { value=goneID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    /** Return a single new row by NewID (as struct). */
    public struct function getNewByID( required numeric newID ) {
        var qry = executeQueryWithRetry(
            "SELECT NewID, RunID, UHApiID, FirstName, LastName, Email, Title, Department, Phone, RawJson, Resolution
             FROM UHSyncNew WHERE NewID = :id",
            { id = { value=newID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

}
