component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getEmails( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT *
             FROM UserEmails
             WHERE UserID = :id
             ORDER BY ISNULL(IsPrimary, 0) DESC, SortOrder, EmailID",
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
        var explicitPrimaryIndex = 0;
        var primaryIndex = 0;
        var idx = 0;

        for (idx = 1; idx <= arrayLen(arguments.emails); idx++) {
            if (val(arguments.emails[idx].isPrimary ?: 0) EQ 1) {
                explicitPrimaryIndex = idx;
                break;
            }
        }

        if (explicitPrimaryIndex GT 0) {
            primaryIndex = explicitPrimaryIndex;
        } else if (arrayLen(arguments.emails) GT 0) {
            primaryIndex = 1;
        }

        executeQueryWithRetry(
            "DELETE FROM UserEmails WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        idx = 0;
        for ( var em in arguments.emails ) {
            idx++;
            executeQueryWithRetry(
                "INSERT INTO UserEmails (UserID, EmailAddress, EmailType, IsPrimary, SortOrder)
                 VALUES (:id, :EmailAddress, :EmailType, :IsPrimary, :SortOrder)",
                {
                    id           = { value=userID,                   cfsqltype="cf_sql_integer"  },
                    EmailAddress = { value=lCase(trim(em.address ?: "")), cfsqltype="cf_sql_nvarchar" },
                    EmailType    = { value=trim(em.type ?: ""),     cfsqltype="cf_sql_nvarchar" },
                    IsPrimary    = { value=(idx EQ primaryIndex ? 1 : 0), cfsqltype="cf_sql_bit" },
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

    public struct function getPrimaryEmailsMap( array userIDs = [] ) {
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
            "SELECT UserID, EmailAddress, EmailType, IsPrimary
             FROM UserEmails
             WHERE UserID IN (#inClause#)
             ORDER BY UserID, ISNULL(IsPrimary,0) DESC, SortOrder, EmailID",
            params,
            { datasource=variables.datasource, timeout=30, fetchSize=1000 }
        );

        for ( var row in qry ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(map, key) ) {
                map[key] = {
                    EMAIL   = trim(row.EMAILADDRESS ?: ""),
                    TYPE    = trim(row.EMAILTYPE ?: ""),
                    PRIMARY = (val(row.ISPRIMARY ?: 0) EQ 1)
                };
            }
        }
        return map;
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserEmails WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }

    public boolean function addEmailIfMissing(
        required numeric userID,
        required string emailAddress,
        string emailType = "UH"
    ) {
        var normalizedEmail = lCase(trim(arguments.emailAddress));
        var existingQry = "";
        var nextSortQry = "";
        var nextSort = 0;

        if (!len(normalizedEmail)) {
            return false;
        }

        existingQry = executeQueryWithRetry(
            "SELECT TOP 1 EmailID
             FROM UserEmails
             WHERE UserID = :id
               AND LOWER(LTRIM(RTRIM(EmailAddress))) = :email",
            {
                id    = { value=arguments.userID, cfsqltype="cf_sql_integer" },
                email = { value=normalizedEmail, cfsqltype="cf_sql_nvarchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        if (existingQry.recordCount GT 0) {
            return false;
        }

        nextSortQry = executeQueryWithRetry(
            "SELECT ISNULL(MAX(SortOrder), -1) + 1 AS NextSort
             FROM UserEmails
             WHERE UserID = :id",
            { id = { value=arguments.userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
        nextSort = val(nextSortQry.NextSort[1]);

        executeQueryWithRetry(
            "INSERT INTO UserEmails (UserID, EmailAddress, EmailType, IsPrimary, SortOrder)
             VALUES (:id, :EmailAddress, :EmailType, :IsPrimary, :SortOrder)",
            {
                id           = { value=arguments.userID, cfsqltype="cf_sql_integer"  },
                EmailAddress = { value=trim(arguments.emailAddress), cfsqltype="cf_sql_nvarchar" },
                EmailType    = { value=trim(arguments.emailType), cfsqltype="cf_sql_nvarchar" },
                IsPrimary    = { value=0, cfsqltype="cf_sql_bit" },
                SortOrder    = { value=nextSort, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return true;
    }
}
