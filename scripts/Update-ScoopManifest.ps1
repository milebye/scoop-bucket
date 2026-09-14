# Update-ScoopManifest.ps1
# Local, server-less auto-updater for manifests in this bucket.
#
# `scoop update` only runs `git pull` on buckets and never runs checkver, so for
# a local (non-git) bucket we run checkver ourselves and then let Scoop install
# the newly discovered version.
#
# Register it as a Scheduled Task for unattended updates, e.g.:
#   schtasks /Create /TN "Scoop Bucket Update" /SC DAILY /ST 12:00 ^
#     /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\scoop-bucket\scripts\Update-ScoopManifest.ps1\""
#
# Note: when the GitHub Actions Excavator workflow is enabled for this bucket,
# this script is unnecessary - the manifest is already bumped server-side.

[CmdletBinding()]
param(
    # Bucket directory that holds the manifests
    [string]$BucketDir = "$env:USERPROFILE\scoop\buckets\milebye",
    # Manifest(s) to update; defaults to every manifest in the bucket
    [string[]]$App = @('*')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'scoop is not on PATH.'
}

if (-not (Test-Path $BucketDir)) {
    throw "Bucket directory not found: $BucketDir"
}

# Locate SCOOP_HOME (the scoop install dir) to reach its bundled checkver.ps1.
$scoopHome = $env:SCOOP_HOME
if (-not $scoopHome) {
    $scoopPs1 = (scoop which scoop | Select-Object -First 1).Trim()
    if ($scoopPs1) { $scoopHome = Split-Path (Split-Path $scoopPs1) }
}
if (-not $scoopHome) {
    throw 'Could not locate SCOOP_HOME. Set the SCOOP_HOME environment variable.'
}
$checkver = Join-Path $scoopHome 'bin\checkver.ps1'
if (-not (Test-Path $checkver)) {
    throw "checkver.ps1 not found under $scoopHome"
}

foreach ($name in $App) {
    Write-Host "Checking upstream release for '$name'..." -ForegroundColor Cyan
    # -Update rewrites version/url/hash in place when a newer release exists.
    & $checkver -Dir $BucketDir $name -Update
}

Write-Host 'Applying Scoop updates...' -ForegroundColor Cyan
scoop update

Write-Host 'Done.' -ForegroundColor Green
