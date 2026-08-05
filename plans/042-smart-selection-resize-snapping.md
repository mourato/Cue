# Plan 042: Add native resize affordances and content-aware snapping to area refinement

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 474743c9..HEAD -- Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift Notinhas/Services/Capture/CaptureSelectionGeometry.swift Notinhas/Services/Capture/AreaSelectionBackdropCapturer.swift Notinhas/Services/Capture/AXElementSnapshot.swift Notinhas/Services/Capture/AXElementInspector.swift Notinhas/Features/Preferences/Models/PreferencesKeys.swift Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Services/Configuration/NotinhasConfigurationExporter.swift Notinhas/Services/Configuration/NotinhasConfigurationImporter.swift Notinhas/Services/Configuration/NotinhasConfigurationDefaultDocument.swift Notinhas/Resources/Localization/Features/Capture.xcstrings Notinhas/Shared/Localization/L10n.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `plans/036-capture-selection-refinement.md`, `plans/040-all-in-one-session-selection-lifecycle.md`
- **Category**: bug
- **Planned at**: commit `474743c9`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no` — cursor routing, AppKit overlay events, screen pixels, Accessibility queries, and All-In-One resize state must be integrated as one interaction path.
- **Reviewer required**: `yes` — the implementation crosses AppKit event handling, Screen Recording/Accessibility permissions, multi-display coordinates, and aspect-locked geometry.
- **Rationale**: The pure resolver can be tested deterministically, but the production behavior depends on WindowServer cursor rects, asynchronous backdrop capture, AX availability, and cross-display drag monitors. A fast isolated edit is not safe here.
- **Escalate when**: Snapping requires changing classic `AreaSelectionOverlayView`, introducing a new capture overlay host, prompting for Accessibility during a drag, changing the public capture result, or touching unrelated recording/video behavior beyond the shared cursor fix.

## Why this matters

The All-In-One refinement overlay already renders eight resize handles, but its cursor-rect fallback registers the entire interaction surface as a crosshair, so users can approach an edge without receiving a reliable native resize affordance. The resize path also accepts raw pointer geometry: when an edge crosses from the intended surface into a neighboring UI/color region, the selection can include the wrong region. This plan makes resize handles discoverable and adds stateless snapping that prioritizes semantic element bounds, then sharp visual/color boundaries, while immediately yielding to continued pointer movement.

The classic ⌘⇧4 area capture remains commit-on-mouseup. This plan changes the All-In-One refinement stage and the shared cursor behavior of `RecordingRegionOverlayWindow`; it does not add resize handles to `AreaSelectionOverlayView`.

## Current state

### Refinement ownership

- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` owns the global refinement rectangle and creates one `RecordingRegionOverlayWindow` per screen. `makeRegionOverlay(for:)` currently creates the overlay, assigns the delegate, enables interaction, and orders it front (`lines 94–101`). Resize callbacks arrive through `overlay(_:didResizeRegionTo:)` and are immediately passed through the existing aspect-lock helper (`lines 305–308`).
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:140–163` reads the existing All-In-One aspect-lock preference, creates the refinement controller, and starts the overlay session. The coordinator already publishes each changed rectangle to the HUD (`lines 166–169`).

### Shared overlay and cursor behavior

- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift:140–148` enables interaction by setting `ignoresMouseEvents`, exposing the view's interaction flag, retaining the window on the view, and calling `refreshCursor()`.
- `RecordingRegionOverlayView.handleAt(point:)` (`lines 317–350`) has eight hit regions, with corners checked before edges. `cursorFor(handle:)` (`lines 352–364`) already maps horizontal and vertical edges to `NSCursor.resizeLeftRight` / `resizeUpDown` and creates diagonal cursors for corners.
- `resetCursorRects()` currently adds one cursor rect covering the entire view (`lines 270–272`), using `.crosshair` whenever interaction is enabled. The dynamic `cursorUpdate`, `mouseMoved`, and `refreshCursor` paths call `updateCursorFor(point:)`, but WindowServer can reapply the full-view cursor rect and hide the resize affordance. Replace the broad fallback with a fallback cursor plus higher-priority handle cursor rects derived from the current highlight rectangle; retain dynamic updates for cross-display movement.
- Cross-display resize is driven by local/global event monitors (`lines 482–533`). The active handle is stored on mouse-down (`lines 653–667`), raw rectangles are computed from the original rectangle and pointer delta (`lines 580–589`), then sent to the delegate. Movement and re-selection use separate branches (`lines 592–613`) and must not invoke snapping.
- `RecordingRegionOverlayWindow` is reused by All-In-One, Recording, and Scrolling Capture. The cursor-rect correction is shared; snapping must be enabled only by the All-In-One refinement controller so existing recording/scrolling semantics do not change.

