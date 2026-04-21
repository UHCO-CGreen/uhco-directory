# UHCO Identity

UHCO Identity is the University of Houston College of Optometry's internal directory platform. It provides:

- an admin application for managing people, organizations, flags, images, external IDs, and profile data
- a self-service UserReview workflow for staged profile updates
- a read-only REST API under `/api/v1/` for downstream systems and integrations
- tooling for UH directory syncs, quickpull endpoints, imports, reporting, and data-quality operations

## Stack

- Adobe ColdFusion / CFML
- Microsoft SQL Server
- IIS with URL Rewrite
- Bootstrap-based admin UI
- LDAP / Active Directory-backed admin authentication

## Runtime Overview

The application uses request-context datasource switching in [Application.cfc](Application.cfc):

- admin requests use `UHCO_Identity_Admin`
- API requests use `UHCO_Identity_API`
- UserReview requests use the admin datasource

Environment values used by the app:

- `UH_API_TOKEN`
- `UH_API_SECRET`

Application mappings defined at startup:

- `/cfc` -> `model/services`
- `/dao` -> `model/dao`
- `/includes` -> `model/includes`

## Main Areas

- `/admin/` - admin back office for user, org, flag, media, settings, reporting, and import management
- `/UserReview/` - self-service review and staged profile change workflow
- `/api/v1/` - JSON API and quickpull endpoints
- `/Docs/` - internal HTML documentation site
- `/sql/` - schema, migrations, and utility scripts
- `/model/services/` - service layer business logic
- `/model/dao/` - DAO layer and SQL access

## Key Features

### User Management

- Core user records in `Users`
- Repeatable contact data: emails, phones, addresses, aliases, degrees, awards
- Academic data in `UserAcademicInfo`
- Student/alumni profile data in `UserStudentProfile`
- External system ID mapping through `UserExternalIDs`

### Admin Workflows

- user editing with tabbed AJAX saves
- role, permission, and admin access management
- UH API comparison and sync reporting
- data-quality review and exclusions
- quickpull configuration for API output shaping
- bulk import generation, upload, validation, and execution

### API

- people, organizations, flags, academic, contact, student profile, awards, and bio endpoints
- token-based authentication
- secret-based unlocking of protected data such as Current Student and Alumni records
- configurable quickpull endpoints for curated external feeds

## Documentation

This repository already includes richer HTML documentation:

- app documentation: [Docs/index.html](Docs/index.html)
- API documentation: [api/docs.html](api/docs.html)
- styling guide: [STYLING.md](STYLING.md)

## Local / Server Setup

This project now includes a local `npm` + Sass asset build for compiled CSS and localized Bootstrap Icons. A working environment generally requires:

1. Adobe ColdFusion installed and configured for this site.
2. IIS configured to serve the application root.
3. URL rewrite support for `/api/` routes.
4. SQL Server datasources created in ColdFusion Administrator:
   - `UHCO_Identity_Admin`
   - `UHCO_Identity_API`
5. Environment variables configured for UH API integration when sync features are needed:
   - `UH_API_TOKEN`
   - `UH_API_SECRET`
6. Network access to LDAP / Active Directory if admin authentication is required.

For local styling work:

7. Node.js installed for the front-end asset build.
8. Run `npm install` once at the repository root.
9. Run `npm run build` to copy vendor assets and compile CSS bundles.
10. Use `npm run watch:styles` during active Sass development.

If application state needs to be rebuilt after config changes, the app supports `?reinit=true` in requests via [Application.cfc](Application.cfc).

## Database Notes

Important tables include:

- `Users`
- `UserFlags`, `UserFlagAssignments`
- `Organizations`, `UserOrganizations`
- `UserAcademicInfo`
- `UserStudentProfile`
- `UserAwards`
- `UserEmails`
- `UserPhones`
- `UserAddresses`
- `UserDegrees`
- `UserExternalIDs`
- `UserImages`

Schema and migration scripts live under [sql](sql).

Versioned schema migrations are now intended to live under [sql/migrations](sql/migrations), with workflow notes in [DB_MIGRATIONS.md](DB_MIGRATIONS.md).

## Project Structure

```text
admin/              Admin UI and operational tools
api/                REST API endpoints and handlers
Docs/               Internal application documentation
model/services/     Service-layer CF components
model/dao/          Data access components
model/includes/     Shared includes and helpers
UserReview/         End-user review workflow
```

## Notes For Developers

- DAO classes extend `dao.BaseDAO` and inherit retry-aware query execution.
- Query results are normalized to uppercase column keys in the DAO layer.
- Much of the admin UI uses AJAX saves into targeted endpoints rather than full-form posts.
- Quickpull configuration is stored in app config as JSON using the key pattern `api.quickpull.{endpoint}.config`.
- Generated CSV endpoints should explicitly disable debug output.

## Recent Work Areas

Recent changes in this codebase include:

- configurable API quickpull output and quickpull admin UI
- bulk section import generation and processing
- UserReview workflow and permissions
- UH sync reporting and field-diff tools
- student profile hometown synchronization from Hometown addresses