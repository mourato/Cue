<div align="center">
  <img src="./banner.png" width="200" height="200" alt="Cue banner" />

  <h1>Cue</h1>
  <p><strong>macOS visual handoff — capture, annotate with numbered pins, and copy a developer-ready brief.</strong></p>

  <p>
    <a href="./README.md">🇺🇸 English</a> •
    <a href="./README.vi.md">🇻🇳 Tiếng Việt</a> •
    <a href="./README.zh-CN.md">🇨🇳 简体中文</a>
  </p>

  <p>
    <a href="#features">Features</a> •
    <a href="#install">Install</a> •
    <a href="#shortcuts">Shortcuts</a> •
    <a href="#automation">Automation</a> •
    <a href="#development">Development</a> •
    <a href="#documentation">Documentation</a> •
    <a href="#security">Security</a> •
    <a href="#contributing">Contributing</a>
  </p>

  <p>
    <a href="https://github.com/mourato/Cue/stargazers"><img alt="GitHub Stars" src="https://img.shields.io/github/stars/mourato/Cue?style=flat&amp;logo=github" /></a>
    <a href="https://github.com/mourato/Cue/releases"><img alt="GitHub Releases" src="https://img.shields.io/github/v/release/mourato/Cue?style=flat&amp;logo=github" /></a>
  </p>
</div>

## Features

Cue is a focused macOS visual-handoff tool for product designers. It turns a screenshot into a clear brief for developers and AI coding agents: capture an area, place numbered pins or rectangles, add concise notes, and copy the result.

- **Capture** with fullscreen, area, window, scrolling, OCR, smart element, and object cutout modes
- **Visual annotation** with numbered pins, rectangles, and concise notes on the annotate canvas
- **Clipboard-ready export**: copy the annotated image and structured note brief in one action
- **Quick Access** floating panel after capture with copy, edit, and drag-to-app
- **Capture history** with editable annotation restore for committed screenshot sessions
- **Explicit sharing** from Annotate and Quick Access through the selected ImgBB or ImageKit image host
- **Configurable shortcuts** with system conflict detection
- **Localization**: English, Vietnamese, Simplified Chinese, Traditional Chinese, Spanish, Japanese, Korean, Russian, French, and German
- **Portable preferences** via `~/.config/cue/config.toml` (export/import, launch-time auto-apply)
- **Local diagnostics** with on-disk log retention (no telemetry)
- **Optional Video module** (compile-time): screen recording and Video Editor — off by default; enable under **Preferences → Advanced** when built with the Video scheme

The core workflow is local and explicit: captures, history, annotations, and exports stay on the Mac unless you choose to share an image with a configured host. See [docs/README.md](docs/README.md) for the full engineering map.

## Install

> Requires **macOS 26.0** or later.

### Download a release

1. Go to [Releases](https://github.com/mourato/Cue/releases)
2. Download the latest `Cue-v<version>.dmg`
3. Move `Cue.app` to `/Applications`
4. Launch Cue
5. Grant **Screen Recording** (and **Accessibility** if prompted for shortcuts) in System Settings
6. Re-launch after granting permissions if macOS asks

### Shell script

```bash
curl -fsSL https://raw.githubusercontent.com/mourato/Cue/main/install.sh | bash
```

### Build from source

```bash
git clone https://github.com/mourato/Cue.git
cd Cue
./scripts/build_and_run.sh
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/mourato/Cue/main/uninstall.sh | bash
```

Or from a clone: `./uninstall.sh`

Removes `/Applications/Cue.app`, app data under `~/Library/Application Support/Cue`, logs, preferences, and resets TCC grants for `com.mourato.cue` (legacy Notinhas/Snapzy paths when present).

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Fullscreen screenshot | `⇧⌘3` |
| Area screenshot | `⇧⌘4` |
| Area screenshot + inline annotate | `⇧⌘7` |
| Scrolling screenshot | `⇧⌘6` |
| OCR text capture | `⇧⌘2` |
| Object cutout capture | `⇧⌘1` |
| Smart element capture | `⌥⇧4` |
| Open Annotate | `⇧⌘A` |
| Show shortcuts list | `⇧⌘K` |

Recording and Video Editor shortcuts apply only when the optional Video module is compiled in and enabled at runtime.

## Automation

Cue registers the `cue://` URL scheme. Toggle integration under **Settings → Advanced → URL Scheme integration**.

| Action | URL |
| --- | --- |
| Area screenshot | `cue://capture/area` |
| Area annotate | `cue://capture/area-annotate` |
| Fullscreen screenshot | `cue://capture/fullscreen` |
| Open Annotate | `cue://open/annotate` |
| Open Settings | `cue://settings` |
| Open Settings tab | `cue://settings?tab=annotate` |

Legacy `notinhas://` and `snapzy://` links are **rejected** — update automations to `cue://`. Full route table: [docs/SHORTCUTS.md](docs/SHORTCUTS.md).

## Development

Start with [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for Xcode setup and `./scripts/build_and_run.sh`.

```bash
open Cue.xcodeproj          # default Cue scheme (Video module off)
./scripts/build_and_run.sh         # Video module on by default (Debug/Release)
./scripts/build_and_run.sh --no-video-module
./scripts/run-tests.sh             # XCTest suite (default scheme)
./scripts/run-tests.sh --skip-visual   # skip on-screen overlay/panel suites
./scripts/run-tests.sh --video-module   # optional Recording/VideoEditor tests
```

Debug builds produce `Cue Debug.app` (`com.mourato.cue.debug`) so TCC grants stay separate from release installs.

Short aliases for common local commands are available through `make`:

```bash
make b      # interactive Debug/Release build + launch
make build  # same as make b
make dmg    # build Release app, ad-hoc sign, and create build/Cue-dryrun.dmg
make test   # run the default XCTest suite
```

`make dmg` uses `scripts/dry-run-release.sh`. Install `create-dmg` to produce the DMG file; without it, the script still validates the Release archive and local code signing.

## Documentation

- [Docs map](docs/README.md)
- [Product references](docs/REFERENCES.md)
- [Migration guide](docs/MIGRATION.md)
- [Project structure](docs/STRUCTURE.md)
- [App lifecycle](docs/APP_LIFECYCLE.md)
- [Capture flows](docs/CAPTURE.md) · [Annotate](docs/ANNOTATE.md) · [Post-capture](docs/POST_CAPTURE.md)
- [Shortcuts & URL scheme](docs/SHORTCUTS.md) · [Preferences](docs/PREFERENCES.md)
- [TOML configuration](docs/CONFIGURATION.md)
- [Build & packaging](docs/BUILD.md) · [Releases](docs/RELEASES.md)
- [Diagnostics](docs/UPDATES.md)

## Security

Cue runs with hardened runtime and minimal entitlements. Network use is limited to explicit uploads to a configured image host — no telemetry, no automatic update checks, and no third-party analytics.

Report vulnerabilities privately via [GitHub Security Advisories](https://github.com/mourato/Cue/security/advisories/new). See [SECURITY.md](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Contributions should follow the current Cue product direction.

## License

BSD 3-Clause License. See [LICENSE](LICENSE).
