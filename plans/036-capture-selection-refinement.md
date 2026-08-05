# Plan 036: Add refinable capture selection (handles, W×H, aspect lock, last rect)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1849b93a..HEAD -- Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Recording/RecordingCoordinator.swift Notinhas/Features/Preferences/Models/PreferencesKeys.swift Notinhas/Services/Capture/AreaSelectionWindow.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift Notinhas/Services/Capture/FloatingToolbar`
> If plan 035 has landed, expect FloatingToolbar paths to exist — that is OK.
> If `RecordingRegionOverlayWindow` / selection excerpts drifted, STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/035-shared-capture-floating-chrome.md
- **Category**: direction
- **Planned at**: commit `1849b93a`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — blocks All-In-One session wiring (037)
- **Reviewer required**: `yes` — selection geometry + overlay interaction is easy to get wrong across displays
- **Rationale**: Touches multi-display selection math and reuses recording/scrolling overlay primitives; needs careful verification, not a fast lane.
- **Escalate when**: Reusing `RecordingRegionOverlayWindow` proves impossible without Video-module linkage, or multi-display refine requires rewriting `AreaSelectionOverlayView` drag/commit model.

## Why this matters

CleanShot All-In-One is not just a mode switcher — it lets the user **refine WHERE** before committing: move/resize with handles, type exact dimensions, lock aspect ratio, and restore the last selection for a quick retake. Classic Notinhas area capture (`AreaSelectionOverlayView`) still commits on mouse-up with read-only size labels and **no** last-rect memory. Recording already persists `recording.lastAreaRect` and scrolling already reuses `RecordingRegionOverlayWindow` for move/resize — this plan builds the screenshot/All-In-One equivalents without changing classic ⌘⇧4 commit-on-mouseup behavior.

## Current state

### Area screenshot selection (commit on mouse-up)

- `AreaSelectionController` / `AreaSelectionOverlayView` in `Notinhas/Services/Capture/AreaSelectionWindow.swift`
- Manual drag → `didSelectRect` / live mouse-up capture path in `ScreenCaptureViewModel`
- Size label is visual only; no numeric editor, no aspect lock, no handles, no last-rect restore for screenshots

### Recording last-rect pattern (reuse policy)

```84:115:Notinhas/Features/Recording/RecordingCoordinator.swift
    private func saveLastAreaRect(_ rect: CGRect) {
      let rectDict: [String: CGFloat] = [
        "x": rect.origin.x, "y": rect.origin.y,
        "width": rect.width, "height": rect.height,
      ]
      UserDefaults.standard.set(rectDict, forKey: PreferencesKeys.recordingLastAreaRect)
    }

    func loadLastAreaRect() -> CGRect? {
      // dictionary decode + isRectVisibleOnScreen validation
    }
```

Key: `PreferencesKeys.recordingLastAreaRect = "recording.lastAreaRect"`.

### Refinement overlay already used by scrolling

`ScrollingCaptureCoordinator` owns `[RecordingRegionOverlayWindow]` and implements `RecordingRegionOverlayDelegate` for move/resize/reselect (`Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift` ~795+, ~1806+).

`RecordingRegionOverlayWindow` (`Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift`) is **always compiled** (no `#if NOTINHAS_VIDEO_MODULE`), with eight `RecordingResizeHandle` positions and cross-display monitors.

### Aspect lock exists elsewhere (Annotate / Video Editor), not capture

e.g. Video Editor custom dimension fields toggle `aspectRatioLocked` — do **not** import Video Editor types into capture. Implement a small pure helper for capture.

### Plan 035 dependency

