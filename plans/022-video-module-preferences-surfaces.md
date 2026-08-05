# Plan 022: Hide Video settings surfaces in Preferences

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- Snapzy/Features/Preferences`
> Require `VideoModuleAvailability` from plan 020. Advanced toggle from 020 must already exist.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/020-video-module-gate-and-build.md (021 recommended first for end-to-end QA, not a hard code dep)
- **Category**: tech-debt | direction
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — Preferences UI workstream (independent of 023 once 020 exists)
- **Reviewer required**: `no` — UI hide/show with clear checklist; escalate if After Capture matrix layout breaks
- **Rationale**: Localized SwiftUI visibility changes; no capture pipeline edits.
- **Escalate when**: Hiding panes requires redesigning `CaptureSettingsPane` navigation beyond filtering cases.

## Why this matters

Capture → Recording pane, recording shortcuts, mic permission row, and History default-filter Videos/GIFs still advertise a feature that is off. Preferences must match the module gate so the app feels coherent for screenshot-only Notinhas users. The **master** runtime toggle stays in Advanced (020); this plan only hides dependent surfaces when `!VideoModuleAvailability.isEnabled` (and when not compiled in).

## Current state

### Capture (`PreferencesCaptureSettingsView.swift`)

- Segmented panes: `general` / `screenshot` / `recording` (`CaptureSettingsPane`, ~11–28).
- General pane video-specific: include-in-recordings (~133–140), recording filename template (~323+), After Capture matrix with recording column (`PreferencesAfterCaptureMatrixView`).
- Entire Recording pane (~367–630): format, FPS, quality, cursor, area, hover bar, menu bar time, mouse highlight, keystrokes, audio/mic.

### Shortcuts (`PreferencesShortcutsSettingsView.swift`)

- Recording section (~439–516): record, app recording, pause, pen, restart, delete.
- Tools: Open Video Editor (~530–538).

### History (`PreferencesHistorySettingsView.swift`)

- Default filter picker includes Videos / GIFs (~56–57).

### Permissions (`PreferencesPermissionsSettingsView.swift`)

- Microphone row (~62–71) — video-only optional.
- Screen Recording row — **keep** (required for screenshots).

### Tabs with no video controls

General, Annotate, Quick Access, Cloud, Advanced (except master toggle from 020), About.

### Locked behavior

| Surface | When `!isEnabled` |
|---------|-------------------|
| Capture Recording pane | Hide pane from segmented control |
| Capture General: include-in-recordings + recording template | Hide |
| After Capture matrix recording column | Hide |
| Shortcuts Recording section + Open Video Editor | Hide |
| History default filter Videos/GIFs | Remove options (keep Screenshots / All) |
| Permissions Microphone | Hide |
| Permissions Screen Recording | Keep |
| Advanced Video toggle | Visible only if `isCompiledIn` (020) |

When user turns Advanced toggle **on**, surfaces reappear without relaunch if views observe availability (use `NotificationCenter` / `@State` refresh / small `ObservableObject`). Prefer observing `.videoModuleAvailabilityDidChange`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Snapzy/Features/Preferences Snapzy/Shared/Localization` | exit 0 |
| Build Video scheme + smoke | `./scripts/build_and_run.sh` with video enabled | app launches |
| Tests | none required unless you add a tiny view-model helper test | — |

## Suggested executor toolkit

- `.agents/skills/localization/SKILL.md`
- `.agents/skills/macos-app-engineering/SKILL.md`
- `.agents/skills/apple-design/SKILL.md` — keep Advanced/Capture chrome consistent

## Scope

**In scope**:
- `Snapzy/Features/Preferences/Components/PreferencesCaptureSettingsView.swift`
- `Snapzy/Features/Preferences/Components/PreferencesAfterCaptureMatrixView.swift`
- `Snapzy/Features/Preferences/Components/PreferencesShortcutsSettingsView.swift`
- `Snapzy/Features/Preferences/Components/PreferencesHistorySettingsView.swift`
- `Snapzy/Features/Preferences/Components/PreferencesPermissionsSettingsView.swift`
- Minimal shared helper if needed (e.g. `VideoModuleAvailability.isEnabled` only — avoid new prefs framework)
- `plans/README.md`

**Out of scope**:
- Advanced master toggle (020)
- Menu/shortcuts runtime registration (021)
- Onboarding (023)
- Compile stripping (024)
- Deleting `PreferencesKeys` recording keys
- Config TOML schema changes

## Git workflow

- Branch: `feat/video-module-preferences-surfaces`
- Commit: `feat: hide video preferences when module disabled`

## Steps

### Step 1: Capture panes

- Filter `CaptureSettingsPane.allCases` (or picker content) to exclude `.recording` when `!VideoModuleAvailability.isEnabled`.
- If `selectedPane == .recording` becomes invalid after disable, reset to `.general`.
- Conditionally hide include-in-recordings + recording filename UI on General pane.

**Verify**: `rg -n "CaptureSettingsPane|includeInRecordings|recordingFileNameTemplate" Snapzy/Features/Preferences/Components/PreferencesCaptureSettingsView.swift` → gated.

### Step 2: After Capture matrix

In `PreferencesAfterCaptureMatrixView.swift`, hide recording column header + toggles when disabled; keep screenshot column layout usable (no empty gap that looks broken — stack or single column).

**Verify**: Visual/manual; code has `VideoModuleAvailability.isEnabled` guard.

### Step 3: Shortcuts

Hide Recording section and Open Video Editor row when disabled. Leave “Edit latest capture” Quick Access shortcut visible (runtime already chooses Annotate vs Editor — Editor path gated in 023).

**Verify**: `rg -n "recordingSection|openVideoEditor|Actions.recordVideo" Snapzy/Features/Preferences/Components/PreferencesShortcutsSettingsView.swift` → gated.

### Step 4: History + Permissions

- History filter: omit `.video` / `.gif` cases when disabled.
- Permissions: omit microphone row when disabled; keep Screen Recording.

**Verify**: `rg -n "microphone|\.video|\.gif" Snapzy/Features/Preferences/Components/PreferencesHistorySettingsView.swift Snapzy/Features/Preferences/Components/PreferencesPermissionsSettingsView.swift`

### Step 5: Live refresh

Ensure flipping Advanced toggle updates open Preferences windows (notification → `objectWillChange` or `.onReceive`). If Preferences is recreated each open, documenting “reopen tab” is acceptable STOP alternative — prefer live update.

**Verify**: Manual with Video build: enable module → Capture shows Recording pane without app restart.

## Test plan

- Prefer manual Preferences checklist (Done criteria).
- Optional: pure helper `CaptureSettingsPane.availablePanes(videoEnabled:)` unit test if you extract filtering — not mandatory.

## Done criteria

- [ ] Recording Capture pane and recording-specific General rows hidden when module disabled
- [ ] After Capture recording column hidden when disabled
- [ ] Recording shortcuts + Open Video Editor hidden when disabled
- [ ] History default filter omits Videos/GIFs when disabled
- [ ] Microphone permission row hidden when disabled; Screen Recording remains
- [ ] Enabling Advanced toggle restores surfaces (live or after revisiting tab — document which)
- [ ] `plans/README.md` updated

## STOP conditions

- After Capture matrix cannot render screenshot-only without a redesign of shared grid — stop with screenshot of layout issue
- Hiding panes leaves `selectedPane` crash
- Plan 020 toggle missing

## Maintenance notes

- New recording prefs must be placed behind the same `isEnabled` checks.
- Do not remove UserDefaults keys; disabled UI simply stops writing new values.
