component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getImages( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserImages WHERE UserID = :id ORDER BY SortOrder",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public numeric function addImage( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserImages (UserID, ImageType, ImageURL, ImageDescription, SortOrder)
            VALUES (:UserID, :ImageType, :ImageURL, :ImageDescription, :SortOrder);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function removeImage( required numeric imageID ) {
        executeQueryWithRetry(
            "DELETE FROM UserImages WHERE ImageID = :id",
            { id={ value=imageID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}