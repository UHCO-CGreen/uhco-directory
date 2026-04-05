component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAllOrgs() {
        var qry = executeQueryWithRetry(
            "SELECT * FROM Organizations ORDER BY OrgName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public array function getOrgAssignments( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "
            SELECT O.*, UO.RoleTitle, UO.RoleOrder
            FROM UserOrganizations UO
            INNER JOIN Organizations O ON UO.OrgID = O.OrgID
            WHERE UO.UserID = :id
            ORDER BY O.OrgName
            ",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function assignOrg( required numeric userID, required numeric orgID, string roleTitle="", numeric roleOrder=0 ) {
        executeQueryWithRetry(
            "
            INSERT INTO UserOrganizations (UserID, OrgID, RoleTitle, RoleOrder)
            VALUES (:uid, :oid, :role, :ord)
            ",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                oid={ value=orgID, cfsqltype="cf_sql_integer" },
                role={ value=arguments.roleTitle, cfsqltype="cf_sql_varchar" },
                ord={ value=arguments.roleOrder, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function updateOrgAssignment( required numeric userID, required numeric orgID, string roleTitle="", numeric roleOrder=0 ) {
        executeQueryWithRetry(
            "
            UPDATE UserOrganizations SET RoleTitle = :role, RoleOrder = :ord
            WHERE UserID = :uid AND OrgID = :oid
            ",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                oid={ value=orgID, cfsqltype="cf_sql_integer" },
                role={ value=arguments.roleTitle, cfsqltype="cf_sql_varchar" },
                ord={ value=arguments.roleOrder, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function removeOrg( required numeric userID, required numeric orgID ) {
        executeQueryWithRetry(
            "DELETE FROM UserOrganizations WHERE UserID = :uid AND OrgID = :oid",
            {
                uid={ value=userID, cfsqltype="cf_sql_integer" },
                oid={ value=orgID, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public struct function getOrgByID( required numeric orgID ) {
        var rows = queryToArray( executeQueryWithRetry(
            "SELECT * FROM Organizations WHERE OrgID = :id",
            { id={ value=orgID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        ) );
        return arrayLen( rows ) ? rows[1] : {};
    }

    public numeric function createOrg( required string orgName, string orgType="", any parentOrgID="", numeric additionalRoles=0 ) {
        var q = executeQueryWithRetry(
            "
            INSERT INTO Organizations (OrgName, OrgType, ParentOrgID, AdditionalRoles)
            VALUES (:orgName, :orgType, :parentOrgID, :additionalRoles);
            SELECT SCOPE_IDENTITY() AS newID;
            ",
            {
                orgName={ value=trim(orgName), cfsqltype="cf_sql_varchar" },
                orgType={ value=trim(orgType), cfsqltype="cf_sql_varchar" },
                parentOrgID={ value=isNumeric(arguments.parentOrgID) ? val(arguments.parentOrgID) : 0, "null"=NOT isNumeric(arguments.parentOrgID), cfsqltype="cf_sql_integer" },
                additionalRoles={ value=arguments.additionalRoles ? 1 : 0, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
        return q.newID;
    }

    public void function updateOrg( required numeric orgID, required string orgName, string orgType="", any parentOrgID="", numeric additionalRoles=0 ) {
        executeQueryWithRetry(
            "UPDATE Organizations SET OrgName = :orgName, OrgType = :orgType, ParentOrgID = :parentOrgID, AdditionalRoles = :additionalRoles WHERE OrgID = :id",
            {
                id={ value=orgID, cfsqltype="cf_sql_integer" },
                orgName={ value=trim(orgName), cfsqltype="cf_sql_varchar" },
                orgType={ value=trim(orgType), cfsqltype="cf_sql_varchar" },
                parentOrgID={ value=isNumeric(arguments.parentOrgID) ? val(arguments.parentOrgID) : 0, "null"=NOT isNumeric(arguments.parentOrgID), cfsqltype="cf_sql_integer" },
                additionalRoles={ value=arguments.additionalRoles ? 1 : 0, cfsqltype="cf_sql_integer" }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function removeAllUserAssignmentsForOrg( required numeric orgID ) {
        executeQueryWithRetry(
            "DELETE FROM UserOrganizations WHERE OrgID = :oid",
            { oid={ value=orgID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function clearChildOrgParents( required numeric orgID ) {
        executeQueryWithRetry(
            "UPDATE Organizations SET ParentOrgID = NULL WHERE ParentOrgID = :oid",
            { oid={ value=orgID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteOrg( required numeric orgID ) {
        executeQueryWithRetry(
            "DELETE FROM Organizations WHERE OrgID = :id",
            { id={ value=orgID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public array function getAllUserOrgAssignments() {
        var qry = executeQueryWithRetry(
            "SELECT UO.UserID, O.OrgID, O.OrgName, O.OrgType, O.ParentOrgID, UO.RoleTitle
             FROM UserOrganizations UO
             INNER JOIN Organizations O ON UO.OrgID = O.OrgID
             ORDER BY O.OrgName",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=2000 }
        );
        return queryToArray(qry);
    }

}