### Existing pixel and semantic seams

- `Notinhas/Services/Capture/AreaSelectionBackdropCapturer.swift:13–46` provides the async `AreaSelectionBackdropCapturing` seam and a production `CGWindowListCreateImage` implementation. XCTest defaults to `SyntheticAreaSelectionBackdropCapturer` (`lines 50–71`) to avoid Screen Recording TCC.
- `AreaSelectionBackdrop` stores a `CGImage`, display id, scale factor, and visibility in `Notinhas/Services/Capture/AreaSelectionBackdrop.swift:15–25`. The refinement implementation should cache one backdrop per active screen and map global AppKit points into that image; it must not capture the overlay itself.
- `Notinhas/Services/Capture/AXElementSnapshot.swift:17–57` already defines a testable AX value snapshot and `AXSnapshotProviding`. `AXAccessibilitySnapshotProvider` calls `AXUIElementCopyElementAtPosition` (`lines 61–75`). `AXElementInspector.findMeaningful` and `screenRect(forTopLeftRect:)` already implement the project's role filtering and coordinate conversion. Reuse these seams instead of duplicating AX role lists or prompting for permission during a drag.
- `SmartElementQueryService` has a debounced publisher, but the new resolver must not subscribe to a publisher per drag frame or emit diagnostic logs for every pointer position. Add a small provider/cache seam around the existing snapshot provider and inspector, with a permission check that returns no semantic candidate when Accessibility is unavailable.

### Existing preferences and configuration

- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift:54–65` contains the capture/screenshot keys and the existing All-In-One keys `captureAllInOneLastAreaRect` and `captureAllInOneAspectRatioLocked`.
- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift:187–207` contains the General-pane Overlay and Magnifier sections. Add the snapping controls to a capture-selection section in this pane, using `@AppStorage` and `SettingRow` conventions.
- Capture TOML is written under `[capture.screenshot]` by `NotinhasConfigurationExporter.writeCapture` (`lines 57–94`), read by `NotinhasConfigurationImporter.collectCapture` (`lines 128–183`), and seeded by `NotinhasConfigurationDefaultDocument.writeCapture` (`lines 54–82`). New values must be validated/clamped on import and included in the default document/export.
- User-facing copy belongs in `Notinhas/Resources/Localization/Features/Capture.xcstrings`; the `L10n.PreferencesCapture` bridge in `Notinhas/Shared/Localization/L10n.swift` is used for settings text that is not extracted cleanly. Follow `docs/LOCALIZATION.md`: edit the owning catalog, keep persisted keys raw, and run the catalog drift check.

### Product and project constraints

