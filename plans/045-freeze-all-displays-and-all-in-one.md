# Plan 045: Honor Freeze Screen in All-In-One and freeze every connected display

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the **STOP conditions** section occurs, stop and
> report — do not improvise. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first):**
> `git diff --stat cf730ede..HEAD -- Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift Notinhas/Services/Capture/ScreenCaptureManager.swift Notinhas/Services/Capture/FrozenAreaCaptureSession.swift Notinhas/Services/Capture/AreaSelectionWindow.swift Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings docs/CAPTURE.md docs/STRUCTURE.md`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none; coordinate the Preferences smoke check with Plan 043 if both are implemented in the same round.
- **Category**: correctness
- **Planned at**: commit `cf730ede`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — snapshot ownership, AppKit overlay lifecycle, All-In-One dispatch, and multi-display crop behavior must be integrated as one state machine.
- **Reviewer required**: yes — this changes Screen Recording capture timing and requires a physical dual-monitor manual gate.
- **Rationale**: The existing frozen-area engine already supports multiple snapshots and composite crops, but All-In-One bypasses that engine in both its initial selection and known-rectangle dispatch. The fix must preserve the existing live path, avoid stale-session invalidation, and maintain overlay cleanup under cancellation and display changes.
- **Escalate when**: the implementation would replace `FrozenAreaCaptureSession`, change generic fullscreen/recording semantics, modify the persisted freeze preference key/default, or require changing the shared recording overlay without an isolated regression test.

## Grilling: what is actually broken

There are two independent correctness gaps:

1. **All-In-One ignores the preference.** `AllInOneCaptureCoordinator.startInitialAreaSelection()` calls `AreaSelectionController.startSelection` with empty backdrops (`AllInOneCaptureCoordinator.swift:107-129`). When a last rectangle already exists, `beginRefinement` uses `AllInOneSelectionRefinementController`, whose backdrop cache is recaptured from the live screen (`AllInOneSelectionRefinementController.swift:275-295`). On dispatch, the Area/Timer commands call `ScreenCaptureViewModel.captureArea(at:)`, which reaches `performAreaCapture(at:)` and always calls the live `ScreenCaptureManager.captureArea` path (`CaptureViewModel.swift:565-569`, `2171-2224`). A fix that only changes the final crop would still violate “freeze while selecting.”
2. **Normal frozen area capture freezes only one monitor.** `startAreaCapture` resolves `ScreenUtility.activeDisplayID()` and prepares either one fast snapshot or `FrozenAreaCaptureSession.prepare(displayIDs: [targetDisplayID], ...)` (`CaptureViewModel.swift:669-737`). The existing session, composite crop, and ScreenCaptureKit snapshot engine already support a set of display IDs; the caller is narrowing the set prematurely.

## Product decisions for this plan

- “All monitors” means every display in `NSScreen.screens` that has a valid display ID at the instant the freeze session is prepared. The session owns those pixels until the selection/capture completes. A display added or removed during the session is handled by the existing display-change/lazy-snapshot behavior; do not silently replace the original session with a live capture.
- The preference remains `PreferencesKeys.screenshotFreezeArea`, remains off by default, and remains the user’s single freeze switch. No new preference or per-monitor toggle is introduced.
- Normal frozen Area/Application selection must receive frozen backdrops for every connected display, even when the selected rectangle touches only one display. A cross-display rectangle must crop from the same session through `FrozenAreaCaptureSession.cropCompositeImage`.
- All-In-One must prepare one shared `FrozenAreaCaptureSession` before presenting its HUDs or selection overlays. The same session supplies the initial selection backdrops, the refinement/snap image, and the final Area/Capture Markup/OCR source where the mode is rectangle-based.
- All-In-One Timer must not retain a stale three-second-old image. Its selection UI uses the frozen session, but the delayed capture prepares a fresh frozen session at timer fire. Fullscreen, Scrolling, and Recording keep their existing semantics; Window delegates to the normal area/application path and therefore receives the multi-display freeze fix.
- If freeze preparation fails, the affected frozen flow must report the existing capture failure and clean up. It must not silently fall back to live pixels while the preference is enabled.

