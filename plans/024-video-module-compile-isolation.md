# Plan 024: Compile-time isolation so Video-off builds drop heavy code

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- Snapzy/Features/Recording Snapzy/Features/VideoEditor Snapzy/Services/Capture Snapzy/Services/Media/GIFConverter.swift Snapzy/App SnapzyTests`
> Plans 020–023 must already gate call sites; this plan makes `NOTINHAS_VIDEO_MODULE` actually omit (or stub) heavy sources.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/020-video-module-gate-and-build.md, plans/021-video-module-shell-entry-gates.md, plans/022-video-module-preferences-surfaces.md, plans/023-video-module-history-qa-onboarding.md
- **Category**: tech-debt | perf
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — binary/membership changes can break upstream merges
- **Rationale**: Large surface; wrong `#if` leaves undefined symbols or dead menus.
- **Escalate when**: Synchronized-group exclusion is required and pbxproj exceptions become unstable — fall back to whole-file `#if` wrapping and report.

## Why this matters

Runtime-off frees schedulers and hotkeys but **does not** shrink the binary or avoid linking recording/editor code. The hybrid design’s compile half only pays off when `Features/Recording`, `Features/VideoEditor`, and recording-only services are not compiled (or are empty stubs) without `NOTINHAS_VIDEO_MODULE`. That is what makes default Notinhas builds meaningfully lighter.

## Current state

- `Snapzy` target uses `PBXFileSystemSynchronizedRootGroup` for the entire `Snapzy/` tree (`project.pbxproj` ~45–51) — files auto-compile.
- Heavy modules: `Snapzy/Features/Recording/` (~29 Swift files), `Snapzy/Features/VideoEditor/` (~37), plus services such as:
  - `Snapzy/Services/Capture/ScreenRecordingManager.swift`
  - `RecordingMetadata.swift`, `RecordingMetadataCleanupScheduler.swift`, `RecordingMouseTracker.swift`
  - `MouseClickHighlightService.swift`, `KeystrokeMonitorService.swift`, `RecordingAudioLevelMeter.swift`
  - `Snapzy/Services/Media/GIFConverter.swift` (post-record GIF path)
- App shell still type-references these types; 021–023 should have wrapped **call sites**. This plan wraps **definitions** / membership.
- Tests under `SnapzyTests/Features/Recording`, `SnapzyTests/Features/VideoEditor`, and several Services tests import recording types.

### Locked approach

1. Prefer **`#if NOTINHAS_VIDEO_MODULE` … `#endif` wrapping the entire body** of recording/video-only Swift files (keep a tiny file header + empty fallback only if the file must exist for the synchronized group).
2. Shared types used by screenshot paths must **not** be wrapped (e.g. Screen Recording TCC helpers used by screenshot capture stay available).
3. `GIFConverter`: wrap if only used by recording pipeline; if screenshot GIF paths exist, STOP and split.
4. SnapzyTests: wrap recording/video test files in the same `#if`, **or** build the test host with `NOTINHAS_VIDEO_MODULE` always on for `./scripts/run-tests.sh` while verifying a separate `xcodebuild … -scheme Snapzy` compile (module off) in Done criteria. **Recommended**: `run-tests.sh` uses Video-enabled compilation so existing tests keep running; add an explicit **compile-only** verification for module-off Snapzy scheme in Done criteria.
5. Do **not** create an SPM package in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Module-off build | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug -derivedDataPath /tmp/snapzy-novideo build` (+ existing local codesign args from `build_and_run.sh`) | BUILD SUCCEEDED |
| Module-on build | same with `-scheme "Snapzy Video"` or Debug+Video | BUILD SUCCEEDED |
| Tests (video-on host) | `./scripts/run-tests.sh` | pass (after script points at video-enabled compile if required) |
| Format | `swiftformat Snapzy SnapzyTests` scoped to touched dirs | exit 0 |

## Suggested executor toolkit

- `.agents/skills/code-quality/SKILL.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/testing-xctest/SKILL.md`
- `.agents/skills/swift-conventions/SKILL.md`

## Scope

**In scope**:
- `#if NOTINHAS_VIDEO_MODULE` isolation for Recording + VideoEditor feature trees and recording-only services listed above
- Fix any remaining unconditional references so module-off builds compile
- Adjust `scripts/run-tests.sh` if needed so the suite still runs (Video-enabled)
- `plans/README.md`

