component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public string function getConfigValue( required string configKey ) {
        var qry = executeQueryWithRetry(
            "SELECT ConfigValue FROM AppConfig WHERE ConfigKey = :key",
            { key = { value=arguments.configKey, cfsqltype="cf_sql_nvarchar" } },
            { datasource=variables.datasource, timeout=30, fetchSize=1 }
        );

        return (qry.recordCount GT 0) ? trim(qry.ConfigValue) : "";
    }

    public void function setConfigValue(
        required string configKey,
        required string configValue,
        string description = "",
        string category    = ""
    ) {
        var hasDesc = len(trim(arguments.description)) GT 0;
        var hasCat  = len(trim(arguments.category)) GT 0;

        var sql = "
            IF EXISTS (SELECT 1 FROM AppConfig WHERE ConfigKey = :key)
                UPDATE AppConfig
                SET    ConfigValue = :val,
                       UpdatedAt   = GETDATE()
                       #( hasDesc ? ', Description = :desc' : '' )#
                       #( hasCat  ? ', Category = :cat'    : '' )#
                WHERE  ConfigKey = :key
            ELSE
                INSERT INTO AppConfig (ConfigKey, ConfigValue, UpdatedAt, Description, Category)
                VALUES (:key, :val, GETDATE(), :desc, :cat)
        ";

        executeQueryWithRetry(
            sql,
            {
                key  = { value=arguments.configKey,              cfsqltype="cf_sql_nvarchar" },
                val  = { value=arguments.configValue,            cfsqltype="cf_sql_nvarchar" },
                desc = { value=trim(arguments.description),      cfsqltype="cf_sql_nvarchar", null=!hasDesc },
                cat  = { value=trim(arguments.category),         cfsqltype="cf_sql_nvarchar", null=!hasCat }
            },
            { datasource=variables.datasource, timeout=30 }
        );
    }

    public void function addConfigKey(
        required string configKey,
        required string configValue,
        string category    = "",
        string description = ""
    ) {
        setConfigValue(
            configKey   = arguments.configKey,
            configValue = arguments.configValue,
            description = arguments.description,
            category    = arguments.category
        );
    }

    public array function getAllConfig() {
        var qry = executeQueryWithRetry(
            "SELECT ConfigKey, ConfigValue, UpdatedAt, Description, Category FROM AppConfig ORDER BY ConfigKey",
            {},
            { datasource=variables.datasource, timeout=30, fetchSize=200 }
        );

        return queryToArray(qry);
    }

}