# Plan 112: Area selection parity with macshot (fluid rubber-band drag)

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command and perform the manual capture gate. Benchmark behavior
> against [macshot](https://github.com/sw33tLie/macshot) area selection — GPL-3.0;
> reimplement behavior independently; do not copy source or assets.

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MED
- **Category:** perf + UX
- **Planned at**: commit `d8b817a5`, 2026-08-30
- **Finding ID:** `area-selection-macshot-parity`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization

## Why this matters

Screenshot area capture with “freeze area” waited for all-display snapshots before
showing the overlay, while recording/scroll selection felt instant. Drag hot path
also ran full snap resolution, full-monitor renders, display activation, and
synchronous pixel caching on every mouse event.

macshot shows overlays immediately, prepares frozen frames in parallel, and snaps
only the moving corner against a pre-built boundary index during rubber-band drag.

## Scope

**In scope:**

- `CaptureSelectionSnapping.swift` — `snapMovingPoint` for initial drag
- `AreaSelectionWindow.swift` — scoped render, throttled activation, deferred pixel cache
- `CaptureViewModel.swift` — parallel frozen overlay show
- `CaptureSelectionSnappingTests.swift` — moving-corner snap test

**Out of scope:**

- Replacing ScreenCaptureKit frozen capture pipeline wholesale
- Recording/scroll selection entry (already live-overlay)

## Done criteria

- [x] Overlay appears before frozen snapshots finish when freeze is enabled
- [x] Rubber-band drag uses lightweight moving-corner snap
- [x] Drag hot path avoids full-monitor render and unthrottled activation
- [x] Backdrop pixel cache deferred when dim overlay is enabled
- [x] Focused tests and `make validate` pass

## Manual gate

- Preferences → enable freeze area for screenshots
- Trigger area capture; confirm overlay is immediate
- Fast rubber-band drag across a strong UI edge; confirm snap and no stutter vs recording entry
- Multi-monitor: drag spanning displays; confirm backdrops reconcile without jump

## STOP conditions

- Frozen capture completes before snapshots ready without user-visible failure
- Snap regressions on resize handles (post initial drag)
- Any focused gate fails twice after reasonable fix attempt
