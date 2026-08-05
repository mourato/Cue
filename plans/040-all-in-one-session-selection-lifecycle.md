# Plan 040: Make All-In-One start with the last area and hand off selection safely

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 8fbb0455..HEAD -- Notinhas/Features/Capture/AllInOne Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Services/Capture/AreaSelectionWindow.swift Notinhas/Services/Capture/CaptureLastSelectionStore.swift NotinhasTests/Features/Capture NotinhasTests/Services/Capture/CaptureLastSelectionStoreTests.swift docs/CAPTURE.md`
> A mismatch in the current-state excerpts is a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/039-all-in-one-direct-mode-actions.md
- **Category**: bug
- **Planned at**: commit `8fbb0455`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — initial selection, HUD lifetime, and Window handoff share the same controller state.
- **Reviewer required**: yes — this crosses `AreaSelectionController` and must not strand capture locks or callbacks.
- **Rationale**: The code is MainActor-based but has re-entrant cancellation and two selection systems; lifecycle mistakes can block every later capture.
- **Escalate when**: Correctness requires changing `AreaSelectionController` completion semantics or introducing a second global selection singleton.

## Why this matters

Activating All-In-One should immediately reveal the floating HUD and the last
valid selection, so Area/Annotate/Scrolling/OCR/Timer can act on that rectangle
with one click. The current coordinator does restore a stored rectangle, but it
also starts an independent first-drag session when no rectangle exists and can
hand off to a new capture while its own selection/HUD state is still active.
The result can be a missing initial HUD, a blocked capture, or two overlapping
selection sessions.

## Current state

- `AllInOneCaptureCoordinator.start(from:)` installs two HUD windows, loads
  `CaptureLastSelectionStore`, and either calls `beginRefinement(with:)` or
  `startInitialAreaSelection()` (`Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:30–62`).
- `beginRefinement(with:)` assigns `sessionState.currentRect`, positions HUDs,
  and creates `AllInOneSelectionRefinementController` for modes with a
  dimensions bar (`...AllInOneCaptureCoordinator.swift:137–166`).
- `startInitialAreaSelection()` sets the ViewModel blocking flag and calls
  `AreaSelectionController.shared.startSelection`; it then reasserts the HUD
  above the screen-saver-level overlay (`...AllInOneCaptureCoordinator.swift:108–135`).
- `cancel()` sets `isAwaitingInitialSelection = false` before checking whether
  it should cancel the underlying selection (`...AllInOneCaptureCoordinator.swift:64–87`).
  It currently relies on `AreaSelectionController.shared.isPresenting` to catch
  that session.
- `ScreenCaptureViewModel.captureApplication()` starts the existing application
  window-selection path through `startAreaCapture(initialInteractionMode: .applicationWindow)`
  (`Notinhas/Features/Capture/CaptureViewModel.swift:637–639`); the ViewModel
  blocks concurrent area selection when `isAreaSelectionActive` is true
  (`...CaptureViewModel.swift:645–649`).
- `CaptureLastSelectionStore.load(...screens:)` already validates visibility on
  connected displays; reuse it rather than introducing another persistence key.

The load-bearing current shape is:

```swift
// AllInOneCaptureCoordinator.swift:56-61
if let lastRect = CaptureLastSelectionStore.load(userDefaults: .standard, screens: screenFrames) {
  beginRefinement(with: lastRect)
} else {
  startInitialAreaSelection()
}
```

```swift
// AllInOneCaptureCoordinator.swift:192-207
let anchorRect = sessionState?.currentRect ?? defaultAnchorRect()
actionHUD?.show(anchorRect: anchorRect)
modeHUD?.show(anchorRect: modeAnchor)
```

Use the existing lifecycle conventions: `AreaSelectionController` is a
single-fire, MainActor singleton; completions are cleared before invocation;
`ScreenCaptureViewModel` owns normal capture entry points; do not change classic
`⌘⇧4` behavior. Screen coordinates are global AppKit coordinates and must not
be converted to a local display space in the All-In-One coordinator.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `swiftformat Notinhas/Features/Capture/AllInOne Notinhas/Features/Capture/CaptureViewModel.swift NotinhasTests/Features/Capture` | exit 0 |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/CaptureLastSelectionStoreTests` | all selected tests pass using the repository's local signing override |
| Default build | `./scripts/build_and_run.sh --no-video-module` | Debug app builds and launches |

## Suggested executor toolkit

- `.agents/skills/macos-app-engineering/SKILL.md` — panel ownership and MainActor lifecycle.
- `.agents/skills/capture-annotate-export/SKILL.md` — preserve area-to-annotate handoff.
- `.agents/skills/testing-xctest/SKILL.md` — keep WindowServer checks manual and logic tests deterministic.
- `.agents/skills/debugging-diagnostics/SKILL.md` — capture permission and overlay diagnosis if needed.

## Scope

**In scope**:

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift` only if needed for lifecycle state
- `Notinhas/Features/Capture/CaptureViewModel.swift` only for a minimal All-In-One handoff guard
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift`
- `NotinhasTests/Services/Capture/CaptureLastSelectionStoreTests.swift` only if a regression test is needed
- `docs/CAPTURE.md`

**Out of scope**:

