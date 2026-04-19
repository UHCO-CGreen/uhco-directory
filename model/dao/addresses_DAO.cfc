component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getAddresses( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAddresses WHERE UserID = :id ORDER BY AddressType",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getAddressTypes() {
        var qry = executeQueryWithRetry(
            "SELECT DISTINCT AddressType FROM UserAddresses WHERE NULLIF(LTRIM(RTRIM(AddressType)), '') IS NOT NULL ORDER BY AddressType",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public numeric function createAddress( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserAddresses (UserID, AddressType, Address1, Address2, City, [State], Zipcode, Building, Room, MailCode, isPrimary)
            VALUES (:UserID, :AddressType, :Address1, :Address2, :City, :State, :Zipcode, :Building, :Room, :MailCode, :isPrimary);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function replaceAddresses( required numeric userID, required array addresses ) {
        executeQueryWithRetry(
            "DELETE FROM UserAddresses WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        for ( var addr in addresses ) {
            addr.UserID = { value=userID, cfsqltype="cf_sql_integer" };
            createAddress( addr );
        }
    }

    public void function deleteAddress( required numeric addressID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAddresses WHERE AddressID = :id",
            { id={ value=addressID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteAllForUser( required numeric userID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAddresses WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}