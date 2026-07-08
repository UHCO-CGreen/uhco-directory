component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    private string function _preferredNamePresentSql( required string aliasPrefix ) {
        return "(
                    LEN(LTRIM(RTRIM(ISNULL(#arguments.aliasPrefix#.FirstName, '')))) > 0
                    OR LEN(LTRIM(RTRIM(ISNULL(#arguments.aliasPrefix#.MiddleName, '')))) > 0
                    OR LEN(LTRIM(RTRIM(ISNULL(#arguments.aliasPrefix#.LastName, '')))) > 0
                )";
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
        var preferredDisplayName = trim(arguments.row.PREFERREDDISPLAYNAME ?: "");
        var hasPreferredName = len(trim(arguments.row.PREFERREDFIRSTNAME ?: ""))
            OR len(trim(arguments.row.PREFERREDMIDDLENAME ?: ""))
            OR len(trim(arguments.row.PREFERREDLASTNAME ?: ""));
        var first = hasPreferredName ? preferredFirst : baseFirst;
        var middle = hasPreferredName ? preferredMiddle : baseMiddle;
        var last = hasPreferredName ? preferredLast : baseLast;

        // Never blank a populated base component when preferred alias only has partial split-name data.
        if ( !len(first) AND len(baseFirst) ) {
            first = baseFirst;
        }
        if ( !len(middle) AND len(baseMiddle) ) {
            middle = baseMiddle;
        }
        if ( !len(last) AND len(baseLast) ) {
            last = baseLast;
        }

        // Final fallback for legacy aliases that only store DisplayName.
        if ( !len(first) AND !len(middle) AND !len(last) AND len(preferredDisplayName) ) {
            var normalizedDisplay = reReplace(trim(preferredDisplayName), "\s+", " ", "all");
            var displayParts = listToArray(normalizedDisplay, " ");
            var partCount = arrayLen(displayParts);

            if ( partCount EQ 1 ) {
                first = displayParts[1];
            } else if ( partCount EQ 2 ) {
                first = displayParts[1];
                last = displayParts[2];
            } else if ( partCount GT 2 ) {
                first = displayParts[1];
                last = displayParts[partCount];
                var middleParts = [];
                for ( var idx = 2; idx < partCount; idx++ ) {
                    arrayAppend(middleParts, displayParts[idx]);
                }
                middle = arrayToList(middleParts, " ");
            }
        }

        arguments.row["FIRSTNAME"] = first;
        arguments.row["MIDDLENAME"] = middle;
        arguments.row["LASTNAME"] = last;

        structDelete(arguments.row, "PREFERREDFIRSTNAME", false);
        structDelete(arguments.row, "PREFERREDMIDDLENAME", false);
        structDelete(arguments.row, "PREFERREDLASTNAME", false);
        structDelete(arguments.row, "PREFERREDDISPLAYNAME", false);
    }

    /**
     * Users with the Clinical-Attending flag.
     * Returns: UserID, FirstName, MiddleName, LastName, Degrees (display string from Users table)
     */
    public array function getAttendingUsers() {
        var preferredNamePresentSql = _preferredNamePresentSql( "pa" );
        var qry = executeQueryWithRetry(
            "SELECT u.UserID,
                    u.FirstName AS FirstName,
                    u.MiddleName AS MiddleName,
                    u.LastName AS LastName,
                    COALESCE(pa.FirstName, '') AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '') AS PreferredLastName,
                                        COALESCE(pa.DisplayName, '') AS PreferredDisplayName,
                    u.Degrees
             FROM   Users u
                    OUTER APPLY (
                                                SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName, ua.DisplayName
                        FROM UserAliases ua
                        WHERE ua.UserID = u.UserID
                          AND ISNULL(ua.IsActive, 1) = 1
                        ORDER BY
                                                        CASE
                                                                WHEN LEN(LTRIM(RTRIM(ISNULL(ua.FirstName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.MiddleName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.LastName, '')))) > 0
                                                                THEN 0 ELSE 1
                                                        END,
                            CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                            ISNULL(ua.SortOrder, 2147483647),
                            ua.AliasID
                    ) pa
             WHERE  u.Active = 1
               AND  EXISTS (
                        SELECT 1
                        FROM   UserFlagAssignments ufa
                               INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                        WHERE  ufa.UserID = u.UserID
                          AND  uf.FlagName = 'Clinical-Attending'
                    )
                 AND  NOT EXISTS (
                       SELECT 1
                       FROM   UserFlagAssignments ufaTest
                           INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                       WHERE  ufaTest.UserID = u.UserID
                         AND  ufTest.FlagName = 'TEST_USER'
                      )
                         ORDER BY CASE WHEN #preferredNamePresentSql# THEN pa.LastName ELSE u.LastName END,
                                            CASE WHEN #preferredNamePresentSql# THEN pa.FirstName ELSE u.FirstName END",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
                var rows = queryToArray(qry);
                _applyPreferredNameToRows( rows );
                return rows;
    }

    /**
     * Alumni filtered to a specific graduation year.
     * Returns: UserID, FirstName, MiddleName, LastName, Program,
        *          FirstExternship, SecondExternship, HometownCity, HometownState (from UserAddresses where AddressType=Hometown)
     */
    public array function getGradClassUsers(
        required numeric gradYear,
        required string programName,
        string lastNameStart = "",
        string lastNameFinish = ""
    ) {
        var preferredNamePresentSql = _preferredNamePresentSql( "pa" );
        var qry = executeQueryWithRetry(
            "SELECT u.UserID,
                    u.FirstName AS FirstName,
                    u.MiddleName AS MiddleName,
                    u.LastName AS LastName,
                    COALESCE(pa.FirstName, '') AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '') AS PreferredLastName,
                    COALESCE(pa.DisplayName, '') AS PreferredDisplayName,
                    programAgg.ProgramList AS Program,
                    usp.FirstExternship,
                    usp.SecondExternship,
                    usp.DissertationThesis,
                    hometownAddr.City AS HometownCity,
                    hometownAddr.[State] AS HometownState
             FROM   Users u
                    LEFT JOIN UserStudentProfile usp ON u.UserID = usp.UserID
                    OUTER APPLY (
                        SELECT ProgramList = STUFF((
                                                        SELECT ', ' + p.OrgName
                                                        FROM (
                                                                SELECT DISTINCT o2.OrgName
                                                                FROM UserOrganizations uo2
                                                                INNER JOIN Organizations o2 ON uo2.OrgID = o2.OrgID
                                                                WHERE uo2.UserID = u.UserID
                                                                    AND o2.OrgName IN ('OD Program', 'PhD Program', 'MS Program')
                                                                    AND (
                                                                                UPPER(:programName) = 'ALL'
                                                                                OR o2.OrgName = :programName
                                                                    )
                                                        ) p
                                                        ORDER BY p.OrgName
                            FOR XML PATH(''), TYPE
                        ).value('.', 'nvarchar(max)'), 1, 2, '')
                    ) programAgg
                    OUTER APPLY (
                                                SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName, ua.DisplayName
                        FROM UserAliases ua
                        WHERE ua.UserID = u.UserID
                          AND ISNULL(ua.IsActive, 1) = 1
                        ORDER BY
                                                        CASE
                                                                WHEN LEN(LTRIM(RTRIM(ISNULL(ua.FirstName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.MiddleName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.LastName, '')))) > 0
                                                                THEN 0 ELSE 1
                                                        END,
                            CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                            ISNULL(ua.SortOrder, 2147483647),
                            ua.AliasID
                    ) pa
                                        OUTER APPLY (
                                                SELECT TOP 1 uaHome.City, uaHome.[State]
                                                FROM UserAddresses uaHome
                                                WHERE uaHome.UserID = u.UserID
                                                    AND LOWER(LTRIM(RTRIM(ISNULL(uaHome.AddressType, '')))) = 'hometown'
                                                ORDER BY ISNULL(uaHome.IsPrimary, 0) DESC, uaHome.AddressID
                                        ) hometownAddr
             WHERE  u.Active = 1
                             AND  LEN(ISNULL(programAgg.ProgramList, '')) > 0
               AND  (
                                                EXISTS (
                                                        SELECT 1
                                                        FROM UserDegrees udMatch
                                                        WHERE udMatch.UserID = u.UserID
                                                            AND (
                                                                        udMatch.IsUHCO = 1
                                                                        OR udMatch.Program IN ('OD', 'MS', 'PhD')
                                                                    )
                                                            AND ISNULL(udMatch.IsEnrolled, 0) = 0
                                                            AND (udMatch.Program IS NULL OR udMatch.Program <> 'Residency')
                                                            AND TRY_CAST(udMatch.GraduationYear AS INT) = :gradYear
                                                )
                                     )
               AND  (
                        :lastNameStart = ''
                        OR (
                            LEFT(UPPER(LTRIM(CASE WHEN #preferredNamePresentSql# THEN pa.LastName ELSE u.LastName END)), 1) >= :lastNameStart
                            AND LEFT(UPPER(LTRIM(CASE WHEN #preferredNamePresentSql# THEN pa.LastName ELSE u.LastName END)), 1) <= :lastNameFinish
                        )
                    )
               AND  EXISTS (
                        SELECT 1
                        FROM   UserFlagAssignments ufa
                               INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                        WHERE  ufa.UserID = u.UserID
                          AND  uf.FlagName = 'Alumni'
                    )
                             AND  NOT EXISTS (
                                                SELECT 1
                                                FROM   UserFlagAssignments ufaTest
                                                             INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                                                WHERE  ufaTest.UserID = u.UserID
                                                    AND  ufTest.FlagName = 'TEST_USER'
                                        )
                         ORDER BY CASE WHEN #preferredNamePresentSql# THEN pa.LastName ELSE u.LastName END,
                                  CASE WHEN #preferredNamePresentSql# THEN pa.FirstName ELSE u.FirstName END",
            {
                gradYear = { value=arguments.gradYear, cfsqltype="cf_sql_integer" },
                programName = { value=arguments.programName, cfsqltype="cf_sql_varchar" },
                lastNameStart = { value=uCase(trim(arguments.lastNameStart ?: "")), cfsqltype="cf_sql_varchar" },
                lastNameFinish = { value=uCase(trim(arguments.lastNameFinish ?: "")), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
        var rows = queryToArray(qry);
        _applyPreferredNameToRows( rows );
        return rows;
    }

    /**
     * Single Alumni user with student profile and academic data.
     * Returns base fields; degrees, awards, and images are fetched separately.
     */
    public array function getGraduateUser( required numeric userID ) {
        var rows = [];
        var qry = executeQueryWithRetry(
            "SELECT u.UserID,
                    u.FirstName AS FirstName,
                    u.MiddleName AS MiddleName,
                    u.LastName AS LastName,
                    COALESCE(pa.FirstName, '') AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '') AS PreferredLastName,
                    COALESCE(pa.DisplayName, '') AS PreferredDisplayName,
                    uai.CurrentGradYear,
                    usp.FirstExternship, usp.SecondExternship,
                    usp.HometownCity, usp.HometownState
             FROM   Users u
                    LEFT JOIN UserAcademicInfo    uai ON u.UserID = uai.UserID
                    LEFT JOIN UserStudentProfile  usp ON u.UserID = usp.UserID
                    OUTER APPLY (
                                                SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName, ua.DisplayName
                        FROM UserAliases ua
                        WHERE ua.UserID = u.UserID
                          AND ISNULL(ua.IsActive, 1) = 1
                        ORDER BY
                                                        CASE
                                                                WHEN LEN(LTRIM(RTRIM(ISNULL(ua.FirstName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.MiddleName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.LastName, '')))) > 0
                                                                THEN 0 ELSE 1
                                                        END,
                            CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                            ISNULL(ua.SortOrder, 2147483647),
                            ua.AliasID
                    ) pa
             WHERE  u.Active = 1
               AND  u.UserID = :userID
               AND  EXISTS (
                        SELECT 1
                        FROM   UserFlagAssignments ufa
                               INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                        WHERE  ufa.UserID = u.UserID
                          AND  uf.FlagName = 'Alumni'
                      )
                 AND  NOT EXISTS (
                       SELECT 1
                       FROM   UserFlagAssignments ufaTest
                           INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                       WHERE  ufaTest.UserID = u.UserID
                         AND  ufTest.FlagName = 'TEST_USER'
                      )",
            { userID = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        rows = queryToArray(qry);
        _applyPreferredNameToRows( rows );
        return rows;
    }

    /**
     * Users with the Deans flag.
     * Returns: UserID, FirstName, MiddleName, LastName
     */
    public array function getDeansUsers() {
        var preferredNamePresentSql = _preferredNamePresentSql( "pa" );
        var qry = executeQueryWithRetry(
            "SELECT u.UserID,
                    u.FirstName AS FirstName,
                    u.MiddleName AS MiddleName,
                    u.LastName AS LastName,
                    COALESCE(pa.FirstName, '') AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '') AS PreferredLastName
                                        ,COALESCE(pa.DisplayName, '') AS PreferredDisplayName
             FROM   Users u
                    OUTER APPLY (
                                                SELECT TOP 1 ua.FirstName, ua.MiddleName, ua.LastName, ua.DisplayName
                        FROM UserAliases ua
                        WHERE ua.UserID = u.UserID
                          AND ISNULL(ua.IsActive, 1) = 1
                        ORDER BY
                                                        CASE
                                                                WHEN LEN(LTRIM(RTRIM(ISNULL(ua.FirstName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.MiddleName, '')))) > 0
                                                                    OR LEN(LTRIM(RTRIM(ISNULL(ua.LastName, '')))) > 0
                                                                THEN 0 ELSE 1
                                                        END,
                            CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                            ISNULL(ua.SortOrder, 2147483647),
                            ua.AliasID
                    ) pa
             WHERE  u.Active = 1
               AND  EXISTS (
                        SELECT 1
                        FROM   UserFlagAssignments ufa
                               INNER JOIN UserFlags uf ON ufa.FlagID = uf.FlagID
                        WHERE  ufa.UserID = u.UserID
                          AND  uf.FlagName = 'Deans'
                    )
                 AND  NOT EXISTS (
                       SELECT 1
                       FROM   UserFlagAssignments ufaTest
                           INNER JOIN UserFlags ufTest ON ufaTest.FlagID = ufTest.FlagID
                       WHERE  ufaTest.UserID = u.UserID
                         AND  ufTest.FlagName = 'TEST_USER'
                      )
                         ORDER BY CASE WHEN #preferredNamePresentSql# THEN pa.LastName ELSE u.LastName END,
                                            CASE WHEN #preferredNamePresentSql# THEN pa.FirstName ELSE u.FirstName END",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
                var rows = queryToArray(qry);
                _applyPreferredNameToRows( rows );
                return rows;
    }

    /**
     * Bulk-fetch degrees for a set of UserIDs.
     * Returns: array of { USERID, DEGREENAME, UNIVERSITY, GRADUATIONYEAR }
     */
    public array function getDegreesForUsers( required array userIDs ) {
        if ( arrayLen(arguments.userIDs) == 0 ) return [];

        var inClause = "";
        var params   = {};
        for ( var i = 1; i <= arrayLen(arguments.userIDs); i++ ) {
            if ( i > 1 ) inClause &= ",";
            inClause &= ":uid#i#";
            params["uid#i#"] = { value=arguments.userIDs[i], cfsqltype="cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            "SELECT UserID, DegreeName, University, GraduationYear
             FROM   UserDegrees
             WHERE  UserID IN (#inClause#)
             ORDER BY UserID, DegreeID",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    /**
     * Bulk-fetch awards for a set of UserIDs.
     * Returns: array of { USERID, AWARDNAME, AWARDTYPE }
     */
    public array function getAwardsForUsers( required array userIDs ) {
        if ( arrayLen(arguments.userIDs) == 0 ) return [];

        var inClause = "";
        var params   = {};
        for ( var i = 1; i <= arrayLen(arguments.userIDs); i++ ) {
            if ( i > 1 ) inClause &= ",";
            inClause &= ":uid#i#";
            params["uid#i#"] = { value=arguments.userIDs[i], cfsqltype="cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            "SELECT UserID, AwardName, AwardType
             FROM   UserAwards
             WHERE  UserID IN (#inClause#)
             ORDER BY UserID, AwardID",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );
        return queryToArray(qry);
    }

    /**
     * Bulk-fetch the primary image URL for a given variant code across a set of UserIDs.
     * Returns a struct keyed by UserID → ImageURL (first image per user by SortOrder).
     */
    public struct function getImageMapByVariant( required string variantCode, required array userIDs ) {
        if ( arrayLen(arguments.userIDs) == 0 ) return {};

        var inClause = "";
        var params   = { code = { value=arguments.variantCode, cfsqltype="cf_sql_varchar" } };
        for ( var i = 1; i <= arrayLen(arguments.userIDs); i++ ) {
            if ( i > 1 ) inClause &= ",";
            inClause &= ":uid#i#";
            params["uid#i#"] = { value=arguments.userIDs[i], cfsqltype="cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            "SELECT UserID, ImageURL
             FROM (
                 SELECT UserID, ImageURL,
                        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY SortOrder) AS rn
                 FROM   UserImages
                 WHERE  ImageVariant = :code
                   AND  UserID IN (#inClause#)
             ) t
             WHERE t.rn = 1",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );

        var result = {};
        for ( var row in qry ) {
            result[ toString(row.USERID) ] = row.IMAGEURL;
        }
        return result;
    }

    /**
     * Look up a user by external ID value (UH_API_ID, COUGARNET, or PEOPLESOFT).
     * Returns UserID if found, 0 if not found.
     */
    public numeric function getUserIDByExternalID(
        required string externalValue,
        required string systemName
    ) {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 uei.UserID
             FROM   UserExternalIDs uei
                    INNER JOIN ExternalSystems es ON uei.SystemID = es.SystemID
             WHERE  es.SystemName = :systemName
               AND  LOWER(TRIM(uei.ExternalValue)) = LOWER(TRIM(:externalValue))",
            {
                systemName = { value=arguments.systemName, cfsqltype="cf_sql_varchar" },
                externalValue = { value=arguments.externalValue, cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        if ( qry.recordCount > 0 ) {
            return val(qry.UserID);
        }
        return 0;
    }

}
