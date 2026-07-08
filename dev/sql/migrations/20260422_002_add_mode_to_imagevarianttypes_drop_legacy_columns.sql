/*
  Migration: add MODE to ImageVariantTypes, backfill from legacy flags,
  then remove legacy columns.
*/
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH('dbo.ImageVariantTypes', 'Mode') IS NULL
    BEGIN
        ALTER TABLE dbo.ImageVariantTypes
        ADD Mode NVARCHAR(20) NULL;
    END;

    IF COL_LENGTH('dbo.ImageVariantTypes', 'Mode') IS NOT NULL
    BEGIN
        DECLARE @hasAllowResize bit = CASE WHEN COL_LENGTH('dbo.ImageVariantTypes', 'AllowResize') IS NOT NULL THEN 1 ELSE 0 END;
        DECLARE @hasAllowManualCrop bit = CASE WHEN COL_LENGTH('dbo.ImageVariantTypes', 'AllowManualCrop') IS NOT NULL THEN 1 ELSE 0 END;

        -- Build dynamic SQL conditionally so column names only appear when the columns exist.
        -- SQL Server validates all column references at parse time, even inside unreachable CASE branches.
        DECLARE @backfillSql NVARCHAR(MAX);
        SET @backfillSql = N'
            UPDATE dbo.ImageVariantTypes
            SET Mode = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(Mode, '''')))) IN (''CROP_RESIZE'', ''RESIZE_ONLY'', ''PASSTHROUGH'')
                    THEN LOWER(LTRIM(RTRIM(Mode)))';

        IF @hasAllowResize = 1
            SET @backfillSql = @backfillSql + N'
                WHEN ISNULL(AllowResize, 1) = 0 THEN ''passthrough''';

        IF @hasAllowManualCrop = 1
            SET @backfillSql = @backfillSql + N'
                WHEN ISNULL(AllowManualCrop, 0) = 1 THEN ''crop_resize''';

        SET @backfillSql = @backfillSql + N'
                ELSE ''resize_only''
            END
            WHERE Mode IS NULL
               OR UPPER(LTRIM(RTRIM(ISNULL(Mode, '''')))) NOT IN (''CROP_RESIZE'', ''RESIZE_ONLY'', ''PASSTHROUGH'');';

        EXEC sp_executesql @backfillSql;
    END;

    IF COL_LENGTH('dbo.ImageVariantTypes', 'Mode') IS NOT NULL
    BEGIN
        EXEC sp_executesql N'ALTER TABLE dbo.ImageVariantTypes ALTER COLUMN Mode NVARCHAR(20) NOT NULL;';

        IF NOT EXISTS (
            SELECT 1
            FROM sys.default_constraints dc
            JOIN sys.columns c
              ON c.object_id = dc.parent_object_id
             AND c.column_id = dc.parent_column_id
            WHERE dc.parent_object_id = OBJECT_ID('dbo.ImageVariantTypes')
              AND c.name = 'Mode'
        )
        BEGIN
            EXEC sp_executesql N'ALTER TABLE dbo.ImageVariantTypes ADD CONSTRAINT DF_ImageVariantTypes_Mode DEFAULT (''resize_only'') FOR Mode;';
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID('dbo.ImageVariantTypes')
              AND name = 'CK_ImageVariantTypes_Mode_Values'
        )
        BEGIN
            EXEC sp_executesql N'
                ALTER TABLE dbo.ImageVariantTypes
                ADD CONSTRAINT CK_ImageVariantTypes_Mode_Values
                    CHECK (Mode IN (''crop_resize'', ''resize_only'', ''passthrough''));
            ';
        END;
    END;

    IF COL_LENGTH('dbo.ImageVariantTypes', 'AllowManualCrop') IS NOT NULL
    BEGIN
                DECLARE @dfAllowManualCrop sysname;
                SELECT @dfAllowManualCrop = dc.name
                FROM sys.default_constraints dc
                JOIN sys.columns c
                    ON c.object_id = dc.parent_object_id
                 AND c.column_id = dc.parent_column_id
                WHERE dc.parent_object_id = OBJECT_ID('dbo.ImageVariantTypes')
                    AND c.name = 'AllowManualCrop';

                IF @dfAllowManualCrop IS NOT NULL
                BEGIN
                    DECLARE @sqlDropAllowManualCrop nvarchar(max);
                    SET @sqlDropAllowManualCrop = N'ALTER TABLE dbo.ImageVariantTypes DROP CONSTRAINT ' + QUOTENAME(@dfAllowManualCrop) + N';';
                    EXEC sp_executesql @sqlDropAllowManualCrop;
                END;

        ALTER TABLE dbo.ImageVariantTypes DROP COLUMN AllowManualCrop;
    END;

    IF COL_LENGTH('dbo.ImageVariantTypes', 'AllowResize') IS NOT NULL
    BEGIN
                DECLARE @dfAllowResize sysname;
                SELECT @dfAllowResize = dc.name
                FROM sys.default_constraints dc
                JOIN sys.columns c
                    ON c.object_id = dc.parent_object_id
                 AND c.column_id = dc.parent_column_id
                WHERE dc.parent_object_id = OBJECT_ID('dbo.ImageVariantTypes')
                    AND c.name = 'AllowResize';

                IF @dfAllowResize IS NOT NULL
                BEGIN
                    DECLARE @sqlDropAllowResize nvarchar(max);
                    SET @sqlDropAllowResize = N'ALTER TABLE dbo.ImageVariantTypes DROP CONSTRAINT ' + QUOTENAME(@dfAllowResize) + N';';
                    EXEC sp_executesql @sqlDropAllowResize;
                END;

        ALTER TABLE dbo.ImageVariantTypes DROP COLUMN AllowResize;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
