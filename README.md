# PI-Desktop Scoop Bucket

Unofficial [Scoop](https://scoop.sh) bucket for [PI-Desktop](https://github.com/vastsa/PI-Desktop)
(the desktop workspace for AI coding agents).

The manifest installs the official Windows **portable** build, unpacks it into the
Scoop app directory, and creates a `PI-Desktop.exe` shim plus a Start Menu shortcut.

## Install

```powershell
scoop bucket add pi https://github.com/<your-name>/pi-scoop-bucket
scoop install pi-desktop
```

## Update

```powershell
scoop update pi-desktop
```

You never edit the manifest by hand. The version and hash are discovered
automatically by Scoop's `checkver` / `autoupdate` from the GitHub releases API.

## How the automatic update works

`bucket/pi-desktop.json` contains:

```json
"checkver": "github",
"autoupdate": {
    "architecture": {
        "64bit": {
            "url": "https://github.com/vastsa/PI-Desktop/releases/download/v$version/PI-Desktop-Portable-$version.exe#/dl.7z"
        }
    },
    "hash": {
        "url": "https://api.github.com/repos/vastsa/PI-Desktop/releases",
        "jp": "$..assets[?(@.browser_download_url == '$url')].digest"
    }
}
```

- `checkver: github` reads the latest release tag.
- `autoupdate` rewrites the download URL for the new tag.
- The `hash` block pulls the SHA-256 `digest` straight from the GitHub API,
  so the updater does **not** re-download the ~115 MB installer just to hash it.

### Important: `scoop update` alone does not refresh the manifest

`checkver`/`autoupdate` are **maintainer-side** features. `scoop update <app>`
only re-installs whatever version the manifest currently declares; `scoop update`
on its own merely `git pull`s the buckets. Nothing on your machine rewrites the
manifest. So to stay current with zero manual work, you need one of these:

1. **Server-side (recommended, fully hands-off):** the `Excavator` GitHub Actions
   workflow in `.github/workflows/excavator.yml` runs every 4 hours, runs checkver
   for every manifest, and commits the bumped `version`/`url`/`hash` back to this
   repo. Fork/copy this repo, enable Actions (Settings → Actions → allow), and your
   `scoop update pi-desktop` will always see the newest release — even while your
   machine was off.

2. **Local (no GitHub repo needed):** run `scripts/Update-PiDesktopScoop.ps1`.
   It invokes Scoop's own `checkver.ps1 -Update` against your local bucket to
   rewrite the manifest, then runs `scoop update pi-desktop`. Register it as a
   Scheduled Task for unattended updates:

   ```powershell
   schtasks /Create /TN "PiDesktop Scoop Update" /SC DAILY /ST 12:00 `
     /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"$env:USERPROFILE\pi-scoop-bucket\scripts\Update-PiDesktopScoop.ps1\""
   ```

Both paths were tested end-to-end: a manifest pinned to an old version is
automatically bumped to the current release with a correct hash, and the new
build installs cleanly.

## Notes

- User data lives in `%APPDATA%\PI-Desktop`, outside the Scoop app directory, so
  updating or reinstalling never touches your settings, sessions, or plugins.
- Only the Windows x64 portable build is covered. macOS/Linux users should use
  the release artifacts directly.
- The portable `.exe` is an NSIS archive; the manifest downloads it as `#/dl.7z`
  and unpacks the inner `$PLUGINSDIR\app-64.7z` into the app directory.