**Out of scope**:
- SPM extraction
- Deleting upstream Recording/VideoEditor code
- Changing product behavior beyond “not linked when flag off”
- ImgBB / Notinhas / Annotate

## Git workflow

- Branch: `feat/video-module-compile-isolation`
- Commits: split if huge (`refactor: wrap Recording sources in NOTINHAS_VIDEO_MODULE`, etc.)

## Steps

### Step 1: Inventory unresolved references

With module flag off, attempt a build and collect undefined/unavailable symbol errors. Produce a checklist of files that still reference Recording/VideoEditor types outside `#if`.

**Verify**: build log path saved; list is empty before declaring Done (iterate Steps 2–3).

### Step 2: Wrap feature modules

For each file under `Snapzy/Features/Recording` and `Snapzy/Features/VideoEditor`, wrap implementation in `#if NOTINHAS_VIDEO_MODULE`. If a type is referenced from non-wrapped code, either move the reference behind `#if` (preferred) or provide a minimal stub API — stubs only when required for compilation of shared code; STOP if stubs grow beyond a handful of no-op methods.

### Step 3: Wrap recording-only services

Same treatment for `ScreenRecordingManager`, metadata/mouse/audio/keystroke/highlight services, `GIFConverter` (after confirming recording-only).

**Careful**: `MouseClickHighlightService` / keystroke — confirm not used by screenshot annotate. If shared, do not wrap; only gate recording call sites.

### Step 4: Tests + run-tests.sh

- Wrap video-only tests in `#if NOTINHAS_VIDEO_MODULE`, **or** pass the flag in `run-tests.sh` xcodebuild invocation (document in script comments).
- Ensure `VideoModuleAvailabilityTests` still covers both worlds if feasible.

### Step 5: Prove both binaries

1. Module-off `Snapzy` scheme build succeeds.
2. Module-on Video scheme build succeeds.
3. `nm` or `strings` optional smoke: module-off binary should not contain obvious `VideoEditorManager` symbol — nice-to-have, not mandatory if Swift mangling makes it noisy.

## Test plan

- Full `./scripts/run-tests.sh` on video-enabled test host.
- Manual: module-off app — screenshot capture + Notinhas still work; no Recording symbols exercised.
- Manual: module-on + runtime on — record → stop still works.

## Done criteria

- [ ] `xcodebuild … -scheme Snapzy` (no `NOTINHAS_VIDEO_MODULE`) succeeds
- [ ] `xcodebuild …` Video-enabled scheme succeeds
- [ ] `./scripts/run-tests.sh` passes under the documented test host configuration
- [ ] No new unconditional references to `VideoEditorManager` / `RecordingCoordinator` / `ScreenRecordingManager` outside `#if NOTINHAS_VIDEO_MODULE` (`rg` audit)
- [ ] Screenshot + Notinhas paths compile and are not wrapped away
- [ ] `plans/README.md` updated

## STOP conditions

- A type is required by screenshot capture **and** lives inside Recording-only files — stop for a split plan
- pbxproj synchronized exclusion corrupts the project
- Stub surface exceeds ~3 small facades — stop and reconsider membership exclusion
- Upstream merge conflict risk looks unmanageable — stop with recommendation

## Maintenance notes

- Upstream Snapzy pulls will reintroduce unwrapped files — document in 025 that merges must re-apply `#if` or membership rules.
- Reviewers: diff size will be large; prioritize “module-off build green” + “screenshot path untouched”.
