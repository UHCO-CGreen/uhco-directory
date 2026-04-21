# NPM Cheatsheet

## What NPM Is

- `npm` is the Node.js package manager.
- In this project, `npm` is only being used for front-end asset work:
  - compiling Sass into CSS
  - copying Bootstrap Icons locally
  - managing front-end packages like `bootstrap`, `bootstrap-icons`, and `sass`

## Important Note For This Server

PowerShell execution policy on this machine blocks `npm.ps1`, so use `npm.cmd` in PowerShell:

```bash
npm.cmd install
npm.cmd run build
npm.cmd run watch:styles
```

If you are in Command Prompt instead of PowerShell, plain `npm` usually works.

## Quick Commands

| Command | Description |
|---------|-------------|
| `npm.cmd install` | Install packages listed in `package.json` |
| `npm.cmd run build` | Copy Bootstrap Icons and compile all CSS bundles |
| `npm.cmd run build:styles` | Compile Sass files into CSS only |
| `npm.cmd run build:icons` | Copy Bootstrap Icons from `node_modules` into local assets |
| `npm.cmd run watch:styles` | Watch Sass files and rebuild CSS automatically while you work |
| `npm.cmd outdated` | Show packages that have newer versions available |
| `npm.cmd list --depth=0` | Show top-level installed packages |

## Typical Workflow

```bash
# 1. Install packages once after cloning or after package changes
npm.cmd install

# 2. Build all front-end assets
npm.cmd run build

# 3. During Sass work, leave the watcher running
npm.cmd run watch:styles
```

## Project Scripts

These scripts are defined in `package.json` for this repository:

| Script | What It Does |
|--------|---------------|
| `build` | Runs `build:icons`, then `build:styles` |
| `build:icons` | Copies Bootstrap Icons into `assets/vendor/bootstrap-icons` |
| `build:styles` | Compiles `assets/scss/admin.scss`, `assets/scss/userreview.scss`, and `assets/scss/api-docs.scss` into `assets/css/` |
| `watch:styles` | Watches the Sass files and rebuilds CSS on save |

Run any script like this:

```bash
npm.cmd run build:styles
npm.cmd run watch:styles
```

## Files You Should Know

| File / Folder | Purpose |
|---------------|---------|
| `package.json` | Defines packages and npm scripts |
| `package-lock.json` | Locks exact dependency versions |
| `node_modules/` | Installed packages folder |
| `assets/scss/` | Source Sass files you edit |
| `assets/css/` | Compiled CSS output |
| `assets/vendor/bootstrap-icons/` | Local copied icon assets |

## Common Tasks

### Install packages

```bash
npm.cmd install
```

Use this when:

- you clone the repo for the first time
- `package.json` changes
- `node_modules/` is missing

### Build everything

```bash
npm.cmd run build
```

Use this when:

- you want a full fresh asset build
- Bootstrap Icons need to be recopied
- you changed Sass and want production-style output

### Compile styles only

```bash
npm.cmd run build:styles
```

Use this when:

- you only changed Sass or styling-related files
- you do not need to recopy icons

### Watch styles while editing

```bash
npm.cmd run watch:styles
```

Use this when:

- you are actively editing files under `assets/scss/`
- you want CSS rebuilt automatically after every save

Stop the watcher with `Ctrl+C`.

## Adding Or Updating Packages

### Install a package used at runtime

```bash
npm.cmd install package-name
```

Example:

```bash
npm.cmd install bootstrap-icons
```

This updates:

- `package.json`
- `package-lock.json`

### Install a development-only package

```bash
npm.cmd install -D package-name
```

Example:

```bash
npm.cmd install -D sass
```

Use `-D` for tooling that helps build the app but is not shipped as application runtime code.

### Update installed packages

```bash
npm.cmd outdated
npm.cmd update
```

`npm.cmd update` only updates packages within the version ranges already allowed by `package.json`.

## Useful Inspection Commands

| Command | Description |
|---------|-------------|
| `npm.cmd list --depth=0` | Show top-level installed packages |
| `npm.cmd outdated` | Show available updates |
| `npm.cmd run` | List available scripts |
| `npm.cmd help` | Show npm help |

## Undoing / Resetting

If packages get into a bad state, this is the usual reset process:

```bash
Remove-Item -Recurse -Force node_modules
Remove-Item -Force package-lock.json
npm.cmd install
```

Only remove `package-lock.json` if you intentionally want npm to regenerate it.

## Typical Styling Workflow For This Repo

```bash
# one-time setup
npm.cmd install

# start active Sass work
npm.cmd run watch:styles

# in another terminal, make your CFML / SCSS edits

# if you want a clean final build
npm.cmd run build
```

## Troubleshooting

### `npm` is not recognized

Node.js is probably not installed, or it is not on your PATH.

### PowerShell says scripts are disabled

Use `npm.cmd` instead of `npm`.

### Sass build shows Bootstrap deprecation warnings

That is currently expected in this repo because Bootstrap still emits upstream Sass warnings during compilation. The build is still valid as long as it completes successfully.

### Changes in Sass are not reflected in the UI

Check these in order:

1. Did `npm.cmd run build:styles` or `npm.cmd run watch:styles` complete successfully?
2. Did the correct bundle change, such as `assets/css/admin.css`?
3. Is the page loading the correct CSS bundle?
4. Does the browser need a hard refresh?

## Safe Default Commands

If you are unsure what to run, these are the safest defaults for styling work in this project:

```bash
npm.cmd install
npm.cmd run build
npm.cmd run watch:styles
```