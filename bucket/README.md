# bucket

Manifests in this directory are consumed by Scoop. Every file here is validated
against the upstream Scoop manifest schema by CI.

- `paseo.json` — [Paseo](https://github.com/getpaseo/paseo)
- `pi-desktop.json` — [PI-Desktop](https://github.com/vastsa/PI-Desktop)
- `pixpin.json` — [PixPin](https://pixpin.cn/)

Adding a manifest? Run `& .\bin\checkver.ps1` to confirm it resolves, then
`& .\bin\formatjson.ps1` and `& .\bin\test.ps1` before committing.