- `AGENTS.md` requires Swift 5.9 naming, `// MARK:` in large types, UI work on the main actor, and capture/image processing off the main actor. Notinhas-specific behavior should remain thin and focused on the capture → annotate/export loop.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup` for both `Notinhas` and `NotinhasTests` (`Notinhas.xcodeproj/project.pbxproj:43–57`), so new files under those roots are automatically target-visible; do not add manual PBX file references unless this project structure changes.
- Existing plan 036 explicitly preserves classic area capture and reuses `RecordingRegionOverlayWindow`; this plan must retain those decisions.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat 474743c9..HEAD -- <in-scope paths>` | No unexpected in-scope drift before implementation, or drift is reviewed and reported. |
| Pure snapping/geometry tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests -only-testing:NotinhasTests/CaptureSelectionGeometryTests` | All selected tests pass. |
| AX seam tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AXElementInspectorTests -only-testing:NotinhasTests/SmartElementQueryServiceTests` | Existing semantic-query tests pass without requesting real permissions. |
| Configuration tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/NotinhasConfigurationImporterTests -only-testing:NotinhasTests/NotinhasConfigurationServiceTests` | Import/export/default-document assertions pass. |
| Localization drift | `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` | `missing=0` and `extra=0`. |
| Format | `swiftformat Notinhas/Services/Capture Notinhas/Features/Capture Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Preferences Notinhas/Services/Configuration NotinhasTests/Services/Capture NotinhasTests/Features/Capture` | exit 0; only scoped Swift files are formatted. |
| Default build | `./scripts/build_and_run.sh --no-video-module` | Default Notinhas scheme builds and launches successfully. |
| Full default tests | `./scripts/run-tests.sh --skip-visual` | Default suite passes, apart from any already documented environment failures. |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md` — keep the classic area path stable and preserve the visual handoff flow.
- `.agents/skills/macos-app-engineering/SKILL.md` — AppKit overlay, cursor rects, WindowServer, and main-actor lifecycle.
- `.agents/skills/swift-concurrency-expert/SKILL.md` — async backdrop capture, cancellation, and MainActor handoff.
- `.agents/skills/testing-xctest/SKILL.md` — pure geometry and synthetic-image tests.
- `.agents/skills/localization/SKILL.md` — settings and capture copy.

## Scope

**In scope (modify only these source/test/document files):**

- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` — correct cursor-rect registration and expose only the minimal state/configuration seam needed by All-In-One snapping.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` — capture/refine backdrop context, maintain a cancellable semantic provider/cache, and apply snapping only in `didResizeRegionTo` before existing aspect-lock/finalization logic.
- `Notinhas/Services/Capture/CaptureSelectionGeometry.swift` — extend pure handle/edge helpers only if needed to keep active-edge and aspect-lock calculations testable.
- `Notinhas/Services/Capture/CaptureSelectionSnapping.swift` (create) — pure configuration, candidate types, image sampling/edge detection, candidate priority, and stateless rectangle resolution. Keep the core resolver independent of AppKit and Accessibility APIs where possible.
- `Notinhas/Services/Capture/CaptureSelectionSemanticBoundaryProvider.swift` (create) — testable adapter/cache over `AXSnapshotProviding` and `AXElementInspector`; no permission prompt in refinement.
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` — add stable keys for snap distance and color sensitivity.
- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` — expose the two capture-selection controls with a 5 px default snap distance and a user-adjustable color sensitivity.
- `Notinhas/Services/Configuration/NotinhasConfigurationExporter.swift` — export the new `[capture.screenshot]` values.
- `Notinhas/Services/Configuration/NotinhasConfigurationImporter.swift` — import, validate, and clamp the new values.
- `Notinhas/Services/Configuration/NotinhasConfigurationDefaultDocument.swift` — seed defaults in generated/default TOML.
- `Notinhas/Resources/Localization/Features/Capture.xcstrings` and `Notinhas/Shared/Localization/L10n.swift` — add localized settings labels/descriptions and any accessibility labels required by the new controls.
- `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift` (create) — pure resolver, candidate priority, image fixtures, and preference mapping tests.
- `NotinhasTests/Services/Capture/CaptureSelectionGeometryTests.swift` — extend only for new active-edge/aspect-lock cases if required.
- `NotinhasTests/Services/Capture/AXElementInspectorTests.swift` / `SmartElementQueryServiceTests.swift` — extend only where the new semantic adapter reuses an existing seam.
- `NotinhasTests/Services/Configuration/NotinhasConfigurationImporterTests.swift` and `NotinhasTests/Services/Configuration/NotinhasConfigurationServiceTests.swift` — cover import/export/default values.
- `plans/README.md` — add/update the status row for plan 042.

**Out of scope:**