Shared HUD chrome (`CaptureFloatingHUDWindow`, placement, icon button) must already exist. This plan may add a **dimensions + aspect-lock** SwiftUI strip that sits in that HUD (or a second HUD), but must not invent a third panel host.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Services/Capture Notinhas/Features/Capture NotinhasTests/Services/Capture` (scoped to touched paths) | exit 0 |
| Geometry tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionGeometryTests` | all pass |
| Persistence tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureLastSelectionStoreTests` | all pass |
| Default build | `./scripts/build_and_run.sh --no-video-module` | build succeeds |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md` — product loop; keep classic area path stable
- `.agents/skills/macos-app-engineering/SKILL.md` — overlay windows
- `.agents/skills/data-persistence/SKILL.md` — UserDefaults key patterns
- `.agents/skills/testing-xctest/SKILL.md` — pure geometry tests first
- `.agents/skills/swift-concurrency-expert/SKILL.md` — MainActor UI boundaries

## Scope

**In scope**:

- **Create** `Notinhas/Services/Capture/CaptureSelectionGeometry.swift` — pure resize / aspect-lock / numeric apply helpers
- **Create** `Notinhas/Services/Capture/CaptureLastSelectionStore.swift` — save/load/validate last rect (screenshot / All-In-One key; **not** the recording key)
- **Create** `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` (or `Services/Capture/` if thinner) — session helper that:
  - presents `RecordingRegionOverlayWindow`(s) for an existing global rect
  - publishes rect changes
  - supports Escape cancel hooks via existing patterns
- **Create** SwiftUI dimensions strip: `Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift` — W × H fields + aspect-lock toggle; uses plan-035 chrome constants/buttons where useful
- **Create** tests:
  - `NotinhasTests/Services/Capture/CaptureSelectionGeometryTests.swift`
  - `NotinhasTests/Services/Capture/CaptureLastSelectionStoreTests.swift`
- **Modify** `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` — add `screenshotLastAreaRect` / `allInOneLastAreaRect` (pick **one** key name; recommended: `capture.allInOne.lastAreaRect`) and `capture.allInOne.aspectRatioLocked` (Bool, default false)
- **Modify** Xcode project membership for new files
- **Modify** `plans/README.md` status for 036

**Out of scope**:

- Classic `captureArea()` / ⌘⇧4 mouse-up commit behavior changes
- Wiring global shortcut / menu / mode picker (plan 037)
- Timer mode
- Changing `recording.lastAreaRect` semantics
- Rewriting `AreaSelectionOverlayView` to add handles inside the drag overlay (reuse region overlay instead)
- Full All-In-One capture dispatch

## Product decisions locked for this plan

1. **Last selection** persists for All-In-One / refinable screenshot selection under a **new** preferences key — do not overwrite `recording.lastAreaRect`.
2. **Classic area capture remains commit-on-mouseup** — refinement is for All-In-One (037) consumption.
3. **Aspect lock** applies while resizing via handles and while editing W or H in the dimensions strip.
4. **Minimum size**: clamp width/height to at least `1` pt (match existing annotation/recording minimums where present; if unsure use `1`).
5. **Visibility validation**: restore only if the rect intersects some `NSScreen.screens` frame (same idea as recording).

## Git workflow

- Branch: `advisor/036-capture-selection-refinement`
- Commits: e.g. `feat(capture): add refinable selection geometry and last-rect store`
- Do NOT push/PR unless instructed.

## Steps

### Step 1: Pure geometry helper

Implement `CaptureSelectionGeometry` with at least:

- `resizedRect(original:handle:translation:aspectLocked:aspectRatio:)` → `CGRect`
- `rectBySettingWidth(_:width:aspectLocked:)` / `rectBySettingHeight(...)`
- `normalized(_:minSize:)` ensuring positive non-zero size
- Aspect ratio = `width/height` captured when lock engages (caller passes locked ratio)

Keep functions `nonisolated` / pure (no AppKit) so XCTest is trivial.

**Verify**: write failing tests first or with the helper; run Step 3 command once tests land.

### Step 2: Last-selection store

`CaptureLastSelectionStore` (or enum namespace):

- `save(_ rect: CGRect, userDefaults:)`
- `load(userDefaults:screens:) -> CGRect?` with intersection validation
- Dictionary encode format identical to recording (`x/y/width/height` CGFloats) for consistency

Add `PreferencesKeys` entries.

**Verify**:
```bash
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureLastSelectionStoreTests
```

### Step 3: Geometry tests

