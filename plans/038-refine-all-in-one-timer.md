# Plan 038: Refine All-In-One chrome and add delayed area capture

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat b1268e0d..HEAD -- Notinhas/Features/Capture/AllInOne Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Features/Preferences/Models/PreferencesKeys.swift Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/Features/Capture.xcstrings NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift docs/CAPTURE.md plans/README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/035-shared-capture-floating-chrome.md,
  plans/036-capture-selection-refinement.md,
  plans/037-all-in-one-capture.md
- **Category**: direction
- **Planned at**: commit `b1268e0d`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — timer lifecycle and HUD styling share the
  All-In-One session state and coordinator.
- **Reviewer required**: `yes` — this alters a permission-sensitive capture
  flow and must preserve the default (Video-off) build.
- **Rationale**: The work is localized, but asynchronous delayed dispatch,
  cancellation, floating AppKit windows, localization, and visual behavior
  make it unsuitable for a low-risk mechanical lane.
- **Escalate when**: a configurable duration, a persistent preference, a
  recurring timer, a recording countdown, or changes outside the listed
  capture paths are required. Those constitute a separate product decision.

## Why this matters

The completed All-In-One flow lets a user choose a capture mode and refine a
rectangle, but its toolbar has only icons and therefore does not yet offer the
fast, self-explanatory visual scan of the CleanShot-inspired reference. It
also deliberately excluded Timer. This plan keeps the product's fast visual
handoff focus: show concise labels, improve the selected-state and dimension
surface, preserve Annotate, and add one predictable three-second delayed area
capture for arranging transient UI before a screenshot.

## Current state

### Relevant files and roles

- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift` — mode
  identity, visibility, icon, title, accessibility, and whether a selection
  rectangle is required.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift` —
  icon-only SwiftUI mode strip.
- `Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift` and
  `AllInOneActionToolbarView.swift` — compact editable dimensions, aspect
  lock, and Capture action in a second floating HUD.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift` —
  `@MainActor` observable session callbacks.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` —
  owns HUD windows/refinement and dispatches the selected mode to
  `ScreenCaptureViewModel`.
- `Notinhas/Shared/Localization/L10n.swift` and
  `Notinhas/Resources/Localization/Features/Capture.xcstrings` — localized
  All-In-One UI strings. Do not hard-code new English UI text.
- `NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift` and
  `AllInOneCaptureCoordinatorTests.swift` — focused XCTest patterns.
- `docs/CAPTURE.md` — documents shipped All-In-One modes; it currently says
  Timer remains outside the strip and therefore must be corrected.

### Planned-at excerpts

`AllInOneCaptureMode.availableModes(videoEnabled:)` includes Annotate and
conditionally appends Recording, but no Timer:

```swift
// Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift:10-28
enum AllInOneCaptureMode: String, CaseIterable, Identifiable, Equatable {
  case area
  case fullscreen
  case window
  case annotate
  case scrolling
  case ocr
  case recording

  static func availableModes(videoEnabled: Bool) -> [AllInOneCaptureMode] {
    var modes: [AllInOneCaptureMode] = [.area, .fullscreen, .window, .annotate, .scrolling, .ocr]
    if videoEnabled { modes.append(.recording) }
    return modes
  }
}
```

The strip currently uses an icon button with only an accessibility label and
an accent-colour outline as selection feedback:

```swift
// Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift:13-36
HStack(spacing: ToolbarConstants.itemSpacing) {
  ForEach(session.availableModes) { mode in
    CaptureFloatingToolbarIconButton(
      systemName: mode.systemImage,
      action: { session.selectMode(mode) },
      accessibilityLabel: mode.accessibilityLabel
    )
    .overlay {
      RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
        .strokeBorder(Color.accentColor.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
    }
  }
}
```

The coordinator saves a rectangle for modes that preserve it, tears down the
HUD/refinement through `cancel()`, and then immediately dispatches a capture:

