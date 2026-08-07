# Plan 083: Customize All-In-One modes and order

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 49f163e4..HEAD -- Notinhas/Features/Capture/AllInOne Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift Notinhas/Features/Preferences/Models/PreferencesKeys.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings NotinhasTests/Features/Capture docs/PREFERENCES.md docs/CAPTURE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/035, 036, 037, 038, 039, 040, 041 (completed
  All-In-One capture foundation)
- **Category**: direction
- **Planned at**: commit `49f163e4`, 2026-08-07

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — the store, Capture preferences, All-In-One
  session state, and HUD consume one shared mode-order contract.
- **Reviewer required**: `yes` — this changes the capture HUD's available
  actions, persistence, optional Video behavior, and child-shortcut routing.
- **Rationale**: The change is bounded but crosses UserDefaults, SwiftUI
  preferences, MainActor session state, optional Video availability, and
  manual Screen Recording/WindowServer behavior. The existing shared reorder
  component keeps the implementation small, but the runtime contract needs a
  focused review.
- **Escalate when**: The implementation needs to alter standalone capture
  menus/global shortcuts/deep links, add TOML import/export, change the
  `AllInOneModeShortcutSettings` storage keys, or introduce a second reorder
  component.

## Why this matters

All-In-One currently exposes a fixed mode list, while Quick Access already lets
users choose which actions appear and drag them into a preferred order. This
plan gives All-In-One the same user control without changing what the modes do
or removing their standalone entry points. The enabled/order choice persists,
Recording remains conditional on the optional Video module, and a hidden mode's
All-In-One child shortcut is retained but cannot activate until the mode is
shown again.

The earlier All-In-One documentation said that Recording stays last. This plan
explicitly supersedes that presentation rule: when Video is available,
Recording participates in the user's custom order; when Video is unavailable,
it is omitted from the visible list and its saved position is retained.

## Product decisions already confirmed

These decisions are settled and must not be reopened during implementation:

- Add a customization section under Preferences → Capture.
- Reuse `PreferencesReorderToggleList`; do not build another drag/toggle list.
- “Remove” means hide/disable the mode in the All-In-One HUD only. Standalone
  menus, global shortcuts, and deep links remain unchanged.
- A disabled mode's child shortcut remains persisted/configurable, but the
  All-In-One HUD ignores it while the mode is disabled. Re-enabling the mode
  restores the same shortcut.
- All currently available modes may be freely reordered, including Recording.
- At least one currently usable non-Video mode must remain enabled. This
  concrete invariant prevents the All-In-One HUD from becoming empty when the
  optional Video module is later disabled; it does not force Area to remain
  enabled.
- Reset restores the default order and enables every available mode.
- No editing control is added inside the capture HUD; settings are the single
  customization surface.

## Current state

### All-In-One catalog and runtime

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift:10-32` owns
  the stable `AllInOneCaptureMode` enum and currently returns a fixed default
  list from `availableModes(videoEnabled:)`; Recording is appended only when
  Video is enabled.

  ```swift
  enum AllInOneCaptureMode: String, CaseIterable, Identifiable, Equatable {
      case area
      case fullscreen
      case window
      case annotate
      case scrolling
      case timer
      case ocr
      case recording

      static func availableModes(videoEnabled: Bool) -> [AllInOneCaptureMode] {
          var modes: [AllInOneCaptureMode] = [
              .area, .fullscreen, .window, .annotate, .scrolling, .timer, .ocr,
          ]
          if videoEnabled {
              modes.append(.recording)
          }
          return modes
      }
  }
  ```

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift:13-34`
  stores the HUD's `availableModes`, starts `selectedMode` as `.area`, and
  rejects activation of a mode not in that list. Change the initializer to
  receive the already-normalized configured list and select its first element;
  do not make the view read UserDefaults directly.

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:54-64`
  creates the session state with the fixed default initializer. The
  coordinator is the correct runtime boundary: it should ask the new store for
  configured, enabled modes using the current `VideoModuleAvailability` and
  pass that snapshot to the state. The existing toolbar already renders
  `session.availableModes` in order, so no toolbar layout redesign is needed.

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:549-557`
  passes `sessionState.availableModes` to
  `AllInOneModeShortcutSettings.mode(matching:in:)`. Keeping disabled modes out
  of that snapshot automatically makes their child keys inert without deleting
  their stored bindings.