- `Notinhas/Services/Capture/AreaSelectionWindow.swift` and `AreaSelectionOverlayView`: do not add resize-after-mouseup behavior to classic ⌘⇧4 capture.
- Moving the selection rectangle: no snapping while `isDragging`; the entire rectangle remains freely movable.
- New capture modes, new HUDs, crop presets, generic markup, recording/video behavior changes, or a new overlay window host.
- Automatic Accessibility permission prompts during refinement. If permission is absent, semantic candidates are unavailable and visual/color fallback continues.
- Logging raw screenshots, pixel buffers, AX labels, window titles, or other sensitive screen content.
- Changes to capture result types, capture output naming, clipboard/export composition, Sparkle, URL aliases, or unrelated configuration keys.

## Product decisions locked for this plan

1. Resize cursors follow macOS conventions: horizontal edges use `resizeLeftRight`, vertical edges use `resizeUpDown`, and corners use system-consistent diagonal resize cursors with the same direction semantics.
2. The attraction radius defaults to 5 screen points/pixels and is adjustable in Capture preferences. The color-difference sensitivity is separately adjustable; use a user-facing strictness/sensitivity control rather than exposing a raw color-space formula.
3. Candidate priority is semantic AX element boundary, then stable visual edge, then color transition. Priority wins over distance when both candidates are within the configured radius; distance breaks ties within one source.
4. Snapping is stateless and recalculated from raw pointer geometry on every resize update. Once the raw edge is outside the radius, the attraction is immediately defeated; do not add hysteresis or a latched snap target.
5. For corners, resolve the active horizontal and vertical edges independently and combine them. For aspect-locked corners, preserve the existing ratio helper and choose the closest valid ratio-preserving result; never silently unlock the aspect ratio.
6. AX permission is opportunistic. The provider may use `AXIsProcessTrusted()` as a gate, but it must not prompt. If untrusted, return no semantic candidate and continue with image/color detection.
7. Backdrops are captured asynchronously per display and cached outside the drag hot path. Tests use injected/synthetic images; production uses the existing `AreaSelectionBackdropCapturing` seam.

## Steps

### Step 1: Add characterization tests and pure snapping contracts

Create `CaptureSelectionSnapping.swift` with a pure, testable contract. It should represent:

- the active resize handle/axes;
- a normalized configuration with snap distance defaulting to 5 and bounded preference values;
- candidate source (`semantic`, `visual`, `color`) and candidate edge coordinate;
- a resolver that receives the original rect, raw proposed rect, active handle, candidate list/sample context, and optional aspect-lock information, then returns a rect plus the selected source for diagnostics/tests.

The resolver must only modify edges owned by the active handle. It must never modify a move operation, snap a non-active edge, cross the desktop bounds, or bypass the existing minimum size. Candidate selection must be deterministic: source priority first, then absolute distance, then stable coordinate ordering. Keep image sampling behind a small protocol/value seam so tests can use a synthetic two-region image without Screen Recording permission.

Add tests before or alongside the implementation for:

- no candidate outside the configured radius;
- semantic candidate wins over a closer color candidate;
- visual candidate wins over a color-only candidate at equal eligibility;
- color sensitivity changes eligibility for a subtle versus sharp boundary;
- left/right/top/bottom edges and all four corners;
- moving the selection does not snap;
- raw pointer movement beyond the radius immediately returns the unsnapped rect;
- minimum-size and desktop-boundary clamping remain intact;
- aspect-locked corner resize preserves ratio while using the closest valid snapped edge.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests -only-testing:NotinhasTests/CaptureSelectionGeometryTests` → all new and existing selected tests pass.

### Step 2: Implement semantic candidate adapter with a non-prompting fallback

Create `CaptureSelectionSemanticBoundaryProvider.swift` around the existing `AXSnapshotProviding` and `AXElementInspector` seams. The provider should accept a screen point (and optional owner PID if the caller already knows it), query the AX snapshot only when `AXIsProcessTrusted()` is true, walk to the meaningful element with `AXElementInspector.findMeaningful`, convert with `AXElementInspector.screenRect(forTopLeftRect:)`, and return only valid on-screen rects.

Add caching/throttling appropriate for drag updates: do not query AX for every pointer event when the pointer remains within the same candidate rect, and do not log every failed query. The provider must return `nil` on denied permission, unavailable element, invalid coordinates, or stale candidate. It must not call `ensureAccessibilityPermission()`.

Use existing `AXElementSnapshot` fixtures and fake providers for tests. Extend AX tests only to prove the adapter preserves the existing role filtering, parent walk, coordinate flip, and permission fallback.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AXElementInspectorTests -only-testing:NotinhasTests/SmartElementQueryServiceTests -only-testing:NotinhasTests/CaptureSelectionSnappingTests` → all selected tests pass without a permission prompt.

