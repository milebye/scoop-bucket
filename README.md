# scoop-bucket

Personal [Scoop](https://scoop.sh) bucket.

## Install

```powershell
scoop bucket add milebye https://github.com/milebye/scoop-bucket
```

Then install what you need:

```powershell
scoop install paseo pi-desktop pixpin
```

### Coming from another bucket?

`paseo` and `pixpin` also exist in other buckets, and Scoop remembers which
bucket an app came from in its `install.json`. If you installed them
elsewhere, remove that bucket only *after* reinstalling from here — otherwise
`scoop status` reports `Manifest removed` and updates silently stop working:

```powershell
scoop uninstall paseo pixpin
scoop install paseo pixpin
scoop bucket rm <old-bucket>
```

User data is not affected: everything lives in $persist_dir, so the reinstall
reconnects it. Close the apps first — their installer scripts refuse to migrate
data while the app is running.

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

## Surviving an OS reinstall

Scoop keeps apps and `persist` data on whatever drive it is installed to, so
wiping C: does not touch them. That only helps if an app's state actually lives
under `persist`.

- **`pi-desktop`** keeps state in `~/.pi-desktop` **and** `%APPDATA%\PI-Desktop`,
  both on C:. Its `installer.script` migrates them into `$persist_dir\data` and
  `$persist_dir\appdata`, then links them back with junctions.
- **`paseo`** does the same for `%APPDATA%\Paseo` and `%USERPROFILE%\.paseo`.
- **`pixpin`** uses the ordinary `persist` field, which Scoop handles natively.

### Why junctions

Junctions are transparent: PI-Desktop still sees `~/.pi-desktop` and does not
know the bytes live on D:. That keeps its single-instance lock working.

The alternative is the app's own `PI_DESKTOP_DATA_DIR` variable via `env_set`.
It is re-applied by `scoop reset` (which matters, because `scoop-reset.ps1`
never runs `installer`/`pre_install`/`post_install` hooks), but it has a real
cost:

```js
const singleInstanceRequired = !process.env.PI_DESKTOP_DATA_DIR;
```

Setting that variable disables the single-instance lock, so launching the app
twice starts two instances sharing one `pi.sqlite`. Junctions avoid that
trade-off, at the price of needing one extra `scoop install`/`scoop update`
after a reinstall to recreate the links. The data itself always survives in
`$persist_dir`; only the pointer needs rebuilding, and it can also be recreated
by hand:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.pi-desktop" `
  -Target "$env:SCOOP\persist\pi-desktop\data"
```

### Migration behaviour

`installer.script` moves pre-existing data once, and is written to be safe to
re-run:

- migrates only when the home path is a real directory and the persist target is
  empty;
- refuses to run while PI-Desktop is open, so a live `pi.sqlite` is never moved;
- if data exists in both places, warns and leaves both untouched;
- on uninstall, removes only the junctions and keeps everything in `$persist_dir`.

## Manifest notes

- **`pi-desktop`** installs the Windows portable build. That `.exe` is an NSIS
  archive; the manifest downloads it as `#/dl.7z` and unpacks the inner
  `$PLUGINSDIR\app-64.7z`. Data persistence is covered above.
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
