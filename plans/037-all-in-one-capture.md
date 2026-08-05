# Plan 037: Ship All-In-One capture session (modes + shortcut + menu)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 1849b93a..HEAD -- Notinhas/Features/Capture/CaptureViewModel.swift Notinhas/Services/Shortcuts/KeyboardShortcutManager.swift Notinhas/App/AppStatusBarController.swift Notinhas/App/NotinhasDeepLinkHandler.swift Notinhas/Features/Preferences/Components/PreferencesShortcutsSettingsView.swift Notinhas/Shared/Localization/L10n.swift docs/CAPTURE.md docs/SHORTCUTS.md Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne`
> Expect plans 035–036 files to exist. If `ShortcutAction` / menu construction / deeplink tables drifted heavily, reconcile carefully or STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/035-shared-capture-floating-chrome.md, plans/036-capture-selection-refinement.md
- **Category**: direction
- **Planned at**: commit `1849b93a`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: `no`
- **Reviewer required**: `yes` — new global shortcut + capture session orchestration across modes
- **Rationale**: Cross-cuts shortcuts, menu bar, capture VM, overlays, L10n, docs; Video-gated Recording mode must stay optional.
- **Escalate when**: Implementing mode switches requires rewriting `AreaSelectionController` session lifecycle, or Recording-from-AIO cannot call existing `startRecordingFlow` without duplicating recording setup.

## Why this matters

CleanShot’s All-In-One gives **one shortcut** that opens capture already in an interactive HUD: pick **what** (mode) and **where** (area), set size / aspect lock, and reuse the last selection. Notinhas already has the individual modes and (after 035–036) shared chrome + refinement primitives — this plan assembles them into a first-class All-In-One session aligned with Notinhas’ visual-handoff loop (especially **Area Annotate**).

Official CleanShot framing to honor: easy access to capture modes with one shortcut; size + aspect lock; last selection for retakes.

## Current state

### No All-In-One today

- Each `ShortcutAction` maps 1:1 to a capture method in `ScreenCaptureViewModel.shortcutTriggered` (`Notinhas/Features/Capture/CaptureViewModel.swift` ~370+).
- Menu bar lists modes flat in `AppStatusBarController` (~450+).
- Deeplinks listed in `NotinhasDeepLinkHandler` / `NotinhasDeepLinkAction`.
- `GlobalShortcutKind` / `ShortcutAction` have no `allInOne` case (`KeyboardShortcutManager.swift` ~511–606).

### Existing modes to expose (MVP set)

| AIO toolbar mode | Dispatches to | Notes |
|------------------|---------------|-------|
| Area | `captureArea()` path **or** AIO-owned crop commit | Default selected mode |
| Fullscreen | `captureFullscreen()` | No area refine needed; hide handles / ignore rect |
| Window | `captureApplication()` / application interaction | Prefer existing application-window flow |
| Annotate | `captureAreaAnnotate()` / inline annotate | Core Notinhas loop — **required** |
| Scrolling | `captureScrolling()` | May hand off to scrolling coordinator after region chosen |
| OCR | `captureOCR()` | Clipboard text; still uses an area |
| Recording | `startRecordingFlow()` / toggle | **Only if** `VideoModuleAvailability.isEnabled` (implies compiled-in) |

**Explicitly out of MVP toolbar**: Timer (does not exist), Smart Element, Object Cutout (keep dedicated shortcuts/menu items).

### Building blocks from 035–036

- `CaptureFloatingHUDWindow` + chrome buttons/placement
- `CaptureLastSelectionStore` + `CaptureSelectionGeometry` + `AllInOneSelectionRefinementController` + `AllInOneDimensionsBarView`

### Conventions

