# scoop-bucket

Personal [Scoop](https://scoop.sh) bucket.

## Install

```powershell
scoop bucket add milebye https://github.com/milebye/scoop-bucket
```

## All manifests

- [**paseo**](https://github.com/getpaseo/paseo) One interface for Claude Code, Codex, Copilot, OpenCode, and Pi agents.
- [**pi-desktop**](https://github.com/vastsa/PI-Desktop) The desktop workspace for AI coding agents.

## How automatic updates work

Every manifest carries `checkver` + `autoupdate`, and
`.github/workflows/excavator.yml` runs Scoop's Excavator every 4 hours on GitHub
Actions. When upstream publishes a release, the workflow commits the bumped
`version`/`url`/`hash` back to this repository automatically.

That means clients only ever need:

```powershell
scoop update
scoop update *
```

No manifest is edited by hand, and no local machine needs to be awake.

### Why the `autoupdate.hash` block matters

`pi-desktop` ships a ~115 MB portable `.exe`, so its manifest declares an
explicit hash source instead of relying on Scoop's default behaviour:

```json
"hash": {
    "url": "https://api.github.com/repos/vastsa/PI-Desktop/releases",
    "jp": "$..assets[?(@.browser_download_url == '$url')].digest"
}
```

Scoop's built-in `github` hash mode matches on the raw download URL. Because the
`pi-desktop` URL ends in a Scoop fragment (`#/dl.7z`), that match fails and Scoop
falls back to downloading the whole artifact just to hash it. Pointing at the
release API `digest` field avoids that download entirely.

`paseo` has no such fragment, so it uses the default `github` mode and needs no
explicit hash block.

## Maintenance

Run from the repository root in PowerShell. The `bin/*.ps1` wrappers call
Scoop's own scripts against `bucket/`.

```powershell
& .\bin\formatjson.ps1          # format all manifests
& .\bin\checkver.ps1            # report available updates
& .\bin\checkhashes.ps1         # verify hashes
& .\bin\test.ps1                # Pester suite (needs BuildHelpers + Pester 5.2.0)
```

See [AGENTS.md](AGENTS.md) for the full conventions.