The visual implementation should reuse `AreaSelectionBackdrop`/`FrozenAreaCaptureSession` and existing overlay lifecycle conventions. Do not add a second crop/compositing algorithm. If the All-In-One refinement needs a static background host, prefer a narrow All-In-One-owned backdrop layer over changing `RecordingRegionOverlayWindow` behavior shared with Recording; any shared-overlay change requires an explicit regression test and both product variants to be reviewed.

## Why this matters

“Freeze screen” promises that the user can select a stable frame. Today, regular Area capture freezes only the active display, so a notebook plus external monitor can show different moments while the selection spans or moves across screens. All-In-One is worse: it displays live content during its custom first-drag/refinement flow and captures the known rectangle live after the HUD closes. This can produce a result that no longer matches the frame the user selected, especially with animations, video, app switching, or multiple monitors.

The existing code already has the right primitives: per-display `FrozenDisplaySnapshot`, `FrozenAreaCaptureSession`, all-display ScreenCaptureKit capture when `displayIDs` is nil, and multi-display composite cropping. The plan should connect those primitives to the two bypassing callers rather than create a new freeze subsystem.

## Current state

### Relevant files and symbols

- `Notinhas/Features/Capture/CaptureViewModel.swift` — owns the normal Area freeze branch, known-rectangle All-In-One capture, inline Annotate capture, lazy frozen display preparation, transition re-freeze, and post-capture lifecycle.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` — owns All-In-One startup, first selection, refinement, HUD teardown, mode dispatch, and Timer scheduling; currently has no frozen-session ownership.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` — owns the last-rectangle refinement overlays and currently captures visible backdrops asynchronously for snapping only.
- `Notinhas/Services/Capture/FrozenAreaCaptureSession.swift` — stores snapshots keyed by display ID, supplies backdrops, supports missing-display hydration, and crops single- or multi-display selections.
- `Notinhas/Services/Capture/ScreenCaptureManager.swift` — `captureDisplaySnapshots(displayIDs: nil)` already captures all connected screens in parallel through ScreenCaptureKit; `captureFastDisplaySnapshot` and its off-main counterpart support the optimized path when exclusions permit.
- `Notinhas/Services/Capture/AreaSelectionWindow.swift` — `AreaSelectionController.startSelection(backdrops:...)` already renders frozen backdrops and handles lazy display activation/transition callbacks.
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` — `InlineAreaAnnotateCoordinator.start(...)` already accepts both all-display backdrops and a `FrozenAreaCaptureSession`; preserve this ownership model when All-In-One hands off Capture Markup.
- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` — current refinement overlay host used by All-In-One; treat as shared-risk code and avoid modifying it unless a narrowly tested static-backdrop capability is required.
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` — `screenshotFreezeArea` is the existing persisted key; do not rename or migrate it.
- `Notinhas/Shared/Localization/L10n.swift` and `Notinhas/Resources/Localization/Features/Capture.xcstrings` — own the “Freeze screen” title/description if the description is updated to explain all connected displays.
- `docs/CAPTURE.md` and `docs/STRUCTURE.md` — currently describe frozen capture as active-display-only or omit All-In-One’s freeze behavior; update them after the implementation is verified.

### Mode behavior matrix

| All-In-One mode | Current handoff | Target when Freeze Screen is enabled |
|---|---|---|
| Area | `captureArea(at:)` → live `performAreaCapture` | Reuse the session captured before selection/refinement; crop from it. |
| Capture Markup | `captureAreaAnnotate(at:)` → its own all-display frozen session | Reuse the shared session when available; preserve existing inline annotation UI and final composition. |
| OCR | `captureOCR(at:)` → live `captureAreaAsImage` | Capture the selected rectangle from the shared frozen session, or explicitly document/test a fresh frozen session if OCR needs a different image API. |
| Timer | delayed `captureArea(at:)` | Freeze the selection UI, then prepare a fresh all-display session when the timer fires. |
| Window | `captureApplication()` → normal selection path | Inherit the normal multi-display frozen selection fix. |
| Scrolling | `captureScrolling(at:)` → scrolling session | Unchanged; freezing the entire desktop would conflict with live scrolling capture. |
| Fullscreen | `captureFullscreen()` | Unchanged; fullscreen already has its own display targeting semantics. |
| Recording | `startRecordingFlow()` | Unchanged; this preference is screenshot-area behavior, not recording. |

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift check | `git diff --stat cf730ede..HEAD -- Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift Notinhas/Services/Capture/ScreenCaptureManager.swift Notinhas/Services/Capture/FrozenAreaCaptureSession.swift Notinhas/Services/Capture/AreaSelectionWindow.swift Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings docs/CAPTURE.md docs/STRUCTURE.md` | Empty output, or each pre-existing change is reviewed against this plan before implementation. |
| Focused capture tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/AreaSelectionModelsTests -only-testing:NotinhasTests/FrozenAreaCaptureSessionTests -only-testing:NotinhasTests/ScreenCaptureAreaCropTests -only-testing:NotinhasTests/LiveAreaMouseUpSnapshotTests` | Exit 0; All-In-One routing, snapshot storage, multi-display crop, and existing live-path tests pass. |
| Default build | `./scripts/build_and_run.sh --no-video-module --verify` | Default Notinhas scheme builds and launches successfully. |
| Optional Video build | `./scripts/build_and_run.sh --video-module --verify` | Video-gated compile path remains valid if shared overlay or capture files are touched. |
| Localization verification | `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` | `missing=0` and `extra=0`; any known unrelated hardcoded Snapzy path issue is reported without widening scope. |
| Formatting | `swiftformat Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Features/Capture/AllInOne Notinhas/Services/Capture/ScreenCaptureManager.swift Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` | Formatting completes on touched Swift files only. |
| Full default tests | `./scripts/run-tests.sh` | Exit 0, or unrelated baseline failures are explicitly recorded. |

