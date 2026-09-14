# Repository Notes

## Scope

- This is a personal Scoop bucket. Active manifests live in `bucket/*.json`.
- `README.md` is an index of manifests, not a build or test source of truth.

## Commands

Run commands from the repository root in PowerShell.

- Format active manifests: `& .\bin\formatjson.ps1` (one app: `& .\bin\formatjson.ps1 -App <name>`).
- Check versions: `& .\bin\checkver.ps1` (focused: `& .\bin\checkver.ps1 -App <name>`); add `-Update` only when intentionally editing versions/hashes.
- Check URLs: `& .\bin\checkurls.ps1`.
- Check hashes: `& .\bin\checkhashes.ps1`; add `-Update` only when intentionally rewriting hashes.
- Full Pester run: `& .\bin\test.ps1`; requires PowerShell 5.1 plus `BuildHelpers` 2.0.1 and `Pester` 5.2.0.

## Tooling Details

- The `bin/*.ps1` wrappers resolve Scoop via `$env:SCOOP_HOME` or `scoop prefix scoop`, then call Scoop's own scripts with `-Dir .\bucket`.
- CI is `.github/workflows/excavator.yml`: a scheduled Windows Excavator job every 4 hours with `SKIP_UPDATED=1`. It commits version/hash bumps back to this repository automatically, so installed clients only need `scoop update`.
- `.github/workflows/ci.yml` runs the manifest Pester tests on push and pull request.
- VS Code maps `bucket/**/*.json` to the upstream Scoop manifest schema.

## File Conventions

- Keep CRLF line endings: `.gitattributes` enforces `* text=auto eol=crlf`, and `.editorconfig` sets `end_of_line = crlf`.
- Use 4-space indentation for JSON and PowerShell; YAML uses 2 spaces.
- Prefer a declarative `autoupdate.hash` block over a bare hash so the Excavator can refresh hashes without downloading large artifacts. `pi-desktop` reads the SHA-256 from the GitHub release API `digest` field; `paseo` uses Scoop's built-in `github` hash mode; `pixpin` is not on GitHub, so its hash must be computed by download on each version bump.
