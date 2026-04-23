component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    /** Insert a new run record, return its RunID. */
    public numeric function createRun( required string triggeredBy ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO DataQualityRuns (TriggeredBy) OUTPUT INSERTED.RunID VALUES (:by)",
            { by = { value=arguments.triggeredBy, cfsqltype="cf_sql_nvarchar" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.RunID;
    }

    /** Update the totals on a completed run. */
    public void function updateRunTotals(
        required numeric runID,
        required numeric totalUsers,
        required numeric totalIssues
    ) {
        executeQueryWithRetry(
            "UPDATE DataQualityRuns SET TotalUsers = :u, TotalIssues = :i WHERE RunID = :id",
            {
                id = { value=runID,        cfsqltype="cf_sql_integer" },
                u  = { value=totalUsers,   cfsqltype="cf_sql_integer" },
                i  = { value=totalIssues,  cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    /** Run the full audit SQL and insert all issues for the given run. Returns the count of issues inserted. */
    public numeric function runAuditAndInsert( required numeric runID ) {
        executeQueryWithRetry(
            "
            INSERT INTO DataQualityIssues (RunID, UserID, IssueCode)
            SELECT :runID, UserID, IssueCode FROM (

                SELECT UserID, 'missing_uh_api_id'       AS IssueCode FROM Users WHERE ISNULL(UH_API_ID,'')      = ''
                UNION ALL
                                SELECT u.UserID, 'missing_primary_alias'
                                FROM Users u
                                WHERE NOT EXISTS (
                                        SELECT 1
                                        FROM UserAliases ua
                                        WHERE ua.UserID = u.UserID
                                            AND ISNULL(ua.IsActive, 0) = 1
                                            AND ISNULL(ua.IsPrimary, 0) = 1
                                )
                                UNION ALL
                SELECT UserID, 'missing_email_primary'                  FROM Users WHERE ISNULL(EmailPrimary,'')  = ''
                UNION ALL
                SELECT UserID, 'missing_title1'                         FROM Users WHERE ISNULL(Title1,'')        = ''
                UNION ALL
                SELECT UserID, 'missing_room'                           FROM Users WHERE ISNULL(Room,'')          = ''
                UNION ALL
                SELECT UserID, 'missing_building'                       FROM Users WHERE ISNULL(Building,'')      = ''
                UNION ALL

                -- Zero flags
                SELECT u.UserID, 'no_flags'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserFlagAssignments ufa WHERE ufa.UserID = u.UserID
                )
                UNION ALL

                -- Zero orgs
                SELECT u.UserID, 'no_orgs'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserOrganizations uo WHERE uo.UserID = u.UserID
                )
                UNION ALL

                -- Missing CougarNet external ID
                SELECT u.UserID, 'missing_cougarnet'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserExternalIDs uei
                    INNER JOIN ExternalSystems es ON uei.SystemID = es.SystemID
                    WHERE uei.UserID = u.UserID
                      AND LOWER(es.SystemName) LIKE '%cougarnet%'
                      AND ISNULL(uei.ExternalValue,'') <> ''
                )
                UNION ALL

                -- Missing PeopleSoft external ID
                SELECT u.UserID, 'missing_peoplesoft'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserExternalIDs uei
                    INNER JOIN ExternalSystems es ON uei.SystemID = es.SystemID
                    WHERE uei.UserID = u.UserID
                      AND LOWER(es.SystemName) LIKE '%peoplesoft%'
                      AND ISNULL(uei.ExternalValue,'') <> ''
                )
                UNION ALL

                -- Missing Legacy ID external ID
                SELECT u.UserID, 'missing_legacy_id'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserExternalIDs uei
                    INNER JOIN ExternalSystems es ON uei.SystemID = es.SystemID
                    WHERE uei.UserID = u.UserID
                      AND LOWER(es.SystemName) LIKE '%legacy%'
                      AND ISNULL(uei.ExternalValue,'') <> ''
                )
                UNION ALL

                -- Missing CurrentGradYear — Current-Student flag holders only
                SELECT u.UserID, 'missing_grad_year'
                FROM Users u
                WHERE EXISTS (
                    SELECT 1 FROM UserFlagAssignments ufa
                    INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                    WHERE ufa.UserID = u.UserID AND uf.FlagName = 'Current-Student'
                )
                AND NOT EXISTS (
                    SELECT 1 FROM UserAcademicInfo uai
                    WHERE uai.UserID = u.UserID
                      AND uai.CurrentGradYear IS NOT NULL
                      AND uai.CurrentGradYear > 0
                )
                UNION ALL

                -- Missing Phone
                SELECT UserID, 'missing_phone' FROM Users WHERE ISNULL(Phone,'') = ''
                UNION ALL

                -- Missing Degrees
                SELECT UserID, 'missing_degrees' FROM Users WHERE ISNULL(Degrees,'') = ''
                UNION ALL

                -- No images
                SELECT u.UserID, 'no_images'
                FROM Users u
                WHERE NOT EXISTS (
                    SELECT 1 FROM UserImages ui WHERE ui.UserID = u.UserID
                )

            ) AS Issues
            -- Filter out any user+code combos the admin has excluded
            WHERE NOT EXISTS (
                SELECT 1 FROM DataQualityExclusions dqe
                WHERE dqe.UserID = Issues.UserID AND dqe.IssueCode = Issues.IssueCode
            )
            ",
            { runID = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=120 }
        );

        var cntQry = executeQueryWithRetry(
            "SELECT COUNT(*) AS cnt FROM DataQualityIssues WHERE RunID = :runID",
            { runID = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return cntQry.cnt;
    }

    /** Total user count in the Users table. */
    public numeric function getTotalUserCount() {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS cnt FROM Users",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.cnt;
    }

    /** Most recent N runs. */
    public array function getRecentRuns( numeric limit=10 ) {
        var qry = executeQueryWithRetry(
            "SELECT TOP(:lim) RunID, RunAt, TriggeredBy, TotalUsers, TotalIssues
             FROM DataQualityRuns ORDER BY RunAt DESC",
            { lim = { value=arguments.limit, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /** Issue counts grouped by type for a given run. */
    public array function getSummaryByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "SELECT IssueCode, COUNT(*) AS IssueCount
             FROM DataQualityIssues WHERE RunID = :runID
             GROUP BY IssueCode ORDER BY IssueCount DESC",
            { runID = { value=arguments.runID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /**
     * Users with issues for a run, one row per user, all issue codes aggregated.
     * Optionally filter to a single issue code.
     */
    public array function getUserDetailByRun( required numeric runID, string filterCode="" ) {
        var params = { runID = { value=arguments.runID, cfsqltype="cf_sql_integer" } };
        var codeFilter = "";
        if (len(trim(arguments.filterCode))) {
            codeFilter = " AND dqi.IssueCode = :issueCode";
            params["issueCode"] = { value=trim(arguments.filterCode), cfsqltype="cf_sql_nvarchar" };
        }
        var qry = executeQueryWithRetry(
            "SELECT dqi.UserID,
                    COALESCE(pa.FirstName, u.FirstName) AS FirstName,
                    COALESCE(pa.LastName, u.LastName) AS LastName,
                    u.EmailPrimary, u.UH_API_ID,
                    STRING_AGG(dqi.IssueCode, ',') WITHIN GROUP (ORDER BY dqi.IssueCode) AS IssueCodes,
                    COUNT(*) AS IssueCount
             FROM DataQualityIssues dqi
             INNER JOIN Users u ON dqi.UserID = u.UserID
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
             WHERE dqi.RunID = :runID" & codeFilter & "
             GROUP BY dqi.UserID, COALESCE(pa.FirstName, u.FirstName), COALESCE(pa.LastName, u.LastName), u.EmailPrimary, u.UH_API_ID
             ORDER BY COUNT(*) DESC, COALESCE(pa.LastName, u.LastName), COALESCE(pa.FirstName, u.FirstName)",
            params,
            { datasource=variables.datasource, timeout=60 }
        );
        return queryToArray(qry);
    }

    /** Return all excluded issue codes for a user as an array of strings. */
    public array function getExclusionsForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT IssueCode FROM DataQualityExclusions WHERE UserID = :uid ORDER BY IssueCode",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        var result = [];
        for (var i = 1; i <= qry.recordCount; i++) {
            arrayAppend(result, qry.IssueCode[i]);
        }
        return result;
    }

    /**
     * Replace all exclusions for a user with the supplied array of issue codes.
     * Pass an empty array to clear all exclusions.
     */
    public void function saveExclusionsForUser( required numeric userID, required array issueCodes ) {
        executeQueryWithRetry(
            "DELETE FROM DataQualityExclusions WHERE UserID = :uid",
            { uid = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        for (var code in arguments.issueCodes) {
            code = trim(code);
            if (!len(code)) continue;
            executeQueryWithRetry(
                "INSERT INTO DataQualityExclusions (UserID, IssueCode) VALUES (:uid, :code)",
                {
                    uid  = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                    code = { value=code,             cfsqltype="cf_sql_nvarchar" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

}
