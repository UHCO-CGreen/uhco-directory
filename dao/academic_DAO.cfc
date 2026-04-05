component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public struct function getAcademicInfo( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAcademicInfo WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public numeric function createAcademicInfo( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserAcademicInfo (
                UserID, OriginalGradYear, CurrentGradYear
            )
            VALUES (
                :UserID, :OriginalGradYear, :CurrentGradYear
            );
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function updateAcademicInfo( required numeric userID, required struct data ) {
        data.id = userID;

        executeQueryWithRetry(
            "
            UPDATE UserAcademicInfo SET
                OriginalGradYear = :OriginalGradYear,
                CurrentGradYear = :CurrentGradYear
            WHERE UserID = :id
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAllAcademicInfo() {
        var qry = executeQueryWithRetry(
            "SELECT UserID, CurrentGradYear, OriginalGradYear FROM UserAcademicInfo",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=2000 }
        );
        return queryToArray(qry);
    }

}