## Scope

**In scope** (the only files to modify, plus focused test/helper files required by the existing test target):

- `Notinhas/Features/Capture/CaptureViewModel.swift` — centralize all-display frozen-session preparation, replace the active-display-only normal freeze selection, and add known-rectangle/session-aware handoffs for All-In-One modes.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` — read the freeze preference for the session, prepare/retain one session before HUD presentation, pass it into selection/refinement, transfer ownership on dispatch, and invalidate it on cancel/error.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` — accept frozen backdrops or a frozen-session-backed sampler and stop recapturing live images when the session is frozen; add/coordinate static backdrop presentation if needed.
- A narrow new All-In-One frozen-backdrop host under `Notinhas/Features/Capture/AllInOne/` if the existing refinement overlay cannot display static images without changing shared Recording behavior.
- `Notinhas/Services/Capture/ScreenCaptureManager.swift` only if a shared all-display fast-snapshot helper is required; reuse `captureDisplaySnapshots(displayIDs: nil)` and the off-main fast path rather than duplicating capture logic.
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift`, `NotinhasTests/Services/Capture/AreaSelectionModelsTests.swift`, `FrozenAreaCaptureSessionTests.swift`, `ScreenCaptureAreaCropTests.swift`, and focused new tests where needed — cover routing, session ownership, display-set selection, and multi-display crops without requiring real displays for unit tests.
- `Notinhas/Shared/Localization/L10n.swift` and `Notinhas/Resources/Localization/Features/Capture.xcstrings` — update the freeze description only if the final UI copy explicitly promises all connected displays.
- `docs/CAPTURE.md` and `docs/STRUCTURE.md` — document all-display frozen selection and the All-In-One mode matrix.
- `plans/README.md` — update plan 045 status when the executor finishes.

**Out of scope** (do not touch):

- `PreferencesKeys.screenshotFreezeArea` name/default, TOML schema, configuration migration, or a new per-monitor preference.
- Fullscreen capture’s existing target-display behavior, multi-file output, Quick Access/history batching, or post-capture routing.
- Recording, Video Editor, Scrolling capture internals, or generic live-area capture behavior when Freeze Screen is disabled.
- A second image compositing/cropping implementation; `FrozenAreaCaptureSession.cropImage` and `cropCompositeImage` remain canonical.
- A silent live fallback when Freeze Screen is enabled.
- Broad redesign of All-In-One HUD controls, selection geometry, timer duration, or capture mode availability.
- Unrelated plan 043 preference reorganization changes; if both plans touch the same documentation region, reconcile deliberately and preserve both contracts.

## Steps

### Step 1: Confirm drift and characterize the bypasses

Run the drift check. Read the current All-In-One coordinator, known-rectangle capture, normal frozen area branch, `FrozenAreaCaptureSession`, `AreaSelectionController` backdrop lifecycle, and tests. Confirm the mode matrix above against the live code. Identify whether `RecordingRegionOverlayWindow` can host a static image without changing Recording behavior; do not assume that its current dim layer is a frozen backdrop.

**Verify**: source inspection confirms the two bypasses (All-In-One empty backdrops/live known-rect capture and normal active-display-only freeze), the existing multi-display crop path is reusable, and no existing test already covers the complete All-In-One freeze contract.

### Step 2: Centralize all-display frozen-session preparation

Create the narrowest reusable preparation seam, preferably by extracting the existing all-display fast-path/SCK fallback logic from `prepareInlineAreaAnnotateFrozenSession` into a helper shared by normal Area capture and All-In-One. The helper must:

1. Resolve every current `NSScreen.displayID` on the main actor.
2. Attempt the optimized CoreGraphics path only when cursor/desktop exclusions permit it, gathering every display all-or-nothing and doing image work off the main actor where possible.
3. Fall back to `FrozenAreaCaptureSession.prepare(displayIDs: nil, ...)`, whose existing ScreenCaptureKit task group captures every connected display in parallel.
4. Return a session containing every display that existed at preparation time, or throw; never return a partial session and then treat it as frozen.
5. Preserve existing `excludeOwnApplication`, cursor, desktop icon/widget, prefetch, color-space, scale, and cancellation behavior.

Change normal `startAreaCapture` to use this all-display session instead of `targetDisplayID` for the frozen branch. Keep active-display resolution only where it is still needed for anchoring/primary-display behavior, not as a limit on frozen pixels. Continue using the existing lazy snapshot and transition re-freeze callbacks for topology/Space changes.

**Verify**: add a deterministic display-set/helper test proving a requested frozen session uses all current IDs; existing `FrozenAreaCaptureSessionTests` and multi-display crop tests remain green; source inspection finds no frozen normal-area call that passes only `[activeDisplayID]`.

### Step 3: Make All-In-One own a frozen session for the whole selection phase

When `AllInOneCaptureCoordinator.start(from:)` observes Freeze Screen enabled, prepare the all-display session before installing HUDs or starting the first selection. Do not capture the HUD itself. Store the session and its preparation state in the coordinator; cancel and invalidate it on every exit path.

- Initial first-drag selection must call the existing `AreaSelectionController.startSelection(backdrops:...)` with the frozen session’s backdrops, while retaining the All-In-One HUD-above-overlay ordering.
- If a last rectangle is available, refinement must use the same static backdrops for pixel snapping and must not refresh them from `AreaSelectionBackdropCapturer` with `isVisible: true`.
- The refinement UI must visibly remain over the frozen frame. Prefer a narrow All-In-One-owned static backdrop host that renders the captured `AreaSelectionBackdrop` per display and ignores mouse events, positioned below the refinement/HUD windows. It must close before dispatch and on cancel, and must not appear in the final screenshot because the captured pixels predate the host.
- If a screen-parameter change occurs, use the existing session refresh/lazy patterns; never replace a frozen display with a live backdrop merely because it was slow to prepare.
- If preparation fails or returns fewer snapshots than the current display set, show the existing capture failure, restore any hidden windows, close HUD/backdrop windows, and leave the coordinator inactive. Do not proceed live.

**Verify**: add coordinator/refinement tests for freeze-on session preparation, empty/backdrop-backed initial selection, frozen sampler precedence, cancel cleanup, and preparation failure without live fallback. Use synthetic `FrozenDisplaySnapshot` data; no Screen Recording permission is required for these tests.

### Step 4: Reuse the session for All-In-One dispatch

Transfer the frozen-session ownership safely from the coordinator to the selected capture operation before calling `cancel()`. Do not let coordinator cleanup invalidate a session that the capture operation still needs.

- **Area**: add a session-aware known-rectangle path that crops the selected rect from the shared session. Use `cropImage` for one display and `cropCompositeImage` when the selection spans displays, then save with the existing `saveProcessedImage`/naming/post-capture pipeline. Preserve `CaptureContext`, scale promotion, sound, and `lastCaptureResult`.
- **Capture Markup**: allow `startInlineAreaAnnotateCapture`/`InlineAreaAnnotateCoordinator` to accept the transferred session/backdrops, avoiding a second snapshot and preserving the existing inline annotation flow. The session must be invalidated after the inline operation completes or cancels.
- **OCR**: add a session-backed image path for the selected rect (single/cross-display crop) before OCR/QR processing. Preserve clipboard composition, notifications, link detection, and failure behavior.
- **Timer**: retain the selected rect, discard the selection-phase session when the HUD closes, and prepare a new all-display frozen session at the scheduled fire time before cropping. A timer must not capture the stale frame from the moment the user first opened All-In-One.
- **Window**: leave the mode dispatch unchanged so it enters the corrected normal frozen area/application path.
- **Scrolling, Fullscreen, Recording**: leave their current dispatch and capture semantics unchanged.

When Freeze Screen is disabled, all All-In-One area/OCR paths must retain their current live behavior. When Freeze Screen is enabled and a session is unavailable, fail explicitly rather than silently using `ScreenCaptureManager.captureArea` live.

**Verify**: focused routing tests cover the mode matrix, session transfer/invalidation exactly once, single-display and cross-display Area crops, Timer freshness, and the unchanged live path when the preference is false. Existing Annotate/clipboard and post-capture behavior remains covered by the current suites.

### Step 5: Update user-facing copy and technical documentation

If the UI description is changed, use the stable existing localization key `preferences-capture.freeze-area-description` and concise copy such as “Freeze all connected displays while selecting. Enable to hold still snapshots across your monitors.” Update `L10n.swift` and the Capture string catalog according to the localization skill; do not hard-code a new English sentence in Swift.

Update `docs/CAPTURE.md` to state that:

- Freeze Screen captures every connected display at session start, not only the active monitor.
- Frozen selections use one per-display session and the canonical composite crop for cross-monitor rectangles.
- All-In-One Area/Markup/OCR selection uses the same frozen session; Timer refreshes at fire time; Scrolling/Fullscreen/Recording remain outside this screenshot-area preference.
- The preference-off live path remains unchanged.

Update `docs/STRUCTURE.md` wherever it says frozen capture targets only the active display. Do not rewrite the broader Capture or Preferences plans.

**Verify**: CatalogTool reports `missing=0` and `extra=0`; `rg -n "active display first|active-display-only|All-In-One.*freeze|all connected displays" docs Notinhas/Resources/Localization/Features/Capture.xcstrings Notinhas/Shared/Localization/L10n.swift` finds no contradictory behavior description; no unrelated copy changes appear.

### Step 6: Run automated gates and perform the physical multi-monitor gate

Run the focused tests, default build, optional Video build when shared overlay code was touched, localization verification, formatting, and full default tests from the Commands table.

Then manually verify with the notebook display plus an external monitor showing distinguishable moving content:

1. Preferences → Capture → Freeze Screen off: All-In-One Area remains live during first drag/refinement and captures current pixels at commit, matching the existing live behavior.
2. Freeze on, no last rectangle: activate All-In-One, confirm both monitors become visibly static before first drag, move/refine the rectangle across displays, and confirm the result matches the frozen frame.
3. Freeze on, valid last rectangle: activate All-In-One, confirm refinement is over the static frame on both displays, then test Area, Capture Markup, and OCR.
4. Freeze on, normal Area capture: confirm both monitors freeze before selection, even when the rectangle starts and ends on only one display; cross-display selection is composited correctly.
5. Freeze on, Window mode: confirm the existing application-selection flow still works with all-display frozen backdrops.
6. Timer: confirm the selection frame is frozen but the final delayed capture uses a fresh frame at timer fire, not the initial stale snapshot.
7. Disconnect/reconnect or change Spaces only if safe in the test environment: confirm cancellation/restoration and no stuck frozen overlay. Do not treat an unstable display topology as a reason to use live fallback.
8. Scrolling, Fullscreen, and Recording remain unchanged; no All-In-One HUD/backdrop is included in saved pixels.

Record automated and manual results separately. Screen Recording and Accessibility permissions are required for the manual capture gate; use the signed debug app and do not save personal test captures in the repository.

## Stop conditions

- The executor can only make the final image frozen while the All-In-One selection/refinement remains live.
- Normal frozen Area capture still prepares only `activeDisplayID` or returns a partial multi-display session.
- A frozen session is invalidated before Area/Markup/OCR crop completion, or cleanup can invalidate a session transferred to Timer/Annotate.
- The static All-In-One backdrop host is captured into the output, intercepts mouse/keyboard events, or leaves a window behind after cancel/dispatch.
- A shared `RecordingRegionOverlayWindow` change affects Recording behavior and no focused regression test/build gate can prove safety.
- Freeze-on preparation silently falls back to live capture, or the implementation changes the freeze preference’s key/default.
- Fullscreen, Scrolling, or Recording behavior changes without an explicit new product decision.
- Physical dual-monitor validation cannot distinguish whether both displays were frozen; report the environment limitation instead of declaring the gate passed.

## Test plan

- Extend `AllInOneCaptureCoordinatorTests` with a testable freeze/session policy and mode matrix; avoid invoking real HUDs or Screen Recording APIs in unit tests.
- Add deterministic tests for all-display snapshot selection and all-or-nothing preparation. If the helper uses injected display IDs/providers, test one success per connected display and one failure that rejects a partial session.
- Extend `FrozenAreaCaptureSessionTests`/`ScreenCaptureAreaCropTests` only for missing cases in session reuse, display-set crop, and scale/coordinate preservation; do not duplicate existing composite coverage.
- Add a session-backed OCR/crop test seam if OCR is routed through a new image helper; preserve existing OCR payload tests.
- Run current `LiveAreaMouseUpSnapshotTests` to prove the Freeze-off live path and its all-or-nothing fast grab remain unchanged.
- Run default and optional Video builds when shared overlay code is touched, then perform the manual dual-monitor gate.

## Done criteria

- [ ] Freeze Screen remains off by default and uses the existing persisted key.
- [ ] Normal frozen Area/Application selection captures every connected display at freeze time, not only the active display.
- [ ] All-In-One honors Freeze Screen during initial selection and last-rectangle refinement with visibly static backdrops on every connected display.
- [ ] All-In-One Area, Capture Markup, and OCR reuse the frozen session for their final source; cross-display Area crops use the canonical composite path.
- [ ] All-In-One Timer refreshes a frozen session at fire time instead of using a stale selection-time image.
- [ ] Freeze-off live behavior remains unchanged.
- [ ] Scrolling, Fullscreen, and Recording semantics remain unchanged.
- [ ] Cancellation, display changes, mode handoff, and session invalidation restore windows and leave no stuck overlay.
- [ ] Focused tests, default build, required optional build, localization verification, and full default tests pass, with baseline failures recorded.
- [ ] Manual notebook-plus-external-monitor validation confirms both monitors freeze and the saved result matches the frozen frame.
