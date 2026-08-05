# Plan 039: Make every All-In-One mode button execute its capture

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 8fbb0455..HEAD -- Notinhas/Features/Capture/AllInOne NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings docs/CAPTURE.md`
> If any in-scope file changed, compare the excerpts below with the live code;
> a mismatch is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/038-refine-all-in-one-timer.md (reconcile its pending manual validation before starting)
- **Category**: bug
- **Planned at**: commit `8fbb0455`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — toolbar contract and coordinator dispatch must change atomically.
- **Reviewer required**: yes — this changes every All-In-One capture entry and must preserve Video-off behavior.
- **Rationale**: The change is localized but affects area, window, fullscreen, OCR, scrolling, annotate, timer, and optional recording dispatch.
- **Escalate when**: A new capture primitive, a change to classic shortcuts, or a rewrite of `AreaSelectionController` appears necessary.

## Why this matters

The current All-In-One UI treats mode buttons as selectors and exposes a second
primary `Capture` button. The requested contract is action-oriented: pressing
Area captures the visible refined rectangle, pressing Screen captures the full
screen, pressing Window starts window selection, and each other mode owns its
own dispatch. Removing the extra confirmation step makes the HUD predictable
and avoids a selected mode that has not yet done anything.

## Current state

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift` — mode
  state and callbacks; `selectMode(_:)` only updates `selectedMode` and calls
  `onModeSelected` (lines 27–31), while `confirmCapture()` is a separate path
  (lines 38–40).
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift` — each
  mode button calls `session.selectMode(mode)` (lines 15–20).
- `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift` — the
  only capture trigger is a prominent `Capture` button (lines 23–31).
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` — the
  private `confirmCapture()` method owns the mode switch (lines 230–293).
- Existing `ScreenCaptureViewModel` entry points already accept a refined rect:
  `captureArea(at:)`, `captureAreaAnnotate(at:)`, `captureOCR(at:)`, and
  `captureScrolling(at:)` in `Notinhas/Features/Capture/CaptureViewModel.swift`
  (lines 565–634). `captureFullscreen()` and `captureApplication()` remain the
  existing fullscreen and application-window flows.

The load-bearing current shape is:

```swift
// AllInOneCaptureToolbarView.swift:15-20
ForEach(session.availableModes) { mode in
  AllInOneCaptureToolbarModeButton(
    mode: mode,
    isSelected: session.selectedMode == mode,
    action: { session.selectMode(mode) }
  )
}
```

```swift
// AllInOneActionToolbarView.swift:23-31
Button(action: session.confirmCapture) {
  Text(L10n.AllInOne.captureButton)
}
.buttonStyle(.borderedProminent)
```

The existing coordinator already has the desired destinations, but only behind
the confirmation callback:

```swift
// AllInOneCaptureCoordinator.swift:258-285
switch mode {
case .area: viewModel.captureArea(at: rect) ...
case .fullscreen: viewModel.captureFullscreen()
case .window: viewModel.captureApplication()
case .annotate: viewModel.captureAreaAnnotate(at: rect) ...
case .scrolling: viewModel.captureScrolling(at: rect) ...
case .ocr: viewModel.captureOCR(at: rect) ...
case .timer: break
}
```

Follow the repository conventions: Swift 5.9, `@MainActor` for UI/session
state, two-space SwiftFormat, localized strings through `L10n`, and no direct
Video-gated symbol in the default build. The capture product boundary remains
area → annotate → export; do not add Smart Element or Object Cutout to this
strip.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Features/Capture/AllInOne Notinhas/Shared/Localization/L10n.swift NotinhasTests/Features/Capture` | exit 0 |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | all selected tests pass using the repository's local signing override |
| Default build smoke | `./scripts/build_and_run.sh --no-video-module` | default scheme builds and launches |
| Video compile smoke | `./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests` | Recording remains conditional and tests pass |

## Suggested executor toolkit

- `.agents/skills/macos-app-engineering/SKILL.md` — AppKit/SwiftUI capture ownership.
- `.agents/skills/capture-annotate-export/SKILL.md` — preserve the visual-handoff loop.
- `.agents/skills/localization/SKILL.md` — remove obsolete Capture-button copy safely.
- `.agents/skills/testing-xctest/SKILL.md` — pure routing tests and MainActor rules.

## Scope

**In scope**:

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `Notinhas/Shared/Localization/L10n.swift`
- `Notinhas/Resources/Localization/Features/Capture.xcstrings`
- `NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift`
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift`
- `docs/CAPTURE.md`

**Out of scope**:

- `ScreenCaptureViewModel` capture implementation, except a minimal adapter if
  a compile-time seam is proven necessary.
- `scripts/run-tests.sh` — local signing support is already handled by the
  repository test runner; do not duplicate or revert that override.
- Classic `⌘⇧4`, standalone menu items, global shortcuts, deeplinks, capture
  persistence keys, Quick Access, and the shared HUD host.
- Any new capture mode or configurable timer behavior.

## Git workflow

- Branch: `advisor/039-all-in-one-direct-mode-actions`
- Use an atomic Conventional Commit, e.g. `fix(capture): make all-in-one modes actionable`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Replace selection-only state with an explicit mode activation callback

