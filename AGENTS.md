# Repository Notes

Maintenance guide for this Scoop bucket. Written so that a fresh agent (or a
future you) can pick it up without re-deriving everything below.

## Scope

- Personal Scoop bucket. Active manifests live in `bucket/*.json`.
- `README.md` is the human-facing index; this file is the source of truth for
  how the repository is meant to be maintained.
- `deprecated/` holds manifests that are no longer installable. Scoop's wrapper
  scripts do not scan it.

## Commands

Run from the repository root in PowerShell. The `bin/*.ps1` wrappers resolve
Scoop via `$env:SCOOP_HOME` or `scoop prefix scoop`, then call Scoop's own
scripts with `-Dir .\bucket`.

| Task | Command |
| --- | --- |
| Format manifests | `& .\bin\formatjson.ps1` (one app: `-App <name>`) |
| Report available updates | `& .\bin\checkver.ps1` |
| **Apply** updates to manifests | `& .\bin\checkver.ps1 -Update` |
| Verify download URLs | `& .\bin\checkurls.ps1` |
| Verify hashes | `& .\bin\checkhashes.ps1` (`-Update` rewrites them) |
| Pester suite | `& .\bin\test.ps1` |

`-Update` edits manifests in place. Only run it when you intend to commit the
version/hash changes.

### Running the test suite locally

`bin\test.ps1` requires PowerShell 5.1 plus **BuildHelpers 2.0.1** and
**Pester 5.2.0**. If those are missing, the suite cannot start. CI installs them
automatically; locally you can stage them anywhere on `PSModulePath`:

```powershell
# Download the .nupkg files, expand them, and lay them out as
# <root>\<ModuleName>\<Version>\<ModuleName>.psd1, then:
$env:PSModulePath = "<root>;" + $env:PSModulePath
$env:SCOOP_HOME   = (scoop prefix scoop)
$env:CI           = $true     # match how CI exercises the tests
& .\bin\test.ps1
```

## How updates work

Two independent mechanisms, and it is important not to confuse them.

**1. Excavator (server-side, the real automation).** `.github/workflows/excavator.yml`
runs every 4 hours on GitHub Actions. It calls `ScoopInstaller/GithubActions`,
which internally runs Scoop's own `bin/auto-pr.ps1` → `checkver.ps1 -Update`,
then commits any bumped `version`/`url`/`hash` back to `main` as
`github-actions[bot]`. No local machine is involved.

`SKIP_UPDATED: 1` maps to checkver's `-SkipUpdated`, which means "silently skip
manifests whose version has not changed". It is a performance switch, **not** a
statement about how fresh the bucket is.

**2. Client-side.** `scoop update` only `git pull`s the bucket; it never runs
checkver. So a manifest is only ever refreshed by mechanism 1. That is the whole
reason this repository must exist — a purely local bucket would never learn
about new upstream releases.

### Silent-failure warning

When checkver's regex matches nothing it **does not fail** — it skips the
manifest quietly, and the Excavator run still reports success. A green
Excavator is therefore not proof that a manifest is current. This is exactly how
the inherited `pixpin` manifest rotted at 3.2.3.1 while upstream had moved to
3.5.5.1.

**Whenever you add or edit a `checkver`, prove it resolves** rather than trusting
the manifest to be correct:

```powershell
# Temporarily pin the manifest to an older version, then confirm checkver
# detects the newer one and rewrites version/url/hash.
& .\bin\checkver.ps1 -App <name> -Update
```

## Hash strategy

Scoop's default `github` hash mode matches on the raw download URL, so it only
works when the URL is a plain GitHub release asset. Each manifest here differs:

| Manifest | Hash source |
| --- | --- |
| `paseo` | Default `github` mode — plain release asset, no extra config. |
| `pi-desktop` | Explicit `autoupdate.hash` reading the release API `digest`. |
| `pixpin` | Not on GitHub. No digest exists, so the Excavator downloads the artifact once per bump to compute the SHA-256. |

`pi-desktop` needs the explicit block because its URL ends in a Scoop fragment
(`#/dl.7z`). That fragment breaks the default URL match, and Scoop would then
fall back to downloading the whole ~115 MB artifact just to hash it:

```json
"hash": {
    "url": "https://api.github.com/repos/vastsa/PI-Desktop/releases",
    "jp": "$..assets[?(@.browser_download_url == '$url')].digest"
}
```

## Data persistence across an OS reinstall

Scoop keeps apps and `persist` data on the drive it is installed to. An OS
reinstall wipes C: but leaves that alone — but only if the app's state actually
lives under `persist`. These apps default to paths on C:, so the manifests
redirect them.

| Manifest | App state | Mechanism |
| --- | --- | --- |
| `paseo` | `%APPDATA%\Paseo`, `~\.paseo` | `installer.script` migrates into `$persist_dir`, links back with junctions |
| `pi-desktop` | `~\.pi-desktop`, `%APPDATA%\PI-Desktop` | same |
| `pixpin` | `Config`, `Data`, `History` inside the app dir | ordinary `persist` field (Scoop-native) |

### Why junctions rather than `env_set`

