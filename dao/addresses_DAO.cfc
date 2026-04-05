component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAddresses( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAddresses WHERE UserID = :id ORDER BY AddressType",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public numeric function createAddress( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserAddresses (UserID, AddressType, Building, Room, MailCode)
            VALUES (:UserID, :AddressType, :Building, :Room, :MailCode);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function deleteAddress( required numeric addressID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAddresses WHERE AddressID = :id",
            { id={ value=addressID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}