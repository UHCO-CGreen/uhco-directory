component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAccessAreas() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM AccessAreas ORDER BY AccessName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getAccessForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT AA.AccessName
            FROM UserAccessAssignments UA
            INNER JOIN AccessAreas AA ON UA.AccessAreaID = AA.AccessAreaID
            WHERE UA.UserID = :id
            ORDER BY AA.AccessName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function grantAccess( required numeric userID, required numeric areaID ) {
        executeQueryWithRetry(
            "
            INSERT INTO UserAccessAssignments (UserID, AccessAreaID)
            VALUES (:uid, :aid)
            ",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                aid={ value=areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function revokeAccess( required numeric userID, required numeric areaID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAccessAssignments WHERE UserID = :uid AND AccessAreaID = :aid",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                aid={ value=areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}