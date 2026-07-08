component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public struct function getPreferredAliasNameMap( array userIDs = [] ) {
        var map = {};
        var allAliasesByUser = getAllActiveAliasesByUserMap(arguments.userIDs);

        for ( var userKey in allAliasesByUser ) {
            if ( isArray(allAliasesByUser[userKey]) AND arrayLen(allAliasesByUser[userKey]) ) {
                var primaryAlias = {};

                for ( var aliasRow in allAliasesByUser[userKey] ) {
                    if ( isBoolean(aliasRow.PRIMARY ?: false) AND aliasRow.PRIMARY ) {
                        primaryAlias = aliasRow;
                        break;
                    }
                }

                if ( structIsEmpty(primaryAlias) ) {
                    primaryAlias = allAliasesByUser[userKey][1];
                }

                map[userKey] = {
                    ALIASID = val(primaryAlias.ALIASID ?: 0),
                    FIRSTNAME = trim(primaryAlias.FIRST ?: ""),
                    MIDDLENAME = trim(primaryAlias.MIDDLE ?: ""),
                    LASTNAME = trim(primaryAlias.LAST ?: ""),
                    DISPLAYNAME = trim(primaryAlias.FULL ?: "")
                };
            }
        }

        return map;
    }

    public struct function getAllActiveAliasesByUserMap( array userIDs = [] ) {
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

        if ( !arrayLen(dedupedIDs) ) {
            return map;
        }

        var inClause = "";
        var params = {};
        for ( var i = 1; i <= arrayLen(dedupedIDs); i++ ) {
            if ( i GT 1 ) {
                inClause &= ",";
            }
            inClause &= ":uid" & i;
            params["uid" & i] = { value = dedupedIDs[i], cfsqltype = "cf_sql_integer" };
        }

        var qry = executeQueryWithRetry(
            "SELECT
                ua.UserID,
                ua.FirstName,
                ua.MiddleName,
                ua.LastName,
                ua.DisplayName,
                ISNULL(ua.IsPrimary, 0) AS IsPrimary,
                ISNULL(ua.SortOrder, 2147483647) AS SortOrder,
                ua.AliasID
             FROM UserAliases ua
             WHERE ISNULL(ua.IsActive, 1) = 1
               AND ua.UserID IN (#inClause#)
             ORDER BY
                ua.UserID,
                CASE WHEN ISNULL(ua.IsPrimary, 0) = 1 THEN 0 ELSE 1 END,
                ISNULL(ua.SortOrder, 2147483647),
                ua.AliasID",
            params,
            { datasource = variables.datasource, timeout = 30, fetchSize = 1000 }
        );

        for ( var row in qry ) {
            var userKey = toString(row.USERID);
            if ( !structKeyExists(map, userKey) ) {
                map[userKey] = [];
            }

            var first = trim(row.FIRSTNAME ?: "");
            var middle = trim(row.MIDDLENAME ?: "");
            var last = trim(row.LASTNAME ?: "");
            var fullParts = [];
            if ( len(first) ) {
                arrayAppend(fullParts, first);
            }
            if ( len(middle) ) {
                arrayAppend(fullParts, middle);
            }
            if ( len(last) ) {
                arrayAppend(fullParts, last);
            }
            var full = arrayToList(fullParts, " ");

            arrayAppend(map[userKey], {
                ALIASID = val(row.ALIASID ?: 0),
                FIRST = first,
                MIDDLE = middle,
                LAST = last,
                FULL = full,
                PRIMARY = (val(row.ISPRIMARY ?: 0) EQ 1)
            });
        }

        return map;
    }
}