Add a clearly named activation operation to `AllInOneCaptureSessionState` (for
example `activateMode(_:)` and `onModeActivated`) and make each toolbar mode
button invoke it. It may continue updating `selectedMode` for accessibility
and transient styling, but the semantic operation must be “activate this
capture”, not “select and wait for Capture”. Keep `updateRect` and the
dimensions/aspect-lock callback unchanged.

Add a small, pure, `Equatable` command/routing representation if needed so the
mode-to-operation matrix can be tested without constructing real capture
overlays. The matrix must be explicit:

| Mode | Action |
|---|---|
| Area | capture current rect; if no rect exists, enter the existing area-selection fallback |
| Fullscreen | `captureFullscreen()` |
| Window | close All-In-One, then `captureApplication()` so the existing window-selection overlay opens |
| Annotate | `captureAreaAnnotate(at:)` with current rect, or existing no-rect fallback |
| Scrolling | `captureScrolling(at:)` with current rect, or existing fallback |
| Timer | existing fixed three-second delayed area capture |
| OCR | `captureOCR(at:)` with current rect, or existing fallback |
| Recording | existing optional Video-module entry, only when available |

**Verify**: `swiftformat Notinhas/Features/Capture/AllInOne NotinhasTests/Features/Capture` → exit 0; `rg -n "session\\.selectMode|session\\.confirmCapture|captureButton" Notinhas/Features/Capture/AllInOne` shows no runtime action path using the old contract.

### Step 2: Remove the standalone Capture action and route mode activation

Remove the prominent `Capture` button from `AllInOneActionToolbarView`. Keep
the dimensions editor and aspect-lock control as editing controls only. Change
the coordinator callback wiring so mode activation reaches one coordinator
entry point that saves the current refined rectangle when appropriate, tears
down the All-In-One HUD/refinement, and dispatches the command exactly once.

Do not call `captureApplication()` before the All-In-One panels and selection
controller have been cleaned up; otherwise the old session can replace or
cancel the new window-selection session. Timer must preserve its existing
cancellation-aware scheduler and must not reintroduce a Capture button.

Remove or replace obsolete `captureButton` and capture-button accessibility
strings only when `rg` confirms there are no remaining callers. Keep the mode
accessibility labels action-oriented (e.g. “Capture area”, “Capture full
screen”, “Select a window to capture”), and localize all new wording.

**Verify**: `rg -n "captureButton|confirmCapture|onConfirmCapture" Notinhas NotinhasTests docs` → no active All-In-One references remain; focused tests pass through `scripts/run-tests.sh`.

### Step 3: Add the complete dispatch matrix tests

Extend `AllInOneCaptureModeTests` and/or `AllInOneCaptureCoordinatorTests` with
one observable assertion per mode. Prefer testing the pure command mapping and
the session activation callback rather than private implementation details.
Cover Video-off exclusion of Recording, Video-on ordering, rect propagation
for Area/Annotate/Scrolling/OCR/Timer, fullscreen ignoring the rect, Window
using the application-window command, and the no-rect fallback contract.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` → all new routing tests pass.

### Step 4: Update the capture documentation

Change `docs/CAPTURE.md` so it states that the mode buttons are the capture
actions and that the dimensions bar only edits the current rectangle. Document
the Window behavior and the fact that there is no extra Capture confirmation.
Keep the existing Timer, Video-module, classic shortcut, and dedicated-mode
boundaries.

**Verify**: `rg -n -i "Capture button|Capture.*button|select.*mode|mode.*button|All-In-One" docs/CAPTURE.md` → wording describes direct mode actions and contains no claim that a second Capture button is required.

## Test plan

- State test: activating every available mode invokes `onModeActivated` with
  the same mode and keeps the current rectangle unchanged.
- Routing test: each mode maps to exactly one command; fullscreen and Window
  do not incorrectly reuse the area rect.
- Regression test: Timer still uses the existing delayed-area command and
  Recording is absent from Video-off mode availability.
- Manual test: with a stored selection visible, click Area, Fullscreen, Window,
  Annotate, Scrolling, Timer, and OCR one at a time; each button closes the HUD
  and starts its own capture path without a second click.

## Done criteria

- [ ] No All-In-One runtime path requires `L10n.AllInOne.captureButton`.
- [ ] Every available mode button invokes a mode-specific capture action.
- [ ] The dimensions/aspect-lock controls never start a capture by themselves.
- [ ] Window activation opens the existing application-window selection flow.
- [ ] Focused routing tests pass; default and Video-on builds compile.
- [ ] `docs/CAPTURE.md` documents the direct-action contract.
- [ ] No files outside the scope list are modified.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- The existing Timer scheduler or Video-off compilation requires adding a new
  global capture API outside this plan.
- A direct Window activation cannot cleanly cancel the All-In-One session before
  `captureApplication()` starts; stop rather than nesting two selection sessions.
- The code at the cited lines no longer matches the excerpts.
- Any focused verification failure persists after one reasonable fix attempt.

## Maintenance notes

Future modes must be added to the explicit routing matrix and its tests; do not
silently fall back to a generic Capture button. Reviewers should check that
mode activation is single-fire, that the refined rect is passed in screen
coordinates, and that optional Recording remains compile- and runtime-gated.
The initial no-last-selection lifecycle and the floating-material host are
handled by plans 040 and 041 respectively.
