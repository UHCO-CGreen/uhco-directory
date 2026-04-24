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
                 ORDER BY
                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
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
                 ORDER BY
                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
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
                "EXISTS (SELECT 1 FROM UserAcademicInfo uai
                         WHERE uai.UserID = u.UserID AND uai.CurrentGradYear = :gradYear)");
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

        // Exclude users that have any of the protected flags
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
                             WHERE ufa.UserID = u.UserID AND uf.FlagName IN (#exFlagList#))");
        }

        // Exclude users that belong to any of the protected orgs
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
                             WHERE uo.UserID = u.UserID AND o.OrgName IN (#exOrgList#))");
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
            "SELECT u.*, thumb.ImageURL AS WebThumbURL,
                    COALESCE(pa.FirstName, '')  AS PreferredFirstName,
                    COALESCE(pa.MiddleName, '') AS PreferredMiddleName,
                    COALESCE(pa.LastName, '')   AS PreferredLastName
             FROM Users u
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
                 ORDER BY
                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
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

    private void function _applyPreferredNameToRows( required array rows ) {
        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            _applyPreferredNameToRow( arguments.rows[i] );
        }
    }

    private void function _applyPreferredNameToRow( required struct row ) {
        var first = len(trim(arguments.row.PREFERREDFIRSTNAME ?: "")) ? trim(arguments.row.PREFERREDFIRSTNAME) : trim(arguments.row.FIRSTNAME ?: "");
        var middle = len(trim(arguments.row.PREFERREDMIDDLENAME ?: "")) ? trim(arguments.row.PREFERREDMIDDLENAME) : trim(arguments.row.MIDDLENAME ?: "");
        var last = len(trim(arguments.row.PREFERREDLASTNAME ?: "")) ? trim(arguments.row.PREFERREDLASTNAME) : trim(arguments.row.LASTNAME ?: "");

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
                UpdatedAt = GETDATE()
            WHERE UserID = :id
            ",
            data,
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
    }

    public void function deleteUser( required numeric userID ) {
        var idParam = { id = { value=userID, cfsqltype="cf_sql_integer" } };
        var opts    = { datasource=variables.datasource, timeout=30, fetchSize=10 };

        // Delete all child-table rows first (FK constraints on Users.UserID)
        executeQueryWithRetry( "DELETE FROM UserFlagAssignments  WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserOrganizations    WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAccessAssignments WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAddresses        WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserAcademicInfo     WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserImages           WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserExternalIDs      WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserDegrees          WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserEmails           WHERE UserID = :id", idParam, opts );
        executeQueryWithRetry( "DELETE FROM UserBio              WHERE UserID = :id", idParam, opts );

        executeQueryWithRetry( "DELETE FROM Users WHERE UserID = :id", idParam, opts );
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

}