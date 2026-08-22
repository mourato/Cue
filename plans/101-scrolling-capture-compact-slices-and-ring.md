# Plan 101: Store only accepted scrolling-capture strips

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command. Stop instead of changing capture scale or final-image
> semantics when a cited assumption is false.
>
> **Drift check (run first):**
> `git diff --stat 5eb42e1..HEAD -- Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureFrameRing.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests.swift`

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MED
- **Depends on:** Plan 100; if Plan 100 is not merged, rebase and preserve its alignment behavior
- **Category:** perf
- **Planned at**: commit `5eb42e1`, 2026-08-21
- **Finding ID:** `scrolling-capture-compact-accepted-slices`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization; no push is authorized by this plan

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** no; serialize with Plans 100, 102, and 103 because the same stitcher state is changing
- **Reviewer required:** yes; output pixels and memory ownership must be checked together
- **Rationale:** The optimization is conceptually small but rewrites how final rows are retained and rendered.
- **Escalate when:** exact pixel preservation requires changing the save pipeline, output scale, or public capture model.

## Why this matters

Every accepted frame currently remains in `contentSlices` as a full-resolution
`RasterImage`, even though only `acceptedDelta` rows are ever copied into the
long result. A 3840 × 2160 RGBA frame is about 32 MiB; long sessions can retain
hundreds of MiB before the final image is created. The frame ring additionally
keeps eight full `CGImage`s even though commit selection always chooses the
latest frame after the last committed sequence.

## Current state

- `ScrollingCaptureStitcher.ContentSlice` at lines 279–283 stores a full
  `RasterImage`, `startRow`, and `rowCount`.
- `start(with:)` stores the first full raster as a slice at lines 334–345.
- On every accepted append, line 571 stores the entire current raster in a new
  slice, even when `acceptedDelta` is much smaller than the viewport.
- `mergedImage()` later copies only the selected rows at lines 604–634.
- `previewImage()` crops only the selected rows, but does so repeatedly at lines
  637–697.
- `ScrollingCaptureFrameRing` has capacity 8 by default at lines 19–40 of
  `ScrollingCaptureFrameRing.swift`; `latestFrame(after:)` is the only selection
  operation used by the coordinator.
- `ScrollingCaptureCoordinator` also explicitly constructs the ring with
  `capacity: 8`, so changing only the ring default would not change live
  sessions.
- `ScrollingCaptureCoordinator.captureFrameForCommit` selects the newest frame
  after `lastCommittedSequenceNumber` at lines 980–1008. It does not use older
  intermediate ring frames to reconstruct missing content.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Stitcher tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` | exit 0 |
| Ring tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureFrameRingTests` | exit 0 after the planned test file is added |
| Scheduler tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureCommitSchedulerTests` | exit 0 |
| Format | `make format-check` | exit 0 |
| Changed Swift lint | `make lint-changed` | exit 0 |
| Repository agent gate | `make agent-check` | exit 0, or report exact baseline failure |

## Scope

**In scope:**

- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift`
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureFrameRing.swift`
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift`
- Matching focused XCTest files under `NotinhasTests/Services/Capture/`
- `docs/SCROLLING_CAPTURE.md` only if the documented ring capacity changes

**Out of scope:**

- Lowering the minimum 2x screenshot scale.
- Changing the alignment algorithm, scroll thresholds, or max output height.
- Replacing `CGImageDestination` with a tiled/streaming encoder.
- Adding a general image-storage abstraction or dependency.

## Steps

### Step 1: Add pixel-preserving strip coverage

Extend the stitcher tests with a fixture whose rows have distinct signatures.
After one or more appends, assert that:

- output width and height remain correct;
- accepted-frame count and delta behavior remain correct;
- the final `mergedImage()` contains the expected row order;
- duplicate and failed-alignment frames do not add rows.

Use pixel assertions rather than only dimensions so a crop/orientation error
cannot hide behind a passing height check.

**Verify:** `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` → all focused tests pass.

### Step 2: Make accepted slices compact

Change `ContentSlice` so it owns only the accepted strip, not a full source
raster. Keep matching state separate: `baseRaster` and `lastRaster` must remain
full frames for the current alignment operation, but older accepted frames must
not remain retained as full rasters.

Use a single no-interpolation crop/copy path that preserves RGBA bytes. The
first frame may remain full until merge direction and static top/bottom bands
are resolved; when `bootstrapContentSlices` runs, replace that initial slice with
the compact content rows. New accepted strips must contain exactly
`acceptedDelta` rows.

Update `mergedImage()` and `previewImage()` to consume compact slices. Preserve
the existing vertical order, side-band behavior, static header/footer behavior,
and max-height clamp.

**Verify:** the focused stitcher command passes, including row-signature tests.

### Step 3: Right-size the live frame history

Reduce the ring's retained history to the smallest capacity that preserves the
current latest-frame contract. Capacity 2 is the default recommendation: it
retains enough history to cover the last committed/latest pending pair while
still bounding memory. If the implementation can safely use a latest-frame
slot plus sequence number, document that choice and test it instead.

Add focused ring tests for:

- monotonic sequence selection after a commit;
- eviction behavior;
- no older frame being selected after `markCommitted`;
- reset clearing both frames and committed sequence.

Do not change the coordinator to process every historical frame. Latest-only is
the intentional behavior of the existing commit scheduler.

**Verify:**
`./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureCommitSchedulerTests` → scheduler tests pass; run the focused stitcher command again.

### Step 4: Run repository gates

Run `make format-check`, `make lint-changed`, and `make agent-check`. Record
manual memory observations only in the handoff; do not add persistent memory
telemetry in this plan.

## Test plan

- Add row-order/pixel-preservation coverage to
  `ScrollingCaptureStitcherTests`.
- Add `ScrollingCaptureFrameRingTests` if no existing ring test file is present;
  keep it value/sequence focused and avoid timing tests.
- Manual after integration: capture a large region for at least 20 accepted
  strips, verify the preview and saved image, and observe Allocations/Memory
  Graph once to confirm old full frames are not retained by the stitcher.

## Done criteria

- [ ] `contentSlices` retains only accepted strip pixels after each append.
- [ ] `baseRaster`/`lastRaster` remain available as needed for current matching,
      but old full frames are not retained by accepted slices.
- [ ] The ring retains no more history than the tested latest-frame contract.
- [ ] Final pixel order, dimensions, static-band handling, and max-height
      behavior are unchanged.
- [ ] Focused tests, format, lint, and agent gates pass or exact baseline
      failures are recorded.
- [ ] Only the in-scope files are modified.

## STOP conditions

- Compacting a slice requires changing the output scale, image format, or save
  pipeline.
- The current code has changed so `latestFrame(after:)` no longer describes the
  commit contract.
- A pixel-preservation test fails and cannot be fixed without changing
  coordinate/orientation semantics.
- The ring must retain historical intermediate frames for correctness; if so,
  stop and report the required contract instead of guessing a smaller capacity.
- Any focused or repository gate fails twice after a reasonable fix attempt.

## Maintenance notes

- The main reviewer concern is byte-for-byte row order, not the exact internal
  type used for a compact strip.
- Keep the compact strip representation easy for Plan 102 to draw into its
  bounded preview canvas.
- Deferred: a tiled/streaming final encoder is not part of this plan. The final
  `CGImage` itself can still be large at the configured 32,768-pixel height;
  revisit only if real sessions hit that ceiling after slice retention is fixed.
