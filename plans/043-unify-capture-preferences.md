# Plan 043: Unify General and Screenshot preferences into one Capture flow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat cf730ede..HEAD -- Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings docs/PREFERENCES.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `cf730ede`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — the pane state, section order, localization, documentation, and optional Video-module conditional layout must remain consistent.
- **Reviewer required**: yes — this is a user-facing Preferences reorganization with a conditional Recording pane and a manual visual acceptance gate.
- **Rationale**: The code change is localized to one SwiftUI view, but it changes discoverability, localized section ownership, and both Video-off and Video-on render paths. A focused implementer with a final UI review is the narrowest safe profile.
- **Escalate when**: The change requires renaming persisted `UserDefaults`/TOML keys, changing `AfterCaptureMatrixView` or recording behavior, modifying root Preferences tabs, or touching capture runtime code.

## Why this matters

The Capture preferences currently split related screenshot settings between nested `General` and `Screenshot` segments. This makes the user switch panes to understand one capture workflow, and the nested `General` label duplicates the root Preferences `General` tab. The selected product direction is one unified Capture surface ordered by the user flow: capture environment → selection → screenshot behavior → special modes → output → post-processing → after-capture actions. The change must preserve every existing preference key and behavior; it is a presentation and documentation reorganization, not a migration.

## Current state

### Relevant files

- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` — owns the nested Capture pane picker, all screenshot/shared setting rows, and the optional Recording pane.
- `Notinhas/Shared/Localization/L10n.swift` — declares the `PreferencesCapture` section and row strings used by the view.
- `Notinhas/Resources/Localization/Features/Capture.xcstrings` — owning string catalog fragment for Capture localization ids.
- `docs/PREFERENCES.md` — reference inventory of Preferences tabs, sections, keys, and after-capture behavior.
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` — persisted keys; do not change this file for this plan.
- `Notinhas/Features/Preferences/Components/PreferencesAfterCaptureMatrixView.swift` — action matrix; keep its behavior and implementation unchanged.
- `Notinhas/Features/Preferences/Components/PreferencesScreenshotDefaultPresetPicker.swift` — default Annotate preset row; keep its behavior and implementation unchanged.

### Pane state today

`PreferencesCaptureSettingsView.swift:11-41` defines `CaptureSettingsPane` as `.general`, `.screenshot`, and conditional `.recording`. With Video disabled it returns `[.general, .screenshot]`; with Video enabled it returns all three. The picker is rendered at `PreferencesCaptureSettingsView.swift:122-140`, and the body gates the shared sections with `selectedPane == .general` or `selectedPane == .screenshot`.

The target state is:

- `.capture` replaces the two non-recording panes and contains all General + Screenshot content.
- When the Video module is disabled, show the unified Capture content directly without an unnecessary segmented picker.
- When the Video module is enabled, show a two-segment picker labeled `Capture` and `Recording`; the Recording segment and all of its current rows stay unchanged.
- `selectedPane` defaults and reconciles to `.capture`.

### Current section blocks and settings

The current General blocks are at `PreferencesCaptureSettingsView.swift:143-245`, `:368-428`, and `:701-718`:

- App Windows: include Notinhas windows in screenshots and, conditionally, recordings.
- Desktop: hide desktop icons and desktop widgets.
- Overlay: dim outside the selection area.
- Magnifier Zoom: reverse scroll-wheel zoom direction.
- Selection Snapping: snap distance and color sensitivity; the copy explicitly says this applies to All-In-One resizing only.
- Output Naming: screenshot/recording filename templates, token help, previews, and reset.
- After Capture: `AfterCaptureMatrixView` plus Auto-Crop Subject.

The current Screenshot blocks are at `PreferencesCaptureSettingsView.swift:249-366`:

- Format: Show Cursor, Freeze Screen, Image Format, and conditional WebP/JPEG notes.
- Preset: `PreferencesScreenshotDefaultPresetPicker`.
- Scrolling Capture: session hints and guidance note.
- OCR: success notification and link detection.

The current Format section mixes capture behavior and file encoding. The current After Capture section places Auto-Crop Subject beside the routing matrix even though its localized description says it applies to background removal in both Capture and Annotate (`L10n.swift:3071-3084`).

### Required target order and grouping

Render the unified `.capture` content in exactly this order:

1. **Capture Environment**
   - Include in Screenshots.
   - Include in Recordings when `NOTINHAS_VIDEO_MODULE` is compiled and the runtime module is enabled.
   - Hide desktop icons.
   - Hide desktop widgets.
