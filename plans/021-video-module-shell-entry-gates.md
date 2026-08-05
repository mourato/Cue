# Plan 021: Gate app shell entry points behind the Video module

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- Snapzy/App Snapzy/Services/Shortcuts/KeyboardShortcutManager.swift Snapzy/Services/Capture/CaptureOverlayShortcutSettings.swift Snapzy/Features/Capture/CaptureViewModel.swift`
> If `VideoModuleAvailability` is missing, STOP — complete plan 020 first.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/020-video-module-gate-and-build.md
- **Category**: tech-debt | direction
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — depends on 020; blocks meaningful manual QA of “module off”
- **Reviewer required**: `yes` — menu bar + hotkeys are easy to get wrong
- **Rationale**: Many call sites; must keep screenshot capture working when video is off.
- **Escalate when**: Gating requires rewriting `GlobalShortcutKind` CaseIterable in a way that breaks config import/export.

## Why this matters

Even with a Preferences toggle, users still see Record Screen / Edit Video in the menu bar, can hit global hotkeys, and `AppCoordinator` always starts `RecordingMetadataCleanupScheduler`. Gating the shell makes “runtime off” and “compile off” actually free CPU/RAM and remove discoverability of a feature Notinhas treats as optional.

## Current state

Menu recording + edit video (always added today):

```517:582:Snapzy/App/AppStatusBarController.swift
    // Recording
    let recordItem = NSMenuItem(
      title: L10n.Menu.recordScreen,
      ...
    )
    ...
    menu?.addItem(editVideoItem)
```

Deep links always dispatch record / editor (`Snapzy/App/SnapzyDeepLinkHandler.swift` ~70–85): `.recordScreen`, `.recordApplication`, `.openVideoEditor`.

Shortcuts: `GlobalShortcutKind` includes `.recording`, `.pauseResumeRecording`, `.togglePenRecording`, `.restartRecording`, `.deleteRecording`, `.videoEditor` (`KeyboardShortcutManager.swift` ~465–477). Hotkey dispatch around ~1303–1326 calls into `CaptureViewModel` / `VideoEditorManager`.

Coordinator always starts/stops metadata cleanup (`AppCoordinator.swift` ~70, ~99).

`CaptureViewModel` exposes `startRecordingFlow()`, `startApplicationRecordingFlow()`, toggle/pause/pen/restart/delete (~1781+).

`AppStatusBarController` holds `ScreenRecordingManager.shared` (~line 22) and observes recording state for menu-bar timer UI.

### Locked behavior

- When `!VideoModuleAvailability.isEnabled`: no recording menu items, no Edit Video, no recording status-item UI path, do not start metadata cleanup scheduler, do not register/fire video-related global shortcuts, deep links for video are no-ops (log + ignore; do not crash).
- When compile-out (`!isCompiledIn`): same effective behavior; prefer `#if NOTINHAS_VIDEO_MODULE` around code that **references** Recording/VideoEditor types so module-off binaries can later drop those types (plan 024). Until 024, runtime checks alone are acceptable **if** compile still includes types — but still add `#if` around new code paths that would break once types are stripped.
- Screenshot / area / annotate / Notinhas menu items must keep working.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused tests | `./scripts/run-tests.sh -only-testing:SnapzyTests/App/SnapzyDeepLinkHandlerTests` | pass (update expectations if video routes change) |
| Status bar tests | `./scripts/run-tests.sh -only-testing:SnapzyTests/App/AppStatusBarControllerTests` | pass |
| Format | `swiftformat Snapzy/App Snapzy/Services/Shortcuts Snapzy/Features/Capture SnapzyTests/App` | exit 0 |

## Suggested executor toolkit

