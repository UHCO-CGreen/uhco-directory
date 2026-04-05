component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }
    
    public struct function getUserByID( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM Users WHERE UserID = :id",
            { id = { value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=60, fetchSize=100 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public array function getAllUsers() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM Users ORDER BY LastName, FirstName",
            {},
            { datasource=variables.datasource, timeout=60, fetchSize=1000 }
        );
        return queryToArray(qry);
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

        // Full-text search
        if (len(trim(arguments.searchTerm))) {
            var s = "%" & trim(arguments.searchTerm) & "%";
            arrayAppend(conditions,
                "(u.FirstName LIKE :s OR u.LastName LIKE :s OR u.EmailPrimary LIKE :s OR u.PreferredName LIKE :s)");
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
            "SELECT u.* FROM Users u #where# ORDER BY u.LastName, u.FirstName
             OFFSET :offset ROWS FETCH NEXT :rows ROWS ONLY",
            dataParams,
            { datasource=variables.datasource, timeout=60 }
        );

        return { data: queryToArray(dataQry), totalCount: total };
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
        if ( !structKeyExists(data, "MaidenName") ) {
            data.MaidenName = "";
        }
        // Map Title fields to parameter names (ColdFusion SQL parser doesn't like numeric placeholders)
        data.TitleOneParam = data.Title1;
        data.TitleTwoParam = data.Title2;
        data.TitleThreeParam = data.Title3;

        var q = executeQueryWithRetry(
            "
            INSERT INTO Users (
                FirstName, MiddleName, LastName, MaidenName, 
                PreferredName, Pronouns,
                EmailPrimary, EmailSecondary,
                Phone, UH_API_ID,
                Title1, Title2, Title3,
                Room, Building
            )
            VALUES (
                :FirstName, :MiddleName, :LastName, :MaidenName,
                :PreferredName, :Pronouns,
                :EmailPrimary, :EmailSecondary,
                :Phone, :UH_API_ID,
                :TitleOneParam, :TitleTwoParam, :TitleThreeParam,
                :Room, :Building

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
        if ( !structKeyExists(data, "MaidenName") ) {
            data.MaidenName = "";
        }
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
                PreferredName = :PreferredName,
                MaidenName = :MaidenName,
                Pronouns = :Pronouns,
                EmailPrimary = :EmailPrimary,
                EmailSecondary = :EmailSecondary,
                Phone = :Phone,
                Room = :Room,
                Building = :Building,
                Title1 = :TitleOneParam,
                Title2 = :TitleTwoParam,
                Title3 = :TitleThreeParam,
                UH_API_ID = :UH_API_ID,
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

        executeQueryWithRetry( "DELETE FROM Users WHERE UserID = :id", idParam, opts );
    }

}