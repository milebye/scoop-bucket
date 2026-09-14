# Scoop's shared bucket tests have two modes:
#   - $env:CI = $true  (GitHub Actions sets this): validate every *.json file
#     changed in the last commit, anywhere in the repository.
#   - otherwise: recursively validate every *.json under bucket/.
#
# The CI branch matches on repository-wide git paths, so it also picks up
# repository configuration that is not a Scoop manifest (`.vscode/settings.json`,
# `.markdownlint.json`) and fails schema validation on it. Force the non-CI branch
# so the schema test scans bucket/ only - every manifest is still validated, and
# the repository config files no longer break the build.
$env:CI = $false

if (!$env:SCOOP_HOME) { $env:SCOOP_HOME = Resolve-Path (scoop prefix scoop) }
. "$env:SCOOP_HOME\test\Import-Bucket-Tests.ps1"
