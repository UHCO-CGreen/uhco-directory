component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public numeric function createRun( required string triggeredBy ) {
        var qry = executeQueryWithRetry(
            "INSERT INTO DuplicateUserRuns (TriggeredBy, Status) OUTPUT INSERTED.RunID VALUES (:by, 'running')",
            { by = { value=trim(arguments.triggeredBy ?: 'manual'), cfsqltype='cf_sql_varchar' } },
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.RunID);
    }

    public void function completeRun(
        required numeric runID,
        required numeric totalUsers,
        required numeric totalPairs,
        string status = "completed",
        string errorMessage = ""
    ) {
        executeQueryWithRetry(
            "
            UPDATE DuplicateUserRuns
            SET CompletedAt = GETDATE(),
                TotalUsers = :totalUsers,
                TotalPairs = :totalPairs,
                Status = :status,
                ErrorMessage = :errorMessage
            WHERE RunID = :runID
            ",
            {
                runID = { value=arguments.runID, cfsqltype='cf_sql_integer' },
                totalUsers = { value=arguments.totalUsers, cfsqltype='cf_sql_integer' },
                totalPairs = { value=arguments.totalPairs, cfsqltype='cf_sql_integer' },
                status = { value=left(trim(arguments.status ?: 'completed'), 20), cfsqltype='cf_sql_varchar' },
                errorMessage = {
                    value=left(trim(arguments.errorMessage ?: ''), 1000),
                    cfsqltype='cf_sql_nvarchar',
                    null=!len(trim(arguments.errorMessage ?: ''))
                }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public numeric function getTotalUserCount() {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS CNT FROM Users",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.CNT);
    }

    public struct function getUserFlagModeMap() {
        var qry = executeQueryWithRetry(
            "
            SELECT
                u.UserID,
                MAX(CASE WHEN LOWER(ISNULL(uf.FlagName, '')) = 'alumni' THEN 1 ELSE 0 END) AS IsAlumni,
                MAX(CASE WHEN LOWER(ISNULL(uf.FlagName, '')) IN ('faculty-fulltime', 'faculty-adjunct') THEN 1 ELSE 0 END) AS IsFaculty,
                MAX(CASE WHEN LOWER(ISNULL(uf.FlagName, '')) IN ('staff', 'temporary-staff') THEN 1 ELSE 0 END) AS IsStaff,
                MAX(CASE
                    WHEN uf.FlagID IS NULL THEN 0
                    WHEN LOWER(ISNULL(uf.FlagName, '')) IN ('alumni', 'faculty-fulltime', 'faculty-adjunct') THEN 0
                    ELSE 1
                END) AS HasOther
            FROM Users u
            LEFT JOIN UserFlagAssignments ufa ON ufa.UserID = u.UserID
            LEFT JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
            GROUP BY u.UserID
            ",
            {},
            { datasource=variables.datasource, timeout=60 }
        );

        var rows = queryToArray(qry);
        var result = {};

        for (var row in rows) {
            result[toString(val(row.USERID ?: 0))] = {
                isAlumni = val(row.ISALUMNI ?: 0) GT 0,
                isFaculty = val(row.ISFACULTY ?: 0) GT 0,
                isStaff = val(row.ISSTAFF ?: 0) GT 0,
                hasOther = val(row.HASOTHER ?: 0) GT 0
            };
        }

        return result;
    }

    public struct function getExternalSystemLabelMap() {
        var qry = executeQueryWithRetry(
            "
            SELECT SystemID, SystemName
            FROM ExternalSystems
            ",
            {},
            { datasource=variables.datasource, timeout=30 }
        );

        var rows = queryToArray(qry);
        var result = {};

        for (var row in rows) {
            var id = val(row.SYSTEMID ?: 0);
            var name = trim(row.SYSTEMNAME ?: "");

            if (id GT 0 && len(name)) {
                result[toString(id)] = name;
            }
        }

        return result;
    }

    public array function findDuplicateSignalsQuick() {
        var qry = executeQueryWithRetry(
            "
            WITH SignalRows AS (
                -- Users table: exact normalized first+last name.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_name' AS SignalType,
                    LOWER(LTRIM(RTRIM(u1.FirstName))) + '|' + LOWER(LTRIM(RTRIM(u1.LastName))) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.LastName, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.FirstName, ''))), '') IS NOT NULL
                  AND NULLIF(LTRIM(RTRIM(ISNULL(u1.LastName, ''))), '') IS NOT NULL

                UNION ALL

                -- Users table: primary email match.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_email_primary' AS SignalType,
                    LOWER(LTRIM(RTRIM(u1.EmailPrimary))) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.EmailPrimary, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.EmailPrimary, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.EmailPrimary, ''))), '') IS NOT NULL

                UNION ALL

                -- Users table: shared UH_API_ID.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_uh_api_id' AS SignalType,
                    LTRIM(RTRIM(u1.UH_API_ID)) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LTRIM(RTRIM(ISNULL(u1.UH_API_ID, ''))) = LTRIM(RTRIM(ISNULL(u2.UH_API_ID, '')))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.UH_API_ID, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAliases table: exact alias first+last match.
                SELECT
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua1.UserID ELSE ua2.UserID END AS UserID_A,
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua2.UserID ELSE ua1.UserID END AS UserID_B,
                    'aliases_name' AS SignalType,
                    LOWER(LTRIM(RTRIM(ua1.FirstName))) + '|' + LOWER(LTRIM(RTRIM(ua1.LastName))) AS SignalValue
                FROM UserAliases ua1
                INNER JOIN UserAliases ua2
                    ON ua1.UserID < ua2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(ua1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(ua2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(ua1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(ua2.LastName, ''))))
                WHERE ISNULL(ua1.IsActive, 1) = 1
                  AND ISNULL(ua2.IsActive, 1) = 1
                  AND NULLIF(LTRIM(RTRIM(ISNULL(ua1.FirstName, ''))), '') IS NOT NULL
                  AND NULLIF(LTRIM(RTRIM(ISNULL(ua1.LastName, ''))), '') IS NOT NULL

                UNION ALL

                -- UserEmails table: any shared email address.
                SELECT
                    CASE WHEN e1.UserID < e2.UserID THEN e1.UserID ELSE e2.UserID END AS UserID_A,
                    CASE WHEN e1.UserID < e2.UserID THEN e2.UserID ELSE e1.UserID END AS UserID_B,
                    'emails_address' AS SignalType,
                    LOWER(LTRIM(RTRIM(e1.EmailAddress))) AS SignalValue
                FROM UserEmails e1
                INNER JOIN UserEmails e2
                    ON e1.UserID < e2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(e1.EmailAddress, '')))) = LOWER(LTRIM(RTRIM(ISNULL(e2.EmailAddress, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(e1.EmailAddress, ''))), '') IS NOT NULL

                UNION ALL

                -- UserPhone table: normalized phone number match.
                SELECT
                    CASE WHEN p1.UserID < p2.UserID THEN p1.UserID ELSE p2.UserID END AS UserID_A,
                    CASE WHEN p1.UserID < p2.UserID THEN p2.UserID ELSE p1.UserID END AS UserID_B,
                    'phones_number' AS SignalType,
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p1.PhoneNumber, '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '') AS SignalValue
                FROM UserPhone p1
                INNER JOIN UserPhone p2
                    ON p1.UserID < p2.UserID
                   AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                       = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p2.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                WHERE NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', ''), '') IS NOT NULL

                UNION ALL

                -- UserExternalIDs table: same external value for same system.
                SELECT
                    CASE WHEN x1.UserID < x2.UserID THEN x1.UserID ELSE x2.UserID END AS UserID_A,
                    CASE WHEN x1.UserID < x2.UserID THEN x2.UserID ELSE x1.UserID END AS UserID_B,
                    'external_ids' AS SignalType,
                    CAST(x1.SystemID AS VARCHAR(20)) + '|' + LTRIM(RTRIM(x1.ExternalValue)) AS SignalValue
                FROM UserExternalIDs x1
                INNER JOIN UserExternalIDs x2
                    ON x1.UserID < x2.UserID
                   AND x1.SystemID = x2.SystemID
                   AND LTRIM(RTRIM(ISNULL(x1.ExternalValue, ''))) = LTRIM(RTRIM(ISNULL(x2.ExternalValue, '')))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(x1.ExternalValue, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAcademicInfo table: same name, different grad year (possible alumni multi-year split).
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'academic_multi_grad_year' AS SignalType,
                    CAST(a1.CurrentGradYear AS VARCHAR(10)) + '|' + CAST(a2.CurrentGradYear AS VARCHAR(10)) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.LastName, ''))))
                INNER JOIN UserAcademicInfo a1 ON a1.UserID = u1.UserID
                INNER JOIN UserAcademicInfo a2 ON a2.UserID = u2.UserID
                WHERE ISNULL(a1.CurrentGradYear, 0) > 0
                  AND ISNULL(a2.CurrentGradYear, 0) > 0
                  AND a1.CurrentGradYear <> a2.CurrentGradYear
            )
            SELECT DISTINCT UserID_A, UserID_B, SignalType, SignalValue
            FROM SignalRows
            ",
            {},
            { datasource=variables.datasource, timeout=120 }
        );

        return queryToArray(qry);
    }

    public array function findDuplicateSignalsForStage( required string stage ) {
        var normalizedStage = lCase(trim(arguments.stage ?: ""));
        var sql = "";

        if (normalizedStage EQ "emails") {
            sql = "
                SELECT
                    CASE WHEN e1.UserID < e2.UserID THEN e1.UserID ELSE e2.UserID END AS UserID_A,
                    CASE WHEN e1.UserID < e2.UserID THEN e2.UserID ELSE e1.UserID END AS UserID_B,
                    'emails_address' AS SignalType,
                    LOWER(LTRIM(RTRIM(e1.EmailAddress))) AS SignalValue
                FROM UserEmails e1
                INNER JOIN UserEmails e2
                    ON e1.UserID < e2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(e1.EmailAddress, '')))) = LOWER(LTRIM(RTRIM(ISNULL(e2.EmailAddress, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(e1.EmailAddress, ''))), '') IS NOT NULL
            ";
        } else if (normalizedStage EQ "phones") {
            sql = "
                SELECT
                    CASE WHEN p1.UserID < p2.UserID THEN p1.UserID ELSE p2.UserID END AS UserID_A,
                    CASE WHEN p1.UserID < p2.UserID THEN p2.UserID ELSE p1.UserID END AS UserID_B,
                    'phones_number' AS SignalType,
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p1.PhoneNumber, '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '') AS SignalValue
                FROM UserPhone p1
                INNER JOIN UserPhone p2
                    ON p1.UserID < p2.UserID
                   AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                       = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p2.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                WHERE NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', ''), '') IS NOT NULL
            ";
        } else if (normalizedStage EQ "flags") {
            sql = "
                SELECT
                    CASE WHEN f1.UserID < f2.UserID THEN f1.UserID ELSE f2.UserID END AS UserID_A,
                    CASE WHEN f1.UserID < f2.UserID THEN f2.UserID ELSE f1.UserID END AS UserID_B,
                    'flags_shared' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(uf.FlagName, '')))) AS SignalValue
                FROM UserFlagAssignments f1
                INNER JOIN UserFlagAssignments f2
                    ON f1.UserID < f2.UserID
                   AND f1.FlagID = f2.FlagID
                INNER JOIN UserFlags uf ON uf.FlagID = f1.FlagID
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(uf.FlagName, ''))), '') IS NOT NULL
            ";
        } else if (normalizedStage EQ "organizations") {
            sql = "
                SELECT
                    CASE WHEN o1.UserID < o2.UserID THEN o1.UserID ELSE o2.UserID END AS UserID_A,
                    CASE WHEN o1.UserID < o2.UserID THEN o2.UserID ELSE o1.UserID END AS UserID_B,
                    'organizations_shared' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(org.OrgName, '')))) AS SignalValue
                FROM UserOrganizations o1
                INNER JOIN UserOrganizations o2
                    ON o1.UserID < o2.UserID
                   AND o1.OrgID = o2.OrgID
                INNER JOIN Organizations org ON org.OrgID = o1.OrgID
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(org.OrgName, ''))), '') IS NOT NULL
            ";
        }

        if (!len(sql)) {
            return [];
        }

        var qry = executeQueryWithRetry(
            sql,
            {},
            { datasource=variables.datasource, timeout=120 }
        );

        return queryToArray(qry);
    }

    public array function findDuplicateSignals() {
        var qry = executeQueryWithRetry(
            "
            WITH SignalRows AS (
                -- Users table: exact normalized first+last name.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_name' AS SignalType,
                    LOWER(LTRIM(RTRIM(u1.FirstName))) + '|' + LOWER(LTRIM(RTRIM(u1.LastName))) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.LastName, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.FirstName, ''))), '') IS NOT NULL
                  AND NULLIF(LTRIM(RTRIM(ISNULL(u1.LastName, ''))), '') IS NOT NULL

                UNION ALL

                -- Users table: primary email match.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_email_primary' AS SignalType,
                    LOWER(LTRIM(RTRIM(u1.EmailPrimary))) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.EmailPrimary, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.EmailPrimary, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.EmailPrimary, ''))), '') IS NOT NULL

                UNION ALL

                -- Users table: shared UH_API_ID.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'users_uh_api_id' AS SignalType,
                    LTRIM(RTRIM(u1.UH_API_ID)) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LTRIM(RTRIM(ISNULL(u1.UH_API_ID, ''))) = LTRIM(RTRIM(ISNULL(u2.UH_API_ID, '')))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(u1.UH_API_ID, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAliases table: exact alias first+last match.
                SELECT
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua1.UserID ELSE ua2.UserID END AS UserID_A,
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua2.UserID ELSE ua1.UserID END AS UserID_B,
                    'aliases_name' AS SignalType,
                    LOWER(LTRIM(RTRIM(ua1.FirstName))) + '|' + LOWER(LTRIM(RTRIM(ua1.LastName))) AS SignalValue
                FROM UserAliases ua1
                INNER JOIN UserAliases ua2
                    ON ua1.UserID < ua2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(ua1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(ua2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(ua1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(ua2.LastName, ''))))
                WHERE ISNULL(ua1.IsActive, 1) = 1
                  AND ISNULL(ua2.IsActive, 1) = 1
                  AND NULLIF(LTRIM(RTRIM(ISNULL(ua1.FirstName, ''))), '') IS NOT NULL
                  AND NULLIF(LTRIM(RTRIM(ISNULL(ua1.LastName, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAliases table: matching display names.
                SELECT
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua1.UserID ELSE ua2.UserID END AS UserID_A,
                    CASE WHEN ua1.UserID < ua2.UserID THEN ua2.UserID ELSE ua1.UserID END AS UserID_B,
                    'aliases_display_name' AS SignalType,
                    LOWER(LTRIM(RTRIM(ua1.DisplayName))) AS SignalValue
                FROM UserAliases ua1
                INNER JOIN UserAliases ua2
                    ON ua1.UserID < ua2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(ua1.DisplayName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(ua2.DisplayName, ''))))
                WHERE ISNULL(ua1.IsActive, 1) = 1
                  AND ISNULL(ua2.IsActive, 1) = 1
                  AND NULLIF(LTRIM(RTRIM(ISNULL(ua1.DisplayName, ''))), '') IS NOT NULL

                UNION ALL

                -- UserEmails table: any shared email address.
                SELECT
                    CASE WHEN e1.UserID < e2.UserID THEN e1.UserID ELSE e2.UserID END AS UserID_A,
                    CASE WHEN e1.UserID < e2.UserID THEN e2.UserID ELSE e1.UserID END AS UserID_B,
                    'emails_address' AS SignalType,
                    LOWER(LTRIM(RTRIM(e1.EmailAddress))) AS SignalValue
                FROM UserEmails e1
                INNER JOIN UserEmails e2
                    ON e1.UserID < e2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(e1.EmailAddress, '')))) = LOWER(LTRIM(RTRIM(ISNULL(e2.EmailAddress, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(e1.EmailAddress, ''))), '') IS NOT NULL

                UNION ALL

                -- UserPhone table: normalized phone number match.
                SELECT
                    CASE WHEN p1.UserID < p2.UserID THEN p1.UserID ELSE p2.UserID END AS UserID_A,
                    CASE WHEN p1.UserID < p2.UserID THEN p2.UserID ELSE p1.UserID END AS UserID_B,
                    'phones_number' AS SignalType,
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(p1.PhoneNumber, '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '') AS SignalValue
                FROM UserPhone p1
                INNER JOIN UserPhone p2
                    ON p1.UserID < p2.UserID
                   AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                       = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p2.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                WHERE NULLIF(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(p1.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', ''), '') IS NOT NULL

                UNION ALL

                -- UserExternalIDs table: same external value for same system.
                SELECT
                    CASE WHEN x1.UserID < x2.UserID THEN x1.UserID ELSE x2.UserID END AS UserID_A,
                    CASE WHEN x1.UserID < x2.UserID THEN x2.UserID ELSE x1.UserID END AS UserID_B,
                    'external_ids' AS SignalType,
                    CAST(x1.SystemID AS VARCHAR(20)) + '|' + LTRIM(RTRIM(x1.ExternalValue)) AS SignalValue
                FROM UserExternalIDs x1
                INNER JOIN UserExternalIDs x2
                    ON x1.UserID < x2.UserID
                   AND x1.SystemID = x2.SystemID
                   AND LTRIM(RTRIM(ISNULL(x1.ExternalValue, ''))) = LTRIM(RTRIM(ISNULL(x2.ExternalValue, '')))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(x1.ExternalValue, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAddresses table: same address line/city/state tuple.
                SELECT
                    CASE WHEN a1.UserID < a2.UserID THEN a1.UserID ELSE a2.UserID END AS UserID_A,
                    CASE WHEN a1.UserID < a2.UserID THEN a2.UserID ELSE a1.UserID END AS UserID_B,
                    'addresses_location' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(a1.Address1, '')))) + '|' + LOWER(LTRIM(RTRIM(ISNULL(a1.City, '')))) + '|' + LOWER(LTRIM(RTRIM(ISNULL(a1.[State], '')))) AS SignalValue
                FROM UserAddresses a1
                INNER JOIN UserAddresses a2
                    ON a1.UserID < a2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(a1.Address1, '')))) = LOWER(LTRIM(RTRIM(ISNULL(a2.Address1, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(a1.City, '')))) = LOWER(LTRIM(RTRIM(ISNULL(a2.City, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(a1.[State], '')))) = LOWER(LTRIM(RTRIM(ISNULL(a2.[State], ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(a1.Address1, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAcademicInfo table: same name, different grad year (possible alumni multi-year split).
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'academic_multi_grad_year' AS SignalType,
                    CAST(a1.CurrentGradYear AS VARCHAR(10)) + '|' + CAST(a2.CurrentGradYear AS VARCHAR(10)) AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.LastName, ''))))
                INNER JOIN UserAcademicInfo a1 ON a1.UserID = u1.UserID
                INNER JOIN UserAcademicInfo a2 ON a2.UserID = u2.UserID
                WHERE ISNULL(a1.CurrentGradYear, 0) > 0
                  AND ISNULL(a2.CurrentGradYear, 0) > 0
                  AND a1.CurrentGradYear <> a2.CurrentGradYear

                UNION ALL

                -- UserFlagAssignments/UserFlags table: faculty + alumni split scenario.
                SELECT
                    CASE WHEN u1.UserID < u2.UserID THEN u1.UserID ELSE u2.UserID END AS UserID_A,
                    CASE WHEN u1.UserID < u2.UserID THEN u2.UserID ELSE u1.UserID END AS UserID_B,
                    'flags_faculty_alumni_split' AS SignalType,
                    'faculty|alumni' AS SignalValue
                FROM Users u1
                INNER JOIN Users u2
                    ON u1.UserID < u2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.FirstName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(u1.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(u2.LastName, ''))))
                WHERE EXISTS (
                    SELECT 1
                    FROM UserFlagAssignments ufa1
                    INNER JOIN UserFlags uf1 ON ufa1.FlagID = uf1.FlagID
                    WHERE ufa1.UserID = u1.UserID
                      AND LOWER(ISNULL(uf1.FlagName, '')) LIKE '%faculty%'
                )
                AND EXISTS (
                    SELECT 1
                    FROM UserFlagAssignments ufa2
                    INNER JOIN UserFlags uf2 ON ufa2.FlagID = uf2.FlagID
                    WHERE ufa2.UserID = u2.UserID
                      AND LOWER(ISNULL(uf2.FlagName, '')) LIKE '%alumni%'
                )

                UNION ALL

                -- UserOrganizations table: same organization assignment.
                SELECT
                    CASE WHEN o1.UserID < o2.UserID THEN o1.UserID ELSE o2.UserID END AS UserID_A,
                    CASE WHEN o1.UserID < o2.UserID THEN o2.UserID ELSE o1.UserID END AS UserID_B,
                    'organizations_shared' AS SignalType,
                    CAST(o1.OrgID AS VARCHAR(20)) AS SignalValue
                FROM UserOrganizations o1
                INNER JOIN UserOrganizations o2
                    ON o1.UserID < o2.UserID
                   AND o1.OrgID = o2.OrgID

                UNION ALL

                -- UserDegrees table: same degree+year combo.
                SELECT
                    CASE WHEN d1.UserID < d2.UserID THEN d1.UserID ELSE d2.UserID END AS UserID_A,
                    CASE WHEN d1.UserID < d2.UserID THEN d2.UserID ELSE d1.UserID END AS UserID_B,
                    'degrees_shared' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(d1.DegreeName, '')))) + '|' + LOWER(LTRIM(RTRIM(ISNULL(d1.GraduationYear, '')))) AS SignalValue
                FROM UserDegrees d1
                INNER JOIN UserDegrees d2
                    ON d1.UserID < d2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(d1.DegreeName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(d2.DegreeName, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(d1.GraduationYear, '')))) = LOWER(LTRIM(RTRIM(ISNULL(d2.GraduationYear, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(d1.DegreeName, ''))), '') IS NOT NULL

                UNION ALL

                -- UserAwards table: same award type/name.
                SELECT
                    CASE WHEN aw1.UserID < aw2.UserID THEN aw1.UserID ELSE aw2.UserID END AS UserID_A,
                    CASE WHEN aw1.UserID < aw2.UserID THEN aw2.UserID ELSE aw1.UserID END AS UserID_B,
                    'awards_shared' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(aw1.AwardType, '')))) + '|' + LOWER(LTRIM(RTRIM(ISNULL(aw1.AwardName, '')))) AS SignalValue
                FROM UserAwards aw1
                INNER JOIN UserAwards aw2
                    ON aw1.UserID < aw2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(aw1.AwardType, '')))) = LOWER(LTRIM(RTRIM(ISNULL(aw2.AwardType, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(aw1.AwardName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(aw2.AwardName, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(aw1.AwardName, ''))), '') IS NOT NULL

                UNION ALL

                -- UserImages table: same image URL.
                SELECT
                    CASE WHEN i1.UserID < i2.UserID THEN i1.UserID ELSE i2.UserID END AS UserID_A,
                    CASE WHEN i1.UserID < i2.UserID THEN i2.UserID ELSE i1.UserID END AS UserID_B,
                    'images_shared_url' AS SignalType,
                    LOWER(LTRIM(RTRIM(i1.ImageURL))) AS SignalValue
                FROM UserImages i1
                INNER JOIN UserImages i2
                    ON i1.UserID < i2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(i1.ImageURL, '')))) = LOWER(LTRIM(RTRIM(ISNULL(i2.ImageURL, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(i1.ImageURL, ''))), '') IS NOT NULL

                UNION ALL

                -- UserBio table: exact bio content match (longer snippets only).
                SELECT
                    CASE WHEN b1.UserID < b2.UserID THEN b1.UserID ELSE b2.UserID END AS UserID_A,
                    CASE WHEN b1.UserID < b2.UserID THEN b2.UserID ELSE b1.UserID END AS UserID_B,
                    'bio_shared_content' AS SignalType,
                    LOWER(LTRIM(RTRIM(b1.BioContent))) AS SignalValue
                FROM UserBio b1
                INNER JOIN UserBio b2
                    ON b1.UserID < b2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(b1.BioContent, '')))) = LOWER(LTRIM(RTRIM(ISNULL(b2.BioContent, ''))))
                WHERE LEN(LTRIM(RTRIM(ISNULL(b1.BioContent, '')))) >= 40

                UNION ALL

                -- UserStudentProfile table: same externship combination.
                SELECT
                    CASE WHEN s1.UserID < s2.UserID THEN s1.UserID ELSE s2.UserID END AS UserID_A,
                    CASE WHEN s1.UserID < s2.UserID THEN s2.UserID ELSE s1.UserID END AS UserID_B,
                    'student_profile_shared' AS SignalType,
                    LOWER(LTRIM(RTRIM(ISNULL(s1.FirstExternship, '')))) + '|' + LOWER(LTRIM(RTRIM(ISNULL(s1.SecondExternship, '')))) AS SignalValue
                FROM UserStudentProfile s1
                INNER JOIN UserStudentProfile s2
                    ON s1.UserID < s2.UserID
                   AND LOWER(LTRIM(RTRIM(ISNULL(s1.FirstExternship, '')))) = LOWER(LTRIM(RTRIM(ISNULL(s2.FirstExternship, ''))))
                   AND LOWER(LTRIM(RTRIM(ISNULL(s1.SecondExternship, '')))) = LOWER(LTRIM(RTRIM(ISNULL(s2.SecondExternship, ''))))
                WHERE NULLIF(LTRIM(RTRIM(ISNULL(s1.FirstExternship, ''))), '') IS NOT NULL
            )
            SELECT DISTINCT UserID_A, UserID_B, SignalType, SignalValue
            FROM SignalRows
            ",
            {},
            { datasource=variables.datasource, timeout=180 }
        );

        return queryToArray(qry);
    }

    public numeric function upsertPair(
        required numeric runID,
        required numeric userID_A,
        required numeric userID_B,
        required numeric confidenceScore,
        required string matchSignalsJSON
    ) {
        var userA = min(arguments.userID_A, arguments.userID_B);
        var userB = max(arguments.userID_A, arguments.userID_B);
        var existing = executeQueryWithRetry(
            "SELECT PairID, Status FROM DuplicateUserPairs WHERE UserID_A = :a AND UserID_B = :b",
            {
                a = { value=userA, cfsqltype='cf_sql_integer' },
                b = { value=userB, cfsqltype='cf_sql_integer' }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        if (existing.recordCount EQ 0) {
            var inserted = executeQueryWithRetry(
                "
                INSERT INTO DuplicateUserPairs (
                    FirstSeenRunID,
                    LastSeenRunID,
                    UserID_A,
                    UserID_B,
                    ConfidenceScore,
                    MatchSignals,
                    Status,
                    LastSeenAt,
                    CreatedAt,
                    UpdatedAt
                )
                OUTPUT INSERTED.PairID
                VALUES (
                    :runID,
                    :runID,
                    :userA,
                    :userB,
                    :score,
                    :signals,
                    'pending',
                    GETDATE(),
                    GETDATE(),
                    GETDATE()
                )
                ",
                {
                    runID = { value=arguments.runID, cfsqltype='cf_sql_integer' },
                    userA = { value=userA, cfsqltype='cf_sql_integer' },
                    userB = { value=userB, cfsqltype='cf_sql_integer' },
                    score = { value=arguments.confidenceScore, cfsqltype='cf_sql_integer' },
                    signals = { value=arguments.matchSignalsJSON, cfsqltype='cf_sql_nvarchar' }
                },
                { datasource=variables.datasource, timeout=30 }
            );
            return val(inserted.PairID);
        }

        var pairID = val(existing.PairID[1]);
        var status = lCase(trim(existing.Status[1] ?: "pending"));

        if (status EQ "pending") {
            executeQueryWithRetry(
                "
                UPDATE DuplicateUserPairs
                SET LastSeenRunID = :runID,
                    ConfidenceScore = :score,
                    MatchSignals = :signals,
                    LastSeenAt = GETDATE(),
                    UpdatedAt = GETDATE()
                WHERE PairID = :pairID
                ",
                {
                    runID = { value=arguments.runID, cfsqltype='cf_sql_integer' },
                    score = { value=arguments.confidenceScore, cfsqltype='cf_sql_integer' },
                    signals = { value=arguments.matchSignalsJSON, cfsqltype='cf_sql_nvarchar' },
                    pairID = { value=pairID, cfsqltype='cf_sql_integer' }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        } else {
            executeQueryWithRetry(
                "
                UPDATE DuplicateUserPairs
                SET LastSeenRunID = :runID,
                    LastSeenAt = GETDATE(),
                    UpdatedAt = GETDATE()
                WHERE PairID = :pairID
                ",
                {
                    runID = { value=arguments.runID, cfsqltype='cf_sql_integer' },
                    pairID = { value=pairID, cfsqltype='cf_sql_integer' }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }

        return pairID;
    }

    public struct function getLatestRun() {
        var runs = getRecentRuns(1);
        return arrayLen(runs) ? runs[1] : {};
    }

    public array function getRecentRuns( numeric limit = 10 ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP(:lim)
                RunID,
                RunAt,
                CompletedAt,
                TriggeredBy,
                TotalUsers,
                TotalPairs,
                Status,
                ErrorMessage
            FROM DuplicateUserRuns
            ORDER BY RunAt DESC
            ",
            { lim = { value=arguments.limit, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        return queryToArray(qry);
    }

    public struct function getRunByID( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT RunID, RunAt, CompletedAt, TriggeredBy, TotalUsers, TotalPairs, Status, ErrorMessage
            FROM DuplicateUserRuns
            WHERE RunID = :runID
            ",
            { runID = { value=arguments.runID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        if (qry.recordCount EQ 0) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public array function getPairsByRun( required numeric runID, string statusFilter = "" ) {
        var params = {
            runID = { value=arguments.runID, cfsqltype='cf_sql_integer' }
        };
        var statusSql = "";

        if (len(trim(arguments.statusFilter ?: ""))) {
            statusSql = " AND p.Status = :statusFilter";
            params.statusFilter = { value=lCase(trim(arguments.statusFilter)), cfsqltype='cf_sql_varchar' };
        }

        var qry = executeQueryWithRetry(
            "
            SELECT
                p.PairID,
                p.UserID_A,
                p.UserID_B,
                p.ConfidenceScore,
                p.MatchSignals,
                p.Status,
                p.LastSeenAt,
                u1.FirstName AS UserAFirstName,
                u1.LastName AS UserALastName,
                u1.EmailPrimary AS UserAEmail,
                u2.FirstName AS UserBFirstName,
                u2.LastName AS UserBLastName,
                u2.EmailPrimary AS UserBEmail,
                ISNULL(fa.FlagsA, '') AS UserAFlags,
                ISNULL(fb.FlagsB, '') AS UserBFlags,
                ISNULL(a1.CurrentGradYear, 0) AS UserAGradYear,
                ISNULL(a2.CurrentGradYear, 0) AS UserBGradYear
            FROM DuplicateUserPairs p
            INNER JOIN Users u1 ON u1.UserID = p.UserID_A
            INNER JOIN Users u2 ON u2.UserID = p.UserID_B
            LEFT JOIN UserAcademicInfo a1 ON a1.UserID = p.UserID_A
            LEFT JOIN UserAcademicInfo a2 ON a2.UserID = p.UserID_B
            OUTER APPLY (
                SELECT STRING_AGG(uf.FlagName, ', ') AS FlagsA
                FROM UserFlagAssignments ufa
                INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
                WHERE ufa.UserID = p.UserID_A
            ) fa
            OUTER APPLY (
                SELECT STRING_AGG(uf.FlagName, ', ') AS FlagsB
                FROM UserFlagAssignments ufb
                INNER JOIN UserFlags uf ON uf.FlagID = ufb.FlagID
                WHERE ufb.UserID = p.UserID_B
            ) fb
            WHERE p.LastSeenRunID = :runID" & statusSql & "
            ORDER BY
                CASE WHEN p.Status = 'pending' THEN 0 WHEN p.Status = 'ignored' THEN 1 ELSE 2 END,
                p.ConfidenceScore DESC,
                p.PairID DESC
            ",
            params,
            { datasource=variables.datasource, timeout=60 }
        );

        return queryToArray(qry);
    }

    public struct function getPairByID( required numeric pairID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT
                p.PairID,
                p.UserID_A,
                p.UserID_B,
                p.ConfidenceScore,
                p.MatchSignals,
                p.Status,
                p.LastSeenAt,
                p.LastSeenRunID,
                u1.FirstName AS UserAFirstName,
                u1.LastName AS UserALastName,
                u1.EmailPrimary AS UserAEmail,
                u2.FirstName AS UserBFirstName,
                u2.LastName AS UserBLastName,
                u2.EmailPrimary AS UserBEmail,
                ISNULL(fa.FlagsA, '') AS UserAFlags,
                ISNULL(fb.FlagsB, '') AS UserBFlags,
                ISNULL(a1.CurrentGradYear, 0) AS UserAGradYear,
                ISNULL(a2.CurrentGradYear, 0) AS UserBGradYear
            FROM DuplicateUserPairs p
            INNER JOIN Users u1 ON u1.UserID = p.UserID_A
            INNER JOIN Users u2 ON u2.UserID = p.UserID_B
            LEFT JOIN UserAcademicInfo a1 ON a1.UserID = p.UserID_A
            LEFT JOIN UserAcademicInfo a2 ON a2.UserID = p.UserID_B
            OUTER APPLY (
                SELECT STRING_AGG(uf.FlagName, ', ') AS FlagsA
                FROM UserFlagAssignments ufa
                INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
                WHERE ufa.UserID = p.UserID_A
            ) fa
            OUTER APPLY (
                SELECT STRING_AGG(uf.FlagName, ', ') AS FlagsB
                FROM UserFlagAssignments ufb
                INNER JOIN UserFlags uf ON uf.FlagID = ufb.FlagID
                WHERE ufb.UserID = p.UserID_B
            ) fb
            WHERE p.PairID = :pairID
            ",
            { pairID = { value=arguments.pairID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=60 }
        );

        if (qry.recordCount EQ 0) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public numeric function createMergeRecord(
        required numeric pairID,
        required numeric primaryUserID,
        required numeric secondaryUserID,
        numeric mergedByAdminUserID = 0,
        string mergeChoicesJSON = "{}",
        string notes = ""
    ) {
        var qry = executeQueryWithRetry(
            "
            INSERT INTO DuplicateUserMerges (
                PairID,
                PrimaryUserID,
                SecondaryUserID,
                MergedByAdminUserID,
                MergeChoices,
                Notes
            )
            OUTPUT INSERTED.MergeID
            VALUES (
                :pairID,
                :primaryUserID,
                :secondaryUserID,
                :mergedByAdminUserID,
                :mergeChoicesJSON,
                :notes
            )
            ",
            {
                pairID = { value=arguments.pairID, cfsqltype='cf_sql_integer' },
                primaryUserID = { value=arguments.primaryUserID, cfsqltype='cf_sql_integer' },
                secondaryUserID = { value=arguments.secondaryUserID, cfsqltype='cf_sql_integer' },
                mergedByAdminUserID = {
                    value=arguments.mergedByAdminUserID,
                    cfsqltype='cf_sql_integer',
                    null=val(arguments.mergedByAdminUserID) LTE 0
                },
                mergeChoicesJSON = { value=left(trim(arguments.mergeChoicesJSON ?: "{}"), 4000), cfsqltype='cf_sql_nvarchar' },
                notes = {
                    value=left(trim(arguments.notes ?: ''), 500),
                    cfsqltype='cf_sql_nvarchar',
                    null=!len(trim(arguments.notes ?: ''))
                }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return val(qry.MergeID);
    }

    public struct function consolidateUsers(
        required numeric primaryUserID,
        required numeric secondaryUserID,
        boolean deactivateSecondary = true
    ) {
        var qry = executeQueryWithRetry(
            "
            DECLARE @primaryUserID INT = :primaryUserID;
            DECLARE @secondaryUserID INT = :secondaryUserID;

            DECLARE @emailsMoved INT = 0, @emailsDeduped INT = 0;
            DECLARE @phonesMoved INT = 0, @phonesDeduped INT = 0;
            DECLARE @addressesMoved INT = 0, @addressesDeduped INT = 0;
            DECLARE @flagsMoved INT = 0, @flagsDeduped INT = 0;
            DECLARE @orgsMoved INT = 0, @orgsDeduped INT = 0;
            DECLARE @accessMoved INT = 0, @accessDeduped INT = 0;
            DECLARE @externalIDsMoved INT = 0, @externalIDsDeduped INT = 0;
            DECLARE @aliasesMoved INT = 0, @aliasesDeduped INT = 0;
            DECLARE @degreesMoved INT = 0, @degreesDeduped INT = 0;
            DECLARE @awardsMoved INT = 0, @awardsDeduped INT = 0;
            DECLARE @imagesMoved INT = 0, @imagesDeduped INT = 0;
            DECLARE @reviewSubmissionsMoved INT = 0;
            DECLARE @academicMoved INT = 0, @academicMerged INT = 0;
            DECLARE @bioMoved INT = 0, @bioMerged INT = 0;
            DECLARE @studentProfileMoved INT = 0, @studentProfileMerged INT = 0;
            DECLARE @secondaryDeactivated INT = 0;

            BEGIN TRY
                BEGIN TRANSACTION;

                -- Emails: move unique addresses, discard exact duplicates.
                DELETE se
                FROM UserEmails se
                WHERE se.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserEmails pe
                      WHERE pe.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pe.EmailAddress, '')))) = LOWER(LTRIM(RTRIM(ISNULL(se.EmailAddress, ''))))
                  );
                SET @emailsDeduped = @emailsDeduped + @@ROWCOUNT;

                UPDATE UserEmails
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @emailsMoved = @emailsMoved + @@ROWCOUNT;

                -- Phones: move unique normalized numbers, discard duplicates.
                DELETE sp
                FROM UserPhone sp
                WHERE sp.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserPhone pp
                      WHERE pp.UserID = @primaryUserID
                        AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(pp.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                            = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(sp.PhoneNumber, ''), '(', ''), ')', ''), '-', ''), ' ', ''), '.', ''), '+', '')
                  );
                SET @phonesDeduped = @phonesDeduped + @@ROWCOUNT;

                UPDATE UserPhone
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @phonesMoved = @phonesMoved + @@ROWCOUNT;

                -- Addresses: move unique rows by normalized full-address fingerprint.
                DELETE sa
                FROM UserAddresses sa
                WHERE sa.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserAddresses pa
                      WHERE pa.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.AddressType, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.AddressType, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.Address1, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.Address1, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.Address2, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.Address2, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.City, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.City, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.[State], '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.[State], ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.Zipcode, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.Zipcode, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.Building, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.Building, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.Room, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.Room, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.MailCode, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.MailCode, ''))))
                  );
                SET @addressesDeduped = @addressesDeduped + @@ROWCOUNT;

                UPDATE UserAddresses
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @addressesMoved = @addressesMoved + @@ROWCOUNT;

                -- Flags: keep one row per flag.
                DELETE sf
                FROM UserFlagAssignments sf
                WHERE sf.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserFlagAssignments pf
                      WHERE pf.UserID = @primaryUserID
                        AND pf.FlagID = sf.FlagID
                  );
                SET @flagsDeduped = @flagsDeduped + @@ROWCOUNT;

                UPDATE UserFlagAssignments
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @flagsMoved = @flagsMoved + @@ROWCOUNT;

                -- Organizations: keep one row per org.
                DELETE so
                FROM UserOrganizations so
                WHERE so.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserOrganizations po
                      WHERE po.UserID = @primaryUserID
                        AND po.OrgID = so.OrgID
                  );
                SET @orgsDeduped = @orgsDeduped + @@ROWCOUNT;

                UPDATE UserOrganizations
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @orgsMoved = @orgsMoved + @@ROWCOUNT;

                -- Access assignments: keep one row per area.
                DELETE saa
                FROM UserAccessAssignments saa
                WHERE saa.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserAccessAssignments paa
                      WHERE paa.UserID = @primaryUserID
                        AND paa.AccessAreaID = saa.AccessAreaID
                  );
                SET @accessDeduped = @accessDeduped + @@ROWCOUNT;

                UPDATE UserAccessAssignments
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @accessMoved = @accessMoved + @@ROWCOUNT;

                -- External IDs: keep one row per external system.
                DELETE sx
                FROM UserExternalIDs sx
                WHERE sx.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserExternalIDs px
                      WHERE px.UserID = @primaryUserID
                        AND px.SystemID = sx.SystemID
                  );
                SET @externalIDsDeduped = @externalIDsDeduped + @@ROWCOUNT;

                UPDATE UserExternalIDs
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @externalIDsMoved = @externalIDsMoved + @@ROWCOUNT;

                -- Aliases: dedupe on normalized name/type/source tuple.
                DELETE sa
                FROM UserAliases sa
                WHERE sa.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserAliases pa
                      WHERE pa.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.FirstName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.FirstName, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.MiddleName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.MiddleName, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.LastName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.LastName, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.AliasType, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.AliasType, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pa.SourceSystem, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sa.SourceSystem, ''))))
                  );
                SET @aliasesDeduped = @aliasesDeduped + @@ROWCOUNT;

                -- One primary alias per user: demote secondary primaries before reassignment.
                IF EXISTS (
                    SELECT 1
                    FROM UserAliases
                    WHERE UserID = @primaryUserID
                      AND ISNULL(IsPrimary, 0) = 1
                )
                BEGIN
                    UPDATE UserAliases
                    SET IsPrimary = 0
                    WHERE UserID = @secondaryUserID
                      AND ISNULL(IsPrimary, 0) = 1;
                END

                UPDATE UserAliases
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @aliasesMoved = @aliasesMoved + @@ROWCOUNT;

                -- Degrees: dedupe on normalized degree tuple.
                DELETE sd
                FROM UserDegrees sd
                WHERE sd.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserDegrees pd
                      WHERE pd.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pd.DegreeName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sd.DegreeName, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pd.University, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sd.University, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pd.GraduationYear, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sd.GraduationYear, ''))))
                  );
                SET @degreesDeduped = @degreesDeduped + @@ROWCOUNT;

                UPDATE UserDegrees
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @degreesMoved = @degreesMoved + @@ROWCOUNT;

                -- Awards: dedupe on normalized award tuple.
                DELETE sw
                FROM UserAwards sw
                WHERE sw.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserAwards pw
                      WHERE pw.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pw.AwardName, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sw.AwardName, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pw.AwardType, '')))) = LOWER(LTRIM(RTRIM(ISNULL(sw.AwardType, ''))))
                  );
                SET @awardsDeduped = @awardsDeduped + @@ROWCOUNT;

                UPDATE UserAwards
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @awardsMoved = @awardsMoved + @@ROWCOUNT;

                -- Images: dedupe on variant+url+source, move remaining.
                DELETE si
                FROM UserImages si
                WHERE si.UserID = @secondaryUserID
                  AND EXISTS (
                      SELECT 1
                      FROM UserImages pi
                      WHERE pi.UserID = @primaryUserID
                        AND LOWER(LTRIM(RTRIM(ISNULL(pi.ImageVariant, '')))) = LOWER(LTRIM(RTRIM(ISNULL(si.ImageVariant, ''))))
                        AND LOWER(LTRIM(RTRIM(ISNULL(pi.ImageURL, '')))) = LOWER(LTRIM(RTRIM(ISNULL(si.ImageURL, ''))))
                        AND ISNULL(pi.UserImageSourceID, 0) = ISNULL(si.UserImageSourceID, 0)
                  );
                SET @imagesDeduped = @imagesDeduped + @@ROWCOUNT;

                UPDATE UserImages
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @imagesMoved = @imagesMoved + @@ROWCOUNT;

                -- User review submissions: reassign all to primary.
                UPDATE UserReviewSubmissions
                SET UserID = @primaryUserID
                WHERE UserID = @secondaryUserID;
                SET @reviewSubmissionsMoved = @reviewSubmissionsMoved + @@ROWCOUNT;

                -- Academic info singleton: move if missing, otherwise backfill missing values.
                IF EXISTS (SELECT 1 FROM UserAcademicInfo WHERE UserID = @secondaryUserID)
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM UserAcademicInfo WHERE UserID = @primaryUserID)
                    BEGIN
                        UPDATE UserAcademicInfo
                        SET UserID = @primaryUserID
                        WHERE UserID = @secondaryUserID;
                        SET @academicMoved = @academicMoved + @@ROWCOUNT;
                    END
                    ELSE
                    BEGIN
                        UPDATE pa
                        SET
                            pa.OriginalGradYear = CASE WHEN ISNULL(pa.OriginalGradYear, 0) <= 0 AND ISNULL(sa.OriginalGradYear, 0) > 0 THEN sa.OriginalGradYear ELSE pa.OriginalGradYear END,
                            pa.CurrentGradYear = CASE WHEN ISNULL(pa.CurrentGradYear, 0) <= 0 AND ISNULL(sa.CurrentGradYear, 0) > 0 THEN sa.CurrentGradYear ELSE pa.CurrentGradYear END
                        FROM UserAcademicInfo pa
                        INNER JOIN UserAcademicInfo sa ON sa.UserID = @secondaryUserID
                        WHERE pa.UserID = @primaryUserID;
                        SET @academicMerged = @academicMerged + @@ROWCOUNT;

                        DELETE FROM UserAcademicInfo WHERE UserID = @secondaryUserID;
                    END
                END

                -- Bio singleton: move if missing, otherwise backfill empty bio.
                IF EXISTS (SELECT 1 FROM UserBio WHERE UserID = @secondaryUserID)
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM UserBio WHERE UserID = @primaryUserID)
                    BEGIN
                        UPDATE UserBio
                        SET UserID = @primaryUserID
                        WHERE UserID = @secondaryUserID;
                        SET @bioMoved = @bioMoved + @@ROWCOUNT;
                    END
                    ELSE
                    BEGIN
                        UPDATE pb
                        SET
                            pb.BioContent = CASE
                                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pb.BioContent, ''))), '') IS NULL
                                 AND NULLIF(LTRIM(RTRIM(ISNULL(sb.BioContent, ''))), '') IS NOT NULL
                                    THEN sb.BioContent
                                ELSE pb.BioContent
                            END,
                            pb.UpdatedAt = GETDATE()
                        FROM UserBio pb
                        INNER JOIN UserBio sb ON sb.UserID = @secondaryUserID
                        WHERE pb.UserID = @primaryUserID;
                        SET @bioMerged = @bioMerged + @@ROWCOUNT;

                        DELETE FROM UserBio WHERE UserID = @secondaryUserID;
                    END
                END

                -- Student profile singleton: move if missing, otherwise backfill missing values.
                IF EXISTS (SELECT 1 FROM UserStudentProfile WHERE UserID = @secondaryUserID)
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM UserStudentProfile WHERE UserID = @primaryUserID)
                    BEGIN
                        UPDATE UserStudentProfile
                        SET UserID = @primaryUserID
                        WHERE UserID = @secondaryUserID;
                        SET @studentProfileMoved = @studentProfileMoved + @@ROWCOUNT;
                    END
                    ELSE
                    BEGIN
                        UPDATE pp
                        SET
                            pp.FirstExternship = CASE
                                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pp.FirstExternship, ''))), '') IS NULL
                                 AND NULLIF(LTRIM(RTRIM(ISNULL(sp.FirstExternship, ''))), '') IS NOT NULL
                                    THEN sp.FirstExternship
                                ELSE pp.FirstExternship
                            END,
                            pp.SecondExternship = CASE
                                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pp.SecondExternship, ''))), '') IS NULL
                                 AND NULLIF(LTRIM(RTRIM(ISNULL(sp.SecondExternship, ''))), '') IS NOT NULL
                                    THEN sp.SecondExternship
                                ELSE pp.SecondExternship
                            END,
                            pp.CommencementAge = CASE
                                WHEN ISNULL(pp.CommencementAge, 0) <= 0 AND ISNULL(sp.CommencementAge, 0) > 0
                                    THEN sp.CommencementAge
                                ELSE pp.CommencementAge
                            END,
                            pp.HometownCity = CASE
                                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pp.HometownCity, ''))), '') IS NULL
                                 AND NULLIF(LTRIM(RTRIM(ISNULL(sp.HometownCity, ''))), '') IS NOT NULL
                                    THEN sp.HometownCity
                                ELSE pp.HometownCity
                            END,
                            pp.HometownState = CASE
                                WHEN NULLIF(LTRIM(RTRIM(ISNULL(pp.HometownState, ''))), '') IS NULL
                                 AND NULLIF(LTRIM(RTRIM(ISNULL(sp.HometownState, ''))), '') IS NOT NULL
                                    THEN sp.HometownState
                                ELSE pp.HometownState
                            END,
                            pp.UpdatedAt = GETDATE()
                        FROM UserStudentProfile pp
                        INNER JOIN UserStudentProfile sp ON sp.UserID = @secondaryUserID
                        WHERE pp.UserID = @primaryUserID;
                        SET @studentProfileMerged = @studentProfileMerged + @@ROWCOUNT;

                        DELETE FROM UserStudentProfile WHERE UserID = @secondaryUserID;
                    END
                END

                IF :deactivateSecondary = 1
                BEGIN
                    UPDATE Users
                    SET Active = 0,
                        UpdatedAt = GETDATE()
                    WHERE UserID = @secondaryUserID
                      AND ISNULL(Active, 1) <> 0;
                    SET @secondaryDeactivated = @secondaryDeactivated + @@ROWCOUNT;
                END

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION;
                THROW;
            END CATCH;

            SELECT
                @emailsMoved AS EmailsMoved,
                @emailsDeduped AS EmailsDeduped,
                @phonesMoved AS PhonesMoved,
                @phonesDeduped AS PhonesDeduped,
                @addressesMoved AS AddressesMoved,
                @addressesDeduped AS AddressesDeduped,
                @flagsMoved AS FlagsMoved,
                @flagsDeduped AS FlagsDeduped,
                @orgsMoved AS OrganizationsMoved,
                @orgsDeduped AS OrganizationsDeduped,
                @accessMoved AS AccessAssignmentsMoved,
                @accessDeduped AS AccessAssignmentsDeduped,
                @externalIDsMoved AS ExternalIDsMoved,
                @externalIDsDeduped AS ExternalIDsDeduped,
                @aliasesMoved AS AliasesMoved,
                @aliasesDeduped AS AliasesDeduped,
                @degreesMoved AS DegreesMoved,
                @degreesDeduped AS DegreesDeduped,
                @awardsMoved AS AwardsMoved,
                @awardsDeduped AS AwardsDeduped,
                @imagesMoved AS ImagesMoved,
                @imagesDeduped AS ImagesDeduped,
                @reviewSubmissionsMoved AS ReviewSubmissionsMoved,
                @academicMoved AS AcademicInfoMoved,
                @academicMerged AS AcademicInfoMerged,
                @bioMoved AS BioMoved,
                @bioMerged AS BioMerged,
                @studentProfileMoved AS StudentProfileMoved,
                @studentProfileMerged AS StudentProfileMerged,
                @secondaryDeactivated AS SecondaryDeactivated;
            ",
            {
                primaryUserID = { value=arguments.primaryUserID, cfsqltype='cf_sql_integer' },
                secondaryUserID = { value=arguments.secondaryUserID, cfsqltype='cf_sql_integer' },
                deactivateSecondary = { value=(arguments.deactivateSecondary ? 1 : 0), cfsqltype='cf_sql_bit' }
            },
            { datasource=variables.datasource, timeout=180 }
        );

        if (qry.recordCount EQ 0) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public struct function getLatestMergeByPairID( required numeric pairID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1
                m.MergeID,
                m.PairID,
                m.PrimaryUserID,
                m.SecondaryUserID,
                m.MergedByAdminUserID,
                m.MergeChoices,
                m.MergedAt,
                m.Notes
            FROM DuplicateUserMerges m
            WHERE m.PairID = :pairID
            ORDER BY m.MergeID DESC
            ",
            { pairID = { value=arguments.pairID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        if (qry.recordCount EQ 0) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public struct function getLatestMergeBySecondaryUserID( required numeric secondaryUserID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1
                m.MergeID,
                m.PairID,
                m.PrimaryUserID,
                m.SecondaryUserID,
                m.MergedByAdminUserID,
                m.MergeChoices,
                m.MergedAt,
                m.Notes
            FROM DuplicateUserMerges m
            WHERE m.SecondaryUserID = :secondaryUserID
            ORDER BY m.MergeID DESC
            ",
            { secondaryUserID = { value=arguments.secondaryUserID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        if (qry.recordCount EQ 0) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public array function getUserDeepScanData(
        required numeric userID,
        required string scanType
    ) {
        var normalizedType = lCase(trim(arguments.scanType ?: ""));
        var sql = "";

        switch (normalizedType) {
            case "profile":
                sql = "SELECT * FROM Users WHERE UserID = :userID";
                break;
            case "aliases":
                sql = "SELECT * FROM UserAliases WHERE UserID = :userID ORDER BY IsPrimary DESC, SortOrder, AliasID";
                break;
            case "emails":
                sql = "SELECT * FROM UserEmails WHERE UserID = :userID ORDER BY IsPrimary DESC, SortOrder, EmailID";
                break;
            case "phones":
                sql = "SELECT * FROM UserPhone WHERE UserID = :userID ORDER BY IsPrimary DESC, SortOrder, PhoneID";
                break;
            case "addresses":
                sql = "SELECT * FROM UserAddresses WHERE UserID = :userID ORDER BY IsPrimary DESC, AddressType, AddressID";
                break;
            case "flags":
                sql = "
                    SELECT ufa.*, uf.FlagName
                    FROM UserFlagAssignments ufa
                    LEFT JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
                    WHERE ufa.UserID = :userID
                    ORDER BY uf.FlagName, ufa.FlagID
                ";
                break;
            case "organizations":
                sql = "
                    SELECT uo.*, o.OrgName, o.OrgDescription
                    FROM UserOrganizations uo
                    LEFT JOIN Organizations o ON o.OrgID = uo.OrgID
                    WHERE uo.UserID = :userID
                    ORDER BY o.OrgName, uo.OrgID
                ";
                break;
            case "external_ids":
                sql = "
                    SELECT uei.*, es.SystemName
                    FROM UserExternalIDs uei
                    LEFT JOIN ExternalSystems es ON es.SystemID = uei.SystemID
                    WHERE uei.UserID = :userID
                    ORDER BY es.SystemName, uei.SystemID, uei.ExternalValue
                ";
                break;
            case "bio":
                sql = "SELECT * FROM UserBio WHERE UserID = :userID";
                break;
            case "academic":
                sql = "SELECT * FROM UserAcademicInfo WHERE UserID = :userID";
                break;
            case "degrees":
                sql = "SELECT * FROM UserDegrees WHERE UserID = :userID ORDER BY DegreeID";
                break;
            case "awards":
                sql = "SELECT * FROM UserAwards WHERE UserID = :userID ORDER BY AwardID";
                break;
            case "student_profile":
                sql = "SELECT * FROM UserStudentProfile WHERE UserID = :userID";
                break;
            case "review_submissions":
                sql = "SELECT * FROM UserReviewSubmissions WHERE UserID = :userID ORDER BY SubmissionID DESC";
                break;
            case "images":
                sql = "
                    SELECT ui.*, uis.SourceKey, uis.DropboxPath, uis.Notes, uis.IsActive,
                           uis.CreatedAt AS SourceCreatedAt, uis.ModifiedAt AS SourceModifiedAt
                    FROM UserImages ui
                    LEFT JOIN UserImageSources uis ON uis.UserImageSourceID = ui.UserImageSourceID
                    WHERE ui.UserID = :userID
                    ORDER BY ui.SortOrder, ui.ImageID
                ";
                break;
            default:
                return [];
        }

        var qry = executeQueryWithRetry(
            sql,
            { userID = { value=arguments.userID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=120 }
        );

        return queryToArray(qry);
    }

    public array function getInactiveMergedAccounts( numeric limit = 100 ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP(:lim)
                m.SecondaryUserID,
                MAX(m.MergedAt) AS LastMergedAt,
                MAX(m.PrimaryUserID) AS LastPrimaryUserID,
                MAX(u.FirstName) AS FirstName,
                MAX(u.LastName) AS LastName,
                MAX(u.EmailPrimary) AS EmailPrimary,
                COUNT(*) AS MergeCount
            FROM DuplicateUserMerges m
            INNER JOIN Users u ON u.UserID = m.SecondaryUserID
            WHERE ISNULL(u.Active, 1) = 0
            GROUP BY m.SecondaryUserID
            ORDER BY MAX(m.MergedAt) DESC, m.SecondaryUserID DESC
            ",
            { lim = { value=arguments.limit, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=60 }
        );

        return queryToArray(qry);
    }

    public struct function getStatusSummaryByRun( required numeric runID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT
                SUM(CASE WHEN Status = 'pending' THEN 1 ELSE 0 END) AS PendingCount,
                SUM(CASE WHEN Status = 'ignored' THEN 1 ELSE 0 END) AS IgnoredCount,
                SUM(CASE WHEN Status = 'merged' THEN 1 ELSE 0 END) AS MergedCount,
                COUNT(*) AS TotalCount
            FROM DuplicateUserPairs
            WHERE LastSeenRunID = :runID
            ",
            { runID = { value=arguments.runID, cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        if (qry.recordCount EQ 0) {
            return { PENDINGCOUNT = 0, IGNOREDCOUNT = 0, MERGEDCOUNT = 0, TOTALCOUNT = 0 };
        }

        return {
            PENDINGCOUNT = val(qry.PendingCount[1]),
            IGNOREDCOUNT = val(qry.IgnoredCount[1]),
            MERGEDCOUNT = val(qry.MergedCount[1]),
            TOTALCOUNT = val(qry.TotalCount[1])
        };
    }

    public numeric function getLatestPendingPairCount() {
        var latestRun = getLatestRun();
        if (structIsEmpty(latestRun)) {
            return 0;
        }

        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS CNT FROM DuplicateUserPairs WHERE LastSeenRunID = :runID AND Status = 'pending'",
            { runID = { value=val(latestRun.RUNID), cfsqltype='cf_sql_integer' } },
            { datasource=variables.datasource, timeout=30 }
        );

        return val(qry.CNT);
    }

    public void function updatePairStatus(
        required numeric pairID,
        required string status,
        string ignoredReason = ""
    ) {
        executeQueryWithRetry(
            "
            UPDATE DuplicateUserPairs
            SET Status = :status,
                IgnoredReason = :ignoredReason,
                UpdatedAt = GETDATE()
            WHERE PairID = :pairID
            ",
            {
                pairID = { value=arguments.pairID, cfsqltype='cf_sql_integer' },
                status = { value=lCase(trim(arguments.status)), cfsqltype='cf_sql_varchar' },
                ignoredReason = {
                    value=left(trim(arguments.ignoredReason ?: ''), 500),
                    cfsqltype='cf_sql_nvarchar',
                    null=!len(trim(arguments.ignoredReason ?: ''))
                }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
