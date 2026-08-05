# Plan 023: Gate History, Quick Access, and Onboarding for Video

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- Snapzy/Features/History Snapzy/Features/QuickAccess Snapzy/Features/Onboarding Snapzy/Services/Capture/PostCaptureActionHandler.swift`
> Require plans 020–021 for coherent behavior (History open must not call Video Editor when disabled).

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/020-video-module-gate-and-build.md, plans/021-video-module-shell-entry-gates.md
- **Category**: tech-debt | direction
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — overlaps History/QA open paths with 021
- **Reviewer required**: `yes` — existing media policy is user-visible
- **Rationale**: Touches open/edit routing and onboarding permissions copy.
- **Escalate when**: GIF clipboard vs editor behavior conflicts with locked policy and needs product re-decision.

## Why this matters

With recording gated, History/Quick Access still open `.video`/`.gif` in `VideoEditorManager`, and onboarding still sells recording + microphone. Locked policy: **keep listing** existing media; **hide edit-in-editor**; keep copy/save/Finder/delete; adjust onboarding when module/runtime off.

## Current state

History open routes video/gif to editor:

```153:174:Snapzy/Features/History/HistoryWindowController.swift
      switch record.captureType {
      case .screenshot:
        ...
        AnnotateManager.shared.openAnnotation(for: item)
      case .video, .gif:
        ...
        VideoEditorManager.shared.openEditor(for: item)
      }
```

Quick Access card: `openVideoEditor()` via `VideoEditorManager.shared.openEditor(for:)` (`QuickAccessCardView.swift` ~429–444).

Onboarding:
- Welcome feature row record (`OnboardingWelcomeView.swift` ~35)
- Microphone + Screen Recording (`OnboardingPermissionsView.swift`)
- Shortcuts section Recording + Video Editor (`OnboardingShortcutsView.swift` ~49–55)

Floating history filters include Videos/GIFs (`HistoryFloatingContentView` — confirm with `rg`).

### Locked behavior

- List `.video`/`.gif` in History/QA when module off.
- Primary “edit” / double-click open that would launch Video Editor: **do not** open editor when `!isEnabled`; prefer reveal in Finder or no-op with a short toast (“Video editor is disabled”) — pick **reveal in Finder** if an existing helper exists; else toast via `AppToastManager` pattern already used in the app.
- Copy / save / delete / show in Finder remain.
- Onboarding when `!isEnabled` (treat compile-out as disabled): hide welcome record row; hide microphone row; hide recording shortcut group + video editor shortcut; keep Screen Recording permission with screenshot-focused description when video disabled.
- When `isEnabled`, current onboarding copy remains.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Tests | `./scripts/run-tests.sh -only-testing:SnapzyTests/Features/QuickAccess` (and History if present) | pass |
| Format | `swiftformat Snapzy/Features/History Snapzy/Features/QuickAccess Snapzy/Features/Onboarding` | exit 0 |

## Suggested executor toolkit

- `.agents/skills/localization/SKILL.md`
- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/accessibility-audit/SKILL.md` — permission row labels
- `.agents/skills/capture-annotate-export/SKILL.md` — do not expand recording scope

## Scope

**In scope**:
- `Snapzy/Features/History/HistoryWindowController.swift`
- History floating filter UI files that list Videos/GIFs (e.g. `HistoryFloatingContentView.swift`, `HistoryFilterBar.swift`) — **filters may still show Videos/GIFs** so users can find old items; only Preferences default-filter options were removed in 022. Do not delete filter chips unless they confuse — keep chips so existing media remains findable.
- `Snapzy/Features/QuickAccess/Components/QuickAccessCardView.swift`
- Any Quick Access “edit latest” path that opens Video Editor (`QuickAccessManager.swift` ~1279+)
- Onboarding: `OnboardingWelcomeView.swift`, `OnboardingPermissionsView.swift`, `OnboardingShortcutsView.swift`
- Shared toast/copy strings in `L10n` as needed
- `plans/README.md`

**Out of scope**:
- Deleting history records when disabling module
- Post-capture pipeline rewrite (recording cannot start when disabled after 021 — `PostCaptureActionHandler.handleVideoCapture` can stay)
- Preferences (022)
- Compile stripping (024)

## Git workflow

- Branch: `feat/video-module-history-onboarding`
- Commit: `feat: gate video editor opens and onboarding behind video module`

## Steps

### Step 1: History open path

Replace unconditional `VideoEditorManager.shared.openEditor` with:

```swift
case .video, .gif:
  guard VideoModuleAvailability.isEnabled else {
    // reveal in Finder OR toast — implement one consistently
    return
  }
  VideoEditorManager.shared.openEditor(for: item)
```

**Verify**: `rg -n "VideoEditorManager" Snapzy/Features/History` → guarded.

### Step 2: Quick Access

Gate `openVideoEditor()` and edit-latest-capture video branch the same way. Hide or disable the Edit action on video cards when module off if the action exists as a button (keep Copy/Save/Delete).

**Verify**: `rg -n "openVideoEditor|VideoEditorManager" Snapzy/Features/QuickAccess` → guarded.

### Step 3: Onboarding

- Welcome: wrap record `FeatureRow` in `if VideoModuleAvailability.isEnabled` (compile-out → false).
- Permissions: hide microphone when disabled; adjust Screen Recording description to screenshot-only string when disabled (add `L10n` string; do not remove the permission).
- Shortcuts page: hide recording section + video editor item when disabled.

**Verify**: `rg -n "welcomeFeatureRecord|microphone|openVideoEditorTitle|recordingSection" Snapzy/Features/Onboarding`

### Step 4: Tests + format

Update any tests that assume History always opens editor. Format. Mark 023 DONE.

## Test plan

- Manual: with module off and an existing video in History (if available), item visible; open does not present Video Editor.
- Manual: onboarding with module off shows no record feature / no mic / no recording shortcuts.
- XCTest: extend QuickAccess/History tests only if existing coverage hits these methods.

## Done criteria

- [ ] History/QA never open Video Editor when module disabled
- [ ] Existing video/gif items remain listed
- [ ] Copy/save/delete/Finder still available for those items
- [ ] Onboarding hides record feature, mic, recording/editor shortcuts when disabled
- [ ] Screen Recording permission remains with appropriate copy
- [ ] `plans/README.md` updated

## STOP conditions

- No Finder-reveal helper and no toast infrastructure — stop and ask which fallback to use (do not silently swallow opens without feedback)
- Onboarding flow structure differs enough that hiding rows breaks pagination — stop

## Maintenance notes

- New “open video” call sites must use the same guard.
- Reviewers: confirm GIF copy-to-clipboard still works when module off (History copy path treated GIF as image — preserve).
