component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }
    
    public struct function getUserByID( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT u.*, 
                    COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '')   AS PreferredLastName
             FROM Users u
             OUTER APPLY (
                 SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                 FROM UserAliases ua
                 WHERE ua.UserID = u.UserID
                   AND ua.IsActive = 1
                                     AND ISNULL(ua.IsPrimary, 0) = 1
                 ORDER BY
                    ISNULL(ua.SortOrder, 999999),
                    ua.AliasID
             ) pa
             WHERE u.UserID = :id",
            { id = { value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=60, fetchSize=100 }
        );
        if ( qry.recordCount EQ 0 ) {
            return {};
        }

        var row = qry.getRow(1);
        _applyPreferredNameToRow( row );
        return row;
    }

    public struct function getUserByCougarnet( required string cougarnetID ) {
        var normalizedID = lCase(trim(arguments.cougarnetID));
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 u.*
            FROM Users u
            WHERE EXISTS (
                SELECT 1
                FROM UserExternalIDs uei
                INNER JOIN ExternalSystems es ON es.SystemID = uei.SystemID
                WHERE uei.UserID = u.UserID
                  AND LOWER(es.SystemName) LIKE '%cougarnet%'
                  AND (
                        LOWER(LTRIM(RTRIM(ISNULL(uei.ExternalValue, '')))) = :cn
                     OR LOWER(
                            CASE
                                WHEN CHARINDEX('@', LTRIM(RTRIM(ISNULL(uei.ExternalValue, '')))) > 1
                                    THEN LEFT(LTRIM(RTRIM(ISNULL(uei.ExternalValue, ''))), CHARINDEX('@', LTRIM(RTRIM(ISNULL(uei.ExternalValue, '')))) - 1)
                                ELSE ''
                            END
                        ) = :cnAt
                  )
            )
            OR EXISTS (
                SELECT 1
                FROM UserEmails ue
                WHERE ue.UserID = u.UserID
                  AND (
                        LOWER(LTRIM(RTRIM(ISNULL(ue.EmailType, '')))) IN ('cougarnet', 'central')
                     OR LOWER(LTRIM(RTRIM(ISNULL(ue.EmailAddress, '')))) LIKE '%@cougarnet%'
                     OR LOWER(LTRIM(RTRIM(ISNULL(ue.EmailAddress, '')))) LIKE '%@central%'
                  )
                  AND (
                        LOWER(LTRIM(RTRIM(ISNULL(ue.EmailAddress, '')))) = :cnEmail
                     OR LOWER(
                            CASE
                                WHEN CHARINDEX('@', LTRIM(RTRIM(ISNULL(ue.EmailAddress, '')))) > 1
                                    THEN LEFT(LTRIM(RTRIM(ISNULL(ue.EmailAddress, ''))), CHARINDEX('@', LTRIM(RTRIM(ISNULL(ue.EmailAddress, '')))) - 1)
                                ELSE ''
                            END
                        ) = :cnAt
                  )
            )
            ORDER BY u.UserID
            ",
            {
                cn = { value=normalizedID, cfsqltype="cf_sql_nvarchar" },
                cnAt = { value=normalizedID, cfsqltype="cf_sql_nvarchar" },
                cnEmail = { value=normalizedID, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=60, fetchSize=10 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public array function getAllUsers() {
        var qry = executeQueryWithRetry(
            "SELECT u.*, 
                    COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '')   AS PreferredLastName
             FROM Users u
             OUTER APPLY (
                 SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                 FROM UserAliases ua
                 WHERE ua.UserID = u.UserID
                   AND ua.IsActive = 1
                                     AND ISNULL(ua.IsPrimary, 0) = 1
                 ORDER BY
                    ISNULL(ua.SortOrder, 999999),
                    ua.AliasID
             ) pa
             ORDER BY COALESCE(pa.LastName, u.LastName), COALESCE(pa.FirstName, u.FirstName)",
            {},
            { datasource=variables.datasource, timeout=60, fetchSize=1000 }
        );
        var rows = queryToArray(qry);
        _applyPreferredNameToRows( rows );
        return rows;
    }

    public array function getAdminListUsers() {
        var qry = executeQueryWithRetry(
            "SELECT
                    u.UserID,
                    u.Active,
                    u.FirstName,
                    u.MiddleName,
                    u.LastName,
                    u.PreferredName,
                    u.EmailPrimary,
                    u.Title1,
                    COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '')   AS PreferredLastName
             FROM Users u
             OUTER APPLY (
                 SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                 FROM UserAliases ua
                 WHERE ua.UserID = u.UserID
                   AND ua.IsActive = 1
                                     AND ISNULL(ua.IsPrimary, 0) = 1
                 ORDER BY
                    ISNULL(ua.SortOrder, 999999),
                    ua.AliasID
             ) pa",
            {},
            { datasource=variables.datasource, timeout=60, fetchSize=1000 }
        );
        var rows = queryToArray(qry);
        _applyPreferredNameToRows( rows );
        return rows;
    }

    /**
     * Return active users whose record update timestamp is older than the
     * configured number of months. Intended for compact dashboard summaries.
     */
    public array function getStaleUsersForDashboard(
        numeric maxRows = 8,
        numeric staleMonths = 6,
        boolean excludeTestUsers = false
    ) {
        var testUserExclusionSql = "";
        var params = {
            staleMonths = { value=val(arguments.staleMonths), cfsqltype="cf_sql_integer" },
            maxRows     = { value=val(arguments.maxRows),     cfsqltype="cf_sql_integer" }
        };

        if ( arguments.excludeTestUsers ) {
            testUserExclusionSql = "
                  AND NOT EXISTS (
                      SELECT 1
                      FROM UserFlagAssignments ufaTest
                      INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                      WHERE ufaTest.UserID = u.UserID
                        AND ufTest.FlagName = 'TEST_USER'
                  )";
        }

        var qry = executeQueryWithRetry(
            "
            WITH ranked AS (
                SELECT u.UserID,
                       u.FirstName,
                       u.MiddleName,
                       u.LastName,
                       u.UpdatedAt,
                       COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                       COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                       COALESCE(pa.LastName, '')   AS PreferredLastName,
                       ROW_NUMBER() OVER (ORDER BY ISNULL(u.UpdatedAt, '1900-01-01') ASC, u.UserID ASC) AS rn
                FROM   Users u
                OUTER APPLY (
                    SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                    FROM UserAliases ua
                    WHERE ua.UserID = u.UserID
                      AND ua.IsActive = 1
                                            AND ISNULL(ua.IsPrimary, 0) = 1
                    ORDER BY
                        ISNULL(ua.SortOrder, 999999),
                        ua.AliasID
                ) pa
                WHERE ISNULL(u.Active, 1) = 1
                                    #testUserExclusionSql#
                  AND ISNULL(u.UpdatedAt, '1900-01-01') < DATEADD(month, -:staleMonths, GETDATE())
            )
            SELECT UserID,
                   FirstName,
                   MiddleName,
                   LastName,
                   UpdatedAt,
                   PreferredFirstName,
                   PreferredMiddleName,
                   PreferredLastName
            FROM ranked
            WHERE rn <= :maxRows
            ORDER BY rn
            ",
            params,
            { datasource=variables.datasource, timeout=60, fetchSize=100 }
        );

        var rows = queryToArray(qry);
        _applyPreferredNameToRows( rows );
        return rows;
    }

    /**
     * Return one page of stale users plus total count for dashboard pagination.
     */
    public struct function getStaleUsersForDashboardPage(
        numeric pageSize = 10,
        numeric pageNumber = 1,
        numeric staleMonths = 6,
        boolean excludeTestUsers = false
    ) {
        var size = max(1, min(100, int(val(arguments.pageSize ?: 10))));
        var page = max(1, int(val(arguments.pageNumber ?: 1)));
        var offsetRows = (page - 1) * size;
        var testUserExclusionSql = "";
        var countParams = {
            staleMonths = { value=val(arguments.staleMonths), cfsqltype="cf_sql_integer" }
        };
        var dataParams = {
            staleMonths = { value=val(arguments.staleMonths), cfsqltype="cf_sql_integer" },
            offsetRows  = { value=offsetRows,                 cfsqltype="cf_sql_integer" },
            pageSize    = { value=size,                       cfsqltype="cf_sql_integer" }
        };

        if ( arguments.excludeTestUsers ) {
            testUserExclusionSql = "
              AND NOT EXISTS (
                  SELECT 1
                  FROM UserFlagAssignments ufaTest
                  INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                  WHERE ufaTest.UserID = u.UserID
                    AND ufTest.FlagName = 'TEST_USER'
              )";
        }

        var countQry = executeQueryWithRetry(
            "
            SELECT COUNT(*) AS TotalCount
            FROM Users u
            WHERE ISNULL(u.Active, 1) = 1
              #testUserExclusionSql#
              AND ISNULL(u.UpdatedAt, '1900-01-01') < DATEADD(month, -:staleMonths, GETDATE())
            ",
            countParams,
            { datasource=variables.datasource, timeout=60 }
        );

        var dataQry = executeQueryWithRetry(
            "
            SELECT u.UserID,
                   u.FirstName,
                   u.MiddleName,
                   u.LastName,
                   u.UpdatedAt,
                   COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                   COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                   COALESCE(pa.LastName, '')   AS PreferredLastName
            FROM Users u
            OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                  AND ua.IsActive = 1
                                    AND ISNULL(ua.IsPrimary, 0) = 1
                ORDER BY
                    ISNULL(ua.SortOrder, 999999),
                    ua.AliasID
            ) pa
            WHERE ISNULL(u.Active, 1) = 1
                            #testUserExclusionSql#
              AND ISNULL(u.UpdatedAt, '1900-01-01') < DATEADD(month, -:staleMonths, GETDATE())
            ORDER BY ISNULL(u.UpdatedAt, '1900-01-01') ASC, u.UserID ASC
            OFFSET :offsetRows ROWS FETCH NEXT :pageSize ROWS ONLY
            ",
                        dataParams,
            { datasource=variables.datasource, timeout=60, fetchSize=200 }
        );

        var rows = queryToArray(dataQry);
        _applyPreferredNameToRows( rows );

        return {
            data = rows,
            totalCount = val(countQry.TotalCount ?: 0),
            pageSize = size,
            pageNumber = page
        };
    }

    public struct function searchUsers(
        string searchTerm   = "",
        string filterFlag   = "",
        string filterOrg    = "",
        string filterClass  = "",
        string excludeFlags = "",
        string excludeOrgs  = "",
        numeric maxRows     = 50,
        numeric startRow    = 1
    ) {
        var conditions = [];
        var params     = {};

        // Always restrict to active records in the API
        arrayAppend(conditions, "u.Active = 1");

        // Full-text search
        if (len(trim(arguments.searchTerm))) {
            var s = "%" & trim(arguments.searchTerm) & "%";
            arrayAppend(conditions,
                "(u.FirstName LIKE :s OR u.LastName LIKE :s OR u.EmailPrimary LIKE :s OR u.PreferredName LIKE :s
                  OR EXISTS (SELECT 1 FROM UserAliases ua WHERE ua.UserID = u.UserID AND (ua.FirstName LIKE :s OR ua.LastName LIKE :s OR ua.DisplayName LIKE :s) AND ua.IsActive = 1))");
            params["s"] = { value=s, cfsqltype="cf_sql_nvarchar" };
        }

        // Filter to a specific flag (by name)
        if (len(trim(arguments.filterFlag))) {
            arrayAppend(conditions,
                "EXISTS (SELECT 1 FROM UserFlagAssignments ufa
                         INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                         WHERE ufa.UserID = u.UserID AND uf.FlagName = :flagName)");
            params["flagName"] = { value=trim(arguments.filterFlag), cfsqltype="cf_sql_nvarchar" };
        }

        // Filter to a specific graduation year (class)
        if (len(trim(arguments.filterClass)) AND isNumeric(trim(arguments.filterClass))) {
            arrayAppend(conditions,
                "(
                  EXISTS (
                      SELECT 1 FROM UserDegrees ud
                      WHERE ud.UserID = u.UserID AND ud.IsUHCO = 1
                        AND (
                               (ud.IsEnrolled = 1 AND ud.ExpectedGradYear = :gradYear
                                AND (ud.Program IS NULL OR ud.Program <> 'Residency'))
                            OR (ud.IsEnrolled = 0 AND TRY_CAST(ud.GraduationYear AS INT) = :gradYear)
                        )
                  )
               OR (
                      NOT EXISTS (
                          SELECT 1 FROM UserDegrees ud2
                          WHERE ud2.UserID = u.UserID AND ud2.IsUHCO = 1
                      )
                  AND EXISTS (
                          SELECT 1 FROM UserAcademicInfo uai
                          WHERE uai.UserID = u.UserID AND uai.CurrentGradYear = :gradYear
                      )
               )
              )");
            params["gradYear"] = { value=val(trim(arguments.filterClass)), cfsqltype="cf_sql_integer" };
        }

        // Filter to a specific org (by name)
        if (len(trim(arguments.filterOrg))) {
            arrayAppend(conditions,
                "EXISTS (SELECT 1 FROM UserOrganizations uo
                         INNER JOIN Organizations o ON uo.OrgID = o.OrgID
                         WHERE uo.UserID = u.UserID AND o.OrgName = :orgName)");
            params["orgName"] = { value=trim(arguments.filterOrg), cfsqltype="cf_sql_nvarchar" };
        }

        // Exclude users that have any of the protected flags.
        // Exception: the Alumni exclusion doesn't apply to Public-Facing users who
        // currently also hold an active-role flag (Staff/Faculty/Resident) — their
        // current role takes precedence over their protected alumni history.
        if (len(trim(arguments.excludeFlags))) {
            var exFlagList = "";
            var i = 0;
            for (var ef in listToArray(arguments.excludeFlags, ",")) {
                i++;
                var pname = "exFlag#i#";
                exFlagList = listAppend(exFlagList, ":#pname#");
                params[pname] = { value=trim(ef), cfsqltype="cf_sql_nvarchar" };
            }
            arrayAppend(conditions,
                "NOT EXISTS (SELECT 1 FROM UserFlagAssignments ufa
                             INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                             WHERE ufa.UserID = u.UserID AND uf.FlagName IN (#exFlagList#)
                               AND NOT (
                                   uf.FlagName = 'Alumni'
                                   AND EXISTS (SELECT 1 FROM UserFlagAssignments pfa
                                               INNER JOIN UserFlags pf ON pfa.FlagID = pf.FlagID
                                               WHERE pfa.UserID = u.UserID AND pf.FlagName = 'Public-Facing')
                                   AND EXISTS (SELECT 1 FROM UserFlagAssignments rfa
                                               INNER JOIN UserFlags rf ON rfa.FlagID = rf.FlagID
                                               WHERE rfa.UserID = u.UserID
                                                 AND rf.FlagName IN ('Staff', 'Faculty-Fulltime', 'Faculty-Adjunct', 'Resident'))
                               ))");
        }

        // Exclude users that belong to any of the protected orgs.
        // Same exception as the Alumni flag above: a Public-Facing user who also
        // holds an active-role flag isn't hidden by any protected-org membership
        // they retained from their student days (e.g. their graduating program).
        if (len(trim(arguments.excludeOrgs))) {
            var exOrgList = "";
            var j = 0;
            for (var eo in listToArray(arguments.excludeOrgs, ",")) {
                j++;
                var opname = "exOrg#j#";
                exOrgList = listAppend(exOrgList, ":#opname#");
                params[opname] = { value=trim(eo), cfsqltype="cf_sql_nvarchar" };
            }
            arrayAppend(conditions,
                "NOT EXISTS (SELECT 1 FROM UserOrganizations uo
                             INNER JOIN Organizations o ON uo.OrgID = o.OrgID
                             WHERE uo.UserID = u.UserID AND o.OrgName IN (#exOrgList#)
                               AND NOT (
                                   EXISTS (SELECT 1 FROM UserFlagAssignments pfa
                                           INNER JOIN UserFlags pf ON pfa.FlagID = pf.FlagID
                                           WHERE pfa.UserID = u.UserID AND pf.FlagName = 'Public-Facing')
                                   AND EXISTS (SELECT 1 FROM UserFlagAssignments rfa
                                               INNER JOIN UserFlags rf ON rfa.FlagID = rf.FlagID
                                               WHERE rfa.UserID = u.UserID
                                                 AND rf.FlagName IN ('Staff', 'Faculty-Fulltime', 'Faculty-Adjunct', 'Resident'))
                               ))");
        }

        var where = arrayLen(conditions) ? "WHERE " & arrayToList(conditions, " AND ") : "";

        var countQry = executeQueryWithRetry(
            "SELECT COUNT(*) AS Total FROM Users u #where#",
            params,
            { datasource=variables.datasource, timeout=60 }
        );
        var total = countQry.Total;

        var dataParams = duplicate(params);
        dataParams["offset"] = { value=arguments.startRow - 1, cfsqltype="cf_sql_integer" };
        dataParams["rows"]   = { value=arguments.maxRows,      cfsqltype="cf_sql_integer" };

        var dataQry = executeQueryWithRetry(
            "SELECT u.*, COALESCE(degYr.EffectiveGradYear, uai.CurrentGradYear) AS CurrentGradYear, prog.Program AS Program, thumb.ImageURL AS WebThumbURL,
                    COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '')   AS PreferredLastName
             FROM Users u
             OUTER APPLY (
                 SELECT TOP 1 ai.CurrentGradYear
                 FROM UserAcademicInfo ai
                 WHERE ai.UserID = u.UserID
             ) uai
             OUTER APPLY (
                 SELECT TOP 1
                     CASE WHEN ud.IsEnrolled = 1 THEN ud.ExpectedGradYear
                          ELSE TRY_CAST(ud.GraduationYear AS INT)
                     END AS EffectiveGradYear
                 FROM UserDegrees ud
                 WHERE ud.UserID = u.UserID AND ud.IsUHCO = 1
                   AND (ud.Program IS NULL OR ud.Program <> 'Residency')
                 ORDER BY ud.IsEnrolled DESC, ud.DegreeID DESC
             ) degYr
             OUTER APPLY (
                 SELECT TOP 1 o.OrgName AS Program
                 FROM UserOrganizations uo
                 INNER JOIN Organizations o ON uo.OrgID = o.OrgID
                 WHERE uo.UserID = u.UserID
                   AND o.OrgName IN ('OD Program', 'MS Program', 'PhD Program')
                   AND EXISTS (
                       SELECT 1
                       FROM UserFlagAssignments ufa
                       INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                       WHERE ufa.UserID = u.UserID
                         AND uf.FlagName IN ('Current-Student', 'Alumni')
                   )
                 ORDER BY CASE o.OrgName
                     WHEN 'OD Program' THEN 1
                     WHEN 'MS Program' THEN 2
                     WHEN 'PhD Program' THEN 3
                     ELSE 99
                 END
             ) prog
             OUTER APPLY (
                 SELECT TOP 1 img.ImageURL
                 FROM UserImages img
                 WHERE img.UserID = u.UserID AND img.ImageVariant = 'WEB_THUMB'
                 ORDER BY img.SortOrder
             ) thumb
             OUTER APPLY (
                 SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName
                 FROM UserAliases ua
                 WHERE ua.UserID = u.UserID
                   AND ua.IsActive = 1
                                     AND ISNULL(ua.IsPrimary, 0) = 1
                 ORDER BY
                    ISNULL(ua.SortOrder, 999999),
                    ua.AliasID
             ) pa
             #where# ORDER BY COALESCE(pa.LastName, u.LastName), COALESCE(pa.FirstName, u.FirstName)
             OFFSET :offset ROWS FETCH NEXT :rows ROWS ONLY",
            dataParams,
            { datasource=variables.datasource, timeout=60 }
        );

        var dataRows = queryToArray(dataQry);
        _applyPreferredNameToRows( dataRows );

        return { data: dataRows, totalCount: total };
    }

    public array function generateSyntheticTestUsers(
        required numeric count,
        required numeric staleMonths
    ) {
        var targetCount = max( 1, val( arguments.count ) );
        var staleThresholdMonths = max( 1, val( arguments.staleMonths ) );
        var reservedNamePairs = _getNormalizedReservedUserNamePairs();
        var createdUsers = [];
        var candidateNumber = 1;
        var suffixIndex = 0;
        var attempts = 0;
        var maxAttempts = targetCount * 200;
        var candidate = {};
        var pairKey = "";
        var newUserID = 0;
        var testFlagID = _getFlagIDByName( "TEST_USER" );

        if ( testFlagID LTE 0 ) {
            throw( message = "The TEST_USER flag must exist before generating test users." );
        }

        while ( arrayLen( createdUsers ) LT targetCount ) {
            attempts++;
            if ( attempts GT maxAttempts ) {
                throw( message = "Unable to find enough unique synthetic test-user names." );
            }

            candidate = _buildSyntheticTestUserCandidate( candidateNumber, suffixIndex );
            pairKey = _buildNormalizedNamePairKey( candidate.firstName, candidate.lastName );

            if ( structKeyExists( reservedNamePairs, pairKey ) ) {
                suffixIndex++;
                continue;
            }

            newUserID = _insertSyntheticTestUser(
                firstName = candidate.firstName,
                middleName = candidate.middleName,
                lastName = candidate.lastName,
                staleMonths = staleThresholdMonths,
                testFlagID = testFlagID
            );

            if ( newUserID LTE 0 ) {
                suffixIndex++;
                continue;
            }

            reservedNamePairs[ pairKey ] = true;
            arrayAppend( createdUsers, {
                USERID = newUserID,
                FIRSTNAME = candidate.firstName,
                MIDDLENAME = candidate.middleName,
                LASTNAME = candidate.lastName,
                FULLNAME = trim( candidate.firstName & " " & candidate.middleName & " " & candidate.lastName )
            } );

            candidateNumber++;
            suffixIndex = 0;
        }

        return createdUsers;
    }

    public numeric function getTestUserCount() {
        var qry = executeQueryWithRetry(
            "
            SELECT COUNT(*) AS TotalCount
            FROM Users u
            WHERE EXISTS (
                SELECT 1
                FROM UserFlagAssignments ufa
                INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                WHERE ufa.UserID = u.UserID
                  AND uf.FlagName = 'TEST_USER'
            )
            ",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return val( qry.TotalCount ?: 0 );
    }

    public array function getUserIDsByFlagName( required string flagName ) {
        var qry = executeQueryWithRetry(
            "
            SELECT DISTINCT ufa.UserID
            FROM UserFlagAssignments ufa
            INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
            WHERE uf.FlagName = :flagName
            ORDER BY ufa.UserID
            ",
            {
                flagName = { value=trim( arguments.flagName ), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        var ids = [];

        for ( var row in qry ) {
            arrayAppend( ids, val( row.UserID ?: 0 ) );
        }

        return ids;
    }

    public struct function resetTestUsers(
        required numeric staleMonths,
        numeric maxUsers = 10
    ) {
        var staleThresholdMonths = max( 1, val( arguments.staleMonths ) );
        var targetCount = max( 1, val( arguments.maxUsers ) );
        var targetUserIDs = getUserIDsByFlagName( "TEST_USER" );
        var testFlagID = _getFlagIDByName( "TEST_USER" );
        var candidate = {};
        var targetUserID = 0;
        var index = 0;

        if ( testFlagID LTE 0 ) {
            throw( message = "The TEST_USER flag must exist before resetting test users." );
        }

        if ( arrayLen( targetUserIDs ) NEQ targetCount ) {
            return {
                success = false,
                message = "Exactly #targetCount# TEST_USER records are required before reset. Found #arrayLen( targetUserIDs )#.",
                resetCount = 0
            };
        }

        transaction {
            for ( index = 1; index <= arrayLen( targetUserIDs ); index++ ) {
                targetUserID = val( targetUserIDs[ index ] );
                candidate = _buildSyntheticTestUserCandidate( index, 0 );

                _purgeUserRelatedData(
                    userID = targetUserID,
                    preserveTestUserFlag = true,
                    testFlagID = testFlagID
                );

                executeQueryWithRetry(
                    "
                    UPDATE Users
                    SET FirstName = :firstName,
                        MiddleName = :middleName,
                        LastName = :lastName,
                        Pronouns = '',
                        EmailPrimary = '',
                        Phone = '',
                        UH_API_ID = '',
                        Title1 = '',
                        Title2 = '',
                        Title3 = '',
                        Room = '',
                        Building = '',
                        Prefix = '',
                        Suffix = '',
                        Degrees = '',
                        Campus = '',
                        Division = '',
                        DivisionName = '',
                        Department = '',
                        DepartmentName = '',
                        Office_Mailing_Address = '',
                        Mailcode = '',
                        DOB = NULL,
                        Gender = NULL,
                        Active = 1,
                        UpdatedAt = DATEADD(month, -:staleMonths, GETDATE())
                    WHERE UserID = :id
                    ",
                    {
                        id = { value=targetUserID, cfsqltype="cf_sql_integer" },
                        firstName = { value=trim( candidate.firstName ), cfsqltype="cf_sql_nvarchar" },
                        middleName = { value=trim( candidate.middleName ), cfsqltype="cf_sql_nvarchar" },
                        lastName = { value=trim( candidate.lastName ), cfsqltype="cf_sql_nvarchar" },
                        staleMonths = { value=staleThresholdMonths, cfsqltype="cf_sql_integer" }
                    },
                    { datasource=variables.datasource, timeout=30 }
                );

                _insertSyntheticTestUserAlias(
                    userID = targetUserID,
                    firstName = candidate.firstName,
                    middleName = candidate.middleName,
                    lastName = candidate.lastName
                );
            }
        }

        return {
            success = true,
            message = "Reset #arrayLen( targetUserIDs )# TEST_USER records to their initial stale state.",
            resetCount = arrayLen( targetUserIDs )
        };
    }

    private struct function _getNormalizedReservedUserNamePairs() {
        var qry = executeQueryWithRetry(
            "
            SELECT DISTINCT
                   LOWER(LTRIM(RTRIM(ISNULL(u.FirstName, '')))) AS FirstNameKey,
                   LOWER(LTRIM(RTRIM(ISNULL(u.LastName, '')))) AS LastNameKey
            FROM Users u
            ",
            {},
            { datasource=variables.datasource, timeout=60, fetchSize=1000 }
        );
        var result = {};
        var row = {};

        for ( row in qry ) {
            result[ _buildNormalizedNamePairKey( row.FirstNameKey ?: "", row.LastNameKey ?: "" ) ] = true;
        }

        return result;
    }

    private struct function _buildSyntheticTestUserCandidate(
        required numeric baseNumber,
        numeric suffixIndex = 0
    ) {
        var firstNames = [
            "Andrew", "Maya", "Jordan", "Elena", "Marcus", "Nina", "Caleb", "Ariana", "Nathan", "Claire",
            "Evan", "Sofia", "Julian", "Leah", "Miles", "Audrey", "Connor", "Naomi", "Isaac", "Vivian",
            "Daniel", "Camila", "Owen", "Jasmine", "Samuel", "Lucy", "Adrian", "Elise", "Henry", "Mia",
            "Theo", "Ruby", "Gavin", "Zoe", "Landon", "Eva", "Bennett", "Ivy", "Rowan", "Anna"
        ];
        var lastNames = [
            "Smith", "Johnson", "Parker", "Bennett", "Hayes", "Coleman", "Brooks", "Reed", "Murphy", "Foster",
            "Bailey", "Cooper", "Sullivan", "Watson", "Price", "Russell", "Ward", "Perry", "Powell", "Long",
            "Graham", "James", "West", "Bryant", "Stone", "Hunter", "Hicks", "Weaver", "Mason", "Jordan",
            "Harper", "Bishop", "Warren", "Wells", "Porter", "Hudson", "Spencer", "Carroll", "Fields", "Knight"
        ];
        var firstNameCount = arrayLen( firstNames );
        var lastNameCount = arrayLen( lastNames );
        var ordinal = max( 1, val( arguments.baseNumber ) + val( arguments.suffixIndex ?: 0 ) );
        var zeroBasedOrdinal = ordinal - 1;
        var firstIndex = ( zeroBasedOrdinal MOD firstNameCount ) + 1;
        var lastIndex = ( ( zeroBasedOrdinal * 7 ) MOD lastNameCount ) + 1;
        var cycleSuffix = _numberToAlphaSuffix( fix( zeroBasedOrdinal / firstNameCount ) );
        var resolvedLastName = lastNames[ lastIndex ];

        if ( len( cycleSuffix ) ) {
            resolvedLastName &= " " & cycleSuffix;
        }

        return {
            firstName = firstNames[ firstIndex ],
            middleName = "Test",
            lastName = resolvedLastName
        };
    }

    private string function _numberToAlphaSuffix( required numeric value ) {
        var indexValue = val( arguments.value );
        var result = "";
        var currentValue = 0;
        var remainder = 0;

        if ( indexValue LTE 0 ) {
            return "";
        }

        currentValue = indexValue;
        while ( currentValue GT 0 ) {
            currentValue--;
            remainder = currentValue MOD 26;
            result = chr( 65 + remainder ) & result;
            currentValue = fix( currentValue / 26 );
        }

        return result;
    }

    private string function _buildNormalizedNamePairKey(
        required string firstName,
        required string lastName
    ) {
        return lCase( trim( arguments.firstName ) ) & "|" & lCase( trim( arguments.lastName ) );
    }

        private boolean function _userNamePairExists(
        required string firstName,
        required string lastName
    ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 1 AS ExistsFlag
            FROM Users u
            WHERE LOWER(LTRIM(RTRIM(ISNULL(u.FirstName, '')))) = :firstName
              AND LOWER(LTRIM(RTRIM(ISNULL(u.LastName, '')))) = :lastName
            ",
            {
                firstName = { value=lCase( trim( arguments.firstName ) ), cfsqltype="cf_sql_nvarchar" },
                lastName = { value=lCase( trim( arguments.lastName ) ), cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return qry.recordCount GT 0;
    }

    private numeric function _insertSyntheticTestUser(
        required string firstName,
        required string middleName,
        required string lastName,
        required numeric staleMonths,
        required numeric testFlagID
    ) {
        var newUserID = 0;
        var insertResult = "";

        if ( _userNamePairExists( arguments.firstName, arguments.lastName ) ) {
            return 0;
        }

        transaction {
            if ( _userNamePairExists( arguments.firstName, arguments.lastName ) ) {
                transaction action="rollback";
                return 0;
            }

            insertResult = executeQueryWithRetry(
                "
                INSERT INTO Users (
                    FirstName, MiddleName, LastName,
                    Pronouns,
                    EmailPrimary,
                    Phone, UH_API_ID,
                    Title1, Title2, Title3,
                    Room, Building,
                    Prefix, Suffix, Degrees,
                    Campus, Division, DivisionName, Department, DepartmentName,
                    Office_Mailing_Address, Mailcode,
                    DOB, Gender,
                    Active, CreatedAt, UpdatedAt
                )
                VALUES (
                    :FirstName, :MiddleName, :LastName,
                    '',
                    '',
                    '', '',
                    '', '', '',
                    '', '',
                    '', '', '',
                    '', '', '', '', '',
                    '', '',
                    NULL, NULL,
                    1,
                    DATEADD(month, -:staleMonths, GETDATE()),
                    DATEADD(month, -:staleMonths, GETDATE())
                );
                SELECT SCOPE_IDENTITY() AS newID;
                ",
                {
                    FirstName = { value=trim( arguments.firstName ), cfsqltype="cf_sql_nvarchar" },
                    MiddleName = { value=trim( arguments.middleName ), cfsqltype="cf_sql_nvarchar" },
                    LastName = { value=trim( arguments.lastName ), cfsqltype="cf_sql_nvarchar" },
                    staleMonths = { value=val( arguments.staleMonths ), cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30, fetchSize=10 }
            );

            newUserID = val( insertResult.newID ?: 0 );
            if ( newUserID LTE 0 ) {
                throw( message = "Synthetic test user insert did not return a UserID." );
            }

            executeQueryWithRetry(
                "
                IF NOT EXISTS (
                    SELECT 1
                    FROM UserFlagAssignments
                    WHERE UserID = :userID
                      AND FlagID = :flagID
                )
                BEGIN
                    INSERT INTO UserFlagAssignments (UserID, FlagID)
                    VALUES (:userID, :flagID)
                END
                ",
                {
                    userID = { value=newUserID, cfsqltype="cf_sql_integer" },
                    flagID = { value=arguments.testFlagID, cfsqltype="cf_sql_integer" }
                },
                { datasource=variables.datasource, timeout=30 }
            );

            _insertSyntheticTestUserAlias(
                userID = newUserID,
                firstName = arguments.firstName,
                middleName = arguments.middleName,
                lastName = arguments.lastName
            );
        }

        return newUserID;
    }

    private void function _insertSyntheticTestUserAlias(
        required numeric userID,
        required string firstName,
        required string middleName,
        required string lastName
    ) {
        var trimmedFirstName = trim( arguments.firstName );
        var trimmedMiddleName = trim( arguments.middleName );
        var trimmedLastName = trim( arguments.lastName );
        var displayParts = [];
        var displayName = "";

        if ( len( trimmedFirstName ) ) {
            arrayAppend( displayParts, trimmedFirstName );
        }
        if ( len( trimmedMiddleName ) ) {
            arrayAppend( displayParts, trimmedMiddleName );
        }
        if ( len( trimmedLastName ) ) {
            arrayAppend( displayParts, trimmedLastName );
        }

        displayName = arrayToList( displayParts, " " );

        executeQueryWithRetry(
            "
            INSERT INTO UserAliases (
                UserID,
                FirstName,
                MiddleName,
                LastName,
                DisplayName,
                AliasType,
                SourceSystem,
                IsActive,
                IsPrimary,
                SortOrder
            )
            VALUES (
                :userID,
                :firstName,
                :middleName,
                :lastName,
                :displayName,
                'SOURCE_VARIANT',
                'TEST MODE',
                1,
                1,
                0
            )
            ",
            {
                userID = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                firstName = { value=trimmedFirstName, cfsqltype="cf_sql_nvarchar", null=( len( trimmedFirstName ) EQ 0 ) },
                middleName = { value=trimmedMiddleName, cfsqltype="cf_sql_nvarchar", null=( len( trimmedMiddleName ) EQ 0 ) },
                lastName = { value=trimmedLastName, cfsqltype="cf_sql_nvarchar", null=( len( trimmedLastName ) EQ 0 ) },
                displayName = { value=displayName, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    private numeric function _getFlagIDByName( required string flagName ) {
        var qry = executeQueryWithRetry(
            "
            SELECT TOP 1 FlagID
            FROM UserFlags
            WHERE FlagName = :flagName
            ",
            {
                flagName = { value=trim( arguments.flagName ), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        if ( qry.recordCount EQ 0 ) {
            return 0;
        }

        return val( qry.FlagID ?: 0 );
    }

    private void function _applyPreferredNameToRows( required array rows ) {
        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            _applyPreferredNameToRow( arguments.rows[i] );
        }
    }

    private void function _applyPreferredNameToRow( required struct row ) {
        var baseFirst = trim(arguments.row.FIRSTNAME ?: "");
        var baseMiddle = trim(arguments.row.MIDDLENAME ?: "");
        var baseLast = trim(arguments.row.LASTNAME ?: "");
        var preferredFirst = trim(arguments.row.PREFERREDFIRSTNAME ?: "");
        var preferredMiddle = trim(arguments.row.PREFERREDMIDDLENAME ?: "");
        var preferredLast = trim(arguments.row.PREFERREDLASTNAME ?: "");
        var hasPreferredName = len(trim(arguments.row.PREFERREDFIRSTNAME ?: ""))
            OR len(trim(arguments.row.PREFERREDMIDDLENAME ?: ""))
            OR len(trim(arguments.row.PREFERREDLASTNAME ?: ""));
        var first = hasPreferredName ? preferredFirst : baseFirst;
        var middle = hasPreferredName ? preferredMiddle : baseMiddle;
        var last = hasPreferredName ? preferredLast : baseLast;

        arguments.row["FIRSTNAME"] = first;
        arguments.row["MIDDLENAME"] = middle;
        arguments.row["LASTNAME"] = last;

        var parts = [];
        if ( len(first) ) {
            arrayAppend(parts, first);
        }
        if ( len(middle) ) {
            arrayAppend(parts, middle);
        }
        if ( len(last) ) {
            arrayAppend(parts, last);
        }

        arguments.row["FULLNAME"] = arrayToList(parts, " ");

        structDelete(arguments.row, "PREFERREDFIRSTNAME", false);
        structDelete(arguments.row, "PREFERREDMIDDLENAME", false);
        structDelete(arguments.row, "PREFERREDLASTNAME", false);
    }

    public numeric function createUser( required struct data ) {
        // Ensure all fields exist with defaults
        if ( !structKeyExists(data, "Title1") ) {
            data.Title1 = "";
        }
        if ( !structKeyExists(data, "Title2") ) {
            data.Title2 = "";
        }
        if ( !structKeyExists(data, "Title3") ) {
            data.Title3 = "";
        }
        if ( !structKeyExists(data, "Room") ) {
            data.Room = "";
        }
        if ( !structKeyExists(data, "Building") ) {
            data.Building = "";
        }
        if ( !structKeyExists(data, "Prefix") ) { data.Prefix = ""; }
        if ( !structKeyExists(data, "Suffix") ) { data.Suffix = ""; }
        if ( !structKeyExists(data, "Degrees") ) { data.Degrees = ""; }
        if ( !structKeyExists(data, "Campus") ) { data.Campus = ""; }
        if ( !structKeyExists(data, "Division") ) { data.Division = ""; }
        if ( !structKeyExists(data, "DivisionName") ) { data.DivisionName = ""; }
        if ( !structKeyExists(data, "Department") ) { data.Department = ""; }
        if ( !structKeyExists(data, "DepartmentName") ) { data.DepartmentName = ""; }
        if ( !structKeyExists(data, "Office_Mailing_Address") ) { data.Office_Mailing_Address = ""; }
        if ( !structKeyExists(data, "Mailcode") ) { data.Mailcode = ""; }
        if ( !structKeyExists(data, "DOB") ) { data.DOB = { value="", cfsqltype="cf_sql_date", null=true }; }
        if ( !structKeyExists(data, "Gender") ) { data.Gender = { value="", cfsqltype="cf_sql_nvarchar", null=true }; }
        // Map Title fields to parameter names (ColdFusion SQL parser doesn't like numeric placeholders)
        data.TitleOneParam = data.Title1;
        data.TitleTwoParam = data.Title2;
        data.TitleThreeParam = data.Title3;

        var q = executeQueryWithRetry(
            "
            INSERT INTO Users (
                FirstName, MiddleName, LastName,
                Pronouns,
                EmailPrimary,
                Phone, UH_API_ID,
                Title1, Title2, Title3,
                Room, Building,
                Prefix, Suffix, Degrees,
                Campus, Division, DivisionName, Department, DepartmentName,
                Office_Mailing_Address, Mailcode,
                DOB, Gender
            )
            VALUES (
                :FirstName, :MiddleName, :LastName,
                :Pronouns,
                :EmailPrimary,
                :Phone, :UH_API_ID,
                :TitleOneParam, :TitleTwoParam, :TitleThreeParam,
                :Room, :Building,
                :Prefix, :Suffix, :Degrees,
                :Campus, :Division, :DivisionName, :Department, :DepartmentName,
                :Office_Mailing_Address, :Mailcode,
                :DOB, :Gender
            );
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return q.newID;
    }

    public void function updateUser( required numeric userID, required struct data ) {
        if ( !structKeyExists(data, "Title1") ) {
            data.Title1 = "";
        }
        if ( !structKeyExists(data, "Title2") ) {
            data.Title2 = "";
        }
        if ( !structKeyExists(data, "Title3") ) {
            data.Title3 = "";
        }
        if ( !structKeyExists(data, "Room") ) {
            data.Room = "";
        }
        if ( !structKeyExists(data, "Building") ) {
            data.Building = "";
        }
        if ( !structKeyExists(data, "Prefix") ) { data.Prefix = ""; }
        if ( !structKeyExists(data, "Suffix") ) { data.Suffix = ""; }
        if ( !structKeyExists(data, "Degrees") ) { data.Degrees = ""; }
        if ( !structKeyExists(data, "Campus") ) { data.Campus = ""; }
        if ( !structKeyExists(data, "Division") ) { data.Division = ""; }
        if ( !structKeyExists(data, "DivisionName") ) { data.DivisionName = ""; }
        if ( !structKeyExists(data, "Department") ) { data.Department = ""; }
        if ( !structKeyExists(data, "DepartmentName") ) { data.DepartmentName = ""; }
        if ( !structKeyExists(data, "Office_Mailing_Address") ) { data.Office_Mailing_Address = ""; }
        if ( !structKeyExists(data, "Mailcode") ) { data.Mailcode = ""; }
        if ( !structKeyExists(data, "Active") ) { data.Active = 1; }
        if ( !structKeyExists(data, "DOB") ) { data.DOB = { value="", cfsqltype="cf_sql_date", null=true }; }
        if ( !structKeyExists(data, "Gender") ) { data.Gender = { value="", cfsqltype="cf_sql_nvarchar", null=true }; }
        if ( !structKeyExists(data, "Notes") ) { data.Notes = ""; }
        data.TitleOneParam = data.Title1;
        data.TitleTwoParam = data.Title2;
        data.TitleThreeParam = data.Title3;
        data.id = userID;

        executeQueryWithRetry(
            "
            UPDATE Users SET
                FirstName = :FirstName,
                MiddleName = :MiddleName,
                LastName = :LastName,
                Pronouns = :Pronouns,
                EmailPrimary = :EmailPrimary,
                Phone = :Phone,
                Room = :Room,
                Building = :Building,
                Title1 = :TitleOneParam,
                Title2 = :TitleTwoParam,
                Title3 = :TitleThreeParam,
                UH_API_ID = :UH_API_ID,
                Prefix = :Prefix,
                Suffix = :Suffix,
                Degrees = :Degrees,
                Campus = :Campus,
                Division = :Division,
                DivisionName = :DivisionName,
                Department = :Department,
                DepartmentName = :DepartmentName,
                Office_Mailing_Address = :Office_Mailing_Address,
                Mailcode = :Mailcode,
                DOB = :DOB,
                Gender = :Gender,
                Active = :Active,
                Notes = :Notes,
                UpdatedAt = GETDATE()
            WHERE UserID = :id
            ",
            data,
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
    }

    public void function deleteUser(
        required numeric userID,
        boolean purgeDuplicatePairs = false
    ) {
        _purgeUserRelatedData(
            userID = arguments.userID,
            purgeDuplicatePairs = arguments.purgeDuplicatePairs
        );
        executeQueryWithRetry(
            "DELETE FROM Users WHERE UserID = :id",
            { id = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
    }

    public void function updateDegreesField( required numeric userID, required string degrees ) {
        executeQueryWithRetry(
            "UPDATE Users SET Degrees = :Degrees, UpdatedAt = GETDATE() WHERE UserID = :id",
            {
                id      = { value=userID,          cfsqltype="cf_sql_integer"  },
                Degrees = { value=arguments.degrees, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateDropboxFolderPath( required numeric userID, required string folderPath ) {
        executeQueryWithRetry(
            "UPDATE Users SET DropboxFolderPath = :path, UpdatedAt = GETDATE() WHERE UserID = :id",
            {
                id   = { value=userID,               cfsqltype="cf_sql_integer"  },
                path = { value=arguments.folderPath, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateTitle1Field( required numeric userID, required string title1 ) {
        executeQueryWithRetry(
            "UPDATE Users SET Title1 = :Title1, UpdatedAt = GETDATE() WHERE UserID = :id",
            {
                id     = { value=userID,            cfsqltype="cf_sql_integer"  },
                Title1 = { value=arguments.title1, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function setUserActive( required numeric userID, required boolean active ) {
        executeQueryWithRetry(
            "
            UPDATE Users
            SET Active = :active,
                UpdatedAt = GETDATE()
            WHERE UserID = :id
            ",
            {
                id = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                active = { value=(arguments.active ? 1 : 0), cfsqltype="cf_sql_bit" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateDemographics(
        required numeric userID,
        string dob = "",
        string gender = ""
    ) {
        var normalizedDob = trim(arguments.dob ?: "");
        var normalizedGender = trim(arguments.gender ?: "");

        executeQueryWithRetry(
            "
            UPDATE Users
            SET DOB = :DOB,
                Gender = :Gender,
                UpdatedAt = GETDATE()
            WHERE UserID = :id
            ",
            {
                id = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                DOB = {
                    value=normalizedDob,
                    cfsqltype="cf_sql_date",
                    null=!len(normalizedDob)
                },
                Gender = {
                    value=normalizedGender,
                    cfsqltype="cf_sql_nvarchar",
                    null=!len(normalizedGender)
                }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    private void function _purgeUserRelatedData(
        required numeric userID,
        boolean preserveTestUserFlag = false,
        numeric testFlagID = 0,
        boolean purgeDuplicatePairs = false
    ) {
        var idParam = { id = { value=arguments.userID, cfsqltype="cf_sql_integer" } };
        var opts = { datasource=variables.datasource, timeout=30, fetchSize=10 };

        executeQueryWithRetry( "DELETE FROM UserImages WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry(
            "DELETE FROM UserImageVariants WHERE UserImageSourceID IN (SELECT UserImageSourceID FROM UserImageSources WHERE UserID = :id)",
            idParam,
            opts
        );
        executeQueryWithRetry( "DELETE FROM UserImageSources WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserOrganizations WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAccessAssignments WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAddresses WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAcademicInfo WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserExternalIDs WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserDegrees WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserEmails WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserPhone WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAliases WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserBio WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAwards WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserStudentProfile WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserReviewSubmissions WHERE UserID = :id", idParam, opts );
        if ( arguments.purgeDuplicatePairs ) {
            executeQueryWithRetry(
                "
                DELETE dum
                FROM DuplicateUserMerges dum
                INNER JOIN DuplicateUserPairs dup ON dup.PairID = dum.PairID
                WHERE dup.UserID_A = :id OR dup.UserID_B = :id
                ",
                idParam,
                opts
            );
            executeQueryWithRetry( "DELETE FROM DuplicateUserPairs WHERE UserID_A = :id OR UserID_B = :id", idParam, opts );
        }

        if ( arguments.preserveTestUserFlag AND arguments.testFlagID GT 0 ) {
            executeQueryWithRetry(
                "DELETE FROM UserFlagAssignments WHERE UserID = :id AND FlagID <> :flagID",
                {
                    id = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                    flagID = { value=arguments.testFlagID, cfsqltype="cf_sql_integer" }
                },
                opts
            );
            executeQueryWithRetry(
                "
                IF NOT EXISTS (
                    SELECT 1
                    FROM UserFlagAssignments
                    WHERE UserID = :id
                      AND FlagID = :flagID
                )
                BEGIN
                    INSERT INTO UserFlagAssignments (UserID, FlagID)
                    VALUES (:id, :flagID)
                END
                ",
                {
                    id = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                    flagID = { value=arguments.testFlagID, cfsqltype="cf_sql_integer" }
                },
                opts
            );
        } else {
            executeQueryWithRetry( "DELETE FROM UserFlagAssignments WHERE UserID = :id", idParam, opts );
        }
    }

}