component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getEmails( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserEmails WHERE UserID = :id ORDER BY SortOrder, EmailID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getEmailTypes() {
        var qry = executeQueryWithRetry(
            "SELECT DISTINCT EmailType FROM UserEmails WHERE NULLIF(LTRIM(RTRIM(EmailType)), '') IS NOT NULL ORDER BY EmailType",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function replaceEmails( required numeric userID, required array emails ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserEmails WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        for ( var em in arguments.emails ) {
            executeQueryWithRetry(
                "INSERT INTO UserEmails (UserID, EmailAddress, EmailType, IsPrimary, SortOrder)
                 VALUES (:id, :EmailAddress, :EmailType, :IsPrimary, :SortOrder)",
                {
                    id           = { value=userID,                   cfsqltype="cf_sql_integer"  },
                    EmailAddress = { value=em.address,               cfsqltype="cf_sql_nvarchar" },
                    EmailType    = { value=em.type,                  cfsqltype="cf_sql_nvarchar" },
                    IsPrimary    = { value=(em.isPrimary ? 1 : 0),   cfsqltype="cf_sql_bit"      },
                    SortOrder    = { value=sortIdx,                  cfsqltype="cf_sql_integer"  }
                },
                { datasource=variables.datasource, timeout=30 }
            );
            sortIdx++;
        }
    }

    public struct function getAllEmailsMap() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserEmails ORDER BY UserID, SortOrder, EmailID",
            {}, { datasource=variables.datasource, timeout=60, fetchSize=5000 }
        );
        var rows = queryToArray(qry);
        var map = {};
        for ( var row in rows ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(map, key) ) { map[key] = []; }
            arrayAppend(map[key], row);
        }
        return map;
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserEmails WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }
}