- Entry point remains `ScreenCaptureViewModel` for captures.
- L10n via `L10n` + xcstrings (`docs/LOCALIZATION.md`).
- Shortcut defaults: prefer **shipping unbound (cleared)** with recommended combo **⌘⇧0** (avoids colliding with ⌘⇧3–7). Seed into cleared set like `pauseResumeRecording`.
- Deep link: `notinhas://capture/all-in-one` (host/path style matching existing routes — read `NotinhasDeepLinkAction` and mirror).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat` on touched Swift paths | exit 0 |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests` | pass |
| Shortcut wiring tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/KeyboardShortcutManagerTests` (or new All-In-One shortcut tests) | pass / or create dedicated file |
| Default suite smoke | `./scripts/run-tests.sh --skip-visual` | no new failures in touched areas |
| Manual | Grant Screen Recording → trigger All-In-One from menu → switch modes → capture | see Test plan |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md`
- `.agents/skills/menubar/SKILL.md` — `AppStatusBarController` invariants
- `.agents/skills/localization/SKILL.md`
- `.agents/skills/documentation/SKILL.md` — CAPTURE.md / SHORTCUTS.md
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/testing-xctest/SKILL.md`
- `.agents/skills/accessibility-audit/SKILL.md` — VoiceOver labels on mode buttons

## Scope

**In scope**:

- **Create** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureMode.swift` — enum of MVP modes + availability helpers
- **Create** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift` — left/main mode strip (icons + labels optional; icons required)
- **Create** `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift` — dimensions bar + aspect lock + Capture button (+ optional chevron menu only if needed; keep simple: primary Capture)
- **Create** `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` — session lifecycle
- **Create** tests under `NotinhasTests/Features/Capture/` e.g. `AllInOneCaptureModeTests.swift` (availability filtering, last-mode memory if implemented)
- **Modify** `ScreenCaptureViewModel` — `captureAllInOne()` + `shortcutTriggered` case
- **Modify** `KeyboardShortcutManager` — kind/action/default/cleared seeding/persistence key
- **Modify** `PreferencesKeys`, `PreferencesShortcutsSettingsView`
- **Modify** `AppStatusBarController` — menu item near top of capture section
- **Modify** `NotinhasDeepLinkHandler` / `NotinhasDeepLinkAction`
- **Modify** Shortcut overlay models if they enumerate global kinds (`ShortcutOverlayModels` / cheat sheet)
- **Modify** `L10n` + xcstrings for user-facing strings
- **Modify** `docs/CAPTURE.md`, `docs/SHORTCUTS.md` (and `docs/APP_LIFECYCLE.md` only if it lists capture entry points)
- **Modify** Xcode project membership
- **Modify** `plans/README.md`

**Out of scope**:

- Replacing classic per-mode shortcuts
- Timer capture
- Adding Smart Element / Cutout into the AIO strip
- Redesigning recording pre-record toolbar
- Changing post-capture routing / annotate tools
- Sparkle / About / snapzy

## Session UX (normative)

1. User invokes All-In-One (shortcut / menu / deeplink).
2. Coordinator shows dimmed capture chrome:
   - Mode toolbar (floating) using plan-035 HUD
   - Action toolbar with dimensions + aspect lock + Capture
3. Selection:
   - If last rect valid → show it via plan-036 refinement overlays immediately.
   - Else → user drags a new rect (use `AreaSelectionController` **or** click-drag on refinement overlay’s reselect path — pick one approach and stick to it; preferred: start `AreaSelectionController` for first drag when no last rect, then hand off to refinement controller; if last rect exists, skip straight to refinement).
4. Mode changes update toolbar selection; may show/hide refinement:
   - Fullscreen: hide handles; Capture runs fullscreen immediately on confirm (rect ignored).
   - Window: switch into application-window picking (reuse existing overlay interaction / `captureApplication` flow). Simplest acceptable MVP: selecting Window dismisses AIO chrome and starts `captureApplication()` directly.
   - Area / Annotate / OCR / Scrolling / Recording: keep/refine rect, then confirm.
5. Capture button:
   - Persist last rect (when mode used a rect)
   - Tear down AIO UI
   - Dispatch to the existing VM method for that mode (for Area, call into the same crop/save pipeline area capture uses — do **not** fork export naming/post-capture).
6. Escape / Cancel tears down without capture.

### Recording mode special case

```swift
guard VideoModuleAvailability.isEnabled else { /* hide mode */ }
#if NOTINHAS_VIDEO_MODULE
  // startRecordingFlow with selected rect if API allows; else startRecordingFlow()
#endif
```

If starting recording with a pre-chosen rect is awkward, MVP may: selecting Recording exits AIO and calls existing `startRecordingFlow()` (which has its own toolbar). Document that compromise in code comment + CAPTURE.md.

## Git workflow

- Branch: `advisor/037-all-in-one-capture`
- Commits: e.g. `feat(capture): add All-In-One capture mode and shortcut`
- Do NOT push/PR unless instructed.

## Steps

### Step 1: Mode model + availability

```swift
enum AllInOneCaptureMode: String, CaseIterable, Identifiable {
  case area, fullscreen, window, annotate, scrolling, ocr, recording
}
```

`static func availableModes(videoEnabled: Bool) -> [AllInOneCaptureMode]` filters `.recording` unless video enabled.

Unit test availability filtering.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests`

### Step 2: Toolbar SwiftUI

Build mode strip + action strip using plan-035 chrome (`CaptureFloatingToolbarIconButton`, dividers, material). Provide accessibility labels via L10n.

