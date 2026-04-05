component extends="dir.dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        variables.datasource = "UHCO_Directory";
        return this;
    }

    public array function getAllSecrets() {
        var qry = executeQueryWithRetry(
            "SELECT SecretID, SecretName, AppName, ProtectedFlags, AllowedIPs, ExpiresAt, IsActive, CreatedAt, LastUsedAt
             FROM APISecrets
             ORDER BY CreatedAt DESC",
            {},
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    public array function getSecretByHash( required string secretHash ) {
        var qry = executeQueryWithRetry(
            "SELECT SecretID, SecretName, AppName, ProtectedFlags, AllowedIPs, ExpiresAt, IsActive, LastUsedAt
             FROM APISecrets
             WHERE SecretHash = :hash
               AND IsActive = 1",
            { hash={ value=arguments.secretHash, cfsqltype="cf_sql_char" } },
            { datasource=variables.datasource, timeout=30 }
        );
        return queryToArray(qry);
    }

    public numeric function createSecret(
        required string secretName,
        required string appName,
        required string secretHash,
        required string protectedFlags,
                 string allowedIPs = "",
                 string expiresAt  = ""
    ) {
        var ipVal     = len(trim(arguments.allowedIPs)) ? arguments.allowedIPs : "";
        var expireVal = len(trim(arguments.expiresAt))  ? arguments.expiresAt  : "";

        var params = {
            name    : { value=arguments.secretName,     cfsqltype="cf_sql_nvarchar" },
            app     : { value=arguments.appName,        cfsqltype="cf_sql_nvarchar" },
            hash    : { value=arguments.secretHash,     cfsqltype="cf_sql_char"     },
            flags   : { value=arguments.protectedFlags, cfsqltype="cf_sql_nvarchar" },
            ips     : { value=ipVal,     cfsqltype="cf_sql_nvarchar", null=!len(trim(arguments.allowedIPs)) },
            expires : { value=expireVal, cfsqltype="cf_sql_timestamp", null=!len(trim(arguments.expiresAt)) }
        };

        var qry = executeQueryWithRetry(
            "INSERT INTO APISecrets (SecretName, AppName, SecretHash, ProtectedFlags, AllowedIPs, ExpiresAt)
             OUTPUT INSERTED.SecretID
             VALUES (:name, :app, :hash, :flags, :ips, :expires)",
            params,
            { datasource=variables.datasource, timeout=30 }
        );
        return qry.SecretID;
    }

    public void function revokeSecret( required numeric secretID ) {
        executeQueryWithRetry(
            "UPDATE APISecrets SET IsActive = 0 WHERE SecretID = :id",
            { id={ value=arguments.secretID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function deleteSecret( required numeric secretID ) {
        executeQueryWithRetry(
            "DELETE FROM APISecrets WHERE SecretID = :id",
            { id={ value=arguments.secretID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function touchLastUsed( required numeric secretID ) {
        executeQueryWithRetry(
            "UPDATE APISecrets SET LastUsedAt = SYSUTCDATETIME() WHERE SecretID = :id",
            { id={ value=arguments.secretID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30 }
        );
    }

}
