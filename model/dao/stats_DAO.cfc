component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public numeric function getTotalUsers() {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS cnt FROM Users",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.cnt);
    }

    public numeric function getTotalUsersByFlags(required array flagNames) {
        if (!arrayLen(arguments.flagNames)) {
            return 0;
        }
        var inClause = "";
        var params = {};
        for (var i = 1; i <= arrayLen(arguments.flagNames); i++) {
            if (i GT 1) inClause &= ",";
            inClause &= ":f#i#";
            params["f#i#"] = { value=trim(arguments.flagNames[i]), cfsqltype="cf_sql_nvarchar" };
        }
        var qry = executeQueryWithRetry(
            "SELECT COUNT(DISTINCT ufa.UserID) AS cnt
             FROM   UserFlagAssignments ufa
             JOIN   UserFlags uf ON uf.FlagID = ufa.FlagID
             WHERE  uf.FlagName IN (#inClause#)",
            params,
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.cnt);
    }

    public numeric function getTotalPublishedImages() {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS cnt FROM UserImages",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.cnt);
    }

    public numeric function getTotalPublications() {
        var qry = executeQueryWithRetry(
            "SELECT COUNT(*) AS cnt FROM Publications",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.cnt);
    }

    public numeric function getTotalUsersByOrgs(required array orgNames) {
        if (!arrayLen(arguments.orgNames)) {
            return 0;
        }
        var inClause = "";
        var params = {};
        for (var i = 1; i <= arrayLen(arguments.orgNames); i++) {
            if (i GT 1) inClause &= ",";
            inClause &= ":o#i#";
            params["o#i#"] = { value=trim(arguments.orgNames[i]), cfsqltype="cf_sql_nvarchar" };
        }
        var qry = executeQueryWithRetry(
            "SELECT COUNT(DISTINCT uo.UserID) AS cnt
             FROM   UserOrganizations uo
             JOIN   Organizations o ON o.OrgID = uo.OrgID
             WHERE  o.OrgName IN (#inClause#)",
            params,
            { datasource=variables.datasource, timeout=30 }
        );
        return val(qry.cnt);
    }

}
