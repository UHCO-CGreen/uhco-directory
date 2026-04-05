component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAllFlags() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserFlags ORDER BY FlagName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getFlagsForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT UF.FlagID, UF.FlagName
            FROM UserFlagAssignments UFA
            INNER JOIN UserFlags UF ON UFA.FlagID = UF.FlagID
            WHERE UFA.UserID = :id
            ORDER BY UF.FlagName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function assignFlag( required numeric userID, required numeric flagID ) {
        executeQueryWithRetry(
            "
            INSERT INTO UserFlagAssignments (UserID, FlagID)
            VALUES (:uid, :fid)
            ",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                fid={ value=flagID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function removeFlag( required numeric userID, required numeric flagID ) {
        executeQueryWithRetry(
            "DELETE FROM UserFlagAssignments WHERE UserID = :uid AND FlagID = :fid",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                fid={ value=flagID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public numeric function createFlag( required string flagName ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserFlags (FlagName)
            VALUES (:flagName);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            { flagName={ value=trim(flagName), cfsqltype="cf_sql_varchar" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function updateFlag( required numeric flagID, required string flagName ) {
        executeQueryWithRetry(
            "UPDATE UserFlags SET FlagName = :flagName WHERE FlagID = :id",
            {
                id={ value=flagID, cfsqltype="cf_sql_integer" },
                flagName={ value=trim(flagName), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function removeAllAssignmentsForFlag( required numeric flagID ) {
        executeQueryWithRetry(
            "DELETE FROM UserFlagAssignments WHERE FlagID = :id",
            { id={ value=flagID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteFlag( required numeric flagID ) {
        executeQueryWithRetry(
            "DELETE FROM UserFlags WHERE FlagID = :id",
            { id={ value=flagID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAllUserFlagAssignments() {
        var qry = executeQueryWithRetry(
            "SELECT UFA.UserID, UF.FlagID, UF.FlagName
             FROM UserFlagAssignments UFA
             INNER JOIN UserFlags UF ON UFA.FlagID = UF.FlagID
             ORDER BY UF.FlagName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=2000 }
        );
        return queryToArray(qry);
    }

}