```swift
// Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:224-255
let mode = sessionState.selectedMode
let rect = sessionState.currentRect
if let rect, mode.preservesSelectionRect {
  CaptureLastSelectionStore.save(rect, userDefaults: .standard)
}
cancel()
switch mode {
case .area:
  if let rect { viewModel.captureArea(at: rect) }
  else { viewModel.captureArea() }
case .annotate:
  if let rect { viewModel.captureAreaAnnotate(at: rect) }
  else { viewModel.captureAreaAnnotate() }
// scrolling, OCR, and optional recording follow
}
```

The existing dimensions behavior is functional and must be preserved:

```swift
// Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift:27-64
HStack(spacing: ToolbarConstants.itemSpacing) {
  dimensionField(label: "W", accessibilityLabel: "Width", text: $widthText) { commitWidth() }
  Text("×")
  dimensionField(label: "H", accessibilityLabel: "Height", text: $heightText) { commitHeight() }
  CaptureFloatingToolbarDivider()
  CaptureFloatingToolbarIconButton(systemName: aspectRatioLocked ? "lock.fill" : "lock.open", ...)
}
.captureFloatingToolbarMaterial()
```

### Project conventions and constraints

- Swift 5.9 and SwiftFormat use two-space indentation and a 120-column limit.
- Keep UI/session state on `@MainActor`; make delay scheduling cancellation
  explicit so a late callback cannot capture after the user cancels or starts
  another session.
- Reuse the always-compiled floating chrome from plan 035:
  `CaptureFloatingHUDWindow`, `CaptureFloatingToolbarIconButton`,
  `CaptureFloatingToolbarDivider`, `ToolbarConstants`, and
  `.captureFloatingToolbarMaterial()`. Do not depend on Video-gated recording
  toolbar views.
- `VideoModuleAvailability` keeps Recording conditional; all new Timer and
  toolbar code must compile in the default Video-off scheme.
- Localized strings follow `L10n` plus `Features/Capture.xcstrings`; the
  existing `L10n.AllInOne` entries are the exemplar.
- Follow the existing focused test pattern: `@MainActor` only for tests that
  create session/UI objects, and one observable behavior per test.
- Product boundary from `AGENTS.md`: this is a screenshot handoff feature;
  do not add recording suites, generic markup, cloud behavior, Smart Element,
  or Object Cutout to the strip.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format changed Swift | `swiftformat Notinhas/Features/Capture/AllInOne Notinhas/Shared/Localization/L10n.swift NotinhasTests/Features/Capture` | exit 0 |
| Focused All-In-One tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | exit 0; all selected tests pass |
| Default regression suite | `./scripts/run-tests.sh --skip-visual` | exit 0; all non-visual default-scheme tests pass |
| Default build/run smoke | `./scripts/build_and_run.sh --no-video-module` | Debug app builds and launches |
| Video-gated compilation check | `./scripts/run-tests.sh --video-module --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests` | exit 0; Recording remains present only when enabled |

The full manual capture checks below are required in addition to `--skip-visual`
tests because this plan changes floating HUDs and overlays.

## Suggested executor toolkit

- `.agents/skills/macos-app-engineering/SKILL.md` — floating SwiftUI/AppKit
  windows and capture overlay ownership.
- `.agents/skills/apple-design/SKILL.md` — material, contrast, sizing, and
  Reduce Motion / Reduce Transparency behavior.
- `.agents/skills/accessibility-audit/SKILL.md` — VoiceOver labels and
  keyboard/cancel behavior.
- `.agents/skills/localization/SKILL.md` — `L10n` and `.xcstrings` changes.
- `.agents/skills/testing-xctest/SKILL.md` and
  `.agents/skills/delivery-workflow/SKILL.md` — focused tests and validation.

## Scope

**In scope** (create/modify only these files unless Xcode target membership
requires the project file to include a newly created Swift source):

- **Modify** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift`
  — add `.timer`, mode ordering/metadata, and rectangle requirements.
- **Modify** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift`
  — replace icon-only mode affordances with compact vertical icon+label buttons
  and an accessible selected state.
- **Modify** `Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift`
  and `AllInOneActionToolbarView.swift` — visually compact the existing W × H
  and aspect-lock surfaces without changing their geometry contract.
