component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public struct function getBio( required numeric userID, string bioType = "ProfessionalBio" ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserBio WHERE UserID = :id AND BioType = :bioType",
            {
                id={ value=userID, cfsqltype="cf_sql_integer" },
                bioType={ value=arguments.bioType, cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public array function getBiosForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserBio WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return queryToArray( qry );
    }

    public void function saveBio( required numeric userID, required struct data, string bioType = "ProfessionalBio" ) {
        data.id = userID;
        data.bioType = { value=arguments.bioType, cfsqltype="cf_sql_varchar" };
        var existing = getBio( userID, arguments.bioType );
        if ( structIsEmpty(existing) ) {
            executeQueryWithRetry(
                "INSERT INTO UserBio (UserID, BioType, BioContent) VALUES (:id, :bioType, :BioContent)",
                data,
                { datasource=variables.datasource, timeout=30 }
            );
        } else {
            executeQueryWithRetry(
                "UPDATE UserBio SET BioContent = :BioContent, UpdatedAt = GETDATE() WHERE UserID = :id AND BioType = :bioType",
                data,
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    public void function deleteForUser( required numeric userID ) {
        executeQueryWithRetry(
            "DELETE FROM UserBio WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
