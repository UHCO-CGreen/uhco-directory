# SQL Migrations

This folder is for ordered, source-controlled schema migrations.

## Naming

Use sortable file names so schema changes apply in a deterministic order.

Recommended formats:

- `20260420_001_add_schema_versions_table.sql`
- `20260420_002_add_new_index.sql`

## Rules

- Never edit a migration after it has been applied to another environment.
- Create a new migration for follow-up changes instead of rewriting history.
- Prefer idempotent patterns where practical, such as `IF OBJECT_ID(...) IS NULL` or conditional `ALTER` guards.
- Keep one logical change per file when possible.
- Avoid mixing schema and one-off cleanup data unless the schema change requires it.

## Runner

Use the VS Code tasks or the PowerShell script at [.vscode/scripts/invoke-db-migrations.ps1](../../.vscode/scripts/invoke-db-migrations.ps1).

The runner:

- creates `dbo.SchemaVersions` if it does not exist
- lists pending `.sql` files in this folder by file name order
- records each successfully applied migration with its checksum
- refuses to continue if an already-applied file has been modified

## First Slice

This implementation is intentionally schema-focused. It does not attempt automated bi-directional data sync.

## Baseline Migration

The first migration in this folder is a baseline marker:

- [20260420_001_baseline_existing_schema.sql](20260420_001_baseline_existing_schema.sql)

Apply this once to each existing environment so future schema work can build on a known migration history without trying to recreate the current live schema.