- `Notinhas/Features/Capture/AllInOne/AllInOneModeShortcutSettings.swift:61-67`
  already accepts an explicit available-mode list. Do not change its key
  format or persistence; add only a regression test proving a mode absent from
  the configured list cannot be returned by matching.

### Existing customization pattern

- `Notinhas/Features/QuickAccess/Models/QuickAccessActionConfigurationStore.swift:11-146`
  is the closest model: a `@MainActor` `ObservableObject`, injectable
  `UserDefaults`, normalized raw-value arrays, published order/enabled state,
  move, toggle, reset, and fail-soft completion of missing catalog entries.
  The new All-In-One store should follow this shape but must not overload the
  Quick Access store or its keys.

- `Notinhas/Features/Preferences/Components/PreferencesReorderToggleList.swift`
  owns the shared drag handle, toggle, drop handling, and reset button. It
  accepts `canToggle`, `onMove`, and an empty accessory, which covers this
  feature.

- `Notinhas/Features/Preferences/Components/PreferencesQuickAccessActionCustomizationView.swift:33-81`
  shows the intended Preferences composition: a localized description,
  `PreferencesReorderToggleList`, bindings into the store, and a reset action.
  `PreferencesAnnotateChromeCustomizationView.swift:51-68` is the smaller
  example without a preview or accessory.

### Preferences, persistence, and localization

- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift:150-428`
  renders the unified Capture form. Insert the new All-In-One customization
  section near the existing Selection section, before Screenshot Behavior.
  The parent already owns `videoModuleEnabled` and updates it when Video
  availability changes, so pass that value into the new child view.

- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift:64-105`
  centralizes the UserDefaults keys. Add versioned keys such as
  `capture.allInOne.modeOrder.v1` and `capture.allInOne.enabledModes.v1`.
  Store raw enum values only; do not rename the existing last-selection,
  aspect-lock, or child-shortcut keys.

- `Notinhas/Shared/Localization/L10n.swift:1330-1410` already exposes stable
  All-In-One mode titles and accessibility labels. Add only the new
  Preferences Capture section/description/footnote/reset strings under
  `L10n.PreferencesCapture`, and add their English entries to
  `Notinhas/Resources/Localization/Features/Capture.xcstrings`. No new
  hard-coded user-facing English text belongs in the SwiftUI view.

### Existing tests and docs

- `NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift` verifies the
  fixed catalog, stable raw values, mode metadata, and command routing. Keep
  the default catalog test (Recording is last by default), then add coverage
  for the new configuration store separately.
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift:79-120`
  verifies session defaults and unavailable-mode rejection. Update the state
  construction to pass an explicit mode list and add the first-configured-mode
  behavior.
- `NotinhasTests/Features/Capture/AllInOneModeShortcutSettingsTests.swift`
  uses isolated `UserDefaults` and is the pattern for testing shortcut
  persistence without leaking state into the app.
- `docs/PREFERENCES.md` currently documents Quick Access action customization
  and the Capture sections but has no All-In-One mode customization entry.
- `docs/CAPTURE.md:118-130` documents the All-In-One session, direct mode
  dispatch, and child keys. Update it to describe the persisted configured
  order, enabled filtering, conditional Recording placement, and inert hidden
  child shortcuts.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat 49f163e4..HEAD -- <scope>` | No unexpected pre-plan changes; inspect any listed in-scope drift before proceeding |
