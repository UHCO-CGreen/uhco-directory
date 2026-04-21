# UHCO Identity Styling Guide

This document defines the styling architecture for UHCO Identity after the move away from ad hoc inline styling and stock CDN Bootstrap CSS.

## Goals

- Keep styling local to this repository.
- Compile branded Bootstrap CSS from Sass instead of relying on stock CDN CSS.
- Reuse the branding approach from `dev/uhco-web-resources-main` only where it fits UHCO Identity.
- Prefer shared utilities and partials over page-level inline styles.
- Keep JavaScript concerns separate from styling concerns.

## Current Asset Build

The repository now includes a local `npm` + Sass workflow in [package.json](package.json).

Primary commands:

- `npm run build` copies local vendor assets and compiles all CSS bundles.
- `npm run build:icons` copies Bootstrap Icons from `node_modules` into the app.
- `npm run build:styles` compiles Sass entry points into application-served CSS files.
- `npm run watch:styles` watches Sass files and recompiles on change.

Generated assets are served from:

- [assets/css/admin.css](assets/css/admin.css)
- [assets/css/userreview.css](assets/css/userreview.css)
- [assets/css/api-docs.css](assets/css/api-docs.css)
- [assets/vendor/bootstrap-icons/bootstrap-icons.css](assets/vendor/bootstrap-icons/bootstrap-icons.css)

## Bundle Boundaries

### Admin Bundle

Entry point: [assets/scss/admin.scss](assets/scss/admin.scss)

Used by:

- [admin/layout.cfm](admin/layout.cfm)
- [admin/login.cfm](admin/login.cfm)
- all admin pages rendered through the shared layout

This bundle holds:

- Bootstrap theme overrides
- shared admin layout styles
- shared admin utilities
- page-specific admin partials when a page has enough custom UI to justify its own partial

### UserReview Bundle

Entry point: [assets/scss/userreview.scss](assets/scss/userreview.scss)

Used by:

- [userreview/layout.cfm](userreview/layout.cfm)

Keep this bundle small and focused on the self-service experience.

### API Docs Bundle

Entry point: [assets/scss/api-docs.scss](assets/scss/api-docs.scss)

Used by:

- [api/docs.html](api/docs.html)
- [api/examples.html](api/examples.html)

This bundle shares the same brand tokens as the admin bundle but keeps docs/example presentation concerns separate.

## Sass Structure

Top-level structure:

- [assets/scss/shared](assets/scss/shared) for cross-bundle tokens and base styles
- [assets/scss/admin](assets/scss/admin) for admin-only partials
- [assets/scss/userreview](assets/scss/userreview) for UserReview partials
- [assets/scss/api](assets/scss/api) for API docs/examples partials

Shared partials currently include:

- [assets/scss/shared/_brand.scss](assets/scss/shared/_brand.scss)
- [assets/scss/shared/_base.scss](assets/scss/shared/_base.scss)

Admin partials currently include:

- [assets/scss/admin/_layout.scss](assets/scss/admin/_layout.scss)
- [assets/scss/admin/_dashboard.scss](assets/scss/admin/_dashboard.scss)
- [assets/scss/admin/_users-index.scss](assets/scss/admin/_users-index.scss)
- [assets/scss/admin/_users-edit.scss](assets/scss/admin/_users-edit.scss)
- [assets/scss/admin/_reporting.scss](assets/scss/admin/_reporting.scss)
- [assets/scss/admin/_settings.scss](assets/scss/admin/_settings.scss)
- [assets/scss/admin/_media.scss](assets/scss/admin/_media.scss)

## Branding and Bootstrap Policy

Brand tokens live in [assets/scss/shared/_brand.scss](assets/scss/shared/_brand.scss).

These values are the app-owned adaptation of the UHCO branding layer originally reviewed in `dev/uhco-web-resources-main/src/sass/theme.scss`.

Current policy:

