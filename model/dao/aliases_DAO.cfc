component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getAliases( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAliases WHERE UserID = :id ORDER BY SortOrder, AliasID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getAliasTypes() {
        var qry = executeQueryWithRetry(
            "SELECT AliasTypeCode, Description FROM AliasTypes ORDER BY AliasTypeCode",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function replaceAliases( required numeric userID, required array aliases ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserAliases WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        for ( var al in arguments.aliases ) {
            var firstName  = al.firstName  ?: "";
            var middleName = al.middleName ?: "";
            var lastName   = al.lastName   ?: "";
            var displayParts = [];
            if ( len(trim(firstName)) )  { arrayAppend(displayParts, trim(firstName)); }
            if ( len(trim(middleName)) ) { arrayAppend(displayParts, trim(middleName)); }
            if ( len(trim(lastName)) )   { arrayAppend(displayParts, trim(lastName)); }
            var displayName = arrayToList(displayParts, " ");
            if ( !len(displayName) ) { displayName = al.displayName ?: "(unnamed)"; }

            executeQueryWithRetry(
                "INSERT INTO UserAliases (UserID, FirstName, MiddleName, LastName, DisplayName, AliasType, SourceSystem, IsActive, SortOrder)
                 VALUES (:id, :FirstName, :MiddleName, :LastName, :DisplayName, :AliasType, :SourceSystem, :IsActive, :SortOrder)",
                {
                    id           = { value=userID,                        cfsqltype="cf_sql_integer"  },
                    FirstName    = { value=firstName,                     cfsqltype="cf_sql_nvarchar", null=(len(firstName) EQ 0) },
                    MiddleName   = { value=middleName,                   cfsqltype="cf_sql_nvarchar", null=(len(middleName) EQ 0) },
                    LastName     = { value=lastName,                     cfsqltype="cf_sql_nvarchar", null=(len(lastName) EQ 0) },
                    DisplayName  = { value=displayName,                  cfsqltype="cf_sql_nvarchar" },
                    AliasType    = { value=al.aliasType,                 cfsqltype="cf_sql_nvarchar" },
                    SourceSystem = { value=(al.sourceSystem ?: ""),       cfsqltype="cf_sql_nvarchar", null=(len(al.sourceSystem ?: "") EQ 0) },
                    IsActive     = { value=(al.isActive ? 1 : 0),        cfsqltype="cf_sql_bit"      },
                    SortOrder    = { value=sortIdx,                      cfsqltype="cf_sql_integer"  }
                },
                { datasource=variables.datasource, timeout=30 }
            );
            sortIdx++;
        }
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserAliases WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }
}
