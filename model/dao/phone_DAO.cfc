component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getPhones( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserPhone WHERE UserID = :id ORDER BY SortOrder, PhoneID",
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

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserPhone WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }
}