- `.agents/skills/menubar/SKILL.md`
- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/delivery-workflow/SKILL.md`
- `.agents/skills/swift-concurrency-expert/SKILL.md` if touching MainActor observers

## Scope

**In scope**:
- `Snapzy/App/AppStatusBarController.swift`
- `Snapzy/App/AppCoordinator.swift`
- `Snapzy/App/SnapzyDeepLinkHandler.swift`
- `Snapzy/Services/Shortcuts/KeyboardShortcutManager.swift` (registration / dispatch only — do not delete enum cases yet)
- `Snapzy/Features/Capture/CaptureViewModel.swift` (early-return guards on recording entry points)
- Tests under `SnapzyTests/App/` that assert video deep links / menu behavior if present
- `plans/README.md` status

**Out of scope**:
- Preferences Capture/Shortcuts UI hiding (022)
- History/QA/Onboarding (023)
- Stripping Recording sources from the target (024)
- Changing shortcut defaults stored in UserDefaults
- Notinhas feature code

## Git workflow

- Branch: continue `feat/video-module-gate` or `feat/video-module-shell-gates`
- Commit style: `feat: gate recording menu and shortcuts behind video module`

## Steps

### Step 1: Helper for “video actions allowed”

In `VideoModuleAvailability` (from 020), ensure callers can use `isEnabled`. Optionally add:

```swift
static var areVideoActionsAllowed: Bool { isEnabled }
```

Do not duplicate UserDefaults reads ad hoc in five files.

**Verify**: `rg -n "VideoModuleAvailability" Snapzy/Services/Configuration/VideoModuleAvailability.swift`

### Step 2: AppCoordinator scheduler

Wrap start/stop of `RecordingMetadataCleanupScheduler` so it only runs when `VideoModuleAvailability.isEnabled` at launch. Observe `.videoModuleAvailabilityDidChange`: if enabled → `start()`; if disabled → `stop()` (only when no active recording — if recording can exist only when enabled, stop is safe).

```69:71:Snapzy/App/AppCoordinator.swift
    RecordingMetadataCleanupScheduler.shared.start()
```

**Verify**: `rg -n "RecordingMetadataCleanupScheduler" Snapzy/App/AppCoordinator.swift` → guarded by availability.

### Step 3: Menu bar

In `AppStatusBarController` menu construction:
- Add Record Screen / Application Recording / Edit Video **only** when `VideoModuleAvailability.isEnabled`.
- Skip recording-in-progress menu items / status title path when disabled (if somehow active, still allow Stop — belt and suspenders; ideally recording cannot start when disabled).
- When compile-out comes in 025, these blocks should already be `#if NOTINHAS_VIDEO_MODULE` + runtime check.

Also gate `observeRecordingState` / timer UI if it retains recorder work while idle — idle observation should not run when module disabled.

**Verify**: Manual with module off: menu has no Record / Edit Video. With module on + runtime on: items return.

### Step 4: Deep links

In `SnapzyDeepLinkHandler`, for `.recordScreen`, `.recordApplication`, `.openVideoEditor`: if `!VideoModuleAvailability.isEnabled`, log and return (same pattern as disabled URL scheme).

Update `SnapzyDeepLinkHandlerTests` accordingly (expect no recording start when disabled).

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/App/SnapzyDeepLinkHandlerTests`

### Step 5: Global shortcuts

In `KeyboardShortcutManager` hotkey dispatch / registration:
- When registering carbon/hotkeys for video kinds, skip if `!isEnabled`.
- On `.videoModuleAvailabilityDidChange`, re-register shortcuts (enable or tear down video kinds).
- `CaptureViewModel` recording methods: first line `guard VideoModuleAvailability.isEnabled else { return }`.

Do **not** remove cases from `GlobalShortcutKind` (config TOML still may list them; 023 hides Preferences UI).

**Verify**: `rg -n "startRecordingFlow|openEmptyEditor|pauseResumeRecording" Snapzy/Services/Shortcuts/KeyboardShortcutManager.swift Snapzy/Features/Capture/CaptureViewModel.swift` → guards present or dispatch unreachable when disabled.

### Step 6: Format + README

`swiftformat` touched paths; mark plan 021 DONE in `plans/README.md`.

## Test plan

- Update deep link tests for disabled module.
- Add or extend a small test if one already builds menus (`AppStatusBarControllerTests`) — only if there is an existing seam for menu contents; do not invent a huge AppKit menu snapshot suite. If no seam, document manual checklist in Done criteria.
- Manual: runtime toggle off → no record hotkey; toggle on → record hotkey works (Video build).

## Done criteria

- [ ] `RecordingMetadataCleanupScheduler` only runs when video module enabled
- [ ] Menu omits Record Screen, Application Recording, Edit Video when disabled
- [ ] Video deep links no-op when disabled; tests updated
- [ ] Global shortcut dispatch does not start recording/editor when disabled
- [ ] `CaptureViewModel` recording entry points guard on `VideoModuleAvailability.isEnabled`
- [ ] Screenshot capture menu items still present when video disabled
- [ ] `plans/README.md` updated

## STOP conditions

- Plan 020 artifacts missing
- Removing `GlobalShortcutKind` cases is required to compile — stop (that belongs with config migration design)
- Menu gating breaks non-video capture items
- Drift makes line references wrong and behavior unclear

## Maintenance notes

- Any new recording entry point (widget, another deep link) must check `VideoModuleAvailability.isEnabled`.
- Reviewers: search for `VideoEditorManager`, `RecordingCoordinator`, `startRecordingFlow` outside `#if` / guards after this lands.
