SET NOCOUNT ON;

-- Seed the dedicated synthetic-user marker flag when missing.
IF NOT EXISTS (
    SELECT 1
    FROM dbo.UserFlags
    WHERE FlagName = 'TEST_USER'
)
BEGIN
    INSERT INTO dbo.UserFlags (FlagName)
    VALUES ('TEST_USER');
END;

-- Seed Test Mode defaults without overwriting existing environment-specific values.
IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'test_mode.enabled'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('test_mode.enabled', '0', GETDATE());
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'test_mode.generation_count'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('test_mode.generation_count', '10', GETDATE());
END;