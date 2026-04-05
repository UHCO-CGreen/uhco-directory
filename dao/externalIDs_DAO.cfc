component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getExternalIDs( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT UE.SystemID, ES.SystemName, UE.ExternalValue
            FROM UserExternalIDs UE
            INNER JOIN ExternalSystems ES ON UE.SystemID = ES.SystemID
            WHERE UE.UserID = :id
            ORDER BY ES.SystemName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function setExternalID( required numeric userID, required numeric systemID, required string value ) {
        executeQueryWithRetry(
            "
            MERGE UserExternalIDs AS target
            USING (SELECT :uid AS UserID, :sid AS SystemID) AS src
            ON target.UserID = src.UserID AND target.SystemID = src.SystemID
            WHEN MATCHED THEN
                UPDATE SET ExternalValue = :val
            WHEN NOT MATCHED THEN
                INSERT (UserID, SystemID, ExternalValue)
                VALUES (:uid, :sid, :val);
            ",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                sid={ value=systemID, cfsqltype="cf_sql_integer" },
                val={ value=value, cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAllExternalIDs() {
        var qry = executeQueryWithRetry(
            "SELECT UserID, SystemID, ExternalValue FROM UserExternalIDs",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=5000 }
        );
        return queryToArray(qry);
    }

}