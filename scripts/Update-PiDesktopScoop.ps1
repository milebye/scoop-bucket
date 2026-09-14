# Update-PiDesktopScoop.ps1
# Local, server-less auto-updater for the pi-desktop Scoop manifest.
#
# `scoop update` only does a `git pull` on buckets and never runs checkver,
# so for a local (non-git) bucket we run checkver ourselves and then let
# Scoop install the newly discovered version.
#
# Register it as a Scheduled Task to get unattended updates, e.g.:
#   schtasks /Create /TN "PiDesktop Scoop Update" /SC DAILY /ST 12:00 ^
#     /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\Update-PiDesktopScoop.ps1\""

[CmdletBinding()]
param(
    # Bucket directory that holds pi-desktop.json
    [string]$BucketDir = "$env:USERPROFILE\scoop\buckets\pi",
    # Manifest name inside the bucket
    [string]$App = 'pi-desktop'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'scoop is not on PATH.'
}

$manifest = Join-Path $BucketDir "$App.json"
if (-not (Test-Path $manifest)) {
    throw "Manifest not found: $manifest"
}

# Locate SCOOP_HOME (the scoop install dir) to reach its bundled checkver.ps1.
# 'scoop which scoop' resolves the shim to <scoop>\apps\scoop\current\bin\scoop.ps1.
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

Write-Host "Checking upstream release for '$App'..." -ForegroundColor Cyan
# -Update rewrites version/url/hash in place when a newer release exists.
& $checkver -Dir $BucketDir $App -Update

Write-Host 'Applying Scoop update...' -ForegroundColor Cyan
scoop update $App

Write-Host 'Done.' -ForegroundColor Green
