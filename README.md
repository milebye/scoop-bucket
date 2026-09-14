# scoop-bucket

Personal [Scoop](https://scoop.sh) bucket.

## Install

```powershell
scoop bucket add milebye https://github.com/milebye/scoop-bucket
```

## All manifests

- [**paseo**](https://github.com/getpaseo/paseo) One interface for Claude Code, Codex, Copilot, OpenCode, and Pi agents.
- [**pi-desktop**](https://github.com/vastsa/PI-Desktop) The desktop workspace for AI coding agents.
- [**pixpin**](https://pixpin.cn/) A free screenshot, pin-to-screen and OCR tool for Windows and macOS.

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

### Hash sources differ per manifest

Scoop's default `github` hash mode matches on the raw download URL. That works
only when the URL is a plain GitHub release asset.

- **`pi-desktop`** needs an explicit source. Its URL ends in a Scoop fragment
  (`#/dl.7z`), so the default match fails and Scoop would download the whole
  ~115 MB artifact just to hash it. Pointing at the release API `digest` field
  avoids that download:

  ```json
  "hash": {
      "url": "https://api.github.com/repos/vastsa/PI-Desktop/releases",
      "jp": "$..assets[?(@.browser_download_url == '$url')].digest"
  }
  ```

- **`paseo`** uses the default `github` mode — no fragment, no explicit block.

- **`pixpin`** is not a GitHub project at all. It scrapes the vendor download
  page with a regex, so there is no API digest to read and the Excavator has to
  download the artifact once per version bump to compute the SHA-256:

  ```json
  "checkver": {
      "url": "https://pixpin.cn/download",
      "regex": "PixPin_win_([\\d.]+)\\.zip"
  }
  ```

## Manifest notes

- **`pi-desktop`** installs the Windows portable build. That `.exe` is an NSIS
  archive; the manifest downloads it as `#/dl.7z` and unpacks the inner
  `$PLUGINSDIR\app-64.7z`. User data lives outside the app directory, so updates
  never touch settings or sessions.
- **`paseo`** keeps state in `%APPDATA%\Paseo` and `%USERPROFILE%\.paseo`. Its
  installer/uninstaller scripts migrate those into `$persist_dir` and replace them
  with junctions. Upstream's manifest declared AGPL-3.0-or-later; the project is
  actually Apache-2.0.
- **`pixpin`** persists `Config`, `Data`, and `History`. The upstream bucket
  (ygguorun) pinned 3.2.3.1 and could no longer update: PixPin renamed its
  portable artifact from `PixPin_cn_zh-cn_<ver>.zip` to `PixPin_win_<ver>.zip`
  and moved downloads to `down.pixpin.cn`, so the old regex matched nothing.
  This manifest tracks the new naming.

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
