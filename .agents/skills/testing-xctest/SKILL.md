---
name: testing-xctest
description: XCTest guidance for Cue — geometry, composer, annotate state, ImgBB parsing, and CueTests layout.
---

# Testing (XCTest)

Use when adding or changing automated tests under `CueTests/`.

## When Adding Tests

- Prefer pure logic first: `CueNoteGeometry`, `CueNotesComposer`, `CueNoteRenderer`, `CueAnnotateState` undo/move, ImgBB response parsing.
- Keep UI/AppKit lifecycle (status item, capture overlay, full annotate window) as manual checks unless a seam is introduced.
- Use fakes for `UserDefaults` or network boundaries when testing configuration/upload services.
- Mark UI-touching tests `@MainActor` when they construct views or main-actor types.

## Structure

- Mirror source names: `CueTests/Features/Cue/CueNoteGeometryTests.swift`, etc.
- One behavior per test name; assert observable outcomes, not private implementation details.

## Commands

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh --skip-visual
./scripts/run-tests.sh --with-visual
./scripts/run-tests.sh -only-testing:CueTests/CueNoteGeometryTests
./scripts/verify-local.sh --base main --plan-only
./scripts/verify-local.sh --base main --plan-only --strict
./scripts/verify-local.sh --base main --execute
```

`./scripts/verify-local.sh` maps changed paths through `scripts/verification-map.tsv`.
Unknown application paths and rows marked `manual-required` must stay visible in the
report; `--strict` fails instead of treating them as fully verified. The command reuses
`./scripts/run-tests.sh` for XCTest execution and does not replace full-suite or manual
UI/TCC/WindowServer gates when overlays, permissions, or unmapped surfaces change.

`./scripts/run-tests.sh` is quiet by default: it skips host suites that flash
real area-selection overlays, Quick Access panels, or status-bar activation
onto the display, and app sound playback is suppressed under XCTest.
`--skip-visual` / `CUE_SKIP_VISUAL_TESTS=1` keeps that behavior explicit;
`--with-visual` opts into the on-screen suites for an intentional UI
integration run. Keep `CUE_ALLOW_TEST_SOUNDS=1` unset except for an
intentional audio integration run.

Splash/onboarding during tests is **not** a skip-list issue: `AppLaunchPolicy`
must keep the interactive host off under XCTest. Do not “fix” onboarding by
skipping unrelated suites — harden launch detection instead.

Area-selection magnifier/luma backdrop grabs use `AreaSelectionBackdropCapturing`.
Under XCTest the default is `SyntheticAreaSelectionBackdropCapturer` (no Screen
Recording TCC). Opt into the live `CGWindowListCreateImage` path with
`CUE_ALLOW_SCREEN_CAPTURE_IN_TESTS=1` only for intentional integration checks.

## Related

- Delivery gate → `delivery-workflow`
- Domain behavior under test → `capture-annotate-export` (when present)