| Focused default tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeConfigurationStoreTests -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/AllInOneModeShortcutSettingsTests` | Exit 0; all selected tests pass |
| Focused Video tests | `./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeConfigurationStoreTests -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/AllInOneModeShortcutSettingsTests` | Exit 0; Recording remains conditional and tests pass |
| Format | `make format-check` | Exit 0; no files require formatting |
| Changed lint | `make lint-changed` | Exit 0; no violations in changed Swift files |
| Default build | `make build` | Exit 0; Debug app builds |
| Video build | `make build-video` | Exit 0; Debug+Video app builds |
| Full tests | `make test` | Exit 0; full XCTest suite passes, with any known baseline diagnostic called out |
| Changed-surface plan | `./scripts/verify-local.sh --base 49f163e4 --plan-only --strict` | Exit 0; changed paths are mapped and manual-required capture/preferences checks remain visible |
| Guidance | `make guidance-check` | Exit 0; repository guidance and plan index are consistent |
| Delivery gate | `make agent-check` | Exit 0; format/lint/verification gates pass |

## Suggested executor toolkit

- Use `data-persistence` for UserDefaults normalization and the invariant
  that malformed storage must not make the HUD empty or crash.
- Use `capture-annotate-export` for the All-In-One runtime boundary and manual
  capture-to-HUD check.
- Use `testing-xctest` for isolated `UserDefaults` tests and for keeping live
  WindowServer UI behavior in the manual gate.
- Use `localization` for the new Preferences Capture strings and accessibility
  wording.
- Use `macos-app-engineering` / `swift-concurrency-expert` for MainActor
  ownership of the store, Preferences view, session state, and coordinator.

## Scope

**In scope** (the only product/source/docs files to modify):

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureModeConfigurationStore.swift` (create)
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `Notinhas/Features/Preferences/Components/PreferencesAllInOneModeCustomizationView.swift` (create)
- `Notinhas/Features/Preferences/Components/PreferencesCaptureSettingsView.swift`
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift`
- `Notinhas/Shared/Localization/L10n.swift`
- `Notinhas/Resources/Localization/Features/Capture.xcstrings`
- `NotinhasTests/Features/Capture/AllInOneCaptureModeConfigurationStoreTests.swift` (create)
- `NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift`
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift`
- `NotinhasTests/Features/Capture/AllInOneModeShortcutSettingsTests.swift`
- `docs/PREFERENCES.md`
- `docs/CAPTURE.md`
- `plans/README.md` (status/index update only)

**Out of scope** (do not touch):

- Quick Access source, store, keys, preview, or `Quick Actions` behavior;
  reuse its pattern only.
- `PreferencesReorderToggleList.swift`; use the existing component as-is.
- Standalone capture menu items, global shortcut bindings, deep links, and
  `ShortcutOverlayModels` summary ordering.
- `AllInOneModeShortcutSettings` preference keys, migration, default key
  assignments, or conflict policy. Only add the focused regression test if
  needed; do not delete hidden-mode bindings.
- Capture command implementations, selection geometry, HUD materials,
  dimensions, timers, Video Editor, or recording behavior.
- TOML configuration import/export. The new UserDefaults keys follow the
  existing Quick Access/Annotate customization pattern and do not add a new
  configuration schema in this plan.
- New All-In-One modes. The current enum is the catalog; future enum cases
  should be normalized and appended automatically by the store.

## Git workflow

- Branch: `advisor/083-customize-all-in-one-modes` in an isolated worktree.
- Commit style: Conventional Commits, e.g.
  `feat(capture): customize All-In-One modes`.
- Do not push or open a PR unless the operator explicitly instructs it.
- Keep the plan/index update in the same logical delivery unit as the feature;
  do not stage unrelated worktree changes.

## Steps

### Step 1: Add the persistent All-In-One mode configuration contract

