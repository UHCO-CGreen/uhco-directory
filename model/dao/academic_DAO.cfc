component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public struct function getAcademicInfo( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAcademicInfo WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public numeric function createAcademicInfo( required struct data ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO UserAcademicInfo (
                UserID, OriginalGradYear, CurrentGradYear
            )
            VALUES (
                :UserID, :OriginalGradYear, :CurrentGradYear
            );
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function updateAcademicInfo( required numeric userID, required struct data ) {
        data.id = userID;

        executeQueryWithRetry(
            "
            UPDATE UserAcademicInfo SET
                OriginalGradYear = :OriginalGradYear,
                CurrentGradYear = :CurrentGradYear
            WHERE UserID = :id
            ",
            data,
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAllAcademicInfo() {
        var qry = executeQueryWithRetry(
            "SELECT UserID, CurrentGradYear, OriginalGradYear FROM UserAcademicInfo",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=2000 }
        );
        return queryToArray(qry);
    }

    public array function getAcademicInfoForUsers( required array userIDs ) {
        var normalizedUserIDs = _normalizeUserIDs(arguments.userIDs);
        var results = [];
        var maxIDsPerBatch = 1000;
        var batchStart = 0;
        var batchEnd = 0;
        var batchUserIDs = [];
        var params = {};
        var inClause = "";
        var idx = 0;
        var qry = "";
        var row = "";

        if ( !arrayLen(normalizedUserIDs) ) {
            return [];
        }

        for ( batchStart = 1; batchStart LTE arrayLen(normalizedUserIDs); batchStart += maxIDsPerBatch ) {
            batchEnd = min(batchStart + maxIDsPerBatch - 1, arrayLen(normalizedUserIDs));
            batchUserIDs = [];
            params = {};
            inClause = "";

            for ( idx = batchStart; idx LTE batchEnd; idx++ ) {
                arrayAppend(batchUserIDs, normalizedUserIDs[idx]);
            }

            for ( idx = 1; idx LTE arrayLen(batchUserIDs); idx++ ) {
                if ( idx GT 1 ) {
                    inClause &= ",";
                }
                inClause &= ":uid" & idx;
                params["uid" & idx] = { value=batchUserIDs[idx], cfsqltype="cf_sql_integer" };
            }

            qry = executeQueryWithRetry(
                "SELECT UserID, CurrentGradYear, OriginalGradYear
                 FROM UserAcademicInfo
                 WHERE UserID IN (#inClause#)",
                params,
                { datasource=variables.datasource, timeout=30, fetchSize=1000 }
            );

            for ( row in queryToArray(qry) ) {
                arrayAppend(results, row);
            }
        }

        return results;
    }

    private array function _normalizeUserIDs( required array userIDs ) {
        var normalized = [];
        var seen = {};
        var rawUserID = "";
        var numericUserID = 0;
        var userKey = "";

        for ( rawUserID in arguments.userIDs ) {
            if ( !isNumeric(rawUserID) ) {
                continue;
            }

            numericUserID = val(rawUserID);
            if ( numericUserID LTE 0 ) {
                continue;
            }

            userKey = toString(numericUserID);
            if ( structKeyExists(seen, userKey) ) {
                continue;
            }

            seen[userKey] = true;
            arrayAppend(normalized, numericUserID);
        }

        return normalized;
    }

}