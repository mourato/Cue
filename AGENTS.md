# Repository Guidelines

## Product Intent

Notinhas is a tailored macOS visual-handoff tool for a product designer. It
turns a screenshot into an unambiguous brief for developers and AI coding
agents: capture an area, place numbered pins or rectangles, add concise notes,
and copy the annotated result. Prioritize speed, precise visual reference, and
clipboard-ready output. Do not add broad recording, cloud, or generic markup
features unless they directly support that workflow.

Do **not** reintroduce removed upstream integrations: Sparkle auto-updates,
About/Check for Updates UI, Report a Problem flows, `snapzy://` URL aliases, or
a public support endpoint. Inherited Snapzy surfaces retained vs removed channels
are recorded in `docs/adr/070-retain-inherited-snapzy-surfaces.md`.

## Project Structure

This repository is a fork of [Snapzy](https://github.com/duongductrong/Snapzy).
`Notinhas/` contains the app: `App/` starts the menu-bar application,
`Features/` owns user-facing flows, `Services/` holds platform and persistence
code, and `Resources/` contains assets and localization. Tests mirror the app
under `NotinhasTests/`; `docs/` and `scripts/` document and automate the
project.

Keep Notinhas-specific behavior in `Notinhas/Features/Notinhas/`, with focused
models and views colocated there. Introduce small protocols or adapters in
`Services/` only where a feature needs to cross a platform boundary. Keep
integration points into the existing capture and annotation flows thin; avoid
renaming, moving, or rewriting upstream code merely to match a new design.

## Skills

Global macOS capabilities provide the portable rules for
`accessibility-audit`, `apple-design`, `code-quality`, `delivery-workflow`,
`macos-app-engineering`, `menubar`, and `swift-conventions`. When one of these
global skills is active, load its matching `.agents/overlays/<skill-name>.md`
companion after the global skill; the overlay supplies Notinhas facts and must
not weaken global safety, privacy, or repository-integrity rules. Do not create
same-name local skill copies.

Project-specific agent skills remain under `.agents/skills/`. Choose the
narrowest relevant skill from its description; use `project-standards` for
guidance governance and routing policy.
`project-standards` owns guidance governance (where docs live, skill template, anti-drift).
`capture-annotate-export` owns the visual handoff loop (capture → pins/notes → clipboard export).
`plan-execute-review` owns execution of plans and its review pipeline.
Keep Notinhas behavior guidance aligned with Product Intent above; do not reintroduce
unrelated product skills from other apps.

## Build, Test, and Run

- `open Notinhas.xcodeproj` — develop and run in Xcode (`⌘R`).
- `./scripts/build_and_run.sh` — canonical build and launch for the isolated debug app.
- `./scripts/launch.sh` — legacy compatibility wrapper that forwards to
  `./scripts/build_and_run.sh --logs`; prefer the canonical command for all options.
- `./scripts/run-tests.sh` — run the XCTest suite with results in `build/`
  (default **Notinhas** scheme). Use `--video-module` (or `ENABLE_VIDEO_MODULE=1`)
  for Recording/VideoEditor XCTests via **Notinhas Video** / **Debug+Video**.
  Use `--skip-visual` (or `NOTINHAS_SKIP_VISUAL_TESTS=1`) locally to skip suites
  that flash real capture overlays / Quick Access panels on screen; still run the
  full suite (or those suites alone) when changing those areas.
- `./scripts/plan-preflight.sh plans/NNN-*.md --scope <path> [--new-file <path>]`
  — read-only preflight for implementation plans (dependency, scope, drift, and
  worktree checks). Write JSON evidence under `build/plan-preflight/` when
  needed. A passing preflight does not replace code review or manual
  capture/TCC/WindowServer validation.
- `./scripts/verify-local.sh --base <ref> [--plan-only] [--execute] [--strict]`
  — changed-surface local verification planner/runner. Maps touched paths to
  XCTest selectors, shell checks, and manual gates via
  `scripts/verification-map.tsv`; writes reports under `build/verification/`.
  Default is `--plan-only`. Use `--strict` to fail on unmapped paths; in
  plan-only mode, manual-required paths remain visible handoff gates without
  making the mapping check fail. Strict execute mode still fails until those
  manual gates are completed. This narrows deterministic feedback; it does
  not replace the full test suite or manual gates when the surface requires
  them.
- `make format-check` / `make format-fix` — validate or apply the SwiftFormat
  6.2 four-space policy from `.swiftformat` (120-column maximum).
- `make lint` / `make lint-changed` / `make lint-fix` — fail-closed SwiftLint
  checks for owned app/tests or the changed Swift surface.
- `make agent-check` — run format, lint, and strict `verify-local` planning.

Screen Recording and Accessibility permissions are required for affected
manual checks. Test capture, annotation, clipboard output, and permission
prompts on macOS whenever they change.

### Optional Video Module

Recording and Video Editor are optional. They compile only when
`NOTINHAS_VIDEO_MODULE` is set (scheme **Notinhas Video** with **Debug+Video** /
**Release+Video**). The default **Notinhas** scheme keeps the module off.
`./scripts/build_and_run.sh` prompts interactively or accepts `--video-module`,
`--no-video-module`, or `ENABLE_VIDEO_MODULE=1|0`. At runtime,
`videoModule.enabled` defaults to off; when the module is compiled in, turn it
on under **Preferences → Advanced** (`VideoModuleAvailability`). Notinhas
capture → annotate → export does not require the Video module.
`./scripts/run-tests.sh` uses the default **Notinhas** scheme (module off). For
Recording/VideoEditor XCTests: `./scripts/run-tests.sh --video-module`.

## Code and Tests

Use Swift 6.2 conventions: `UpperCamelCase` types, `lowerCamelCase` members,
descriptive file names, and `// MARK:` in large types. The project uses
complete strict concurrency with nonisolated-by-default targets; keep SwiftUI,
AppKit, and lifecycle entry points explicitly `@MainActor`, and move capture,
file, and image processing off it through value snapshots or focused adapters.
Add XCTest cases in the matching `NotinhasTests/` area, named by behavior—for
example, `testPinNoteExportKeepsMarkerOrder()`.

Remaining `Snapzy` / `snapzy` strings in source are **legacy compatibility**
(readers, migration, or rejection tests) — do not expand them into active product branding.

## Fork and Contribution Workflow

`origin` is `mourato/Notinhas`; `upstream` is `duongductrong/Snapzy`. Before
starting substantial work, run `git fetch upstream`. Bring upstream changes in
as focused merge or rebase commits, resolve conflicts without deleting
Notinhas modules, and validate the affected flow afterward. Keep commits
atomic and Conventional (`feat: add numbered callouts`, `fix: copy annotation
to clipboard`). Pull requests state the user outcome, validation performed,
upstream conflicts or compatibility risks, and include screenshots or a short
recording for UI changes.

## Distribution

Releases are manual GitHub Releases with `Notinhas-v<version>.dmg`. No Sparkle
appcast or in-app update channel; no Homebrew cask or Discord release bot (see
ADR 070). Optional `install.sh` / `uninstall.sh` remain convenience helpers. User migration notes live
in `docs/MIGRATION.md`.
