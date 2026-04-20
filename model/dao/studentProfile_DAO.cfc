component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public struct function getProfile( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserStudentProfile WHERE UserID = :id",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=10 }
        );
        return (qry.recordCount > 0) ? qry.getRow(1) : {};
    }

    public void function saveProfile( required numeric userID, required struct data ) {
        data.id = userID;
        var existing = getProfile( userID );
        var firstExternship = structKeyExists(data, "FirstExternship") ? data.FirstExternship : "";
        var secondExternship = structKeyExists(data, "SecondExternship") ? data.SecondExternship : "";
        var commencementAge = structKeyExists(data, "CommencementAge") ? data.CommencementAge : { value="", cfsqltype="cf_sql_integer", null=true };
        var hometownCity = structKeyExists(data, "HometownCity") ? data.HometownCity : { value="", cfsqltype="cf_sql_nvarchar", null=true };
        var hometownState = structKeyExists(data, "HometownState") ? data.HometownState : { value="", cfsqltype="cf_sql_nvarchar", null=true };

        data.FirstExternship = firstExternship;
        data.SecondExternship = secondExternship;
        data.CommencementAge = commencementAge;
        data.HometownCity = hometownCity;
        data.HometownState = hometownState;

        if ( structIsEmpty(existing) ) {
            executeQueryWithRetry(
                "INSERT INTO UserStudentProfile (UserID, FirstExternship, SecondExternship, CommencementAge, HometownCity, HometownState)
                 VALUES (:id, :FirstExternship, :SecondExternship, :CommencementAge, :HometownCity, :HometownState)",
                data,
                { datasource=variables.datasource, timeout=30 }
            );
        } else {
            executeQueryWithRetry(
                "UPDATE UserStudentProfile
                 SET FirstExternship=:FirstExternship, SecondExternship=:SecondExternship,
                     CommencementAge=:CommencementAge,
                     HometownCity=:HometownCity,
                     HometownState=:HometownState,
                     UpdatedAt=GETDATE()
                 WHERE UserID=:id",
                data,
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    public void function saveHometown( required numeric userID, string hometownCity = "", string hometownState = "" ) {
        saveProfile( userID, {
            HometownCity = { value=trim(arguments.hometownCity), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.hometownCity)) },
            HometownState = { value=trim(arguments.hometownState), cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.hometownState)) }
        } );
    }

    public array function getMissingHometownSyncCandidates() {
        var qry = executeQueryWithRetry(
            "
            WITH rankedAddresses AS (
                SELECT
                    ua.UserID,
                    ua.City,
                    ua.[State],
                    ROW_NUMBER() OVER (
                        PARTITION BY ua.UserID
                        ORDER BY ISNULL(ua.isPrimary, 0) DESC, ua.AddressID DESC
                    ) AS RowNum
                FROM UserAddresses ua
                WHERE LOWER(LTRIM(RTRIM(ISNULL(ua.AddressType, '')))) = 'hometown'
            ),
            targetUsers AS (
                SELECT DISTINCT ufa.UserID
                FROM UserFlagAssignments ufa
                INNER JOIN UserFlags uf ON uf.FlagID = ufa.FlagID
                WHERE LOWER(LTRIM(RTRIM(ISNULL(uf.FlagName, '')))) IN ('alumni', 'current-student', 'current student')
            )
            SELECT
                ra.UserID,
                ra.City,
                ra.[State],
                CASE WHEN usp.UserID IS NULL THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END AS HasProfile
            FROM rankedAddresses ra
            INNER JOIN targetUsers tu ON tu.UserID = ra.UserID
            LEFT JOIN UserStudentProfile usp ON usp.UserID = ra.UserID
            WHERE ra.RowNum = 1
              AND (
                  NULLIF(LTRIM(RTRIM(ISNULL(ra.City, ''))), '') IS NOT NULL
                  OR NULLIF(LTRIM(RTRIM(ISNULL(ra.[State], ''))), '') IS NOT NULL
              )
              AND (
                  usp.UserID IS NULL
                  OR (
                      NULLIF(LTRIM(RTRIM(ISNULL(usp.HometownCity, ''))), '') IS NULL
                      AND NULLIF(LTRIM(RTRIM(ISNULL(usp.HometownState, ''))), '') IS NULL
                  )
              )
            ORDER BY ra.UserID
            ",
            {},
            { datasource=variables.datasource, timeout=120, fetchSize=2000 }
        );
        return queryToArray(qry);
    }

    public array function getAwards( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAwards WHERE UserID = :id ORDER BY AwardID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function replaceAwards( required numeric userID, required array awards ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserAwards WHERE UserID = :id",
            idParam,
            { datasource=variables.datasource, timeout=30 }
        );
        for ( var award in arguments.awards ) {
            executeQueryWithRetry(
                "INSERT INTO UserAwards (UserID, AwardName, AwardType) VALUES (:id, :AwardName, :AwardType)",
                {
                    id        = { value=userID,         cfsqltype="cf_sql_integer"  },
                    AwardName = { value=award.name,     cfsqltype="cf_sql_nvarchar" },
                    AwardType = { value=award.type,     cfsqltype="cf_sql_nvarchar" }
                },
                { datasource=variables.datasource, timeout=30 }
            );
        }
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserAwards          WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
        executeQueryWithRetry( "DELETE FROM UserStudentProfile  WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }

}