### Step 3: Add captured-image boundary and color sampling support

Use `AreaSelectionBackdropCapturing` to obtain a backdrop for each screen participating in the refinement. Keep the capture asynchronous and cancellable; never call `CGWindowListCreateImage` synchronously from a mouse event. Map global AppKit coordinates into each `AreaSelectionBackdrop.image` using the actual image dimensions relative to the captured screen frame, following the scale-derivation lesson already encoded in `AreaSelectionOverlayView` luma tests.

Implement a narrow scan around the active edge rather than scanning the whole desktop every frame. Detect only stable, sharp transitions across a run of neighboring samples. Compare colors using a named perceptual/difference helper and the configured sensitivity; do not compare packed RGBA bytes directly. A single noisy pixel, a soft gradient, or a transition caused only by the overlay must not create a candidate. Keep the sampler pure and test it with synthetic images containing uniform regions, sharp vertical/horizontal boundaries, subtle gradients, and one-pixel noise.

When the backdrop is unavailable, stale, invisible, or lacks valid pixel data, skip visual/color candidates without failing the resize. Keep semantic snapping available independently.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests -only-testing:NotinhasTests/AreaSelectionBackdropCapturerTests -only-testing:NotinhasTests/AreaSelectionOverlayLumaSamplingTests` → all selected tests pass and no live screen capture is attempted under XCTest.

### Step 4: Fix cursor-rect registration and preserve shared overlay behavior

Update `RecordingRegionOverlayView.resetCursorRects()` so it registers a fallback cursor first and handle-specific cursor rectangles afterward. Use the current local highlight rect, the existing hit size, and corner-first precedence. Keep `cursorUpdate`, `mouseMoved`, `mouseDown`, cross-display mouse-up, `refreshCursor()`, and `close()` behavior consistent with the existing state machine. Ensure a stale resize cursor is restored to the arrow when interaction is disabled or the window closes.

If the diagonal cursor implementation cannot use a public AppKit cursor, keep the existing generated diagonal cursor but centralize/cache the two diagonal cursor instances so a new `NSCursor`/`NSImage` is not allocated during every mouse event. Do not alter cursor behavior for the move or reselect states.

Add deterministic coverage for handle-to-direction mapping and fallback behavior. If pure testing requires extraction, add a small AppKit-free handle geometry helper rather than flashing a full-screen overlay in XCTest.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests -only-testing:NotinhasTests/CaptureSelectionGeometryTests` → handle/cursor mapping tests pass; then `./scripts/build_and_run.sh --no-video-module` → default build succeeds.

### Step 5: Integrate snapping into All-In-One resize only

In `AllInOneSelectionRefinementController`:

1. Capture the configured snapping preferences when the refinement session begins.
2. Start cancellable per-display backdrop preparation from `present()` (or an equivalent session-owned method) and tear it down in `tearDown()`/`deinit`.
3. Maintain the active resize handle from the existing `beginResizeIfNeeded` path. On `overlay(_:didResizeRegionTo:)`, treat the delegate rectangle as raw proposed geometry, read the current screen pointer from the existing main-thread event path, resolve semantic/visual/color candidates, and then feed the result through the existing aspect-lock helper and `updateRect`.
4. Apply no resolver call in `didMoveRegionTo` or `didReselectWithRect`.
5. Recompute from the raw proposed rectangle on every callback. Do not use the previously snapped rectangle as the next raw input, otherwise the 5 px radius becomes sticky.
6. Preserve `finishInteraction`, minimum size, cross-display clamping, HUD updates, Escape teardown, and last-rect persistence. If the pointer crosses to another display, use that display's backdrop/candidate context and keep the current handle.

