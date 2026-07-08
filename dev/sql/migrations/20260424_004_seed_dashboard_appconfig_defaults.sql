SET NOCOUNT ON;

-- Seed dashboard settings keys with safe defaults when missing.
IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'dashboard.list_page_size'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('dashboard.list_page_size', '10', GETDATE());
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'dashboard.stale_months'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('dashboard.stale_months', '6', GETDATE());
END;