Cover:

- corner resize without lock
- corner resize with lock preserves ratio (within ~0.01)
- setting width with lock updates height
- setting height with lock updates width
- reject/clamp degenerate sizes

**Verify**:
```bash
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionGeometryTests
```

### Step 4: Refinement controller using `RecordingRegionOverlayWindow`

Build a small `@MainActor` controller that:

1. Takes an initial `CGRect` in global screen coordinates
2. Creates per-intersecting-screen `RecordingRegionOverlayWindow` instances (copy the creation/update patterns from `ScrollingCaptureCoordinator` — open that file and mirror; do not invent a third overlay)
3. Implements `RecordingRegionOverlayDelegate` to update the published rect
4. On finish move/resize, optionally calls geometry normalization
5. Exposes `onRectChanged: (CGRect) -> Void` and `tearDown()`

Wire aspect lock **into delegate resize callbacks** by adjusting the proposed rect through `CaptureSelectionGeometry` before applying to overlays (if the overlay itself is free-form, post-process each `didResizeRegionTo`).

If aspect-correcting every live resize frame is too noisy, apply lock on `overlayDidFinishResizing` **and** during dimensions-bar edits — but prefer live lock if straightforward.

**Verify**: default scheme builds. Manual check deferred to plan 037; still compile-test here.

### Step 5: Dimensions bar UI

`AllInOneDimensionsBarView`:

- Two compact numeric fields (width, height) showing integer pixel/point values of the current rect
- Aspect-lock toggle button (SF Symbol `lock` / `lock.open` or diagonal arrows — match CleanShot spirit but use existing SF Symbols)
- On commit of a field, update rect via geometry helper and call `onRectChange`
- Persist aspect-lock Bool to the new preferences key when toggled

Host this view later in plan 037’s HUD; for this plan, ensure it compiles and is Preview-friendly. Optionally show it from a tiny debug-only preview — not required.

**Verify**: `swiftformat` + default build.

### Step 6: Dual-scheme build smoke + index

```bash
./scripts/build_and_run.sh --no-video-module
```
Update `plans/README.md` 036 status.

## Test plan

| File | Cases |
|------|-------|
| `CaptureSelectionGeometryTests` | free resize; locked resize; width/height field apply; min size |
| `CaptureLastSelectionStoreTests` | round-trip save/load; reject off-screen rect; empty defaults → nil |

Pattern: pure XCTest like `AreaSelectionModelsTests.swift`.

Do **not** add visual overlay XCTests that flash real screens unless following existing `AreaSelectionOverlayTestCase` patterns — prefer pure logic here (`--skip-visual` friendly).

## Done criteria

- [ ] Geometry + last-selection store exist with passing unit tests
- [ ] Preferences keys added for All-In-One last rect + aspect lock
- [ ] Refinement controller reuses `RecordingRegionOverlayWindow` (no new handle-drawing system)
- [ ] Dimensions bar view compiles and applies geometry helper
- [ ] Classic `captureArea()` path untouched
- [ ] Default (no Video) build succeeds
- [ ] No shortcut/menu/All-In-One mode switcher yet
- [ ] `plans/README.md` updated

## STOP conditions

- Plan 035 shared chrome is missing — stop and report; do not re-implement HUD hosting here.
- `RecordingRegionOverlayWindow` becomes video-gated or unavailable in default scheme (unexpected drift).
- Correct aspect-locked resize appears to require modifying the overlay’s internal hit-testing in unsafe ways — stop and propose a narrower approach (lock only on dimension fields + finish-resize).
- Any change to classic area commit-on-mouseup seems “necessary” — it is not; STOP and rethink.

## Maintenance notes

- Plan 037 will: start All-In-One → restore last rect or wait for first drag → attach refinement controller + dimensions bar → on Capture, save last rect and dispatch mode.
- Reviewers: ensure recording last-rect key is never reused; multi-display restore must not crash with zero screens in tests (inject screens list).
- Follow-up (explicitly deferred): offering last-selection restore inside classic ⌘⇧4.
