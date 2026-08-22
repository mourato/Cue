# Plan 102: Bound scrolling-capture preview composition work

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command. Preserve the current preview truth states and final
> image path; this plan optimizes the preview surface only.
>
> **Drift check (run first):**
> `git diff --stat 5eb42e1..HEAD -- Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests.swift docs/SCROLLING_CAPTURE.md`

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MED
- **Depends on:** Plan 101; compact slices provide the bounded preview sources
- **Category:** perf
- **Planned at**: commit `5eb42e1`, 2026-08-21
- **Finding ID:** `scrolling-capture-bounded-preview-render`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization; no push is authorized by this plan

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** no; serialize after Plan 101 and before Plan 103
- **Reviewer required:** yes; preview output must remain visually and geometrically faithful
- **Rationale:** The preview is user-visible and updated during a stateful capture session, but the change can stay inside the stitcher/coordinator preview path.
- **Escalate when:** the change needs a new window, renderer, image format, or final-save pipeline.

## Why this matters

The live flow intentionally skips rebuilding the full merged image, but it still
rebuilds the small preview from every slice after each stitch update. Worse,
`refreshPreview` regenerates that preview even when a frame was ignored and the
stitched output did not change. The current implementation also creates a new
cropped `CGImage` for each slice on every preview render. The preview should be
cheap and bounded without changing the final output.

## Current state

- `ScrollingCaptureCoordinator.refreshPreview` updates `sessionModel.previewImage`
  whenever a processed stitcher is returned, regardless of whether the outcome
  appended pixels; see the post-stitch update around lines 641–649 of
  `ScrollingCaptureCoordinator.swift`.
- `ScrollingCaptureStitcher.previewImage` allocates a target bitmap capped by
  the preview bounds, then loops over all slices at lines 637–697.
- Each slice is cropped into an intermediate image before being drawn at lines
  670–693.
- `ScrollingCapturePreviewLayout` intentionally caps the visible rail at 220 ×
  420 points; keep the 2x render target and `.fit` display contract.
- Plan 101 changes accepted slices to compact strips. This plan must consume
  that representation rather than reintroduce full-frame retention.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Stitcher tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` | exit 0 |
| Preview/window tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureWindowSharingTests` | exit 0 |
| Format | `make format-check` | exit 0 |
| Changed Swift lint | `make lint-changed` | exit 0 |
| Repository agent gate | `make agent-check` | exit 0, or report exact baseline failure |

## Scope

**In scope:**

- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift`
- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureCoordinator.swift`
- Matching preview/stitcher XCTest files
- `docs/SCROLLING_CAPTURE.md` only if the preview-rendering description needs correction

**Out of scope:**

- Changing preview dimensions, material, badge semantics, or window placement.
- Changing `activePreviewImage` precedence.
- Replacing the layer-backed renderer or adding a third-party image library.
- Changing final `mergedImage()` pixels or save behavior.

## Steps

### Step 1: Render from compact strips without full-frame intermediates

Adapt `previewImage(maxPixelWidth:maxPixelHeight:)` to consume Plan 101's
compact strip representation directly. Do not call a crop operation that copies
rows from a full-resolution frame during every preview refresh. Keep the target
canvas bounded by the existing maximum dimensions and preserve the current
vertical mapping and interpolation quality.

If the compact representation is a `CGImage` strip, draw it directly. If it is
a compact raster, use one narrow conversion path that does not retain a full
source frame. Keep the implementation local to the stitcher; do not introduce a
generic thumbnail service.

**Verify:** focused stitcher tests pass and existing preview max-bound tests
still assert both width and height limits.

### Step 2: Do not rerender unchanged stitch output

In `refreshPreview`, update the stitched preview only when the stitcher output
changed: `.initialized`, `.appended`, or an output-changing height-limit result.
For `.ignoredNoMovement` and `.ignoredAlignmentFailed`, retain the last valid
preview image. Preserve captions, truth badges, failure guidance, and metrics.

Use accepted frame count/output height or an equivalent existing state signal;
do not compare large image bitmaps.

**Verify:** add or extend a focused test/helper assertion that an ignored frame
does not replace the existing preview image, then run the stitcher and window
test commands.

### Step 3: Preserve final-image behavior

Confirm that `mergedImage()` still returns the full accepted result at Done and
that preview-only downscaling never becomes the saved image. The preview may be
cached or rebuilt internally, but `latestImage` and finalization must retain the
existing full-resolution path.

**Verify:** the focused stitcher tests pass; manually capture, press Done, and
compare the saved image dimensions and visible strip order with the preview.

### Step 4: Run repository gates

Run the two focused test commands, then `make format-check`,
`make lint-changed`, and `make agent-check`. Record any baseline failure
verbatim.

## Test plan

- Preserve `testPreviewImage_respectsMaxBounds`.
- Add coverage for preview stability after `.ignoredNoMovement` and
  `.ignoredAlignmentFailed` outcomes where the test seam permits it.
- Add a row-signature preview test only if it can stay deterministic and small;
  do not add wall-clock assertions.
- Manual: Screen Recording permission, a long capture with at least 10 commits,
  boundary/no-movement pause, and final save.

## Done criteria

- [ ] Preview composition uses compact accepted strips and does not crop full
      historical frames on every update.
- [ ] Ignored/non-mutating stitch outcomes do not rebuild or replace the
      stitched preview image.
- [ ] Preview remains within the existing 440 × 840 pixel render budget and
      displays correctly in the existing 220 × 420 point rail.
- [ ] Final `mergedImage()` and save output remain full-resolution and unchanged
      in pixel order.
- [ ] Focused tests, format, lint, and agent gates pass or baseline failures are
      recorded.
- [ ] Only the in-scope files are modified.

## STOP conditions

- Plan 101's compact-slice contract is absent or incompatible with direct
  preview rendering.
- Preserving preview correctness requires changing final output or image scale.
- The only viable implementation creates a second full-resolution merged image
  on every commit.
- A failed/ignored stitch outcome currently carries required preview pixels that
  would be lost by retaining the previous preview; stop and report the exact
  state contract instead of guessing.
- Any focused or repository gate fails twice after a reasonable fix attempt.

## Maintenance notes

- The preview is intentionally a downscaled rail, not a second final-image
  pipeline. Keep its memory bound obvious in code.
- Reviewers should inspect allocations inside the per-commit preview loop and
  confirm that no full historical raster is recreated there.
- Deferred: a mathematically incremental canvas is not required if compact-strip
  direct drawing keeps preview work bounded and responsive; do not add a custom
  tile cache without a measured need.
