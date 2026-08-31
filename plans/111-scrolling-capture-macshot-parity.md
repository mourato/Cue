# Plan 111: Scroll capture parity with macshot (smoothness + preview UX)

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command and perform the manual capture gate. Benchmark behavior
> against [macshot](https://github.com/sw33tLie/macshot) scroll capture — GPL-3.0;
> reimplement behavior independently; do not copy source or assets.
>
> **Drift check (run first):**
> `git diff --stat HEAD -- Notinhas/Services/Capture/ScrollingCapture/ docs/SCROLLING_CAPTURE.md NotinhasTests/Services/Capture/`

## Status

- **Priority:** P1
- **Effort:** L (multi-phase; execute in order)
- **Risk:** MED
- **Depends on:** Plans 100–103 (DONE)
- **Category:** perf + UX
- **Planned at**: commit `0992174`, 2026-08-30
- **Finding ID:** `scrolling-capture-macshot-parity`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization; no push is authorized by this plan

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** no; phases touch the same coordinator, preview window, and selection entry
- **Reviewer required:** yes; stitch safety and final-image contract must not regress
- **Rationale:** macshot achieves perceived smoothness via capture-during-scroll and immediate merged preview; Notinhas currently waits for scroll settle before most commits.
- **Escalate when:** parity requires replacing ScreenCaptureKit with legacy APIs wholesale, removing safety tiers, or copying macshot code.

## Why this matters

Comparative audit (2026-08-30) against macshot `ScrollCaptureController` and
`ScrollCapturePreviewPanel` showed the main perceptual gap is **commit cadence**
and **preview presentation**, not raw stitch accuracy:

- macshot stitches **during** active scroll (~150 ms cadence) via
  `grabAndProcess()`; Notinhas gates most commits on scroll settle (50–280 ms)
  plus minimum spacing (60–90 ms).
- macshot preview = full merged image → `NSImageView` immediately after each
  strip; Notinhas shows throttled live viewport + downscaled stitched rail with
  truth badges that expose lag (`liveAhead`, `Syncing`).
- macshot auto-starts on region confirm; Notinhas requires an explicit **Start**
  step.

Plans 100–103 reduced stitch/preview cost but did not change the settle-first
commit model that causes preview to trail continuous scrolling.

## Reference behavior (macshot)

| Behavior | macshot | Notinhas (HEAD) |
| --- | --- | --- |
| Commit during scroll | Yes (`manualCaptureInterval` 150 ms) | Mostly no (settle + spacing) |
| Commit after idle | Yes (`settlementInterval` 250 ms + TIFF settle) | Yes (`scrollIdleTimeout` 280 ms) |
| Preview surface | AppKit `NSImageView`, bottom-anchored, grows up | SwiftUI rail, center-anchored, capped height |
| Preview content | Always full merged | Stitched thumbnail + throttled live |
| Session start | On selection confirm | Ready → Start |
| Mouse hover suppression | CGEvent tap blocks `mouseMoved` | None |
| Capture API | `CGWindowListCreateImage` on demand | `SCStream` + still fallback |
| Alignment | Vision-only | Guided pixel + Vision recovery |

## Commands you will need

| Purpose | Command | Expected result |
| --- | --- | --- |
| Streaming policy tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureWindowSharingTests` | exit 0 |
| Commit scheduler tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureCommitSchedulerTests` | exit 0 |
| Stitcher regression | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` | exit 0 |
| Format | `make format-check` | exit 0 |
| Changed Swift lint | `make lint-changed` | exit 0 |
| Repository agent gate | `make agent-check` | exit 0, or report exact baseline failure |

## Scope

**In scope (by phase):**

- Phase 1 — `ScrollingCaptureCoordinator.swift`, focused coordinator policy tests,
  `docs/SCROLLING_CAPTURE.md` scroll-detection section
- Phase 2 — `ScrollingCapturePreviewWindow.swift`, `ScrollingCapturePreviewView.swift`,
  optional AppKit preview path, preview layout tests
- Phase 3 — `AreaSelectionController` / scrolling capture entry (auto-start),
  `CaptureViewModel` if needed, localization for removed Start step
- Phase 4 — mouse-move suppression during capture session (Accessibility-gated)
- Phase 5 — optional hybrid on-demand commit capture adapter (evaluate before coding)

**Out of scope:**

- Copying macshot source (GPL-3.0)
- Removing stitch safety tiers or duplicate-boundary rejection
- Replacing ScreenCaptureKit entirely without a measured hybrid design
- Removing truth badges entirely (may simplify visibility rules in Phase 2)
- Horizontal scroll capture (both apps are vertical-first today)

## Phase 1 — During-scroll streaming commits (P0)

**Status:** implemented on branch `scrolling-capture-streaming-commits`.

### Goal

While the user is actively scrolling, schedule stitch commits at a fixed
interval (~150 ms) when pending motion exists, **without** waiting for scroll
settle. Preserve the existing settle + idle flush for the final visible strip.

### Current state

- `startLiveRefreshLoopIfNeeded` polls every 50 ms but `shouldRefresh` requires
  `hasEnoughSettledMotion` (`idleDuration >= scrollSettleDelay`) unless forced
  refresh distance (28–42 pt) is exceeded.
- During continuous scrolling `idleDuration` stays near zero, so commits stall
  until large forced distance accumulates.

### Steps

1. Add testable policy helper `shouldScheduleStreamingCommit(...)` on
   `ScrollingCaptureCoordinator` with deterministic XCTest coverage (mirror
   `shouldPublishLivePreviewFrame`).
2. Add `duringScrollCommitInterval` (~0.15 s) and treat
   `idleDuration < scrollIdleTimeout` as active scrolling.
3. Update the live refresh loop: `shouldRefresh` is true when
   `shouldScheduleStreamingCommit` **or** existing settled/forced/idle paths fire.
4. Record streaming commits in session metrics (new counter or refresh reason tag).
5. Update `docs/SCROLLING_CAPTURE.md` threshold table with the streaming path.

**Verify:** focused window + scheduler + stitcher tests; manual capture on a long
web page — preview stitched rail should advance during continuous scroll, not
only after pauses.

## Phase 2 — Immediate merged preview + lighter panel (P0 UX)

**Status:** implemented on branch `scrolling-capture-streaming-commits`.

### Goal

Match macshot preview feel: show the stitched result as soon as pixels append;
reduce MainActor/SwiftUI layout churn; bottom-anchor the rail and grow upward.

### Steps

1. After `.appended` outcomes, publish `previewImage` immediately (no extra
   throttle when output height changes).
2. Bottom-anchor preview panel (`alignTop` image alignment); grow upward toward
   screen top (reference `ScrollCapturePreviewPanel`).
3. Keep Plan 103 layout-signature coalescing; extend so merged-image-only updates
   skip intrinsic layout when aspect ratio unchanged.
4. Optional: AppKit `NSImageView` representable for the image surface only — keep
   SwiftUI chrome if it does not regress performance.

**Verify:** manual — rapid scroll shows rail growing smoothly; badges still
correct when commit lane briefly lags.

## Phase 3 — Auto-start on selection confirm (P1)

**Status:** implemented on branch `scrolling-capture-streaming-commits`.

### Goal

Remove friction: confirming the scrolling-capture region starts the session
immediately (macshot `autoScrollCaptureMode`).

### Steps

1. When `AreaSelectionController` completes `.scrollingCapture`, call
   `startCapture()` without a separate Start click.
2. Retain Cancel / Done / Auto Scroll on the HUD; hide or repurpose Start.
3. Update `docs/SCROLLING_CAPTURE.md` overview and localization strings.

**Verify:** entry from menu, shortcut, and deep link; Esc still cancels only in
`ready` if a pre-start state remains for region edits.

## Phase 4 — Suppress mouse-moved during capture (P1 stability)

**Status:** implemented on branch `scrolling-capture-streaming-commits`.

### Goal

Prevent hover/tooltip churn in the target app from breaking alignment (macshot
`CGEvent` tap on `mouseMoved`).

### Steps

1. After capture starts, install Accessibility-gated event tap; remove on cancel/finish.
2. Document manual gate: requires Accessibility permission for best results.

**Verify:** capture over a UI with heavy hover states; fewer alignment pauses.

## Phase 5 — Hybrid on-demand commit frames (P2)

**Status:** implemented on branch `scrolling-capture-streaming-commits`.

### Goal

Evaluate whether commit frames should use on-demand still capture
(`capturePreparedArea` / window-targeted grab) instead of stream ring frames
for fresher compositor output. Only implement if Phase 1–2 metrics still show
stale-frame commits (`stream` with high `frameAgeMs`).

### STOP for Phase 5

- Requires new capture adapter touching `ScreenCaptureManager`
- No evidence of stale stream frames in session metrics after Phase 1

## Test plan

- Deterministic policy tests for streaming commit scheduling; no wall-clock FPS
  assertions in XCTest.
- Preserve existing stitcher safety tests unchanged.
- Manual after each phase: Screen Recording permission, long page scroll, Done,
  verify final image completeness and no duplicated seams at boundaries.

## Done criteria (full plan)

- [ ] Phase 1: streaming commits during active scroll; docs updated; tests pass
- [ ] Phase 2: preview advances with each append; bottom-anchored rail
- [ ] Phase 3: no extra Start click for scrolling capture entry
- [ ] Phase 4: mouse-move suppression when Accessibility granted
- [ ] Phase 5: deferred or completed with metric justification
- [ ] Focused tests, format, lint, and agent gates pass or baseline failures recorded
- [ ] Only in-scope files modified per phase

## STOP conditions

- Streaming commits increase alignment failures or duplicate boundaries in manual QA
- Preview changes alter final saved pixels or output height contract
- Auto-start breaks region resize in ready state
- Any focused or repository gate fails twice after a reasonable fix attempt
- Executor needs to copy macshot code or remove safety tiers to match UX

## Maintenance notes

- Compare `ScrollingCaptureSessionMetrics` before/after Phase 1:
  `refreshAvgMs`, `commitCoalesced`, alignment path counts, `previewTruthLiveAhead`.
- macshot uses Vision-only alignment; keep Notinhas guided+recovery matcher —
  parity target is **cadence and preview**, not algorithm identity.
- Future: target-window resolution (macshot `resolveTargetWindow`) as a separate
  plan if hybrid capture lands.
