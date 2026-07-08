# Legacy SCSS Compatibility Layer

The active source of truth for UHCO_Identity styles now lives under:

```text
assets/css/src/
```

The top-level entry files in this folder are kept only as compatibility shims.

Do not add new styling here.

Update these files instead:

1. `assets/css/src/themes/uhco-identity/`
2. `assets/css/src/apps/uhco-identity/`

The legacy partial subfolders previously kept under `assets/scss/` have been removed after parity validation.
Only the top-level compatibility entrypoints in this folder remain.