1. Add versioned keys to `PreferencesKeys`.
2. Add `AllInOneCaptureMode.defaultOrder` and a default enabled set to the
   mode model. Keep the existing enum raw values stable. Make
   `availableModes(videoEnabled:)` filter the explicit default catalog rather
   than depending on incidental `CaseIterable` order.
3. Create `AllInOneCaptureModeConfigurationStore` as a `@MainActor`
   `ObservableObject` with injectable `UserDefaults`, following the Quick
   Access store's shape:
   - published `modeOrder` and `enabledModes`;
   - normalized raw-value loading that drops unknown/duplicate IDs and appends
     missing catalog modes in default order;
   - `orderedModes(videoEnabled:includeDisabled:)`, where Preferences passes
     `includeDisabled: true` and the HUD passes `false`;
   - `isEnabled`, `setEnabled`, `moveMode`, and `resetToDefaults`;
   - persistence after every accepted order/toggle/reset mutation.
4. Enforce the confirmed invariant: disabling the last enabled non-Video mode
   is a no-op, and expose a `canToggle` result so the Preferences row can show
   that switch as non-toggleable. Recording may be freely disabled when Video
   is available, but it must never be the only surviving enabled mode.
5. When Video is off, filter Recording from the visible/configuration list but
   keep its raw ID, enabled state, and custom position in the store. When Video
   returns, its position and enabled state must reappear unchanged.
6. Make `moveMode` operate on the currently available list shown by
   Preferences while preserving hidden Recording's relative slot in the full
   persisted order. Do not index the full order directly with an index from a
   Video-off filtered list.
7. Add `AllInOneCaptureModeConfigurationStoreTests` using
   `UserDefaultsFactory.make()` (or the repository's equivalent isolated
   defaults factory) covering defaults, normalization, persistence, custom
   order, disable/re-enable, last-non-Video protection, Video filtering and
   restoration, hidden-slot preservation, and reset.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeConfigurationStoreTests` → the new store tests pass.

### Step 2: Make the All-In-One session and child shortcuts consume configured modes

1. Change `AllInOneCaptureSessionState` to accept a non-empty configured mode
   list rather than constructing the fixed catalog itself. Initialize
   `selectedMode` to the first configured mode, preserving the safe `.area`
   fallback only if a defensive empty-list case is unavoidable.
2. Update `AllInOneCaptureCoordinator.start(from:)` to request
   `AllInOneCaptureModeConfigurationStore.shared.orderedModes(
   videoEnabled: VideoModuleAvailability.isEnabled, includeDisabled: false)`
   and pass that snapshot to the state. Keep the state snapshot stable for the
   lifetime of the active HUD; changes in Preferences apply on the next AIO
   session, not halfway through an active capture.
3. Keep `AllInOneCaptureToolbarView` unchanged unless compilation requires a
   mechanical initializer update: it already iterates `session.availableModes`
   and therefore renders the configured order and enabled subset.
4. Preserve the existing child shortcut persistence. Because the coordinator
   already passes `sessionState.availableModes` into
   `AllInOneModeShortcutSettings.mode(matching:in:)`, a hidden mode's child key
   must not match while hidden. Do not remove or reset that key.
5. Update test seams and tests to pass explicit mode lists where they need the
   old full catalog. Add tests proving the first configured mode is selected,
   unavailable modes remain rejected, and a stored child shortcut is ignored
   when its mode is omitted from the active list. Keep the existing command
   routing and default-mode tests.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/AllInOneModeShortcutSettingsTests` → all selected tests pass.

### Step 3: Add the Capture Preferences customization UI and localized copy

