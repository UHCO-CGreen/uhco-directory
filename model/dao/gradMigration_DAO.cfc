component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // APP CONFIG
    // ══════════════════════════════════════════════════════════════════════════

    /** Read a config value by key. Returns empty string if not found. */
    public string function getConfigValue( required string configKey ) {
        var qry = executeQueryWithRetry(
            "SELECT ConfigValue FROM AppConfig WHERE ConfigKey = :key",
            { key = { value=arguments.configKey, cfsqltype="cf_sql_nvarchar" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return (qry.recordCount > 0) ? qry.ConfigValue : "";
    }

    /** Set a config value (upsert). */
    public void function setConfigValue( required string configKey, required string configValue ) {
        executeQueryWithRetry(
            "IF EXISTS (SELECT 1 FROM AppConfig WHERE ConfigKey = :key)
                UPDATE AppConfig SET ConfigValue = :val, UpdatedAt = GETDATE() WHERE ConfigKey = :key
             ELSE
                INSERT INTO AppConfig (ConfigKey, ConfigValue) VALUES (:key, :val)",
            {
                key = { value=arguments.configKey,   cfsqltype="cf_sql_nvarchar" },
                val = { value=arguments.configValue,  cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Convenience: is auto-execute enabled? */
    public boolean function getAutoExecuteEnabled() {
        return ( lCase(trim(getConfigValue("grad_migration_auto_execute"))) == "true" );
    }

    /** Convenience: set auto-execute toggle. */
    public void function setAutoExecuteEnabled( required boolean enabled ) {
        setConfigValue("grad_migration_auto_execute", arguments.enabled ? "true" : "false");
    }

    /** Convenience: get notification email. */
    public string function getNotifyEmail() {
        return trim(getConfigValue("grad_migration_notify_email"));
    }

    /** Convenience: set notification email. */
    public void function setNotifyEmail( required string email ) {
        setConfigValue("grad_migration_notify_email", trim(arguments.email));
    }

    // ══════════════════════════════════════════════════════════════════════════
    // RUN MANAGEMENT
    // ══════════════════════════════════════════════════════════════════════════

    /** Create a new migration run. Returns RunID. */
    public numeric function createRun(
        required numeric gradYear,
        required string  mode,
        required string  triggeredBy
    ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO GradMigrationRuns (GradYear, Mode, TriggeredBy)
             OUTPUT INSERTED.RunID
             VALUES (:yr, :mode, :by)",
            {
                yr   = { value=arguments.gradYear,    cfsqltype="cf_sql_integer"  },
                mode = { value=arguments.mode,        cfsqltype="cf_sql_nvarchar" },
                by   = { value=arguments.triggeredBy, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.RunID;
    }

    /** Update run status and set CompletedAt when finishing. */
    public void function updateRunStatus( required numeric runID, required string status ) {
        var setCompleted = ( listFindNoCase("completed,completed_w_errors,failed", arguments.status) )
            ? ", CompletedAt = GETDATE()" : "";
        executeQueryWithRetry(
            "UPDATE GradMigrationRuns SET Status = :st #setCompleted# WHERE RunID = :id",
            {
                id = { value=arguments.runID,  cfsqltype="cf_sql_integer"  },
                st = { value=arguments.status, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Update run totals after processing. */
    public void function updateRunTotals(
        required numeric runID,
        required numeric totalTargeted,
        required numeric totalMigrated,
        required numeric totalErrors
    ) {
        executeQueryWithRetry(
            "UPDATE GradMigrationRuns
             SET TotalTargeted = :t, TotalMigrated = :m, TotalErrors = :e
             WHERE RunID = :id",
            {
                id = { value=arguments.runID,          cfsqltype="cf_sql_integer" },
                t  = { value=arguments.totalTargeted,  cfsqltype="cf_sql_integer" },
                m  = { value=arguments.totalMigrated,  cfsqltype="cf_sql_integer" },
                e  = { value=arguments.totalErrors,    cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Mark notification as sent. */
    public void function markNotificationSent( required numeric runID ) {
        executeQueryWithRetry(
            "UPDATE GradMigrationRuns SET NotificationSent = 1 WHERE RunID = :id",
            { id = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Return the latest run (empty struct if none). */
    public struct function getLatestRun() {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 * FROM GradMigrationRuns ORDER BY RunID DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        if ( qry.recordCount == 0 ) return {};
        var rows = queryToArray(qry);
        return rows[1];
    }

    /** Return the latest completed run for a given grad year (empty struct if none). */
    public struct function getCompletedRunForYear( required numeric gradYear ) {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 * FROM GradMigrationRuns
             WHERE GradYear = :yr AND Status = 'completed'
             ORDER BY RunID DESC",
            { yr = { value=arguments.gradYear, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        if ( qry.recordCount == 0 ) return {};
        var rows = queryToArray(qry);
        return rows[1];
    }

    /** Return recent N runs. */
    public array function getRecentRuns( numeric maxRuns=10 ) {
        var topN = val(arguments.maxRuns) > 0 ? val(arguments.maxRuns) : 10;
        var qry = executeQueryWithRetry(
            "SELECT TOP #topN# * FROM GradMigrationRuns ORDER BY RunID DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /** Return a single run by ID (empty struct if not found). */
    public struct function getRunByID( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM GradMigrationRuns WHERE RunID = :id",
            { id = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        if ( qry.recordCount == 0 ) return {};
        var rows = queryToArray(qry);
        return rows[1];
    }

    /** Mark a run as rolled back. */
    public void function markRunRolledBack( required numeric runID, required string rolledBackBy ) {
        executeQueryWithRetry(
            "UPDATE GradMigrationRuns
             SET Status = 'rolled_back', RolledBackAt = GETDATE(), RolledBackBy = :by
             WHERE RunID = :id",
            {
                id = { value=arguments.runID,         cfsqltype="cf_sql_integer"  },
                by = { value=arguments.rolledBackBy, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DETAIL RECORDS
    // ══════════════════════════════════════════════════════════════════════════

    /** Insert a detail record. Returns DetailID. */
    public numeric function insertDetail(
        required numeric runID,
        required numeric userID,
        required numeric previousFlagID,
        required numeric newFlagID,
        required string  previousTitle1,
        required string  newTitle1
    ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO GradMigrationDetails
                (RunID, UserID, PreviousFlagID, NewFlagID, PreviousTitle1, NewTitle1)
             OUTPUT INSERTED.DetailID
             VALUES (:run, :uid, :prevFlag, :newFlag, :prevTitle, :newTitle)",
            {
                run       = { value=arguments.runID,           cfsqltype="cf_sql_integer"  },
                uid       = { value=arguments.userID,          cfsqltype="cf_sql_integer"  },
                prevFlag  = { value=arguments.previousFlagID,  cfsqltype="cf_sql_integer"  },
                newFlag   = { value=arguments.newFlagID,       cfsqltype="cf_sql_integer"  },
                prevTitle = { value=arguments.previousTitle1,  cfsqltype="cf_sql_nvarchar" },
                newTitle  = { value=arguments.newTitle1,       cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.DetailID;
    }

    /** Update a detail record's status, counts, and optional error. */
    public void function updateDetailStatus(
        required numeric detailID,
        required string  status,
        numeric exclusionsAdded   = 0,
        numeric exclusionsRemoved = 0,
        string  errorMessage      = ""
    ) {
        executeQueryWithRetry(
            "UPDATE GradMigrationDetails
             SET Status            = :st,
                 ExclusionsAdded   = :ea,
                 ExclusionsRemoved = :er,
                 ErrorMessage      = :err
             WHERE DetailID = :id",
            {
                id  = { value=arguments.detailID,          cfsqltype="cf_sql_integer"  },
                st  = { value=arguments.status,            cfsqltype="cf_sql_nvarchar" },
                ea  = { value=arguments.exclusionsAdded,   cfsqltype="cf_sql_integer"  },
                er  = { value=arguments.exclusionsRemoved, cfsqltype="cf_sql_integer"  },
                err = { value=arguments.errorMessage,      cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Bulk-mark migrated/error details as rolled_back for a given run. */
    public void function markDetailsRolledBack( required numeric runID ) {
        executeQueryWithRetry(
            "UPDATE GradMigrationDetails SET Status = 'rolled_back'
             WHERE RunID = :id AND Status IN ('migrated','error')",
            { id = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Return all detail records for a run (joined with user name). */
    public array function getDetailsByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT d.*, u.FirstName, u.LastName, u.EmailPrimary
             FROM   GradMigrationDetails d
             INNER JOIN Users u ON u.UserID = d.UserID
             WHERE  d.RunID = :id
             ORDER BY u.LastName, u.FirstName",
            { id = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // STUDENT QUERIES
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Return all active users who have the 'current-student' flag
     * and a matching CurrentGradYear.
     */
    public array function getGraduatingStudents( required numeric gradYear ) {
        var qry = executeQueryWithRetry(
            "SELECT u.UserID, u.FirstName, u.LastName, u.EmailPrimary,
                                        u.Title1,
                                        cnet.ExternalValue AS CougarNetID,
                    uai.CurrentGradYear,
                    uf.FlagID AS CurrentStudentFlagID
             FROM   Users u
             INNER JOIN UserFlagAssignments ufa ON ufa.UserID = u.UserID
             INNER JOIN UserFlags           uf  ON uf.FlagID  = ufa.FlagID
                                               AND LOWER(TRIM(uf.FlagName)) = 'current-student'
             INNER JOIN UserAcademicInfo    uai ON uai.UserID = u.UserID
                         OUTER APPLY (
                                 SELECT TOP 1 ue.ExternalValue
                                 FROM UserExternalIDs ue
                                 INNER JOIN ExternalSystems es ON es.SystemID = ue.SystemID
                                 WHERE ue.UserID = u.UserID
                                     AND LOWER(TRIM(es.SystemName)) = 'cougarnet'
                                 ORDER BY ue.ExternalValue
                         ) cnet
             WHERE  uai.CurrentGradYear = :yr
               AND  u.Active = 1
             ORDER BY u.LastName, u.FirstName",
            { yr = { value=arguments.gradYear, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DATA QUALITY EXCLUSIONS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Add alumni-specific data quality exclusion codes for a single user.
     * Uses INSERT ... WHERE NOT EXISTS to skip existing rows.
     * Returns the number of rows inserted.
     */
    public numeric function addAlumniExclusions( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO DataQualityExclusions (UserID, IssueCode, CreatedAt)
             SELECT :uid, codes.IssueCode, GETDATE()
             FROM (
                 SELECT 'missing_uh_api_id'   AS IssueCode
                 UNION ALL SELECT 'missing_email_primary'
                 UNION ALL SELECT 'missing_room'
                 UNION ALL SELECT 'missing_building'
                 UNION ALL SELECT 'missing_phone'
                 UNION ALL SELECT 'missing_degrees'
                 UNION ALL SELECT 'missing_cougarnet'
                 UNION ALL SELECT 'missing_peoplesoft'
                 UNION ALL SELECT 'missing_legacy_id'
             ) AS codes(IssueCode)
             WHERE NOT EXISTS (
                 SELECT 1 FROM DataQualityExclusions x
                 WHERE x.UserID = :uid2 AND x.IssueCode = codes.IssueCode
             )",
            {
                uid  = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                uid2 = { value=arguments.userID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.recordCount ?: 0);
    }

    /**
     * Remove current-student-specific exclusion codes for a single user.
     * Only removes codes that are student-specific but NOT alumni-specific.
     * Returns the number of rows deleted.
     */
    public numeric function removeStudentExclusions( required numeric userID ) {
        // Student-only codes: missing_degrees, missing_phone, missing_building, missing_room
        // All 4 of these are also in the alumni set, so during migration
        // they will be covered by addAlumniExclusions. We still remove them
        // first so addAlumniExclusions re-inserts with a current timestamp.
        var qry = executeQueryWithRetry(
            "DELETE FROM DataQualityExclusions
             WHERE UserID = :uid
                             AND IssueCode IN ('missing_degrees','missing_phone','missing_building','missing_room')",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
                return val(qry.recordCount ?: 0);
    }

    /**
     * Remove alumni-specific exclusion codes for a single user (rollback).
     * Only removes the codes that were added as part of the migration.
     * Returns the number of rows deleted.
     */
    public numeric function removeAlumniExclusions( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "DELETE FROM DataQualityExclusions
             WHERE UserID = :uid
               AND IssueCode IN (
                   'missing_uh_api_id','missing_email_primary','missing_room',
                   'missing_building','missing_phone','missing_degrees',
                   'missing_cougarnet','missing_peoplesoft','missing_legacy_id'
               )",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.recordCount ?: 0);
    }

    /**
     * Re-add current-student exclusion codes for a single user (rollback).
     * Returns the number of rows inserted.
     */
    public numeric function addStudentExclusions( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO DataQualityExclusions (UserID, IssueCode, CreatedAt)
             SELECT :uid, codes.IssueCode, GETDATE()
             FROM (
                 SELECT 'missing_degrees'  AS IssueCode
                 UNION ALL SELECT 'missing_phone'
                 UNION ALL SELECT 'missing_building'
                 UNION ALL SELECT 'missing_room'
             ) AS codes(IssueCode)
             WHERE NOT EXISTS (
                 SELECT 1 FROM DataQualityExclusions x
                 WHERE x.UserID = :uid2 AND x.IssueCode = codes.IssueCode
             )",
            {
                uid  = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                uid2 = { value=arguments.userID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.recordCount ?: 0);
    }

}