- Use one Bootstrap version for all locally compiled CSS.
- Bootstrap is compiled from Sass with theme variable overrides.
- Do not pull full CMS-specific styling or unrelated third-party CSS into UHCO Identity by default.
- Bootstrap Icons are localized and served from [assets/vendor/bootstrap-icons](assets/vendor/bootstrap-icons).

If Bootstrap is upgraded, upgrade it in [package.json](package.json), rebuild, and regression-check all three bundles.

## Utility vs Partial Rules

### Use a shared utility class when:

- the pattern is purely presentational
- the pattern repeats across multiple pages
- the rule is small and generic

Examples:

- hidden-state helpers in [assets/scss/admin/_settings.scss](assets/scss/admin/_settings.scss)
- scroll-panel sizing in [assets/scss/admin/_settings.scss](assets/scss/admin/_settings.scss)
- shared media preview sizing in [assets/scss/admin/_media.scss](assets/scss/admin/_media.scss)

### Use a page-specific partial when:

- the page has a distinct UI structure
- the styles are tightly coupled to that page’s markup
- the page has enough custom rules that a utility-only approach becomes unclear

Examples:

- [assets/scss/admin/_dashboard.scss](assets/scss/admin/_dashboard.scss)
- [assets/scss/admin/_users-index.scss](assets/scss/admin/_users-index.scss)
- [assets/scss/admin/_users-edit.scss](assets/scss/admin/_users-edit.scss)

## Inline Style Policy

Inline styles are now the exception, not the default.

Allowed:

- values that are truly dynamic at render time and difficult to express otherwise
- temporary state values that JS mutates directly and that do not justify a stable class

Avoid:

- fixed widths
- max-height rules
- overflow rules
- text/link color overrides
- badge sizing
- image sizing
- repeated display rules used only for initial hidden state

Examples of acceptable residual inline use:

- server-rendered dynamic `display:` state tied directly to runtime checkbox selection in [admin/users/edit.cfm](admin/users/edit.cfm)

If an inline style repeats more than once or appears on more than one page, move it into Sass.

## CFML Page Migration Pattern

When migrating a CFML page:

1. Identify repeated inline styles or embedded `<style>` blocks.
2. Separate static presentation from dynamic state.
3. Move static presentation into a shared utility or page partial.
4. Keep only truly dynamic values inline if needed.
5. Rebuild CSS with `npm run build:styles`.
6. Check the touched files for editor errors.

This pattern has already been applied to:

- [admin/dashboard.cfm](admin/dashboard.cfm)
- [admin/users/index.cfm](admin/users/index.cfm)
- [admin/users/edit.cfm](admin/users/edit.cfm)
- [admin/reporting/data_quality_report.cfm](admin/reporting/data_quality_report.cfm)
- [admin/reporting/uh_sync_report.cfm](admin/reporting/uh_sync_report.cfm)
- [admin/settings/query-builder/index.cfm](admin/settings/query-builder/index.cfm)
- [admin/settings/import/upload.cfm](admin/settings/import/upload.cfm)
- [admin/settings/import/process.cfm](admin/settings/import/process.cfm)
- [admin/user-media/crop.cfm](admin/user-media/crop.cfm)
- [admin/user-media/resize.cfm](admin/user-media/resize.cfm)
- [admin/user-media/variants.cfm](admin/user-media/variants.cfm)

## Layout Hooks

The admin layout now supports a page-level CSS hook via `pageStyles` in [admin/layout.cfm](admin/layout.cfm).

Use this only when:

- a page has a narrow stylesheet need that is not yet worth a shared partial
- the style is intentionally page-local

Preferred order of choice:

1. existing shared utility
2. existing page partial
3. new shared/page partial
4. `pageStyles` hook
5. inline style as a last resort

## Documentation Maintenance

When new partials are added or bundle responsibilities change:

- update this document
- keep the README aligned with the current build flow
- prefer documenting conventions here rather than scattering them across comments in templates

## Future Work

- Continue migrating remaining admin pages with repeated inline styles.
- Evaluate whether CropperJS and Quill CSS should be localized similarly to Bootstrap Icons.
- Expand the shared brand token set if typography, spacing, or elevation tokens become necessary.