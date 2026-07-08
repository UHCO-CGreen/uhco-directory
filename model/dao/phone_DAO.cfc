component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getPhones( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT *
             FROM UserPhone
             WHERE UserID = :id
             ORDER BY ISNULL(IsPrimary, 0) DESC, SortOrder, PhoneID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getPhoneTypes() {
        var qry = executeQueryWithRetry(
            "SELECT DISTINCT PhoneType FROM UserPhone WHERE NULLIF(LTRIM(RTRIM(PhoneType)), '') IS NOT NULL ORDER BY PhoneType",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function replacePhones( required numeric userID, required array phones ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserPhone WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        for ( var ph in arguments.phones ) {
            executeQueryWithRetry(
                "INSERT INTO UserPhone (UserID, PhoneNumber, PhoneType, IsPrimary, SortOrder)
                 VALUES (:id, :PhoneNumber, :PhoneType, :IsPrimary, :SortOrder)",
                {
                    id          = { value=userID,                   cfsqltype="cf_sql_integer"  },
                    PhoneNumber = { value=ph.number,                cfsqltype="cf_sql_nvarchar" },
                    PhoneType   = { value=ph.type,                  cfsqltype="cf_sql_nvarchar" },
                    IsPrimary   = { value=(ph.isPrimary ? 1 : 0),   cfsqltype="cf_sql_bit"      },
                    SortOrder   = { value=sortIdx,                  cfsqltype="cf_sql_integer"  }
                },
                { datasource=variables.datasource, timeout=30 }
            );
            sortIdx++;
        }
    }

    public struct function getPrimaryPhonesMap( array userIDs = [] ) {
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
            "SELECT UserID, PhoneNumber, PhoneType, IsPrimary
             FROM UserPhone
             WHERE UserID IN (#inClause#)
             ORDER BY UserID, ISNULL(IsPrimary,0) DESC, SortOrder, PhoneID",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );

        for ( var row in qry ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(map, key) ) {
                map[key] = {
                    PHONE   = trim(row.PHONENUMBER ?: ""),
                    TYPE    = trim(row.PHONETYPE ?: ""),
                    PRIMARY = (val(row.ISPRIMARY ?: 0) EQ 1)
                };
            }
        }
        return map;
    }

    public struct function getAllPrimaryPhonesMap() {
        var qry = executeQueryWithRetry(
            "SELECT UserID, PhoneNumber, PhoneType, IsPrimary
             FROM UserPhone
             ORDER BY UserID, ISNULL(IsPrimary,0) DESC, SortOrder, PhoneID",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=5000 }
        );
        var map = {};
        for ( var row in qry ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(map, key) ) {
                map[key] = {
                    PHONE   = trim(row.PHONENUMBER ?: ""),
                    TYPE    = trim(row.PHONETYPE ?: ""),
                    PRIMARY = (val(row.ISPRIMARY ?: 0) EQ 1)
                };
            }
        }
        return map;
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserPhone WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }
}
