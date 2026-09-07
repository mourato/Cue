# 115 — Screenshot preferences reshuffle (Capture → Screenshot, existing controls only)

- Status: TODO
- Priority: P1 / Effort: S–M
- Depends on: 043 (unified Capture flow) — presentation only, no key migration
- Primary skill: `capture-annotate-export` (visual-handoff scope + scope questions)
- Complementary: global `delivery-workflow` + Cue overlay (build/test gates), `test-hygiene` (tests, no visual/sound suites by default)
- UI contract: read `docs/ui.md` before touching Preferences; update it only if this establishes a reusable rule
- Generated against: run `git rev-parse HEAD` at execution and record base SHA here (read-only in planning)

## 1. Objective

Restructure the current Capture tab into the reference layout (Output / Capture / Window Screenshots) and rename the tab to `Screenshot`, reusing only controls that already have a backend. No new capture behavior in this plan.

User-confirmed decisions:
- Phased: reorganize existing now; sRGB / Retina 1x / 1px border / configurable Self-Timer / wallpaper-vs-transparent cards + Padding are follow-ups, not disabled placeholder UI.
- Destination: restructure the current Capture tab, rename it to `Screenshot` (no second tab).
- Reuse: Background preset = current `PreferencesScreenshotDefaultPresetPicker`; Window Background links to existing wallpaper settings / `SystemWallpaperManager`; Reset Defaults is scoped to this screen only.

## 2. Concrete findings (verified read-only)

- Tab root: `Cue/Features/Preferences/PreferencesView.swift` (TabView, `PreferencesTab.capture`, persists via `PreferencesNavigationState` / `preferences.selectedTab`, 760×550).
- Capture body: `Cue/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` (701 lines). Current `.capture` pane sections: Capture Environment & Behavior, Selection & Snapping, Output & Storage, All-In-One customization, Post Processing, Specialized Capture + conditional Recording panes.
- Existing keys/controls to keep (no rename/migration):
  - `screenshot.format` + `ImageFormatOption` (+ existing jpeg quality / webp notes / filename template + `resetOutputNamingDefaults`)
  - `screenshot.showCursor` (`screenshotShowCursor`)
  - `screenshot.freezeArea` (`freezeAreaCapture`)
  - `capture.windowShadow`
  - Default preset via `AnnotateCanvasPresetStore` + `PreferencesScreenshotDefaultPresetPicker` (+ `ScreenshotPresetAutoApplier`)
  - Wallpaper affordances: `hideDesktopIcons`, `wallpaper.directoryBookmark`, `SystemWallpaperManager`
- Missing backends (explicitly OUT, see §6): `Convert to sRGB` (today only internal in `OCRService` / `ScreenCaptureManager` / upload), `Scale Retina to 1x`, `Add 1px border`, configurable `Self-Timer interval` (today fixed `AllInOneTimerScheduler.defaultDelayNanoseconds = 3s`), window `With wallpaper / Transparent` toggle + `Padding` slider (today `backgroundPadding` is VideoEditor-only).
- L10n: `Cue/Shared/Localization/L10n.swift`, tables `Settings` / `Capture`; tab string is `preferences.tab.capture` default `"Capture"`.
- Styles: `Cue/Shared/Styles/DesignTokens.swift`, `PopoverTokens`; row pattern `PreferencesSettingRow.swift` / `SettingRow`; accessibility rule in `docs/ui.md` (explicit `.accessibilityLabel` per control even with `.labelsHidden()`).

## 3. Scope

### In
- Rename tab label Capture → Screenshot, keeping `PreferencesTab.capture` case and `preferences.selectedTab` persisted value unchanged.
- Reorder the `.capture` pane into three cards:
  - **Output:** File format (existing picker) + Background preset picker (existing) + footnote text from reference (`Apply Background Tool preset… Hold Shift…` — verify Shift-bypass wording against `ScreenshotPresetAutoApplier` at execution; adjust copy, not behavior).
  - **Capture:** Show cursor on screenshots (+ footnote `This works in Fullscreen or Self-Timer modes only.` as copy only, no semantic change) + Freeze screen toggle.
  - **Window Screenshots:** existing `Capture window shadow` toggle + existing wallpaper-settings link/copy. No new card selector, no new slider.
- Scoped `Reset Defaults` button at the foot (as in reference): resets only the keys displayed on this screen (format, jpegQuality, includeOwnApp if shown, showCursor, freezeArea, windowShadow; default preset via `clearDefaultPresetId()`). Confirm exact list in preflight; do not widen to global restore (Advanced owns global restore).
- L10n for new section titles, footnotes, reset; Light/Dark, Reduce Motion/Transparency, keyboard + VoiceOver preserved.