Visual reference: user-provided CleanShot screenshot (mode icons in a dark translucent bar; separate dimensions + capture cluster). Match **spirit**, not pixel-perfect cloning.

**Verify**: previews compile; default build later.

### Step 3: Coordinator session

`AllInOneCaptureCoordinator` (`@MainActor`):

- `start(from: ScreenCaptureViewModel)` / `cancel()` / `confirm()`
- Owns HUD window(s), refinement controller, selected mode, current rect
- Saves/loads last rect via `CaptureLastSelectionStore`
- Ensures only one session (cancel previous if re-entered) — mirror `AreaSelectionController` re-entrancy discipline

Wire `ScreenCaptureViewModel.captureAllInOne()` to start the coordinator after permission checks (same guards other capture methods use).

**Verify**: default build.

### Step 4: Shortcut + preferences + menu + deeplink

1. Add `GlobalShortcutKind.allInOne`, `ShortcutAction.captureAllInOne`
2. `ShortcutConfig.defaultAllInOne` = ⌘⇧0
3. Seed cleared-on-first-launch (unbound by default) like other optional shortcuts
4. Persistence key in `PreferencesKeys`
5. Preferences Shortcuts UI row near Area / Fullscreen
6. Menu item **above** Capture Area (or immediately below a separator at top of capture block) titled via L10n (e.g. “All-In-One”)
7. Deeplink route
8. Cheat-sheet / shortcut overlay enumeration if required for compile exhaustiveness

**Verify**: unit test that `shortcut(for: .allInOne)` is nil when cleared; action maps when bound. Update any exhaustive switches the compiler flags.

### Step 5: Localization + docs

- Add L10n strings for mode names already shared where possible (`L10n.Actions.*`); new strings for “All-In-One”, dimensions a11y, Capture button a11y
- Update `docs/CAPTURE.md` flow index + mode table
- Update `docs/SHORTCUTS.md` global table

**Verify**: docs mention All-In-One; `rg "All-In-One|all-in-one|allInOne" docs` shows hits.

### Step 6: Format, tests, manual checklist, index

```bash
swiftformat <touched paths>
./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureModeTests
./scripts/build_and_run.sh --no-video-module
```

Manual (operator or executor with Screen Recording):

1. Bind All-In-One shortcut in Preferences (⌘⇧0).
2. Invoke → HUD appears; last rect restores if prior capture saved one.
3. Switch Area → Annotate → Capture → lands in annotate flow.
4. Switch Fullscreen → Capture → fullscreen save path.
5. With Video module off, Recording mode absent; with module on + enabled, Recording visible.

Update `plans/README.md`.

## Test plan

- `AllInOneCaptureModeTests`: availability with video on/off; raw value stability
- Shortcut manager: cleared default; enabling registers (follow existing shortcut test patterns under `NotinhasTests/Services/Shortcuts/`)
- Prefer **not** adding full visual overlay tests that flash screens; if adding any, gate with existing visual-skip patterns

## Done criteria

- [ ] All-In-One reachable from menu, optional shortcut, and `notinhas://` deeplink
- [ ] Mode strip shows MVP modes; Recording gated by `VideoModuleAvailability.isEnabled`
- [ ] Dimensions + aspect lock + last selection work via plan-036 pieces
- [ ] Confirm dispatches into existing capture pipelines (no forked save/export)
- [ ] Escape cancels cleanly; re-entry cancels prior session
- [ ] Default scheme build + focused tests pass
- [ ] `docs/CAPTURE.md` + `docs/SHORTCUTS.md` updated
- [ ] Classic per-mode shortcuts still work unchanged
- [ ] `plans/README.md` updated

## STOP conditions

- Plans 035 or 036 incomplete / APIs missing — do not reimplement chrome or geometry here.
- Exhaustive switch updates appear in unrelated modules with unclear behavior — stop and list them.
- Application-window or scrolling handoff requires large rewrites of those coordinators — narrow MVP (Window/Scrolling = “exit AIO and call existing entry point”) instead of improvising deep integration; if even that fails, STOP.
- Pressure to add Timer / Smart Element / Cutout into the strip — refuse; out of scope.
- Any suggestion to depend on `RecordingToolbarWindow` (video-gated) for AIO chrome — refuse; use plan-035 host.

## Maintenance notes

- Future modes: extend `AllInOneCaptureMode` + toolbar + docs; keep availability helpers centralized.
- Reviewers: permission prompts, overlay level vs selection overlays, and that Video-off builds never reference recording-only symbols without `#if`.
- Deferred: Timer countdown mode; in-AIO Smart Element; migrating classic area capture to refinement; pixel-perfect CleanShot visual clone; scrolling HUD migration onto shared host.