Prefer injecting the backdrop capturer, semantic provider, and screen-frame source behind protocols/closures so unit tests do not need real screens. Do not change `RecordingRegionOverlayDelegate` unless there is no safe way to obtain the existing `NSEvent.mouseLocation`; if the protocol must change, update every conformer (Recording and Scrolling) and stop for review before widening the scope.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests -only-testing:NotinhasTests/CaptureSelectionGeometryTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` → all selected tests pass; `./scripts/build_and_run.sh --no-video-module` → default build succeeds.

### Step 6: Expose and persist the two tuning controls

Add stable `PreferencesKeys` entries for snap distance and color sensitivity. Use a 1–20 px bounded control with default 5 px. For color sensitivity, use a localized user-facing strictness/sensitivity control backed by a stable numeric/enum raw value; keep the storage value independent of localized text. Clamp invalid imported values to the documented range and fall back to defaults when missing.

Add the controls to the Capture preferences pane near the existing selection overlay/magnifier settings. The descriptions must explain that snapping applies to resizing only, that semantic snapping requires Accessibility permission, and that image/color fallback remains available without that permission. Do not add a permission prompt to the settings control; the existing Permissions tab remains the permission entry point.

Update TOML export/import/default document under `[capture.screenshot]` (or a clearly documented nested capture-selection section if the existing reader supports it) and add tests for missing/default, valid, invalid, round-trip, and clamped values. Add English source strings to `Capture.xcstrings` and corresponding `L10n` entries as required by the localization workflow.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/NotinhasConfigurationImporterTests -only-testing:NotinhasTests/NotinhasConfigurationServiceTests` → configuration tests pass; `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` → `missing=0` and `extra=0`.

### Step 7: Run focused and full validation

Run formatting only on touched Swift paths, then the focused tests and default build. Run the full default suite with `--skip-visual`; do not claim the visual gate is covered by that flag. For manual validation, grant Screen Recording and Accessibility as needed, start All-In-One, create/refine an area, and verify:

- every edge/corner shows the expected macOS resize cursor before mouse-down;
- semantic element boundary wins over a nearby color edge;
- a sharp color boundary is selected without including the adjacent region;
- subtle gradient/noise does not create an unwanted snap at strict sensitivity;
- changing sensitivity/radius in Preferences affects a subsequent refinement session;
- moving beyond the radius immediately defeats the attraction;
- moving the whole rectangle never snaps;
- aspect lock, minimum size, multi-monitor crossing, HUD repositioning, Escape, and teardown still work;
- absence of Accessibility permission does not block refinement and uses visual/color fallback;
- classic ⌘⇧4 remains commit-on-mouseup and unchanged.

**Verify**: run the commands in the Commands table and record their exit status/output in the implementation handoff. The manual gate must be reported separately from automated XCTest results.

## Test plan

| File | Cases |
|---|---|
| `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift` | Candidate priority; distance/tolerance; immediate snap defeat; semantic fallback; sharp versus subtle image boundaries; noise/gradient rejection; all handles/corners; no move snapping; aspect-lock preservation; minimum/bounds behavior. |
| `NotinhasTests/Services/Capture/CaptureSelectionGeometryTests.swift` | Any new pure active-edge/aspect-lock helpers, preserving all existing geometry cases. |
| `NotinhasTests/Services/Capture/AXElementInspectorTests.swift` | Existing role filtering and coordinate conversion remain valid if the new adapter exposes shared helpers. |
| `NotinhasTests/Services/Capture/SmartElementQueryServiceTests.swift` | Permission-denied/no-prompt and provider/cache behavior only if the implementation reuses this seam. |
| `NotinhasTests/Services/Configuration/NotinhasConfigurationImporterTests.swift` | New keys import, invalid values reject or clamp according to existing reader conventions, and missing values preserve defaults. |
| `NotinhasTests/Services/Configuration/NotinhasConfigurationServiceTests.swift` | Export/default document contains the new keys and round-trips through the existing configuration service. |

