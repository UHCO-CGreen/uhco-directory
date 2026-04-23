component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getAliases( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAliases WHERE UserID = :id ORDER BY IsPrimary DESC, SortOrder, AliasID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public struct function getPreferredAliasMap( array userIDs = [] ) {
        var idx = 0;
        var row = {};
        var map = {};
        var dedupedUserIDs = [];
        var seenUserIDs = {};
        var maxBatchSize = 2000;
        var batchStart = 0;
        var batchEnd = 0;
        var batchPosition = 0;
        var inClause = "";
        var params = {};
        var whereClause = "";
        var qry = "";

        for (idx = 1; idx <= arrayLen(arguments.userIDs); idx++) {
            if (isNumeric(arguments.userIDs[idx])) {
                var idValue = val(arguments.userIDs[idx]);
                var idKey = toString(idValue);
                if (idValue GT 0 AND NOT structKeyExists(seenUserIDs, idKey)) {
                    seenUserIDs[idKey] = true;
                    arrayAppend(dedupedUserIDs, idValue);
                }
            }
        }

        if (arrayLen(arguments.userIDs) AND NOT arrayLen(dedupedUserIDs)) {
            return map;
        }

        if (arrayLen(dedupedUserIDs)) {
            for (batchStart = 1; batchStart <= arrayLen(dedupedUserIDs); batchStart += maxBatchSize) {
                batchEnd = min(batchStart + maxBatchSize - 1, arrayLen(dedupedUserIDs));
                inClause = "";
                params = {};
                batchPosition = 0;

                for (idx = batchStart; idx <= batchEnd; idx++) {
                    batchPosition++;
                    if (batchPosition GT 1) {
                        inClause &= ",";
                    }
                    inClause &= ":uid#batchPosition#";
                    params["uid#batchPosition#"] = { value=dedupedUserIDs[idx], cfsqltype="cf_sql_integer" };
                }

                whereClause = "WHERE ua.UserID IN (#inClause#)";

                qry = executeQueryWithRetry(
                    "WITH RankedAliases AS (
                        SELECT
                            ua.UserID,
                            ua.FirstName,
                            ua.MiddleName,
                            ua.LastName,
                            ROW_NUMBER() OVER (
                                PARTITION BY ua.UserID
                                ORDER BY
                                    CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                                    CASE WHEN ISNULL(ua.IsActive, 0) = 1 THEN 0 ELSE 1 END,
                                    ISNULL(ua.SortOrder, 2147483647),
                                    ua.AliasID
                            ) AS rn
                        FROM UserAliases ua
                        #whereClause#
                    )
                    SELECT UserID, FirstName, MiddleName, LastName
                    FROM RankedAliases
                    WHERE rn = 1",
                    params,
                    { datasource=variables.datasource, timeout=30, fetchSize=500 }
                );

                for (row in qry) {
                    map[toString(row.USERID)] = {
                        FIRSTNAME = row.FIRSTNAME ?: "",
                        MIDDLENAME = row.MIDDLENAME ?: "",
                        LASTNAME = row.LASTNAME ?: ""
                    };
                }
            }
        } else {
            qry = executeQueryWithRetry(
                "WITH RankedAliases AS (
                    SELECT
                        ua.UserID,
                        ua.FirstName,
                        ua.MiddleName,
                        ua.LastName,
                        ROW_NUMBER() OVER (
                            PARTITION BY ua.UserID
                            ORDER BY
                                CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                                CASE WHEN ISNULL(ua.IsActive, 0) = 1 THEN 0 ELSE 1 END,
                                ISNULL(ua.SortOrder, 2147483647),
                                ua.AliasID
                        ) AS rn
                    FROM UserAliases ua
                )
                SELECT UserID, FirstName, MiddleName, LastName
                FROM RankedAliases
                WHERE rn = 1",
                {},
                { datasource=variables.datasource, timeout=30, fetchSize=500 }
            );

            for (row in qry) {
                map[toString(row.USERID)] = {
                    FIRSTNAME = row.FIRSTNAME ?: "",
                    MIDDLENAME = row.MIDDLENAME ?: "",
                    LASTNAME = row.LASTNAME ?: ""
                };
            }
        }

        return map;
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
        var existingAliases = getAliases(arguments.userID);
        var existingPrimaryKey = "";
        var existingAlias = {};
        var hasExplicitPrimary = false;
        var firstActiveIndex = 0;
        var primaryIndex = 0;
        var idx = 0;

        for (existingAlias in existingAliases) {
            if (val(existingAlias.ISPRIMARY ?: 0) EQ 1) {
                existingPrimaryKey = lCase(trim(existingAlias.FIRSTNAME ?: "")) & "|" &
                    lCase(trim(existingAlias.MIDDLENAME ?: "")) & "|" &
                    lCase(trim(existingAlias.LASTNAME ?: "")) & "|" &
                    lCase(trim(existingAlias.ALIASTYPE ?: "")) & "|" &
                    lCase(trim(existingAlias.SOURCESYSTEM ?: ""));
                break;
            }
        }

        // Resolve target primary index once so inserts are deterministic.
        for (idx = 1; idx <= arrayLen(arguments.aliases); idx++) {
            var candidate = arguments.aliases[idx];
            var candidateKey = lCase(trim(candidate.firstName ?: "")) & "|" &
                lCase(trim(candidate.middleName ?: "")) & "|" &
                lCase(trim(candidate.lastName ?: "")) & "|" &
                lCase(trim(candidate.aliasType ?: "")) & "|" &
                lCase(trim(candidate.sourceSystem ?: ""));
            var candidateActive = val(candidate.isActive ?: 0) EQ 1;

            if (val(candidate.isPrimary ?: 0) EQ 1 AND NOT hasExplicitPrimary) {
                hasExplicitPrimary = true;
                primaryIndex = idx;
            }
            if (firstActiveIndex EQ 0 AND candidateActive) {
                firstActiveIndex = idx;
            }
            if (primaryIndex EQ 0 AND len(existingPrimaryKey) AND candidateKey EQ existingPrimaryKey) {
                primaryIndex = idx;
            }
        }

        if (primaryIndex EQ 0) {
            primaryIndex = firstActiveIndex;
        }
        if (primaryIndex EQ 0 AND arrayLen(arguments.aliases) GT 0) {
            primaryIndex = 1;
        }

        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserAliases WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        idx = 0;
        for ( var al in arguments.aliases ) {
            idx++;
            var firstName  = al.firstName  ?: "";
            var middleName = al.middleName ?: "";
            var lastName   = al.lastName   ?: "";
            var displayParts = [];
            if ( len(trim(firstName)) )  { arrayAppend(displayParts, trim(firstName)); }
            if ( len(trim(middleName)) ) { arrayAppend(displayParts, trim(middleName)); }
            if ( len(trim(lastName)) )   { arrayAppend(displayParts, trim(lastName)); }
            var displayName = arrayToList(displayParts, " ");
            if ( !len(displayName) ) { displayName = al.displayName ?: "(unnamed)"; }
            var isPrimary = (idx EQ primaryIndex) ? 1 : 0;

            executeQueryWithRetry(
                "INSERT INTO UserAliases (UserID, FirstName, MiddleName, LastName, DisplayName, AliasType, SourceSystem, IsActive, IsPrimary, SortOrder)
                 VALUES (:id, :FirstName, :MiddleName, :LastName, :DisplayName, :AliasType, :SourceSystem, :IsActive, :IsPrimary, :SortOrder)",
                {
                    id           = { value=userID,                        cfsqltype="cf_sql_integer"  },
                    FirstName    = { value=firstName,                     cfsqltype="cf_sql_nvarchar", null=(len(firstName) EQ 0) },
                    MiddleName   = { value=middleName,                   cfsqltype="cf_sql_nvarchar", null=(len(middleName) EQ 0) },
                    LastName     = { value=lastName,                     cfsqltype="cf_sql_nvarchar", null=(len(lastName) EQ 0) },
                    DisplayName  = { value=displayName,                  cfsqltype="cf_sql_nvarchar" },
                    AliasType    = { value=al.aliasType,                 cfsqltype="cf_sql_nvarchar" },
                    SourceSystem = { value=(al.sourceSystem ?: ""),       cfsqltype="cf_sql_nvarchar", null=(len(al.sourceSystem ?: "") EQ 0) },
                    IsActive     = { value=(al.isActive ? 1 : 0),        cfsqltype="cf_sql_bit"      },
                    IsPrimary    = { value=isPrimary,                    cfsqltype="cf_sql_bit"      },
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