1. Create `PreferencesAllInOneModeCustomizationView` under
   `Notinhas/Features/Preferences/Components/`. Accept the parent's
   `videoModuleEnabled` value and observe the new store. Render one localized
   section containing:
   - a short description explaining that enabled modes appear in the
     All-In-One toolbar and the handle changes their order;
   - `PreferencesReorderToggleList` with
     `store.orderedModes(videoEnabled: videoModuleEnabled, includeDisabled: true)`;
   - existing `mode.compactTitle`, SF Symbol, and standard toggle bindings;
   - `canToggle` from the store's last-mode guard;
   - `moveMode(from:to:videoEnabled:)` for reordering;
   - a localized reset action that restores all modes/default order;
   - a short localized footnote explaining that at least one non-Video mode
     must remain enabled.
2. Insert the new view into the Capture form near Selection, before Screenshot
   Behavior. Pass the existing `videoModuleEnabled` state so Recording appears
   only when the optional Video module is actually available.
3. Add stable `L10n.PreferencesCapture` accessors and matching English
   `Capture.xcstrings` entries for section title, description, reset label, and
   the minimum-one-mode footnote. Keep labels concise and action-oriented;
   reuse existing `AllInOneCaptureMode.settings`/accessibility labels where
   possible instead of adding duplicate mode names.
4. Keep SwiftUI/AppKit work on MainActor through the existing view/store
   ownership. Do not add a preview card or a new drag payload: the shared list
   already owns the reorder interaction.

**Verify**: `make format-check && make lint-changed` → exit 0; no formatting or changed-file lint violations.

### Step 4: Update tests, docs, and delivery evidence

1. Update `docs/PREFERENCES.md` under Capture to document the All-In-One
   section, enabled/order behavior, versioned keys, reset behavior, and the
   non-Video minimum invariant.
2. Update `docs/CAPTURE.md` under the All-In-One session to document:
   - the toolbar uses the persisted enabled order;
   - Recording is conditional on Video but may occupy any saved position;
   - hidden modes do not respond to All-In-One child keys;
   - standalone mode entry points remain unaffected;
   - settings changes take effect when the next All-In-One session starts.
3. Run the focused default and Video test commands, both builds, full tests,
   `verify-local` plan-only strict, `make guidance-check`, and
   `make agent-check` from the command table. Do not hide warnings or
   manual-required profiles.
4. Perform the manual gate with Screen Recording and Accessibility granted:
   - open Preferences → Capture → All-In-One;
   - reorder several modes, disable one, close/reopen Preferences, and confirm
     persistence;
   - attempt to disable the last non-Video mode and confirm it remains enabled;
   - start a new All-In-One session and confirm HUD order/visibility;
   - configure a child key for a hidden mode, confirm it does nothing, re-enable
     the mode, and confirm the same key works again;
   - with Video enabled, place Recording away from the end, turn Video off and
     back on, and confirm its saved position returns;
   - use Reset and confirm the default order/all-enabled state;
   - capture a real area and verify the existing dispatch/output flow is
     unchanged.
5. Capture a screenshot or short recording of the Preferences section and HUD
   order for the handoff, as required for visual changes.
6. Update the Plan 083 row in `plans/README.md` only with the actual status and
   resulting commit/review SHAs after delivery; do not mark it DONE before the
   manual gate and review are complete.

**Verify**: `make agent-check` → exit 0; the report maps every changed path and
keeps the capture/preferences manual gate visible.

## Test plan

Add `AllInOneCaptureModeConfigurationStoreTests.swift`, modeled on
`AllInOneModeShortcutSettingsTests` for isolated `UserDefaults`. Cover:

- default full order and enabled set;
- unknown, duplicate, missing, and corrupt stored IDs normalize without crash;
- custom order round-trips, including Recording before non-Video modes;
- disabling hides a mode but re-enabling restores it without losing order;
- the last enabled non-Video mode cannot be disabled;
- Video-off filtering hides Recording without deleting its state or position;
- Video-on restoration returns Recording to its saved position when enabled;
- move semantics use the filtered Preferences list correctly;
- reset restores default order and all enabled modes.

Extend the existing All-In-One tests for:

- session selection starts at the first configured mode;
- configured mode order is the HUD order;
- hidden modes remain rejected by session activation;
- child shortcut matching ignores a mode absent from the active configured list
  while the shortcut's UserDefaults value remains present.