- Rewriting `AreaSelectionController` or changing standalone area/window/OCR/scrolling flows.
- `scripts/run-tests.sh` — local signing support is already handled by the
  repository test runner; do not modify it in this feature plan.
- New persistence keys, last-mode memory, screen recording behavior, Quick Access, or post-capture routing.
- Material/rounded-corner changes; plan 041 owns the HUD host.

## Git workflow

- Branch: `advisor/040-all-in-one-session-selection-lifecycle`
- Use an atomic Conventional Commit, e.g. `fix(capture): harden all-in-one selection handoff`.
- Do not push or open a PR unless explicitly instructed.

## Steps

### Step 1: Characterize the session entry states

Define the observable states needed by the coordinator: active with a valid
last rectangle, active while waiting for the first drag, and inactive after
cancel or capture dispatch. Keep the HUD installation before either branch.
When a valid last rectangle exists, assign it to session state and position the
HUD/refinement immediately. When no rectangle exists, show the HUD anchored to
the existing default anchor while the first-drag overlay is prepared; do not
hide the mode buttons behind the selection overlay.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` → state/lifecycle tests pass or the environment reports only the documented signing failure.

### Step 2: Make cancellation re-entrancy-safe before every mode handoff

Snapshot whether the coordinator owns an initial selection before clearing its
flags. On cancellation, tear down refinement callbacks, cancel an underlying
`AreaSelectionController` session exactly once, release
`setAllInOneSelectionBlocking(false)`, close both HUDs, and clear the session.
Do not let the selection completion call back into a partially reinitialized
coordinator. Preserve the existing single-fire semantics of
`AreaSelectionController`; do not add a second completion invocation.

**Verify**: `rg -n "isAwaitingInitialSelection|setAllInOneSelectionBlocking|cancelSelection|onCancel|onRectChanged" Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` → each cleanup path has one owner and no callback is retained after teardown; focused tests still pass.

### Step 3: Implement safe direct handoff for Window and no-rect actions

For Window activation, first finish the All-In-One session cleanup, then call
the existing `viewModel.captureApplication()` entry point. The ViewModel must
see its All-In-One blocking flag cleared before it evaluates its
`isAreaSelectionActive` guard. The application-window overlay must therefore
be the only active selection session.

For Area-like modes activated without a current rectangle, use the existing
no-rect capture entry point or the existing first-drag completion path, but
never call a no-rect ViewModel method while the All-In-One overlay is still
presenting. Preserve the existing fixed Timer scheduler and save the current
rect before dispatch only when a valid rect exists.

**Verify**: `rg -n "captureApplication\\(|captureArea\\(|captureAreaAnnotate\\(|captureScrolling\\(|captureOCR\\(" Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` → every direct call is preceded by a single, explicit session teardown path; no nested `AreaSelectionController.startSelection` is introduced.

### Step 4: Add deterministic lifecycle tests and perform manual overlay checks

Add tests around any extracted pure session transition/dispatch helper. Cover
last-rect startup, no-rect startup, cancellation while the first selection is
open, Window handoff, repeated All-In-One activation cancelling the prior
session, and saving the last rect only for rect-preserving actions.

Manual checks are required because the existing testing skill keeps real
WindowServer overlays out of normal XCTest:

1. Trigger All-In-One with a valid stored rectangle: HUD and refinement are
   visible immediately and the rectangle is on the same screen.
2. Trigger with no stored rectangle: HUD remains visible during the first drag;
   completing the drag enters refinement exactly once.
3. Click Window: the All-In-One HUD disappears, the application-window overlay
   appears, one window selection completes one capture, and the next All-In-One
   invocation is not blocked.
4. Press Escape in each state: no HUD, selection overlay, or blocking flag remains.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/CaptureLastSelectionStoreTests` → all deterministic tests pass through the local-signing-aware runner.

## Test plan

- Reuse `CaptureLastSelectionStoreTests` for visible/off-screen rectangle
  behavior; do not duplicate persistence logic.
- Add one test per transition rather than asserting private window instances.
- Keep real overlay, permission, and WindowServer behavior in the manual gate.
- Run the default build with Video off so the lifecycle does not accidentally
  depend on Recording symbols.

## Done criteria

- [ ] All-In-One shows its HUD immediately and restores a valid last rectangle.
- [ ] First-run selection keeps the HUD visible and completes once.
- [ ] Window mode closes All-In-One before opening application-window capture.
- [ ] Escape and repeated activation leave no stale selection block or callback.
- [ ] Rect-preserving actions save the current rect using the existing store.
- [ ] Focused tests pass and manual overlay checks are recorded by the executor.
- [ ] No standalone capture behavior regresses and no out-of-scope files change.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- `AreaSelectionController` completion behavior must be changed to avoid a
  double callback; stop and report instead of changing that shared contract.
- The ViewModel's `isAreaSelectionActive` guard still blocks Window after the
  All-In-One teardown; stop and report the exact state transition.
- A valid last rectangle cannot be restored without changing its existing key or
  coordinate contract.
- Screen Recording/Accessibility permission behavior requires a product change.

## Maintenance notes

This plan establishes one active selection owner at a time. Future capture modes
must use the same teardown-before-handoff rule. Reviewers should inspect
re-entrancy, cancellation, and coordinate-space handling before visual polish.
Plan 041 may change panel hosting, but must not change these session states.
