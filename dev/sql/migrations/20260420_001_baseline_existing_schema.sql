/*
    20260420_001_baseline_existing_schema.sql

    Purpose:
    Establish a source-controlled baseline entry for databases that already
    contain the UHCO Identity schema prior to adoption of the migration runner.

    Notes:
    - This migration is intentionally non-destructive.
    - Apply it once per environment to mark the starting point for future
      ordered migrations.
    - Subsequent schema changes should be added as new files rather than
      modifying this one.
*/

SET NOCOUNT ON;

PRINT 'Baseline migration applied for existing UHCO Identity schema.';