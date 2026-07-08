component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getAddresses( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT *
             FROM UserAddresses
             WHERE UserID = :id
             ORDER BY ISNULL(IsPrimary, 0) DESC, AddressType, AddressID",
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

    public struct function getPrimaryAddressesMap( array userIDs = [] ) {
        var map = {};
        var dedupedIDs = [];
        var seen = {};
        for ( var rawID in arguments.userIDs ) {
            if ( isNumeric(rawID) ) {
                var numericID = val(rawID);
                var idKey = toString(numericID);
                if ( numericID GT 0 AND !structKeyExists(seen, idKey) ) {
                    seen[idKey] = true;
                    arrayAppend(dedupedIDs, numericID);
                }
            }
        }
        if ( !arrayLen(dedupedIDs) ) return map;

        var inClause = "";
        var params = {};
        for ( var i = 1; i <= arrayLen(dedupedIDs); i++ ) {
            if ( i GT 1 ) inClause &= ",";
            inClause &= ":uid" & i;
            params["uid" & i] = { value=dedupedIDs[i], cfsqltype="cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            "SELECT AddressID, UserID, AddressType, Address1, Address2, City,
                    [State], Zipcode, Building, Room, MailCode, IsPrimary
             FROM UserAddresses
             WHERE UserID IN (#inClause#)
             ORDER BY UserID, ISNULL(IsPrimary,0) DESC, AddressType, AddressID",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );

        for ( var row in qry ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(map, key) ) {
                map[key] = row;
            }
        }
        return map;
    }

    public void function deleteAllForUser( required numeric userID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAddresses WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}