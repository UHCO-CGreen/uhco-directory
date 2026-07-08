SET NOCOUNT ON;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.AppConfig
    WHERE ConfigKey = 'scheduled_tasks.uhco_duplicateusersreport.scan_mode'
)
BEGIN
    INSERT INTO dbo.AppConfig (ConfigKey, ConfigValue, UpdatedAt)
    VALUES ('scheduled_tasks.uhco_duplicateusersreport.scan_mode', 'alumni_vs_faculty', GETDATE());
END;
