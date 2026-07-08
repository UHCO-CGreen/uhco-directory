# UHCO Identity Styling Guide

This document defines the styling architecture for UHCO Identity after the migration to the shared portal CSS platform structure.

## Goals

- Keep styling local to this repository.
- Compile branded Bootstrap CSS from Sass instead of relying on stock CDN CSS.
- Separate neutral shared/platform code from UHCO Identity theme code and app-surface code.
- Treat UHCO Identity as three compiled surfaces: admin, api, and userreview.
- Prefer shared utilities and partials over page-level inline styles.

## Current Asset Build

The repository includes a local `npm` + Sass workflow in [package.json](package.json).

Primary commands:

- `npm run build` copies local vendor assets and compiles all CSS bundles.
- `npm run build:icons` copies Bootstrap Icons from `node_modules` into the app.
- `npm run build:styles` compiles Sass entry points into application-served CSS files.
- `npm run watch:styles` watches Sass files and recompiles on change.
- `npm run scaffold:css:app -- -AppName "Example App" -DisplayName "Example App"` scaffolds a new admin/api/userreview app set.

Generated assets are served from:

- [assets/css/dist/admin/admin.css](assets/css/dist/admin/admin.css)
- [assets/css/dist/userreview/userreview.css](assets/css/dist/userreview/userreview.css)
- [assets/css/dist/api/api-docs.css](assets/css/dist/api/api-docs.css)
- [assets/vendor/bootstrap-icons/bootstrap-icons.css](assets/vendor/bootstrap-icons/bootstrap-icons.css)

## Bundle Boundaries

### Admin Bundle

Entry point: [assets/css/src/apps/uhco-identity/admin.scss](assets/css/src/apps/uhco-identity/admin.scss)

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

Entry point: [assets/css/src/apps/uhco-identity/userreview.scss](assets/css/src/apps/uhco-identity/userreview.scss)

Used by:

- [userreview/layout.cfm](userreview/layout.cfm)

Keep this bundle small and focused on the self-service experience.

### API Docs Bundle

Entry point: [assets/css/src/apps/uhco-identity/api.scss](assets/css/src/apps/uhco-identity/api.scss)

Used by:

- [api/docs.html](api/docs.html)
- [api/examples.html](api/examples.html)

This bundle shares the same brand tokens as the admin bundle but keeps docs/example presentation concerns separate.

## Sass Structure

Top-level source structure:

- [assets/css/src/shared](assets/css/src/shared) for neutral shared base styles and mixins
- [assets/css/src/platform](assets/css/src/platform) for neutral platform primitives
- [assets/css/src/themes/uhco-identity](assets/css/src/themes/uhco-identity) for UHCO Identity tokens and theme rules
- [assets/css/src/apps/uhco-identity/admin](assets/css/src/apps/uhco-identity/admin) for admin-only partials
- [assets/css/src/apps/uhco-identity/userreview](assets/css/src/apps/uhco-identity/userreview) for UserReview partials
- [assets/css/src/apps/uhco-identity/api](assets/css/src/apps/uhco-identity/api) for API docs/examples partials

Shared partials currently include:

- [assets/css/src/shared/_base.scss](assets/css/src/shared/_base.scss)
- [assets/css/src/shared/_mixins.scss](assets/css/src/shared/_mixins.scss)

Theme partials currently include:

- [assets/css/src/themes/uhco-identity/_tokens.scss](assets/css/src/themes/uhco-identity/_tokens.scss)
- [assets/css/src/themes/uhco-identity/_theme.scss](assets/css/src/themes/uhco-identity/_theme.scss)

Admin partials currently include:

- [assets/css/src/apps/uhco-identity/admin/_layout.scss](assets/css/src/apps/uhco-identity/admin/_layout.scss)
- [assets/css/src/apps/uhco-identity/admin/_dashboard.scss](assets/css/src/apps/uhco-identity/admin/_dashboard.scss)
- [assets/css/src/apps/uhco-identity/admin/_users-index.scss](assets/css/src/apps/uhco-identity/admin/_users-index.scss)
- [assets/css/src/apps/uhco-identity/admin/_users-edit.scss](assets/css/src/apps/uhco-identity/admin/_users-edit.scss)
- [assets/css/src/apps/uhco-identity/admin/_reporting.scss](assets/css/src/apps/uhco-identity/admin/_reporting.scss)
- [assets/css/src/apps/uhco-identity/admin/_settings.scss](assets/css/src/apps/uhco-identity/admin/_settings.scss)
- [assets/css/src/apps/uhco-identity/admin/_media.scss](assets/css/src/apps/uhco-identity/admin/_media.scss)