2. **Selection**
   - Show selection area overlay.
   - Reverse magnifier zoom direction.
   - All-In-One Selection Snapping controls, retaining descriptions that state they apply to resize refinement only.
3. **Screenshot Behavior**
   - Freeze Screen.
   - Show Cursor.
4. **Specialized Capture**
   - Scrolling Capture session hints and guidance.
   - OCR success notification and link detection.
5. **Output**
   - Image Format and its existing WebP/JPEG notes.
   - Screenshot and conditional Recording filename templates, token help, previews, and reset.
6. **Post-Processing**
   - Default Annotate Preset.
   - Auto-Crop Subject.
7. **After Capture**
   - `AfterCaptureMatrixView` only; do not change its action defaults, storage, or behavior.

Use the existing `Section` and `SettingRow` patterns. Do not create a second settings model or rename persisted keys to represent the new visual groups.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift check | `git diff --stat cf730ede..HEAD -- Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings docs/PREFERENCES.md` | Empty output, or intentional pre-existing changes reviewed against this plan before proceeding. |
| Focused preferences tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/PreferencesCoreTests` | Exit 0; all PreferencesCoreTests pass. |
| Localization verification | `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` | `missing=0` and `extra=0`; if the known unrelated hardcoded Snapzy path failure appears, report it without modifying unrelated localization tooling. |
| Default build | `./scripts/build_and_run.sh --no-video-module --verify` | Default Notinhas scheme builds and launches successfully. |
| Video-module build | `./scripts/build_and_run.sh --video-module --verify` | Notinhas Video / Debug+Video builds and launches successfully. |
| Full default tests | `./scripts/run-tests.sh` | Exit 0, or existing unrelated failures are recorded explicitly in the handoff. |

## Suggested executor toolkit

- Read `.agents/skills/macos-app-engineering/SKILL.md` before changing the SwiftUI Preferences layout.
- Read `.agents/skills/localization/SKILL.md` before changing `L10n.swift` or `Capture.xcstrings`.
- Use `.agents/skills/delivery-workflow/SKILL.md` for the default and optional Video-module validation commands.
- Use `swiftformat` only on the touched Swift file after the layout change; do not format unrelated source.

## Scope

**In scope** (the only files to modify):

- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` — pane state and unified section order/grouping.
- `Notinhas/Shared/Localization/L10n.swift` — new merged section ids and removal of obsolete section ids only when no longer referenced.
- `Notinhas/Resources/Localization/Features/Capture.xcstrings` — matching source-catalog entries and removal of obsolete ids only when no longer referenced.
- `docs/PREFERENCES.md` — update the Capture tab reference to describe the unified pane and exact section order.
- `plans/README.md` — update plan 043 status when the executor finishes.

**Out of scope** (do NOT touch, even though they look related):

- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift` and all TOML importer/exporter/default-document files — persisted keys and configuration format must remain stable.
- `Notinhas/Features/Preferences/Components/PreferencesAfterCaptureMatrixView.swift` — action matrix behavior is unchanged.
- `Notinhas/Features/Preferences/Components/PreferencesScreenshotDefaultPresetPicker.swift` — preset loading and persistence are unchanged.
- The Recording pane rows, recording runtime, capture runtime, menu bar, root Preferences tabs, or any other Preferences tab.
- New preference values, new capture modes, new collapsible controls, or broad visual redesign.
- Unit-test changes unless a compile-safe, deterministic pane-availability assertion becomes necessary; do not add screenshot/UI snapshot tests for this reordering.

## Git workflow

- Branch: `advisor/043-unify-capture-preferences` (or the repository's active branch convention if the orchestrator has already assigned an isolated branch).
- Commit message: `feat(preferences): unify capture settings layout`.
- Do not push or open a PR unless the operator explicitly instructs it.

## Steps

### Step 1: Confirm the drift baseline and identify localization references

Run the drift check and inspect the live view, localization bridge, catalog fragment, and Preferences documentation. Use `rg` to confirm that the old section ids (`appWindowsSection`, `desktopSection`, `overlaySection`, `magnifierZoomSection`, `selectionSnappingSection`, `screenshotFormatSection`, `screenshotPresetSection`, `scrollingCaptureSection`, `outputNamingSection`, `afterCaptureSection`, and `ocrSection`) are not referenced outside the intended Preferences view and localization sources before removing or replacing any of them.

**Verify**: `rg -n "appWindowsSection|desktopSection|overlaySection|magnifierZoomSection|selectionSnappingSection|screenshotFormatSection|screenshotPresetSection|scrollingCaptureSection|outputNamingSection|afterCaptureSection|ocrSection" Notinhas NotinhasTests docs` → every match is understood; no unrelated consumer requires an old section id to remain.

### Step 2: Replace the nested General/Screenshot pane state with unified Capture state

Update `CaptureSettingsPane` and the picker logic in `PreferencesCaptureSettingsView.swift`:

1. Replace `.general` and `.screenshot` with `.capture`.
2. Keep conditional `.recording` exactly as the optional Video-module pane.
3. Make `availablePanes(videoModuleEnabled:)` return `[.capture]` with Video disabled and `[.capture, .recording]` when the runtime Video module is enabled.
4. Default and reconcile `selectedPane` to `.capture`.
5. Use `L10n.Preferences.captureTab` for the optional unified Capture segment label.
6. Do not render a one-item segmented picker when only `.capture` is available; the unified content should occupy the view directly in the default Video-off build.
7. Preserve the existing notification-based reconciliation when Video availability changes.

Change all shared-content conditions from `.general`/`.screenshot` to `.capture`; leave every `.recording` condition and its implementation unchanged.

**Verify**: `./scripts/build_and_run.sh --no-video-module --verify` → the default scheme builds, launches, and contains no compile/reference errors for the removed pane cases.

### Step 3: Reorder and merge the unified Capture sections

Inside the `.capture` form content, rearrange existing rows into the target order from Current state. Use these exact grouping rules:

- Combine App Windows and Desktop into `Capture Environment`.
- Combine Overlay, Magnifier Zoom, and Selection Snapping into `Selection`.
- Move Freeze Screen and Show Cursor into `Screenshot Behavior`, in that order.
- Combine Scrolling Capture and OCR into `Specialized Capture`, preserving their existing info text and row descriptions.
- Combine Image Format and Output Naming into `Output`; preserve both format warnings, filename token text, live previews, and reset action.
- Combine the default Annotate preset and Auto-Crop Subject into `Post-Processing`; preserve both bindings and the existing Auto-Crop explanation.
- Leave `AfterCaptureMatrixView()` in its own final `After Capture` section, with Auto-Crop removed from that section.

Do not alter any `@AppStorage` key, binding, default, conditional compilation guard, permission flow, or action matrix call. Keep `SettingRow` controls and existing component boundaries unless a small local extraction is required to keep the SwiftUI body type-checkable.

**Verify**: `swiftformat Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` followed by `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/PreferencesCoreTests` → formatting completes and the PreferencesCoreTests suite passes.

### Step 4: Update section localization without changing persisted vocabulary

Add localized section ids for the merged headings, using the existing `preferences-capture.*` ownership and the project’s `L10n`/String Catalog conventions. Suggested source values are:

- `Capture Environment`
- `Selection`
- `Screenshot Behavior`
- `Specialized Capture`
- `Output`
- `Post-Processing`

Remove obsolete section ids from `L10n.swift` and `Capture.xcstrings` only after Step 1 confirms they have no remaining production references. Keep all row ids and user-facing descriptions that still describe unchanged settings. Do not localize or change stored filename templates, preference keys, capture type raw values, or action identifiers.

**Verify**: `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` → `missing=0` and `extra=0`, subject only to the documented unrelated Snapzy-path issue; no new hardcoded user-facing strings appear in the Swift view.

### Step 5: Update the Preferences reference documentation

Revise `docs/PREFERENCES.md:26-49` so it no longer describes three panes as General / Screenshot / Recording. Document:

- Capture as one unified pane with the seven sections in exact order.
- The optional Recording pane remains conditional on the Video module.
- Which existing keys belong to each new section.
- That Selection Snapping applies only to All-In-One resizing.
- That Auto-Crop Subject is grouped under Post-Processing and applies to capture background removal and Annotate.
- That the after-capture matrix remains the final routing section.

Keep the storage-pattern and after-capture-matrix documentation consistent with the existing `PreferencesManager` and `PreferencesKeys` contracts. Do not document a new key or migration.

**Verify**: `rg -n "General pane|Screenshot pane|Capture.*three panes|Capture Environment|Post-Processing|After Capture" docs/PREFERENCES.md` → the old pane description is gone and the unified structure is present.

### Step 6: Validate both product variants and perform the manual UI gate

Run the focused tests, localization verification, default build, optional Video-module build, and full default test suite from the Commands table. Then manually inspect Preferences:

- Video module off: Capture opens directly to one unified scrollable form; there is no General/Screenshot segmented control.
- The groups appear in the exact seven-section order and all existing rows are reachable.
- Changing format, cursor, freeze, naming, preset, OCR, and after-capture values persists after closing and reopening Preferences.
- Video module on: the optional picker shows Capture and Recording; Recording remains available and unchanged.
- The Recording pane still shows its existing format, quality, behavior, controls, overlay, and audio sections.
- Optional Video disabled at runtime returns safely to Capture without a stale `.recording` selection.

Record automated and manual results separately. The manual gate is a Preferences UI check and does not require Screen Recording, Accessibility, Microphone, or cloud permissions.

**Verify**: `./scripts/run-tests.sh` plus both build commands → commands pass or any unrelated pre-existing failures are explicitly recorded; manual checklist is completed.

## Test plan

- Keep `NotinhasTests/Features/Preferences/PreferencesCoreTests.swift` unchanged unless the executor discovers that pane availability must be extracted into a testable non-UI type. Existing tests cover preference model behavior and tab identity, not visual section order.
- Run `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/PreferencesCoreTests` after the view refactor.
- Run the full default `./scripts/run-tests.sh` before handoff.
- Verify the default Video-off and optional Video-on compile paths separately because the nested pane enum is conditional.
- Perform the manual UI checklist in Step 6; do not substitute a source-only test for the visual order check.

## Done criteria

- [ ] General and Screenshot content render as one unified Capture pane; no General/Screenshot inner segments remain.
- [ ] With Video disabled, no one-item segmented picker is shown; with Video enabled, the only inner segments are Capture and Recording.
- [ ] Unified sections render in this exact order: Capture Environment, Selection, Screenshot Behavior, Specialized Capture, Output, Post-Processing, After Capture.
- [ ] All existing preference bindings, defaults, UserDefaults keys, TOML keys, and runtime behavior remain unchanged.
- [ ] Selection Snapping remains clearly labeled as All-In-One resize refinement behavior.
- [ ] Auto-Crop Subject is displayed under Post-Processing, while `AfterCaptureMatrixView` remains unchanged and final.
- [ ] Recording rows and conditional behavior remain unchanged in both Video-off and Video-on builds.
- [ ] `swiftformat` passes on the touched Swift view.
- [ ] Focused PreferencesCoreTests pass.
- [ ] Localization verification reports `missing=0` and `extra=0`, or the known unrelated CatalogTool path issue is explicitly recorded without widening scope.
- [ ] Default and optional Video-module builds pass.
- [ ] Full default tests pass, with unrelated pre-existing failures documented if present.
- [ ] `docs/PREFERENCES.md` accurately describes the new structure and existing keys.
- [ ] No files outside the Scope list are modified; `git status --short` confirms the boundary.
- [ ] `plans/README.md` status row for plan 043 is updated.

## STOP conditions

Stop and report back; do not improvise, if:

- The current `PreferencesCaptureSettingsView.swift` pane enum, conditions, or section blocks differ materially from the Current state excerpts.
- Removing the old section localization ids reveals a consumer outside the planned Preferences view or requires changing unrelated localization ownership.
- The unified body cannot compile without changing persisted preference keys, configuration import/export, or runtime capture behavior.
- The Recording pane would need row reordering or behavior changes to support the two-segment picker.
- The one-item picker cannot be hidden without changing root Preferences tab behavior or the fixed Preferences window contract.
- The requested UI requires collapsible groups, a new design system, a new preference, or a change to the product decision to keep Recording separate.
- Either build path requires enabling unrelated modules or changing signing/project configuration.
- Localization verification fails for reasons other than the already documented unrelated hardcoded Snapzy path, or fails twice after a reasonable fix attempt.
- Any verification command fails twice after a reasonable fix attempt.
- The implementation needs to touch any out-of-scope file.

## Maintenance notes

- Future Capture settings should be assigned to one of the seven user-flow sections before being appended to the view. Avoid restoring a General/Screenshot split unless a new product decision explicitly requires it.
- Keep persisted keys and configuration names independent from visual section names; users may import TOML files created before this reorganization.
- The optional Video module is the main compile-time boundary. Any new shared row must be reviewed for whether it applies to screenshots, recordings, or both before placement in Capture Environment or Output.
- If the Capture form becomes too tall at the fixed 760×550 Preferences window size, the next change should be a separate approved disclosure/scrolling design plan; do not add collapsible groups in this plan.
- Reviewers should verify that the section order is identical in the code and `docs/PREFERENCES.md`, and that Auto-Crop was moved visually without changing its Annotate/capture behavior.