### Out (do not touch)
- No new `PreferencesKeys`, no TOML/UserDefaults migration or rename, no `ScreenCaptureManager` / export-pipeline change.
- No sRGB / Retina / border / timer-interval / wallpaper-transparent / padding implementation (follow-ups 115–117).
- No change to Selection & Snapping, filename templates (beyond keeping them where they are or explicitly leaving them out — see open point), All-In-One customization, scrolling/OCR, Recording pane, Cloud/Uploads, Shortcuts, History, Advanced.
- No new design-system document; no iconography overhaul (reuse `SettingRow`/tokens; drop icons only if the card style requires it and `docs/ui.md` is updated accordingly).

## 4. Design notes (Ponytail: smallest diff)

- Prefer restacking existing `SettingRow` / `Toggle` / `Picker` views into the three cards over a new component. Extract a tiny local `ScreenshotCard` wrapper only if duplication exceeds two call sites; no generic preferences-card framework.
- Tab rename = display-string change only (`preferences.tab.capture` default `"Screenshot"`); keep the L10n key, `PreferencesTab` case, and persisted string stable so restores keep working.
- Recording segmented pane (`CaptureSettingsPane`) stays as-is when the Video module is on; only the tab label changes. If this reads oddly in review, note it — do not redesign recording in this plan.
- Footnotes are copy-only (`Text(.caption).foregroundStyle(.secondary)`), matching the reference tone.

## 5. Execution steps

1. Preflight (read-only): `scripts/plan-preflight.sh plans/115-screenshot-settings-reshuffle.md --scope Cue/Features/Preferences`.
2. Bind `delivery-contract` with base SHA (`git rev-parse HEAD`), absolute isolated worktree + branch, exact file list from §3, integration authority; PASS required before any patch.
3. Restructure `PreferencesCaptureSettingsView` `.capture` pane into Output / Capture / Window cards with existing bindings only.
4. Rename tab label to Screenshot (L10n default change + any preview/docs string); verify `PreferencesNavigationState` restore still works.
5. Add scoped Reset Defaults (local defaults only) with existing destructive-confirmation tone; wire default-preset clear via the store.
6. Add/adjust L10n + accessibility labels; run `./scripts/run-tests.sh` (quiet default: no `--with-visual`, no `CUE_ALLOW_TEST_SOUNDS=1`); add 1 focused XCTest for scoped reset + 1 for tab-restore stability if cheap, else characterization only.
7. `scripts/verify-local.sh --base <ref>` + `make validate` (`make agent-check`); `make validate-lane` before merge.
8. Manual gates: tab switch + restore, Light/Dark, keyboard/VoiceOver per row, reset scoped, smoke capture → annotate → clipboard (presentation-only, no TCC reset expected).
9. Commit → merge → cleanup → push per `plans/README.md` loop; then thermo-nuclear review and fix every finding before next plan.

## 6. Explicit follow-ups (not this plan)

- 115: Output pipeline toggles — sRGB convert, Retina-to-1x, 1px border (needs export-pipeline design + pixel/dimension tests).
- 116: Configurable Self-Timer interval (persist interval, wire `AllInOneTimerScheduler`, picker e.g. Off/3/5/10s).
- 117: Window Background cards (wallpaper/transparent) + Padding slider (new state + window composition + `SystemWallpaperManager` wiring; prefer `SteppedSliderControl` per 034/053).

## 7. Acceptance

- [ ] Tab reads `Screenshot`; last-tab restore unbroken; Recording pane behavior unchanged.
- [ ] Output / Capture / Window sections match reference order with existing controls only; no dead toggles/sliders.
- [ ] Reset restores only this screen's scope; global restore still lives in Advanced.
- [ ] L10n complete; no hardcoded English in views; `docs/ui.md` reconciled only if a reusable rule was added.
- [ ] `make validate`, quiet test suite, and manual checklist recorded in handoff.

## 8. Risks / STOP conditions

- Unexpected changed paths in worktree → STOP, report, preserve; do not absorb.
- Any pressure to add a functional-looking toggle without a backend → STOP and move it to 115–117.
- Tab-rename tempting a `PreferencesTab` case or persisted-key rename → forbidden in this plan (display string only).
- If `Shift`-bypass copy proves behaviorally false, change the copy, not the behavior.

## 9. Ledger update

On creation, append to `plans/README.md` (or current ledger location): `| 115 | Screenshot preferences reshuffle | P1 | S–M | 043 | TODO |`.
