# Project workflow facts

Read before implementation, validation, or delivery. Paths below name repository-root facts; links resolve from this document. Shared project conventions (UI contract, reference apps, lint baseline, `validate-lane`) live in `${AGENT_CONFIG_HOME:-$HOME/.agents}/core/policies/project-context.md`; delivery order follows the global `core/policies/worktrees.md`.

## Product Intent

Cue is a tailored macOS visual-handoff tool for a product designer. It
turns a screenshot into an unambiguous brief for developers and AI coding
agents: capture an area, place numbered pins or rectangles, add concise notes,
and copy the annotated result. Prioritize speed, precise visual reference, and
clipboard-ready output. Do not add broad recording, cloud, or generic markup
features unless they directly support that workflow.

Do **not** reintroduce removed upstream integrations: Sparkle auto-updates,
About/Check for Updates UI, Report a Problem flows, `snapzy://` or `notinhas://`
URL aliases, or a public support endpoint. Inherited Snapzy surfaces retained vs
removed channels are recorded in `docs/adr/070-retain-inherited-snapzy-surfaces.md`.

## Project Structure

This repository is a fork of [Snapzy](https://github.com/duongductrong/Snapzy).
`Cue/` contains the app: `App/` starts the menu-bar application,
`Features/` owns user-facing flows, `Services/` holds platform and persistence
code, and `Resources/` contains assets and localization. Tests mirror the app
under `CueTests/`; `docs/` and `scripts/` document and automate the
project.

Cue-specific behavior lives in `Cue/Features/Cue/`; small protocols or
adapters go in `Services/` only to cross a platform boundary. Keep integration
points into upstream capture and annotation flows thin.

## Skills

`project-standards` owns guidance governance (where docs live, skill template, anti-drift).
`capture-annotate-export` owns the visual handoff loop (capture → pins/notes → clipboard export).
`plan-execute-review` owns execution of plans and its review pipeline.
Keep Cue behavior guidance aligned with Product Intent above; do not reintroduce
unrelated product skills from other apps.

## Build, Test, and Run

- `open Cue.xcodeproj` — develop and run in Xcode (`⌘R`).
- `./scripts/build_and_run.sh` — canonical isolated debug build and launch.
- `./scripts/launch.sh` — legacy wrapper; use `build_and_run.sh` for options.
- `./scripts/run-tests.sh [--video-module]` — quiet XCTest suite by default:
  no on-screen overlay/panel suites and no app sounds. Use `--with-visual`
  only for an intentional UI integration run; use `CUE_ALLOW_TEST_SOUNDS=1`
  only for an intentional audio integration run.
- `./scripts/plan-preflight.sh plans/NNN-*.md --scope <path>` — read-only plan
  preflight; use `--new-file <path>` when needed.
- `./scripts/verify-local.sh --base <ref> [--plan-only|--execute] [--strict]`
  — changed-surface verification through `scripts/verification-map.tsv`.
- `make build` and `make test` are the full default gate; the optional module
  is covered by `make build-video` and `make test-video` using the `Cue Video`
  / `Debug+Video` configuration.
- `make validate` is the canonical focused local gate and delegates to
  `make agent-check`; use the full variants before merge.
- `make validate-lane` wraps `make validate`; `VALIDATE_BASE` defaults to merge-base `origin/main HEAD`. Watch ignored `build/verification/` and remove its `build/` parent only if this run created it.

Screen Recording and Accessibility permissions are required for affected
manual checks. Test capture, annotation, clipboard output, and permission
prompts on macOS whenever they change.

### Optional Video Module

Recording and Video Editor compile with `CUE_VIDEO_MODULE` using
**Cue Video** / **Debug+Video**. `./scripts/build_and_run.sh` includes the
module by default (`--no-video-module` or `ENABLE_VIDEO_MODULE=0` to opt out).
The plain **Cue** Xcode scheme keeps the module off. Enable it at runtime
under **Preferences → Advanced**; capture → annotate → export does not require
it.

### Test isolation

Agents must use the default quiet test command. The XCTest host does not start
the interactive app, visual overlay/panel suites are opt-in, and app sound
playback is suppressed during tests. Keep
`CUE_ALLOW_SCREEN_CAPTURE_IN_TESTS=1`,
`CUE_ALLOW_TEST_SOUNDS=1`, and
`CUE_RUN_MICROPHONE_INTEGRATION=1` unset unless the task explicitly
requires that integration surface.

## Code and Tests

Move capture, file, and image processing off the main actor through value snapshots or focused adapters.
Add XCTest cases in the matching `CueTests/` area, named by behavior—for
example, `testPinNoteExportKeepsMarkerOrder()`.
Formatter/lint commands are `make format-check`, `make lint`, and
`make lint-changed`; use `make format-fix` or `make lint-fix` only as
explicit autofix commands, and verification must fail closed.
`.swiftlint-baseline.json` records existing project debt when present.

Remaining `Snapzy` / `snapzy` and `Notinhas` / `notinhas` strings in source are
**legacy compatibility** (readers, migration, or rejection tests) — do not
expand them into active product branding.

## Fork and Contribution Workflow

`origin` is `mourato/Cue`; `upstream` is `duongductrong/Snapzy`. For
upstream work, fetch it first, integrate focused changes without deleting
Cue modules, and validate the affected flow afterward. UI changes include
screenshots or a short recording in the handoff.

## Completion

- Behavior changes pass `make test` and `make validate`; guidance changes pass `make guidance-check`.
- Capture, TCC, WindowServer, or permission changes include the required manual check; visual changes include screenshots or a recording.

## Distribution

Releases are manual GitHub Releases with `Cue-v<version>.dmg`. No Sparkle
appcast or in-app update channel; no Homebrew cask or Discord release bot (see
ADR 070). Optional `install.sh` / `uninstall.sh` remain convenience helpers. User migration notes live
in `docs/MIGRATION.md`.