- **Modify** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureSessionState.swift`
  only if an explicit countdown state/cancel callback is necessary for the
  HUD; keep it minimal.
- **Modify** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
  — schedule/cancel a fixed delayed area capture safely and retain all current
  dispatch behavior.
- **Create only if needed for deterministic testing** a focused
  `Notinhas/Features/Capture/AllInOne/AllInOneTimerScheduler.swift` with a
  narrow injectable scheduling seam. Do not reuse or move
  `QuickAccessCountdownTimer`; its pausable card-dismiss semantics are a
  different responsibility.
- **Modify** `Notinhas/Shared/Localization/L10n.swift` and
  `Notinhas/Resources/Localization/Features/Capture.xcstrings` — all mode,
  Timer, countdown, and accessibility copy.
- **Modify** `NotinhasTests/Features/Capture/AllInOneCaptureModeTests.swift`
  and `AllInOneCaptureCoordinatorTests.swift`; create a dedicated timer test
  file only if the scheduler seam warrants it.
- **Modify** `docs/CAPTURE.md` — replace the stale statement that Timer stays
  outside the strip; document the fixed three-second delayed area behavior.
- **Modify** `plans/README.md` — mark plan 038 DONE only after all plan gates
  and manual checks are recorded.

**Out of scope**:

- A preference, custom durations, recurring/interval screenshots, menu-bar
  timer, recording countdown, or a timer global shortcut.
- Smart Element, Object Cutout, and any new mode beyond Timer.
- Changes to classic `⌘⇧4`, standalone capture menu entries, deep links,
  keyboard shortcut registration, capture persistence keys, or Quick Access.
- Replacing the shared floating-HUD primitives from plans 035–037.
- Recording UI/flow changes; only preserve its compile/runtime gate and order.
- Cloud, annotate-canvas tooling, generic crop presets, or history changes.

## Git workflow

- Branch: `advisor/038-refine-all-in-one-timer`
- Use one focused Conventional Commit, for example:
  `feat(capture): refine all-in-one timer controls`.
- Do not push or open a pull request unless the operator instructs it.
- Preserve all unrelated changes in the shared worktree; never reset or
  overwrite them.

## Steps

### Step 1: Define the Timer capture contract in the mode model and localization

Add `case timer` to `AllInOneCaptureMode` after `.scrolling` and before `.ocr`
so the order reads Area, Fullscreen, Window, Annotate, Scrolling, Timer, OCR,
then optional Recording. Give it an SF Symbol appropriate to a delayed capture
(for example `timer`), a concise localized display label, and an action-based
VoiceOver label. Treat it like Area for `preservesSelectionRect` and
`showsDimensionsBar`.

Add stable `all-in-one.*` keys through `L10n.AllInOne` and the Capture strings
catalog for: the Timer display label, its accessibility action, the countdown
status if it is shown, and compact mode labels used by the visible strip. Do
not use `L10n.Actions.captureArea` for the visible label if its wording is
longer than the compact toolbar needs. Keep existing strings intact unless a
specific key is being replaced by an equivalent All-In-One label.

**Verify**: Run the focused test command after expanding
`AllInOneCaptureModeTests` to assert the exact Video-off and Video-on order,
stable `timer` raw value, non-empty title/accessibility/symbol, and that
Annotate remains available.

### Step 2: Make the mode strip scan like the reference without copying its branding

Replace the icon-only `CaptureFloatingToolbarIconButton` composition with a
small All-In-One-local button view: icon above a one-line localized label,
consistent hit target, and button styling inside the existing floating
material. Reuse `ToolbarConstants`/`captureFloatingToolbarMaterial()` rather
than creating a second material system.

For the selected mode, use a filled, high-contrast rounded surface plus a
subtle border or tint; do not rely on a blue outline alone. Unselected labels
may be secondary but must remain legible against varied captured desktops.
Keep buttons in the current data-driven `ForEach`, preserve natural keyboard
button focus, and add `.isSelected` plus an action-oriented accessibility
label/value. Honor system appearance; if adding a transition, it must be short
and skipped/reduced under Reduce Motion. Verify Reduce Transparency and
Increase Contrast do not leave the selected state dependent solely on a
translucent fill.

Do not use CleanShot names, assets, measurements, or copied visual code. The
reference establishes interaction hierarchy only.

**Verify**: Build the default scheme. In an Xcode SwiftUI preview or the debug
app, confirm Video-off shows seven labeled modes (including Annotate and
Timer) and Video-on shows Recording last; labels do not truncate at the
reference-resolution width.

### Step 3: Refine the existing dimensions/action surface without changing geometry

Keep `AllInOneDimensionsBarView` as the sole path for width/height edits and
the `CaptureSelectionGeometry` helpers as the source of truth. Tighten its
visual hierarchy to match the reference: monospaced numeric values, a visible
`×`, clear field grouping, separator, and recognizable aspect-lock affordance.
The compact visible form may remove redundant W/H glyphs only if the fields
retain their current localized VoiceOver labels (Width and Height) and their
focus order remains width, height, lock, Capture.

Keep invalid input behavior (restore the current rectangle) and aspect-ratio
math unchanged. The Capture button remains explicit and visible; it must
describe the selected mode when it improves VoiceOver clarity. Do not add the
reference's crop/dropdown controls because Notinhas has no corresponding
behavior.

Ensure the coordinator continues to position two separate HUD windows without
overlap after the mode strip grows vertically. Adjust only All-In-One placement
math if necessary; retain the selection white/L-shaped handles supplied by
`AllInOneSelectionRefinementController` / `RecordingRegionOverlayWindow`.

**Verify**: Run the focused tests. Manually resize a rectangle by a handle and
by Width/Height fields, toggle the aspect lock, and confirm the fields and
selection remain synchronized on a Retina and a non-Retina display if
available.

### Step 4: Implement one cancellable three-second delayed area capture

When Timer is selected and Capture is pressed with a selected rectangle:

1. Save the rectangle using the existing All-In-One last-selection behavior.
2. Tear down selection/refinement/HUD windows before the delay so no Notinhas
   chrome is captured.
3. Schedule exactly one capture for three seconds later on a cancellation-aware
   mechanism owned by `AllInOneCaptureCoordinator` (a `Task` held by the
   coordinator, or the narrow scheduler seam described in Scope).
4. At expiry, capture only `viewModel.captureArea(at: rect)`; never invoke
   fullscreen, window, annotate, OCR, scrolling, or recording from Timer.
5. Cancel the pending work if All-In-One is cancelled, restarted, the app is
   terminated, or a new timer request replaces it. A cancelled/dismissed
   request must never capture later.

If a short countdown indicator is retained after HUD teardown, it must be a
separate non-capturable Notinhas surface, be explicitly cancellable with
Escape, and have an accessible status announcement. Prefer no new indicator
unless it can be proven not to be included in the delayed screenshot; a fixed
three-second delay itself is sufficient for this plan.

Do not use `QuickAccessCountdownTimer`; it owns pausable post-capture card
dismissal. Do not create a `UserDefaults` duration key.

**Verify**: Add deterministic tests using an injected/manual scheduler or
equivalent seam: (a) Timer dispatches exactly one area capture with the chosen
rectangle after its scheduled callback; (b) cancellation before expiry dispatches
none; (c) a second request cannot let the first callback capture; (d) Area and
Annotate dispatch behavior remains unchanged. Run focused tests with no real
three-second sleeps.

### Step 5: Update documentation and run the full validation matrix

Update `docs/CAPTURE.md` so its All-In-One modes list includes both Annotate
and Timer, and define Timer precisely as a fixed three-second delayed area
capture. Remove the stale text that says Timer stays a dedicated entry. Do not
claim a preference, shortcut, or countdown UI that this plan does not ship.

Format only the changed Swift files and run all commands from "Commands you
will need." Resolve relevant failures before updating the plan index.

**Verify**: `git diff --check` exits 0, all listed automated commands pass,
and the manual checks below are recorded in the change handoff.

## Test plan

- Extend `AllInOneCaptureModeTests` with exact mode ordering for Video-off and
  Video-on, `.timer.rawValue == "timer"`, `.timer.preservesSelectionRect`, and
  non-empty title, SF Symbol, and accessible action label.
- Extend `AllInOneCaptureCoordinatorTests` or add an All-In-One-only scheduler
  test file to prove delayed dispatch, cancellation, and replacement semantics
  without sleeping or accessing Screen Recording.
- Retain existing tests proving unavailable Recording is ignored in Video-off
  state and session callbacks still work.
- Run the focused tests plus the default Video-off suite; run the targeted
  Video-on mode test to protect the conditional Recording ordering.
- Manual macOS smoke with Screen Recording permission granted:
  1. Start All-In-One with no stored selection, drag a rectangle, and verify
     all seven labeled modes in default scheme: Area, Fullscreen, Window,
     Annotate, Scrolling, Timer, OCR.
  2. Select Annotate, resize via handles and dimensions, capture, and confirm
     the existing annotate flow opens unchanged.
  3. Select Timer, press Capture, arrange transient UI inside the selected
     region, and confirm exactly one screenshot appears after about three
     seconds with no HUD, selection overlay, or countdown window included.
  4. Start Timer and cancel/restart before expiry; wait more than three seconds
     and confirm no stale screenshot is created.
  5. Build/run Video-on, enable its runtime preference, and verify Recording
     remains the final labeled mode; do not test recording behavior as part of
     this plan.
  6. With VoiceOver, verify each mode announces its action and selected state;
     with Increase Contrast/Reduce Transparency enabled, verify selected and
     unselected modes remain distinguishable.

## Done criteria

All must hold:

- [ ] `AllInOneCaptureMode.availableModes(videoEnabled: false)` has Area,
  Fullscreen, Window, Annotate, Scrolling, Timer, OCR in that order and no
  Recording; Video-on appends Recording last.
- [ ] Timer is a fixed three-second, cancellable delayed call to
  `captureArea(at:)` using the selected rectangle; it cannot produce a stale
  capture after cancellation/restart.
- [ ] Annotate remains available and its existing selected-rectangle dispatch
  path passes regression tests.
- [ ] The default Video-off build/tests pass, and the targeted Video-on test
  confirms Recording remains gated.
- [ ] Each visible mode has a localized icon+label button, accessible action
  label, and a non-colour-only selected state.
- [ ] Width/height edits and aspect lock retain existing geometry behavior and
  accessible Width/Height labels.
- [ ] `docs/CAPTURE.md` describes Timer accurately and no longer says it is
  outside the strip.
- [ ] `swiftformat` and `git diff --check` pass.
- [ ] No files outside Scope are modified, except necessary Xcode project
  membership for a newly created timer scheduler file.
- [ ] `plans/README.md` marks 038 DONE only after validation is complete.

## STOP conditions

Stop and report back rather than improvising if:

- The live mode/coordinator/HUD code no longer matches the planned-at excerpts
  and the differences change timer dispatch or lifecycle ownership.
- Capturing after the delay requires a different `ScreenCaptureViewModel` API,
  a persistent preference, a new permission, or a new global shortcut.
- There is no safe way to keep a countdown indicator out of the captured
  image; omit the indicator rather than adding a risky overlay.
- Adding Timer would require changing classic `⌘⇧4`, standalone capture
  commands, Quick Access countdown code, Recording behavior, or a file outside
  Scope.
- A default-scheme build fails because Timer code references a Video-gated
  symbol.
- The focused timing tests can pass only by sleeping for real time or by
  depending on Screen Recording TCC.

## Maintenance notes

- `AllInOneCaptureMode` is the canonical availability/order contract. Future
  modes must define their display/accessibility metadata, selection requirement,
  coordinator dispatch, and Video-gate behavior together; do not add a toolbar
  case without a dispatch test.
- The Timer contract intentionally stays minimal. If product needs selectable
  duration, a visible countdown, repeat capture, or a shortcut, make a new
  design plan covering persistence, cancellation/permission semantics, and
  capture-overlay exclusion rather than extending this one ad hoc.
- Reviewers should scrutinize lifetime/cancellation of delayed work and verify
  that no floating Notinhas window remains visible inside the delayed capture.
- Smart Element/Object Cutout remain dedicated capture entries; keeping the
  all-in-one strip focused is intentional.