`pi-desktop` exposes `PI_DESKTOP_DATA_DIR`, which `env_set` could point at
`$persist_dir`. That was implemented first and then reverted, because setting
that variable changes application behaviour:

```js
const singleInstanceRequired = !process.env.PI_DESKTOP_DATA_DIR;
```

Setting it **disables the single-instance lock**, so launching the app twice
starts two instances sharing one `pi.sqlite`. Junctions are invisible to the app
and keep that protection intact.

The trade-off is that `scoop reset` re-applies `env_set` but never runs
`installer`/`pre_install`/`post_install` hooks (`scoop-reset.ps1` only calls
`create_shims`, `create_startmenu_shortcuts`, `env_add_path`, `env_set`,
`unlink_persist_data`, `persist_data`). So after a reinstall the links must be
rebuilt by running an install/update once:

```powershell
scoop update <app> -f   # -f is required: the version has not changed
```

The data itself always survives in `$persist_dir`; only the pointer is lost, and
it can also be recreated by hand:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.pi-desktop" `
  -Target "$env:SCOOP\persist\pi-desktop\data"
```

### Junction safety

These were tested explicitly, because junctions can destroy real data when
handled carelessly:

| Operation | Result |
| --- | --- |
| `Remove-Item` on the junction itself | target data survives |
| Cross-volume `Move-Item` (C: → D:) | contents copied correctly |
| `Remove-Item -Recurse` on a parent containing a junction | target data survives |
| `cmd /c rmdir /s /q` on that parent | target data survives |

Creating a junction does **not** require admin rights.

### Rules for the installer scripts

Keep these invariants when editing `installer.script`:

1. Migrate only when the home path is a real directory (no `LinkType`) and the
   persist target is empty.
2. **Refuse to run while the app is open** — moving a live SQLite database
   corrupts it. The scripts `throw` in that case.
3. If data exists in both places, warn and change nothing. Never guess which
   copy wins.
4. Be idempotent: a second run must not move or delete anything.
5. `uninstaller.script` removes only the junctions; everything in `$persist_dir`
   stays.

## Adding a manifest

1. Create `bucket/<app>.json`. Prefer `checkver: "github"` with a plain release
   asset URL.
2. If the URL carries a `#/...` fragment, add an explicit `autoupdate.hash`
   block (see the `pi-desktop` pattern above).
3. **Prove checkver resolves** (see the warning section) — do not assume.
4. Run `& .\bin\formatjson.ps1`, then `& .\bin\test.ps1`.
5. Commit, push, and confirm CI is green.
6. Add the app to `README.md` and `bucket/README.md`.

## File conventions

- **CRLF line endings**, enforced by `.gitattributes` (`* text=auto eol=crlf`) and
  `.editorconfig`. CI fails on LF. When writing files programmatically, convert:
  `$t = $t -replace "\r\n","\n" -replace "\n","\r\n"`.
- **No BOM.** CI fails on a leading UTF-8 BOM. Note that `Set-Content -Encoding utf8`
  in Windows PowerShell 5.1 *adds* one — use
  `[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))`.
- 4-space indentation for JSON and PowerShell; 2 spaces for YAML.
- Files must end with a newline and contain no trailing whitespace.

## Repository configuration

- `.github/workflows/excavator.yml` — scheduled updater (see above). Third-party
  actions are pinned to commit SHAs, not floating tags.
- `.github/workflows/ci.yml` — runs `bin\test.ps1` on push/PR against both
  `powershell` and `pwsh`.
- `Scoop-Bucket.Tests.ps1` — sets `$env:CI = $false` before importing Scoop's
  shared tests. Reason: with `CI=true`, Scoop's schema test validates *every*
  `.json` changed in the last commit anywhere in the repo, including
  `.vscode/settings.json` and `.markdownlint.json`, which are not manifests and
  fail validation. Forcing the non-CI branch scans `bucket/` only, so every
  manifest is still validated while repo config no longer breaks the build.
- `.vscode/settings.json` maps `bucket/**/*.json` to the upstream Scoop schema.
  It references `PSScriptAnalyzerSettings.psd1`, which is intentionally
  gitignored (a local override, not a shared file).
- `scripts/Update-ScoopManifest.ps1` — optional local updater for the case where
  you want updates without GitHub Actions. Redundant while Excavator runs.

## Verified history

Findings worth not re-discovering, each confirmed by experiment:

- `scoop update` never runs checkver; only the Excavator does.
- `scoop update <app> -f` **does** re-run `installer.script` (verified with a
  probe manifest that wrote a marker file).
- `scoop reset` re-applies `env_set` but never runs installer hooks.
- Setting `PI_DESKTOP_DATA_DIR` disables PI-Desktop's single-instance lock
  (two instances were successfully started).
- The inherited `pixpin` manifest was dead: PixPin renamed
  `PixPin_cn_zh-cn_<ver>.zip` → `PixPin_win_<ver>.zip` and moved downloads to
  `down.pixpin.cn`, so the old regex matched nothing.
- Upstream `paseo` declared `AGPL-3.0-or-later`; the project is actually
  Apache-2.0 (see its `LICENSE` and `package.json`).
