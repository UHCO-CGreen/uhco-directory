component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAllTokens() {
        var qry = executeQueryWithRetry(
            "SELECT TokenID, TokenName, AppName, Scopes, AllowedIPs, ExpiresAt, IsActive, CreatedAt, LastUsedAt
             FROM APITokens
             ORDER BY CreatedAt DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    /**
     * Look up a token by its SHA-256 hash.
     * Returns empty array if not found or inactive.
     */
    public array function getTokenByHash( required string tokenHash ) {
        var qry = executeQueryWithRetry(
            "SELECT TokenID, TokenName, AppName, Scopes, AllowedIPs, ExpiresAt, IsActive, LastUsedAt
             FROM APITokens
             WHERE TokenHash = :hash
               AND IsActive = 1",
            { hash={ value=arguments.tokenHash, cfsqltype="cf_sql_char" } },
            { datasource=variables.datasource, timeout=10 }
        );
        return queryToArray(qry);
    }

    public numeric function createToken(
        required string tokenName,
        required string appName,
        required string tokenHash,
        required string scopes,
                 string allowedIPs = "",
                 string expiresAt  = ""
    ) {
        var ipVal     = len(trim(arguments.allowedIPs)) ? arguments.allowedIPs : "";
        var expireVal = len(trim(arguments.expiresAt))  ? arguments.expiresAt  : "";

        var params = {
            name    : { value=arguments.tokenName, cfsqltype="cf_sql_nvarchar" },
            app     : { value=arguments.appName,   cfsqltype="cf_sql_nvarchar" },
            hash    : { value=arguments.tokenHash, cfsqltype="cf_sql_char"     },
            scopes  : { value=arguments.scopes,    cfsqltype="cf_sql_nvarchar" },
            ips     : { value=ipVal,     cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.allowedIPs)) },
            expires : { value=expireVal, cfsqltype="cf_sql_timestamp", null=!len(trim(arguments.expiresAt)) }
        };

        var qry = executeQueryWithRetry(
            "INSERT INTO APITokens (TokenName, AppName, TokenHash, Scopes, AllowedIPs, ExpiresAt)
             OUTPUT INSERTED.TokenID
             VALUES (:name, :app, :hash, :scopes, :ips, :expires)",
            params,
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.TokenID;
    }

    public void function revokeToken( required numeric tokenID ) {
        executeQueryWithRetry(
            "UPDATE APITokens SET IsActive = 0 WHERE TokenID = :id",
            { id={ value=arguments.tokenID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function touchLastUsed( required numeric tokenID ) {
        executeQueryWithRetry(
            "UPDATE APITokens SET LastUsedAt = SYSUTCDATETIME() WHERE TokenID = :id",
            { id={ value=arguments.tokenID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=10 }
        );
    }

    public void function deleteToken( required numeric tokenID ) {
        executeQueryWithRetry(
            "DELETE FROM APITokens WHERE TokenID = :id",
            { id={ value=arguments.tokenID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }
}