Use `./scripts/run-tests.sh --skip-visual` for automated behavior. Keep actual
HUD/window/permission behavior in the manual matrix; do not turn the XCTest
suite into a live Screen Recording or WindowServer test merely to avoid the
manual gate.

## Done criteria

- [ ] `AllInOneCaptureModeConfigurationStore` owns versioned order/enabled
  persistence with fail-soft normalization and isolated-defaults tests.
- [ ] Preferences → Capture exposes localized reorder/toggle/reset controls
  using the existing `PreferencesReorderToggleList`.
- [ ] The All-In-One HUD renders only enabled currently available modes in the
  persisted order, with the first configured mode selected.
- [ ] Recording can be reordered when Video is enabled and disappears without
  losing configuration when Video is disabled.
- [ ] At least one non-Video mode remains enabled; no empty All-In-One HUD is
  possible through the UI or malformed persisted values.
- [ ] Hidden mode child shortcuts remain stored but cannot activate; standalone
  capture shortcuts, menus, and deep links are unchanged.
- [ ] `./scripts/run-tests.sh --skip-visual ...` focused command exits 0 in the
  default and Video configurations.
- [ ] `make format-check`, `make lint-changed`, `make build`, `make build-video`,
  `make test`, `make guidance-check`, and `make agent-check` exit 0, with
  baseline warnings/failures explicitly recorded if any remain.
- [ ] `./scripts/verify-local.sh --base 49f163e4 --plan-only --strict` exits 0
  and retains the manual-required profiles.
- [ ] Manual Preferences/HUD/child-shortcut/Video matrix passes, and a visual
  screenshot or recording is included in the handoff.
- [ ] No files outside the Scope list are modified, apart from the executor's
  scoped commit metadata and the required `plans/README.md` status update.

## STOP conditions

Stop and report back instead of improvising if:

- `AllInOneCaptureMode` gains or loses cases, or its raw values differ from the
  current stable catalog, before the store normalization is designed for the
  drift.
- Video availability cannot be observed through the existing
  `VideoModuleAvailability`/notification path without changing out-of-scope
  app-shell code.
- Reordering the Video-off list would require deleting or rewriting the user's
  saved Recording position rather than preserving it.
- Preventing an empty HUD requires making Area permanently mandatory, changing
  standalone capture behavior, or introducing a new configuration layer beyond
  the confirmed non-Video invariant.
- A hidden child shortcut still activates after the coordinator receives the
  configured list, or fixing it requires changing shortcut storage/migration
  keys.
- `PreferencesReorderToggleList` cannot express the last-mode guard without
  modifying the shared component; stop before forking or changing that shared
  component.
- The current localization extraction path differs from `L10n.swift` plus
  `Features/Capture.xcstrings`, or adding the strings creates CatalogTool
  errors that cannot be fixed within the listed localization files.
- Any test/build failure repeats twice after a reasonable scoped fix, or a
  required change falls outside the Scope list.

## Maintenance notes

- Future All-In-One modes must be added to the enum's explicit default catalog
  and metadata. The store will append a new raw value to existing users'
  persisted order and enable it by default unless product policy changes.
- Do not use `AllInOneCaptureMode.allCases` directly for the HUD; the store's
  configured visible list is the runtime contract. `allCases` remains useful
  for the complete shortcut-settings catalog and exhaustive tests.
- The saved order is independent of the optional Video module. Review any
  future Video availability changes against the hidden-slot preservation tests.
- Reviewers should scrutinize the last-non-Video invariant, the filtered move
  algorithm, and the fact that child shortcut settings remain stored while
  dispatch uses only currently visible modes.
- This plan intentionally does not add TOML backup/import support, live HUD
  mutation while Preferences is open, or a new mode catalog. Add those only as
  separately scoped follow-ups with migration and manual verification plans.
