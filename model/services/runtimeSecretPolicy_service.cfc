component output="false" singleton {

    public any function init() {
        variables.appConfigService = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    public string function getEnvironmentSecret(required string envKey, string defaultValue = "") {
        if (
            structKeyExists(server, "system")
            AND structKeyExists(server.system, "environment")
            AND structKeyExists(server.system.environment, arguments.envKey)
        ) {
            return trim(server.system.environment[arguments.envKey]);
        }

        return trim(arguments.defaultValue ?: "");
    }

    public string function getAppConfigSecret(required string configKey, string defaultValue = "") {
        return trim(variables.appConfigService.getValue(arguments.configKey, arguments.defaultValue));
    }

    public struct function getUHApiCredentials() {
        var credentials = {
            token = getEnvironmentSecret("UH_API_TOKEN"),
            secret = getEnvironmentSecret("UH_API_SECRET")
        };

        credentials.success = len(credentials.token) GT 0 AND len(credentials.secret) GT 0;
        return credentials;
    }

    public string function getLdapBindUsername() {
        return getAppConfigSecret("ldap.cougarnet.bind_username");
    }

    public string function getLdapBindPassword() {
        return getAppConfigSecret("ldap.cougarnet.bind_password");
    }

    public boolean function requiresAppConfigEncryption(string environmentName = "local") {
        var normalizedEnvironment = lCase(trim(arguments.environmentName ?: "local"));
        return !listFindNoCase("local,dev,development", normalizedEnvironment);
    }

    public boolean function isAppConfigEncryptionReady(string environmentName = "local") {
        if (!requiresAppConfigEncryption(arguments.environmentName)) {
            return true;
        }

        return len(getEnvironmentSecret("UHCO_IDENT_APPCONFIG_ENC_KEY")) GT 0;
    }

    public struct function getHealthStatus(string environmentName = "local") {
        var health = {
            environmentName = lCase(trim(arguments.environmentName ?: "local")),
            requiresAppConfigEncryption = requiresAppConfigEncryption(arguments.environmentName),
            appConfigEncryptionReady = isAppConfigEncryptionReady(arguments.environmentName),
            missing = []
        };

        if (health.requiresAppConfigEncryption AND !health.appConfigEncryptionReady) {
            arrayAppend(health.missing, "UHCO_IDENT_APPCONFIG_ENC_KEY");
        }

        health.ready = (arrayLen(health.missing) EQ 0);
        return health;
    }
}