Follow `AreaSelectionOverlayTestCase` only for tests that genuinely require an overlay view. Prefer pure XCTest with synthetic `CGImage` fixtures and fake AX providers; do not add real Screen Recording or Accessibility dependencies to the default unit-test path.

## Done criteria

- [ ] `resetCursorRects()` no longer makes the full active overlay permanently crosshair-shaped; all eight handles expose the correct resize direction on hover.
- [ ] Diagonal cursor instances are cached/reused and no stale resize cursor survives disable/close.
- [ ] `CaptureSelectionSnapping` has deterministic, pure tests for semantic > visual > color priority and the configured radius/tolerance.
- [ ] Semantic snapping uses existing AX filtering/conversion seams and never prompts during refinement.
- [ ] Pixel/color fallback uses the existing async backdrop capture seam, ignores overlay pixels, and avoids per-frame full-screen image work.
- [ ] Snapping applies only while resizing in All-In-One; move, reselect, classic ⌘⇧4, Recording, and Scrolling behavior remain within their prior contracts.
- [ ] Continued pointer movement outside the radius immediately defeats attraction; no hysteresis or sticky target exists.
- [ ] Minimum size, desktop bounds, multi-display drag, and aspect lock remain correct.
- [ ] Preferences expose adjustable snap radius (default 5 px) and color sensitivity; values persist and round-trip through configuration import/export.
- [ ] Localization catalog verification reports `missing=0` and `extra=0`.
- [ ] Focused tests, default build, and `./scripts/run-tests.sh --skip-visual` pass, with any pre-existing failures explicitly recorded.
- [ ] Manual Screen Recording/Accessibility capture smoke test is reported separately and covers both permission states.
- [ ] No files outside the Scope list are modified; `git status --short` confirms the boundary.
- [ ] `plans/README.md` status row for plan 042 is updated.

## STOP conditions

Stop and report back; do not improvise, if:

- The current `RecordingRegionOverlayWindow` or All-In-One refinement code differs materially from the excerpts above.
- The only viable cursor fix requires rewriting `AreaSelectionOverlayView` or changing classic ⌘⇧4 from commit-on-mouseup.
- Screen Recording capture cannot be made asynchronous/injectable, or the implementation would capture the Notinhas overlay into the backdrop.
- Accessibility queries require prompting during a drag, blocking the main thread, or exposing AX labels/window titles in diagnostics.
- Semantic candidate discovery requires changing the capture result model or broadening Smart Element Capture beyond this refinement flow.
- A resolver candidate can remain latched after the raw edge leaves the configured radius.
- Aspect lock, minimum size, or cross-display bounds cannot be preserved without changing out-of-scope geometry contracts.
- A protocol change would require unrelated behavioral changes in Recording or Scrolling; stop and propose the smallest compatibility seam instead.
- A verification command fails twice after a reasonable fix attempt, or the default build requires enabling the optional Video module.
- Localization/catalog verification reports drift that cannot be explained by the new keys.

## Maintenance notes

- Any future capture overlay that reuses `RecordingRegionOverlayWindow` inherits the cursor-rect registration rules; review handle hit regions and cursor fallback together when changing the highlight geometry.
- The snapping resolver must stay pure and stateless. Future snapping sources should add candidates with an explicit priority rather than embedding source-specific conditionals inside pointer handling.
- Backdrop freshness and AX cache invalidation are the main correctness risks when the frontmost app/window changes during refinement. Refresh or invalidate those caches on screen/app transitions before adding more candidate types.
- Do not log screenshot pixels, AX labels, or full screen rectangles beyond the existing diagnostic conventions. Test fixtures should remain synthetic and should not persist screen content.
- Explicitly deferred follow-up: applying the same content-aware snapping to classic ⌘⇧4 or to rectangle movement. Those are separate product decisions and must not be inferred from this plan.
