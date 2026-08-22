# Plan 100: Move scrolling-capture Vision alignment to the recovery path

> **Executor instructions:** Read this brief fully before editing. Run every
> verification command. Stop on any condition listed under STOP conditions;
> do not replace the alignment algorithm or widen the capture scope.
>
> **Drift check (run first):**
> `git diff --stat 5eb42e1..HEAD -- Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests.swift docs/SCROLLING_CAPTURE.md`
> If the in-scope code changed since this plan, compare the current symbols and
> excerpts before proceeding.

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MED
- **Depends on:** none
- **Category:** perf
- **Planned at**: commit `5eb42e1`, 2026-08-21
- **Finding ID:** `scrolling-capture-lazy-vision-alignment`
- **Publication:** local plan
- **Integration:** local `main` only after review and explicit authorization; no push is authorized by this plan

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** no; serialize with Plans 101–103 because all touch the scrolling-capture stitch/preview path
- **Reviewer required:** yes; changing alignment fallback policy can create silent duplicated or missing content
- **Rationale:** The change is localized but affects the safety-critical frame-matching decision.
- **Escalate when:** the executor needs to replace the matcher, change frame geometry, add a new Vision abstraction, or alter the final-image contract.

## Why this matters

`ScrollingCaptureStitcher.append` currently calls `estimateVisionAlignment` before
the fast guided matcher has established whether Vision is needed. That creates
up to three cropped-image allocations and Vision registrations per commit,
even when the pixel matcher is confident. The documented design says Vision is
recovery/cross-validation, so the implementation and documentation are out of
sync. The goal is to keep the existing safety behavior while making the cheap
guided path the default.

## Current state

- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift`
  owns the stateful vertical matcher.
- At lines 397–404, `append` calls `estimateVisionAlignment` before
  `bestMatch(... searchMode: .guided)`.
- At lines 449–474, the fast result may then trigger another guided search with
  the already-computed Vision estimate.
- At lines 476–489, a recovery search uses Vision-derived guidance if the fast
  match is absent.
- At lines 1461–1545, Vision examines up to three regions.
- At lines 1547–1580, each region is cropped into two new `CGImage`s before a
  `VNTranslationalImageRegistrationRequest` runs.
- `shouldValidateFastGuidedMatch` at lines 1407–1416 already expresses the
  intended low-confidence/disagreement gate, but it can only be useful after a
  fast match has been attempted.
- `docs/SCROLLING_CAPTURE.md` currently describes Vision as recovery rather than
  the default path; keep that wording accurate after the change.

## Commands you will need

| Purpose | Command | Expected result |
|---|---|---|
| Focused stitcher tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` | exit 0; all focused tests pass |
| Format | `make format-check` | exit 0 |
| Changed Swift lint | `make lint-changed` | exit 0 |
| Repository agent gate | `make agent-check` | exit 0, or report an existing baseline failure exactly |

## Scope

**In scope:**

- `Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift`
- `NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests.swift`
- `docs/SCROLLING_CAPTURE.md` only for the now-accurate Vision-path wording

**Out of scope:**

- Replacing the guided matcher or changing its scoring thresholds broadly.
- Removing Vision entirely.
- Changing output dimensions, pixel scale, max height, scroll thresholds, or
  the final save path.
- Adding a generic alignment protocol, dependency, telemetry service, or
  persistent performance database.

## Steps

### Step 1: Characterize the existing decision paths

Read the existing stitcher tests and add only the smallest deterministic
coverage needed to distinguish these cases:

1. a high-confidence guided match does not require a Vision estimate;
2. a missing/low-confidence/ambiguous guided match still reaches the existing
   Vision-assisted validation or recovery path;
3. identical frames still return `.ignoredNoMovement` and do not append;
4. an alignment failure still remains unsafe and does not append pixels.

Prefer asserting `alignmentDebug.path`, `usedVisionEstimate`, output height,
and accepted-frame count. Do not make synthetic tests accept an alignment
failure for a fixture that is supposed to prove a successful path.

**Verify:** `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/ScrollingCaptureStitcherTests` → focused tests pass.

### Step 2: Make the guided match the first attempt

Reorder `append` so it performs the existing cheap frame-difference check and
guided `bestMatch` first. Only after that result exists should it decide whether
to call `estimateVisionAlignment`:

- high confidence and no disagreement signal: keep the guided result;
- low confidence or ambiguous result: compute Vision and rerun guided matching
  with the estimate when useful;
- no guided result: compute Vision and use the existing recovery search;
- near-identical frame: preserve duplicate-boundary behavior without paying for
  Vision first.

Do not accept a match merely because Vision returned a translation. Preserve the
existing `isAcceptable`, ambiguity, duplicate-boundary, safety, and failure
handling rules.

If a small private/internal pure gating helper makes the policy testable, keep
it local to `ScrollingCaptureStitcher`; do not introduce a one-implementation
protocol.

**Verify:** the focused stitcher test command passes and the test output covers
both guided and Vision-assisted paths.

### Step 3: Reconcile the documentation

Update the Frame/Stitching wording in `docs/SCROLLING_CAPTURE.md` only if the
new control flow requires it. It must say that the guided pixel match is the
hot path and Vision is used for low-confidence validation or recovery.

**Verify:** `rg -n "Vision|guided|recovery" docs/SCROLLING_CAPTURE.md Notinhas/Services/Capture/ScrollingCapture/ScrollingCaptureStitcher.swift` → no statement claims Vision is the unconditional default.

### Step 4: Run repository gates

Run the focused tests, then `make format-check`, `make lint-changed`, and
`make agent-check`. Record any pre-existing failure rather than weakening a
gate.

## Test plan

- Extend `ScrollingCaptureStitcherTests` with deterministic path assertions.
- Preserve coverage for duplicate frames, mismatched dimensions, shifted
  content, height limits, and `renderMergedImage: false`.
- Do not add a performance benchmark that depends on wall-clock timing in the
  normal XCTest suite; timing is too noisy for a correctness gate.
- Manual after integration: with Screen Recording permission, capture a large
  scrolling region for at least 10 commits and verify no duplicated boundary,
  missing strip, or premature end-of-content state.

## Done criteria

- [ ] Guided matching runs before Vision on the normal high-confidence path.
- [ ] Vision remains available for low-confidence validation and recovery.
- [ ] No accepted-frame count, output height, safety outcome, or alignment
      failure contract regresses.
- [ ] Focused tests, format, lint, and agent gates pass or baseline failures are
      recorded.
- [ ] Only the in-scope files are modified.
- [ ] The implementation branch remains isolated; no merge or push occurs
      without explicit authorization.

## STOP conditions

- The stitcher has drifted so the cited `append`/Vision symbols no longer match.
- The fast matcher cannot distinguish a high-confidence path without changing
  its scoring algorithm.
- The change requires altering `ScreenCaptureManager`, frame normalization, or
  the saved-image format.
- A test can pass only by accepting a new silent alignment failure or by
  weakening an existing safety assertion.
- Any focused or repository gate fails twice after a reasonable fix attempt.

## Maintenance notes

- Keep `ScrollingCaptureSessionMetrics.visionEstimateCount` useful as a field
  metric: after this change it should measure fallback/validation usage, not
  every append.
- Reviewers should compare `fastGuidedMatches`, `guidedVisionMatches`, and
  `recoveryVisionMatches` before and after a real manual session.
- Deferred: reduced-resolution matching is not part of this plan; consider it
  only if real stitch durations remain above the live commit budget after this
  change.
