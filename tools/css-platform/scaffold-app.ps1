[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)]
  [string]$AppName,

  [string]$DisplayName = "",

  [string]$BodyClassPrefix = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-NormalizedSlug {
  param([string]$Value)

  $slug = $Value.Trim().ToLowerInvariant()
  $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
  $slug = $slug.Trim("-")

  if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "AppName must contain at least one letter or number."
  }

  return $slug
}

function New-BodyClassPrefix {
  param(
    [string]$ProvidedPrefix,
    [string]$Slug
  )

  if (-not [string]::IsNullOrWhiteSpace($ProvidedPrefix)) {
    return $ProvidedPrefix.Trim()
  }

  return $Slug
}

function Write-ScaffoldFile {
  param(
    [string]$Path,
    [string]$Content
  )

  $targetDir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $targetDir)) {
    if ($PSCmdlet.ShouldProcess($targetDir, "Create directory")) {
      New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
  }

  if (Test-Path -LiteralPath $Path) {
    Write-Host "Skipping existing file: $Path"
    return
  }

  if ($PSCmdlet.ShouldProcess($Path, "Create file")) {
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$slug = New-NormalizedSlug -Value $AppName
$resolvedDisplayName = if ([string]::IsNullOrWhiteSpace($DisplayName)) { $AppName.Trim() } else { $DisplayName.Trim() }
$resolvedBodyClassPrefix = New-BodyClassPrefix -ProvidedPrefix $BodyClassPrefix -Slug $slug

$themeDir = Join-Path $repoRoot "assets\css\src\themes\$slug"
$appDir = Join-Path $repoRoot "assets\css\src\apps\$slug"
$adminDir = Join-Path $appDir "admin"
$apiDir = Join-Path $appDir "api"
$userReviewDir = Join-Path $appDir "userreview"
$distRootDir = Join-Path $repoRoot "assets\css\dist\$slug"
$distAdminDir = Join-Path $distRootDir "admin"
$distApiDir = Join-Path $distRootDir "api"
$distUserReviewDir = Join-Path $distRootDir "userreview"

foreach ($dir in @($themeDir, $appDir, $adminDir, $apiDir, $userReviewDir, $distRootDir, $distAdminDir, $distApiDir, $distUserReviewDir)) {
  if (-not (Test-Path -LiteralPath $dir)) {
    if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
  }
}

$tokensContent = @'
$primary: #c8102e;
$secondary: #ffffff;
$success: #00b388;
$danger: #c8102e;
$info: #fff9d9;
$warning: #f6be00;

$app-bg: #f8f9fa;
$surface-bg: #ffffff;
$surface-muted: #f4f6f8;
$border-color: #dbe1ea;
$text-color: #213547;
$text-muted: #54585a;

$admin-sidebar-bg: var(--slate, #212529);
$admin-sidebar-text: #adb5bd;
$admin-sidebar-active: #f0d878;

$userreview-bg: #f4f6f8;
$userreview-header-start: #0f3d56;
$userreview-header-end: #1b6a8f;

$code-bg: #1e1e1e;
$code-fg: #d4d4d4;
$code-inline-bg: #f9f2f4;
$code-inline-fg: #c7254e;
'@

$themeContent = @'
@use "./tokens" as brand;

:root {
  --uhco-primary: #{brand.$primary};
  --uhco-success: #{brand.$success};
  --uhco-warning: #{brand.$warning};
  --uhco-info: #{brand.$info};
  --uhco-surface: #{brand.$surface-bg};
  --uhco-surface-muted: #{brand.$surface-muted};
  --uhco-border: #{brand.$border-color};
  --uhco-text: #{brand.$text-color};
  --uhco-text-muted: #{brand.$text-muted};
  --slate: #54585a;
  --med-gray: #dadada;
  --grey: #888b8d;
  --white: #ffffff;
}

body {
  background: brand.$app-bg;
  color: var(--uhco-text);
}

body.__BODY_CLASS_PREFIX__-admin,
body.__BODY_CLASS_PREFIX__-api,
body.__BODY_CLASS_PREFIX__-userreview {
  min-height: 100vh;
}
'@
$themeContent = $themeContent.Replace("__BODY_CLASS_PREFIX__", $resolvedBodyClassPrefix)

$adminLayoutContent = @'
@use "../../../themes/__SLUG__/tokens" as brand;

body {
  background: brand.$app-bg;
}

.sidebar {
  width: 260px;
  flex-shrink: 0;
  background: brand.$admin-sidebar-bg;
  color: #fff;
}

.main-content {
  margin-left: 260px;
}
'@
$adminLayoutContent = $adminLayoutContent.Replace("__SLUG__", $slug)

$apiDocsContent = @'
@use "../../../themes/__SLUG__/tokens" as brand;

body {
  background: brand.$app-bg;
}

.endpoint-card {
  border-left: 4px solid var(--bs-primary);
}

.method-badge {
  font-size: 0.7rem;
  letter-spacing: 0.05em;
}

pre.example,
pre.code,
#live-response {
  background: brand.$code-bg;
  color: brand.$code-fg;
}
'@
$apiDocsContent = $apiDocsContent.Replace("__SLUG__", $slug)

$userReviewLayoutContent = @'
@use "../../../themes/__SLUG__/tokens" as brand;

body {
  background: brand.$userreview-bg;
}

.ur-shell {
  max-width: 1100px;
  margin: 0 auto;
}

.ur-header {
  background: linear-gradient(135deg, brand.$userreview-header-start, brand.$userreview-header-end);
  color: #fff;
}
'@
$userReviewLayoutContent = $userReviewLayoutContent.Replace("__SLUG__", $slug)

$adminEntryContent = @'
@use "../../themes/__SLUG__/tokens" as brand;
@use "bootstrap/scss/bootstrap" with (
  $primary: brand.$primary,
  $secondary: brand.$secondary,
  $success: brand.$success,
  $danger: brand.$danger,
  $info: brand.$info,
  $warning: brand.$warning
);

@use "../../shared/base";
@use "../../shared/mixins";
@use "../../themes/__SLUG__/theme";
@use "./admin/layout";
'@
$adminEntryContent = $adminEntryContent.Replace("__SLUG__", $slug)

$apiEntryContent = @'
@use "../../themes/__SLUG__/tokens" as brand;
@use "bootstrap/scss/bootstrap" with (
  $primary: brand.$primary,
  $secondary: brand.$secondary,
  $success: brand.$success,
  $danger: brand.$danger,
  $info: brand.$info,
  $warning: brand.$warning
);

@use "../../shared/base";
@use "../../shared/mixins";
@use "../../themes/__SLUG__/theme";
@use "./api/docs";
'@
$apiEntryContent = $apiEntryContent.Replace("__SLUG__", $slug)

$userReviewEntryContent = @'
@use "../../themes/__SLUG__/tokens" as brand;
@use "bootstrap/scss/bootstrap" with (
  $primary: brand.$primary,
  $secondary: brand.$secondary,
  $success: brand.$success,
  $danger: brand.$danger,
  $info: brand.$info,
  $warning: brand.$warning
);

@use "../../shared/base";
@use "../../shared/mixins";
@use "../../themes/__SLUG__/theme";
@use "./userreview/layout";
'@
$userReviewEntryContent = $userReviewEntryContent.Replace("__SLUG__", $slug)

$readmeContent = @'
Scaffold created for __DISPLAY_NAME__.

Compile targets to wire manually if this app is activated:
- assets/css/src/apps/__SLUG__/admin.scss -> assets/css/dist/__SLUG__/admin/admin.css
- assets/css/src/apps/__SLUG__/api.scss -> assets/css/dist/__SLUG__/api/api-docs.css
- assets/css/src/apps/__SLUG__/userreview.scss -> assets/css/dist/__SLUG__/userreview/userreview.css

Recommended body classes:
- __BODY_CLASS_PREFIX__-admin
- __BODY_CLASS_PREFIX__-api
- __BODY_CLASS_PREFIX__-userreview
'@
$readmeContent = $readmeContent.Replace("__DISPLAY_NAME__", $resolvedDisplayName)
$readmeContent = $readmeContent.Replace("__SLUG__", $slug)
$readmeContent = $readmeContent.Replace("__BODY_CLASS_PREFIX__", $resolvedBodyClassPrefix)

Write-ScaffoldFile -Path (Join-Path $themeDir "_tokens.scss") -Content $tokensContent
Write-ScaffoldFile -Path (Join-Path $themeDir "_theme.scss") -Content $themeContent
Write-ScaffoldFile -Path (Join-Path $adminDir "_layout.scss") -Content $adminLayoutContent
Write-ScaffoldFile -Path (Join-Path $apiDir "_docs.scss") -Content $apiDocsContent
Write-ScaffoldFile -Path (Join-Path $userReviewDir "_layout.scss") -Content $userReviewLayoutContent
Write-ScaffoldFile -Path (Join-Path $appDir "admin.scss") -Content $adminEntryContent
Write-ScaffoldFile -Path (Join-Path $appDir "api.scss") -Content $apiEntryContent
Write-ScaffoldFile -Path (Join-Path $appDir "userreview.scss") -Content $userReviewEntryContent
Write-ScaffoldFile -Path (Join-Path $distRootDir "README.txt") -Content $readmeContent

Write-Host "Scaffold ready for app slug '$slug'."
Write-Host "Theme: $themeDir"
Write-Host "App:   $appDir"
Write-Host "Dist:  $distRootDir"