Legacy compatibility entrypoints still exist in [assets/scss](assets/scss), but they now delegate to `assets/css/src` and should not receive new styling work.

## Branding and Bootstrap Policy

Brand tokens live in [assets/css/src/themes/uhco-identity/_tokens.scss](assets/css/src/themes/uhco-identity/_tokens.scss).

Current policy:

- Use one Bootstrap version for all locally compiled CSS.
- Bootstrap is compiled from Sass with theme variable overrides.
- Do not pull unrelated third-party CSS into UHCO Identity by default.
- Bootstrap Icons are localized and served from [assets/vendor/bootstrap-icons](assets/vendor/bootstrap-icons).

If Bootstrap is upgraded, upgrade it in [package.json](package.json), rebuild, and regression-check all three bundles.

## Utility vs Partial Rules

### Use a shared utility class when:

- the pattern is purely presentational
- the pattern repeats across multiple pages
- the rule is small and generic

Examples:

- hidden-state helpers in [assets/css/src/apps/uhco-identity/admin/_settings.scss](assets/css/src/apps/uhco-identity/admin/_settings.scss)
- scroll-panel sizing in [assets/css/src/apps/uhco-identity/admin/_settings.scss](assets/css/src/apps/uhco-identity/admin/_settings.scss)
- shared media preview sizing in [assets/css/src/apps/uhco-identity/admin/_media.scss](assets/css/src/apps/uhco-identity/admin/_media.scss)

### Use a page-specific partial when:

- the page has a distinct UI structure
- the styles are tightly coupled to that page’s markup
- the page has enough custom rules that a utility-only approach becomes unclear

Examples:

- [assets/css/src/apps/uhco-identity/admin/_dashboard.scss](assets/css/src/apps/uhco-identity/admin/_dashboard.scss)
- [assets/css/src/apps/uhco-identity/admin/_users-index.scss](assets/css/src/apps/uhco-identity/admin/_users-index.scss)
- [assets/css/src/apps/uhco-identity/admin/_users-edit.scss](assets/css/src/apps/uhco-identity/admin/_users-edit.scss)

## Inline Style Policy

Inline styles are the exception, not the default.

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

If an inline style repeats more than once or appears on more than one page, move it into Sass.

## CFML Page Migration Pattern

When migrating a CFML page:

1. Identify repeated inline styles or embedded `<style>` blocks.
2. Separate static presentation from dynamic state.
3. Move static presentation into a shared utility or page partial.
4. Keep only truly dynamic values inline if needed.
5. Rebuild CSS with `npm run build:styles`.
6. Check the touched files for editor errors.

## Layout Hooks

The admin layout supports a page-level CSS hook via `pageStyles` in [admin/layout.cfm](admin/layout.cfm).

Preferred order of choice:

1. existing shared utility
2. existing page partial
3. new shared/page partial
4. `pageStyles` hook
5. inline style as a last resort

## Scaffold Automation

This repo includes a UHCO Identity-specific scaffold command for future admin/api/userreview app sets.

Use:

- `npm run scaffold:css:app -- -AppName "Example App" -DisplayName "Example App"`

Implementation lives in [tools/css-platform/scaffold-app.ps1](tools/css-platform/scaffold-app.ps1).

This scaffold generates new source sets under `assets/css/src/themes/<app-slug>` and `assets/css/src/apps/<app-slug>`, plus segregated outputs under `assets/css/dist/<app-slug>`.

Do not use the scaffold to overwrite `uhco-identity`; it is intended for new app sets that follow the same three-surface model.

## Documentation Maintenance

When partials, bundle responsibilities, or build paths change:

- update this document
- keep the README aligned with the current build flow
- prefer documenting conventions here rather than scattering them across comments in templates