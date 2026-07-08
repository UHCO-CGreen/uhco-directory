component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();        return this;
    }

    public array function getAccessAreas() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM AccessAreas ORDER BY AccessName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public struct function getAccessAreaByID(required numeric areaID) {
        var qry = executeQueryWithRetry(
            "SELECT TOP 1 AccessAreaID, AccessName FROM AccessAreas WHERE AccessAreaID = :areaID",
            {
                areaID = { value=arguments.areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        if (!qry.recordCount) {
            return {};
        }

        return queryToArray(qry)[1];
    }

    public numeric function countAssignmentsForArea(required numeric areaID) {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS AssignmentCount FROM UserAccessAssignments WHERE AccessAreaID = :areaID",
            {
                areaID = { value=arguments.areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return qry.recordCount ? val(qry.AssignmentCount[1]) : 0;
    }

    public numeric function createAccessArea(required string accessName) {
        var qry = executeQueryWithRetry(
            "INSERT INTO AccessAreas (AccessName) OUTPUT INSERTED.AccessAreaID VALUES (:accessName)",
            {
                accessName = { value=trim(arguments.accessName), cfsqltype="cf_sql_varchar" }
            },
            { datasource=variables.datasource, timeout=30 }
        );

        return qry.recordCount ? val(qry.AccessAreaID[1]) : 0;
    }

    public void function updateAccessArea(required numeric areaID, required string accessName) {
        executeQueryWithRetry(
            "UPDATE AccessAreas SET AccessName = :accessName WHERE AccessAreaID = :areaID",
            {
                accessName = { value=trim(arguments.accessName), cfsqltype="cf_sql_varchar" },
                areaID = { value=arguments.areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteAccessArea(required numeric areaID) {
        executeQueryWithRetry(
            "DELETE FROM AccessAreas WHERE AccessAreaID = :areaID",
            {
                areaID = { value=arguments.areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAccessForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT AA.AccessName
            FROM UserAccessAssignments UA
            INNER JOIN AccessAreas AA ON UA.AccessAreaID = AA.AccessAreaID
            WHERE UA.UserID = :id
              AND UA.IsActive = 1
              AND (UA.ExpiresAt IS NULL OR UA.ExpiresAt > GETDATE())
            ORDER BY AA.AccessName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getPermissionsForUser( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT AA.AccessName
            FROM UserAccessAssignments UA
            INNER JOIN AccessAreas AA ON UA.AccessAreaID = AA.AccessAreaID
            WHERE UA.UserID = :id
              AND UA.IsActive = 1
              AND (UA.ExpiresAt IS NULL OR UA.ExpiresAt > GETDATE())
            ORDER BY AA.AccessName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function grantAccess(
        required numeric userID,
        required numeric areaID,
        numeric grantedBy = 0
    ) {
        executeQueryWithRetry(
            "
            INSERT INTO UserAccessAssignments (UserID, AccessAreaID, GrantedAt, GrantedBy)
            VALUES (:uid, :aid, GETDATE(), :grantedBy)
            ",
            {
                uid      ={ value=userID,                               cfsqltype="cf_sql_integer" },
                aid      ={ value=areaID,                               cfsqltype="cf_sql_integer" },
                grantedBy={ value=(grantedBy GT 0 ? grantedBy : javaCast("null","")), null=(grantedBy EQ 0), cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function revokeAccess( required numeric userID, required numeric areaID ) {
        executeQueryWithRetry(
            "DELETE FROM UserAccessAssignments WHERE UserID = :uid AND AccessAreaID = :aid",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                aid={ value=areaID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getUsersForPermission( required string permission ) {
        var qry = executeQueryWithRetry(
            "
            SELECT u.UserID,
                   LTRIM(RTRIM(
                       COALESCE(NULLIF(LTRIM(RTRIM(pa.FirstName)), ''), NULLIF(LTRIM(RTRIM(u.PreferredName)), ''), LTRIM(RTRIM(u.FirstName)))
                       + ' ' + LTRIM(RTRIM(COALESCE(NULLIF(LTRIM(RTRIM(pa.LastName)), ''), LTRIM(RTRIM(u.LastName)))))
                   )) AS PrimaryName,
                   ISNULL(u.EmailPrimary, '') AS PrimaryEmail,
                   ISNULL(cnet.ExternalValue, '') AS CougarnetID
            FROM Users u
            INNER JOIN UserAccessAssignments uaa ON uaa.UserID = u.UserID
            INNER JOIN AccessAreas aa ON aa.AccessAreaID = uaa.AccessAreaID
            OUTER APPLY (
                SELECT TOP 1 ua.FirstName, ua.LastName
                FROM UserAliases ua
                WHERE ua.UserID = u.UserID
                  AND ua.IsActive = 1
                  AND ISNULL(ua.IsPrimary, 0) = 1
                ORDER BY ISNULL(ua.SortOrder, 999999), ua.AliasID
            ) pa
            OUTER APPLY (
                SELECT TOP 1 ue.ExternalValue
                FROM UserExternalIDs ue
                INNER JOIN ExternalSystems es ON es.SystemID = ue.SystemID
                WHERE ue.UserID = u.UserID
                  AND LOWER(TRIM(es.SystemName)) = 'cougarnet'
                ORDER BY ue.ExternalValue
            ) cnet
            WHERE aa.AccessName = :permission
              AND u.Active = 1
              AND uaa.IsActive = 1
              AND (uaa.ExpiresAt IS NULL OR uaa.ExpiresAt > GETDATE())
            ORDER BY u.LastName, u.FirstName
            ",
            { permission={ value=arguments.permission, cfsqltype="cf_sql_varchar" } },
            { datasource=variables.datasource, timeout=30, fetchSize=500 }
        );
        return queryToArray(qry);
    }

}