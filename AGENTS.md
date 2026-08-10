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
`swiftui-accessibility-audit`, `apple-design`, `code-quality`,
`delivery-workflow`, `macos-app-engineering`, and `swift-conventions`. When one of these
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
- `./scripts/build_and_run.sh` — canonical isolated debug build and launch.
- `./scripts/launch.sh` — legacy wrapper; use `build_and_run.sh` for options.
- `./scripts/run-tests.sh [--video-module]` — quiet XCTest suite by default:
  no on-screen overlay/panel suites and no app sounds. Use `--with-visual`
  only for an intentional UI integration run; use `NOTINHAS_ALLOW_TEST_SOUNDS=1`
  only for an intentional audio integration run.
- `./scripts/plan-preflight.sh plans/NNN-*.md --scope <path>` — read-only plan
  preflight; use `--new-file <path>` when needed.
- `./scripts/verify-local.sh --base <ref> [--plan-only|--execute] [--strict]`
  — changed-surface verification through `scripts/verification-map.tsv`.
- `make format-check`, `make lint-changed`, and `make agent-check` — focused
  local gates; use the full variants before merge.

Screen Recording and Accessibility permissions are required for affected
manual checks. Test capture, annotation, clipboard output, and permission
prompts on macOS whenever they change.

### Optional Video Module

Recording and Video Editor compile only with `NOTINHAS_VIDEO_MODULE` or
`--video-module` using **Notinhas Video** / **Debug+Video**. The default
**Notinhas** scheme keeps the module off. Enable it at runtime under
**Preferences → Advanced**; capture → annotate → export does not require it.

### Test isolation

Agents must use the default quiet test command. The XCTest host does not start
the interactive app, visual overlay/panel suites are opt-in, and app sound
playback is suppressed during tests. Keep
`NOTINHAS_ALLOW_SCREEN_CAPTURE_IN_TESTS=1`,
`NOTINHAS_ALLOW_TEST_SOUNDS=1`, and
`NOTINHAS_RUN_MICROPHONE_INTEGRATION=1` unset unless the task explicitly
requires that integration surface.

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

`origin` is `mourato/Notinhas`; `upstream` is `duongductrong/Snapzy`. For
upstream work, fetch it first, integrate focused changes without deleting
Notinhas modules, and validate the affected flow afterward. UI changes include
screenshots or a short recording in the handoff.

## Completion

A task is complete when:

- The changed surface, risk/lane, and `reuse → extend → create` decision are recorded.
- Behavior changes pass `make test` and `make agent-check`; guidance changes pass `make guidance-check`.
- Capture, TCC, WindowServer, or permission changes include the required manual check; visual changes include screenshots or a recording.
- The handoff records commands and results, assumptions, manual gates, and known baseline failures.

## Distribution

Releases are manual GitHub Releases with `Notinhas-v<version>.dmg`. No Sparkle
appcast or in-app update channel; no Homebrew cask or Discord release bot (see
ADR 070). Optional `install.sh` / `uninstall.sh` remain convenience helpers. User migration notes live
in `docs/MIGRATION.md`.
