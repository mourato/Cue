# Plan 103: Throttle live-preview UI work without slowing frame commits

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command and perform the manual capture gate. Keep the capture
> stream/ring available for commits; only reduce redundant UI/layout work.
>
> **Drift check (run first):**
> `git diff --stat 5eb42e1..HEAD -- Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCapturePreviewWindow.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCapturePreviewView.swift NotinhasTests/Services/Capture/ScrollingCaptureWindowSharingTests.swift`

## Status

- **Priority:** P2
- **Effort:** M
- **Risk:** MED
- **Depends on:** Plans 100, 101, and 102; implement after their merges
- **Category:** perf
- **Planned at**: commit `5eb42e1`, 2026-08-21
- **Finding ID:** `scrolling-capture-live-preview-ui-throttle`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization; no push is authorized by this plan

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** no; serialize with other scrolling-capture plans because the model and preview window are shared
- **Reviewer required:** yes; live/committed truth indicators must remain accurate while reducing UI work
- **Rationale:** This is a native AppKit/SwiftUI lifecycle change with a small surface but timing-sensitive behavior.
- **Escalate when:** the executor needs to redesign the scheduler, change capture FPS, or alter truth-state semantics.

## Why this matters

The stream publishes up to 30 frames per second. Each publication writes
`@Published` state and calls `updatePreviewTruthState`; the preview window
observes every `objectWillChange` and performs intrinsic-size/layout work. Once
the first stitched preview exists, the raw live image is usually no longer the
visible image, but it still causes SwiftUI invalidation and panel-layout work.
This can consume MainActor time while the commit lane is trying to keep up.

## Current state

- `ScrollingCaptureFrameSource` publishes at up to 30 fps through
  `publishLivePreviewFrame`.
- `ScrollingCaptureCoordinator.publishLivePreviewFrame` assigns
  `livePreviewImage`, state, timestamps, and truth metrics at lines 1193–1225.
- `ScrollingCaptureSessionModel.activePreviewImage` returns
  `previewImage ?? livePreviewImage`; after the first stitched preview, the raw
  viewport is no longer the preferred visible image.
- `ScrollingCapturePreviewWindow` subscribes to all model changes at lines
  38–42 and calls `invalidateIntrinsicContentSize`, layout, fitting-size, and
  positioning at lines 52–72.
- The SwiftUI renderer is already layer-backed and `.fit`; retain that design.
- The commit scheduler is already latest-only. Do not replace it with a second
  queue or make frame capture wait for UI rendering.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Window/policy tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureWindowSharingTests` | exit 0 |
| Commit scheduler tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureCommitSchedulerTests` | exit 0 |
| Format | `make format-check` | exit 0 |
| Changed Swift lint | `make lint-changed` | exit 0 |
| Repository agent gate | `make agent-check` | exit 0, or report exact baseline failure |

## Scope

**In scope:**

- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift`
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCapturePreviewWindow.swift`
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCapturePreviewView.swift` only if a view identity/update change is required
- Matching capture-window tests

**Out of scope:**

- Changing `SCStream` maximum frame rate or pixel format.
- Changing scroll detection, auto-scroll event cadence, or stitch thresholds.
- Removing `livePreviewImage`, the truth badge, or the committed/live distinction.
- Adding a generic UI scheduler, Combine framework layer, or third-party dependency.

## Steps

### Step 1: Coalesce preview-window layout work

Keep SwiftUI free to update the layer contents, but stop recalculating panel
intrinsic layout for every image-only frame. Add the smallest local signature or
coalescing guard that distinguishes layout-affecting changes from image-content
changes. Layout-affecting changes include at least:

- anchor/selected rectangle;
- active preview image dimensions/aspect ratio;
- caption text or truth badge text that can change panel height;
- phase changes that alter the visible panel content.

Same-sized image replacement must update the layer contents without forcing
`invalidateIntrinsicContentSize` and `fittingSize` again. If multiple model
changes arrive in one main-run-loop turn, schedule at most one layout pass.

**Verify:** existing window-sharing/layout tests pass; add a focused test for
same-size image updates not changing the layout signature if the current test
seam permits it.

### Step 2: Throttle only redundant raw viewport publication

Keep every frame available to the ring/commit lane. Once `previewImage` exists,
publish `livePreviewImage` to the UI at a modest bounded rate (recommended
10–15 fps), while continuing to update the timestamp used for truth-state lag
from the newest captured frame. Before the first committed preview, retain the
current responsive live viewport behavior.

Do not let UI throttling make `captureFrameForCommit` select an older frame or
make `liveAhead`/`previewCommitLagMs` lie. If separate captured-vs-published
timestamps are needed, name them explicitly and test both meanings.

**Verify:** focused window and scheduler tests pass. During manual capture,
confirm that the stitched preview continues to advance and the badge still
transitions correctly between Live, Syncing, Captured, Paused, Finishing, and
Saving.

### Step 3: Preserve latest-only commit behavior

Review the interaction with `ScrollingCaptureCommitScheduler`. Do not add a
second queue or block the frame source on UI. If a small backpressure adjustment
is clearly required after Steps 1–2, make only the minimal change supported by
existing metrics (`commitCoalesced`, `stitchAvgMs`, `refreshAvgMs`) and add a
focused policy test. Do not tune hard-coded intervals speculatively; leave them
unchanged when the metrics do not demonstrate scheduler saturation.

**Verify:** run the focused scheduler command and record the decision about any
interval change in the handoff.

### Step 4: Run repository gates

Run the two focused test commands, then `make format-check`,
`make lint-changed`, and `make agent-check`. Record exact baseline failures.

## Test plan

- Preserve existing window level, non-interactive panel, placement, and layout
  tests.
- Add only deterministic state/identity tests; do not assert wall-clock frame
  counts in XCTest.
- Manual after integration: grant Screen Recording permission, capture a large
  scrolling area, observe preview responsiveness during rapid scrolling, press
  Done, and verify the final image is complete.

## Done criteria

- [ ] Same-size live image updates do not force redundant panel intrinsic-layout
      work.
- [ ] Multiple model changes in one run-loop turn produce at most one layout
      pass.
- [ ] The capture ring/commit lane still sees the newest frames independently of
      UI publication throttling.
- [ ] Truth-state lag and badges remain semantically correct.
- [ ] No speculative commit-interval change is made without metric evidence.
- [ ] Focused tests, format, lint, and agent gates pass or exact baseline
      failures are recorded.
- [ ] Only the in-scope files are modified.

## STOP conditions

- UI throttling would make commit selection use a stale frame or change the
  stitched output.
- The current model cannot distinguish captured timestamps from UI-published
  timestamps without changing an out-of-scope API.
- Layout coalescing causes the panel to retain an incorrect size, caption, badge,
  or placement during a session.
- The executor needs to change stream FPS, frame normalization, or matcher
  behavior to make the UI optimization work.
- Any focused or repository gate fails twice after a reasonable fix attempt.

## Maintenance notes

- The important invariant is: frame capture/commit truth is independent from
  preview presentation frequency.
- Reviewers should inspect MainActor work in `publishLivePreviewFrame` and
  `ScrollingCapturePreviewWindow.updateLayout`, not only visual output.
- Deferred: adaptive commit cadence remains a measured follow-up. Existing
  latest-only coalescing is sufficient until session metrics show sustained
  saturation.
