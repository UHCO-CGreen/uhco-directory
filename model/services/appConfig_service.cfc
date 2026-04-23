component output="false" singleton {

    public any function init() {
        variables.AppConfigDAO = createObject("component", "dao.AppConfigDAO").init();
        variables.encryptedPrefix = "enc::";
        return this;
    }

    public string function getValue(
        required string configKey,
        string defaultValue = ""
    ) {
        var value = variables.AppConfigDAO.getConfigValue( arguments.configKey );

        if ( !len(value) ) {
            return arguments.defaultValue;
        }

        if ( isSensitiveKey(arguments.configKey) ) {
            return decryptValue(arguments.configKey, value);
        }

        return value;
    }

    public void function setValue(
        required string configKey,
        required string configValue
    ) {
        var valueToStore = trim(arguments.configValue);

        if ( isSensitiveKey(arguments.configKey) AND len(valueToStore) ) {
            valueToStore = encryptValue(arguments.configKey, valueToStore);
        }

        variables.AppConfigDAO.setConfigValue( arguments.configKey, valueToStore );
    }

    public array function getAll() {
        var rows = variables.AppConfigDAO.getAllConfig();
        var row = {};

        for ( row in rows ) {
            row.IS_SENSITIVE = isSensitiveKey(row.CONFIGKEY ?: "");
            if ( row.IS_SENSITIVE ) {
                row.CONFIGVALUE_DISPLAY = len(trim(row.CONFIGVALUE ?: "")) ? "********" : "";
            } else {
                row.CONFIGVALUE_DISPLAY = row.CONFIGVALUE ?: "";
            }
        }

        return rows;
    }

    public boolean function isSensitiveKey( required string configKey ) {
        var normalizedKey = lCase(trim(arguments.configKey));

        if ( !len(normalizedKey) ) {
            return false;
        }

        if ( listFindNoCase("dropbox.app_secret,dropbox.refresh_token,ldap.cougarnet.bind_password", normalizedKey) ) {
            return true;
        }

        return reFindNoCase("(^|\.)(password|secret|token)$", normalizedKey) GT 0;
    }

    private string function encryptValue(
        required string configKey,
        required string plainValue
    ) {
        var encryptionKey = getEncryptionKey();

        if ( !len(encryptionKey) ) {
            // Backward-compatible fallback: when no encryption key is configured,
            // preserve legacy plaintext behavior so production does not break.
            return arguments.plainValue;
        }

        return variables.encryptedPrefix & encrypt(arguments.plainValue, encryptionKey, "AES", "Base64");
    }

    private string function decryptValue(
        required string configKey,
        required string storedValue
    ) {
        var trimmedValue = trim(arguments.storedValue);
        var encryptionKey = "";

        if ( !len(trimmedValue) ) {
            return "";
        }

        if ( left(trimmedValue, len(variables.encryptedPrefix)) NEQ variables.encryptedPrefix ) {
            // Backward compatibility for legacy plaintext values already in AppConfig.
            return trimmedValue;
        }

        encryptionKey = getEncryptionKey();
        if ( !len(encryptionKey) ) {
            // If encrypted values exist but no key is available, fail closed for this value
            // instead of throwing from all callers that read AppConfig.
            return "";
        }

        return decrypt(
            right(trimmedValue, len(trimmedValue) - len(variables.encryptedPrefix)),
            encryptionKey,
            "AES",
            "Base64"
        );
    }

    private string function getEncryptionKey() {
        if (
            structKeyExists(server, "system")
            AND structKeyExists(server.system, "environment")
            AND structKeyExists(server.system.environment, "UHCO_IDENT_APPCONFIG_ENC_KEY")
        ) {
            return trim(server.system.environment["UHCO_IDENT_APPCONFIG_ENC_KEY"]);
        }

        return "";
    }

}