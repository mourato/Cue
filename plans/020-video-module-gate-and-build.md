# Plan 020: Introduce the Video module gate and build affordances

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat f29a2c6..HEAD -- scripts/build_and_run.sh Snapzy.xcodeproj Snapzy/Features/Preferences Snapzy/App Snapzy/Services/Capture/RecordingMetadataCleanupScheduler.swift Snapzy/Shared/Localization/L10n.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt | direction
- **Planned at**: commit `f29a2c6`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — foundation for 021–025
- **Reviewer required**: `yes` — build-flag / scheme / script UX must match maintainer decisions
- **Rationale**: Touches Xcode project, schemes, and the interactive build script; wrong defaults ship a heavy video stack.
- **Escalate when**: Xcode synchronized-group / scheme edits require structural pbxproj changes beyond adding `SWIFT_ACTIVE_COMPILATION_CONDITIONS` and a shared scheme copy.

## Why this matters

Notinhas product intent is screenshot visual handoff, not Snapzy’s full recording suite. Recording + Video Editor must become an **optional module**: compile-time flag (default off) plus a runtime toggle (default off when compiled in). This plan creates the single availability API, wires the build flag, adds a `Snapzy Video` scheme, and makes `./scripts/build_and_run.sh` ask interactively whether to enable the module — so developers do not hunt xcconfig by hand.

## Current state

- Preferences tabs: `PreferencesTab` in `Snapzy/Features/Preferences/Models/PreferencesNavigationState.swift` (no video tab; Advanced has URL scheme + diagnostics).
- Advanced UI today (integration section only):

```114:123:Snapzy/Features/Preferences/Components/PreferencesAdvancedSettingsView.swift
      Section(L10n.PreferencesAdvanced.integrationSection) {
        SettingRow(
          icon: "link",
          title: L10n.PreferencesAdvanced.urlSchemeTitle,
          description: L10n.PreferencesAdvanced.urlSchemeDescription
        ) {
          Toggle("", isOn: $urlSchemeEnabled)
            .labelsHidden()
        }
      }
```

- Project Debug already sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";` in `Snapzy.xcodeproj/project.pbxproj` (~line 328). There is **no** `NOTINHAS_VIDEO_MODULE` flag.
- Only one shared scheme: `Snapzy.xcodeproj/xcshareddata/xcschemes/Snapzy.xcscheme`.
- Interactive build menu in `scripts/build_and_run.sh` (`configure_interactive_build`, ~lines 80–116) asks Debug vs Release and clean — **not** video module.
- `run_xcodebuild` always uses `SCHEME="Snapzy"` and does not pass extra Swift flags (~272–300).
- Lifecycle always starts recording metadata cleanup:

```69:71:Snapzy/App/AppCoordinator.swift
    LogCleanupScheduler.shared.start()
    RecordingMetadataCleanupScheduler.shared.start()
    CaptureHistoryRetentionService.shared.start()
```

- **No** feature-flag / module-enable pattern exists for video.
- Conventions: Swift 5.9, two-space indent, Conventional Commits (`feat:`, `refactor:`). Localization via `L10n` in `Snapzy/Shared/Localization/L10n.swift`. Preferences keys in `PreferencesKeys`.
- Product intent (AGENTS.md): do not expand broad recording unless it serves handoff; making video opt-in is aligned.

### Locked product decisions (do not reopen)

1. Hybrid: compile flag `NOTINHAS_VIDEO_MODULE` + runtime toggle when compiled in.
2. Perimeter: Recording + VideoEditor + recording-only services + menu/shortcuts/deeplinks/prefs for those; **keep** Screen Recording TCC for screenshots; leave generic Cloud / Annotate / Notinhas alone.
3. Runtime default: **off** (opt-in).
4. Existing `.video`/`.gif` history: keep listed; hide open-in-Video-Editor; keep copy/save/Finder/delete (implemented in later plans).
5. Runtime toggle lives in **Advanced**.
6. Cannot turn runtime off while a recording session is active (UI disabled or alert) — implement toggle policy here; full session wiring may complete in 021.
7. Onboarding gating → plan 023.
8. Debug/Release default compile **off**; dedicated **Snapzy Video** scheme with flag **on**; `build_and_run.sh` configures the flag **interactively**.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat scripts Snapzy/Features/Preferences Snapzy/App Snapzy/Services/Configuration Snapzy/Shared/Localization SnapzyTests` (only paths you touch; skip scripts if no Swift) | exit 0 |
| Unit tests (host may still include video until 024) | `./scripts/run-tests.sh -only-testing:SnapzyTests/VideoModuleAvailabilityTests` | all pass (after Step 5) |
| Build default (module off) | `./scripts/build_and_run.sh --configuration Debug` non-interactive path after implementing flags — or `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug -derivedDataPath .build/xcode-derived-data build CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=…` | BUILD SUCCEEDED |
| Build video scheme | `xcodebuild -project Snapzy.xcodeproj -scheme "Snapzy Video" -configuration Debug … build` | BUILD SUCCEEDED |

## Suggested executor toolkit

- `.agents/skills/delivery-workflow/SKILL.md` — build/test scripts
- `.agents/skills/macos-app-engineering/SKILL.md` — Preferences / AppKit shell
- `.agents/skills/swift-conventions/SKILL.md` — naming / format
- `.agents/skills/capture-annotate-export/SKILL.md` — product perimeter (do not expand recording scope)
- `.agents/skills/localization/SKILL.md` — new Advanced strings
- `.agents/skills/testing-xctest/SKILL.md` — new XCTest file layout

## Scope

**In scope**:
- New: `Snapzy/Services/Configuration/VideoModuleAvailability.swift` (or `Snapzy/Features/Preferences/Models/` if you prefer Preferences-owned — pick **Services/Configuration** so App + Preferences + Capture can share without Feature cycles)
- `Snapzy/Features/Preferences/Models/PreferencesKeys.swift` — add runtime key
- `Snapzy/Features/Preferences/Components/PreferencesAdvancedSettingsView.swift` — Optional modules section + toggle (compiled-in only)
- `Snapzy/Shared/Localization/L10n.swift` — Advanced strings for the toggle
- `Snapzy.xcodeproj/project.pbxproj` — ensure default configs do **not** define `NOTINHAS_VIDEO_MODULE`; document how the Video scheme injects it
- New shared scheme: `Snapzy.xcodeproj/xcshareddata/xcschemes/Snapzy Video.xcscheme` (copy of Snapzy + compilation condition)
- `scripts/build_and_run.sh` — interactive prompt + non-interactive env/flag override
- New tests: `SnapzyTests/Services/Configuration/VideoModuleAvailabilityTests.swift`
- `plans/README.md` status row only

**Out of scope**:
- Hiding Capture/Shortcuts/History recording UI (plan 022)
- Menu bar / shortcut / deep-link gating beyond what the Advanced toggle needs for “active recording” detection stubs (plan 021)
- History/QA/Onboarding (plan 023)
- Wrapping `Features/Recording` / `Features/VideoEditor` file bodies in `#if` for binary size (plan 024)
- Moving folders to an SPM package
- Changing Screen Recording permission copy (023)
- Committing secrets / changing git config

## Git workflow

- Branch: `feat/video-module-gate` (or `advisor/020-video-module-gate`)
- Commits: Conventional, e.g. `feat: add optional video module build gate`
- Do NOT push or open a PR unless the operator asks

## Steps

### Step 1: Add `VideoModuleAvailability` + preferences key

Create `Snapzy/Services/Configuration/VideoModuleAvailability.swift`:

```swift
import Foundation

/// Compile + runtime gate for Recording / Video Editor (Notinhas optional module).
enum VideoModuleAvailability {
  /// True only when the binary was built with `NOTINHAS_VIDEO_MODULE`.
  static var isCompiledIn: Bool {
    #if NOTINHAS_VIDEO_MODULE
    true
    #else
    false
    #endif
  }

  /// Effective feature enablement. Always false when not compiled in.
  /// Runtime default is **off** (opt-in) when the key is unset.
  static var isEnabled: Bool {
    guard isCompiledIn else { return false }
    if UserDefaults.standard.object(forKey: PreferencesKeys.videoModuleEnabled) == nil {
      return false
    }
    return UserDefaults.standard.bool(forKey: PreferencesKeys.videoModuleEnabled)
  }

  /// Set runtime enablement. No-op when not compiled in.
  /// Callers that must refuse while a recording is active belong in the Advanced UI / plan 022.
  static func setEnabled(_ enabled: Bool) {
    guard isCompiledIn else { return }
    UserDefaults.standard.set(enabled, forKey: PreferencesKeys.videoModuleEnabled)
    NotificationCenter.default.post(name: .videoModuleAvailabilityDidChange, object: nil)
  }
}

extension Notification.Name {
  static let videoModuleAvailabilityDidChange = Notification.Name("videoModuleAvailabilityDidChange")
}
```

Add to `PreferencesKeys.swift` (near recording keys):

```swift
static let videoModuleEnabled = "videoModule.enabled"
```

**Verify**: `rg -n "VideoModuleAvailability|videoModuleEnabled" Snapzy` → both symbols present.

### Step 2: Wire Advanced Preferences toggle (compile-in only)

In `PreferencesAdvancedSettingsView.swift`, add a section **above** Integration (or below Backup — prefer after Integration is fine; maintainer chose Advanced, not Capture):

- Wrap the section in `#if NOTINHAS_VIDEO_MODULE` … `#endif` so builds without the module never show the row.
- Use `@AppStorage(PreferencesKeys.videoModuleEnabled)` with default `false`, **or** bind through `VideoModuleAvailability.setEnabled` so the notification fires.
- While `ScreenRecordingManager.shared.isActive` (or equivalent public API — confirm name on `ScreenRecordingManager` / `RecordingCoordinator`) is true: disable the toggle and/or show `.help` / alert copy that recording must be stopped first. If reading `isActive` pulls heavy deps that break module-off builds, use a thin check behind `#if NOTINHAS_VIDEO_MODULE` only (this whole section is already `#if`).

Add `L10n.PreferencesAdvanced` strings (English defaults OK; follow existing `string(...)` pattern):
- section title e.g. “Optional modules”
- title e.g. “Video recording & editor”
- description e.g. “Enable screen recording, GIF capture, and the video editor. Off by default.”
- disabled-while-recording help string

**Verify**: With a Video-enabled build, open Advanced in the running app (manual later) — for now `swiftformat` the touched Swift files and ensure the project still typechecks in Step 4.

### Step 3: Default project = module OFF; add `Snapzy Video` scheme = module ON

1. Confirm **Debug** and **Release** project-level / target-level `SWIFT_ACTIVE_COMPILATION_CONDITIONS` do **not** include `NOTINHAS_VIDEO_MODULE` (keep existing `DEBUG` on Debug).
2. Copy `Snapzy.xcscheme` → `Snapzy Video.xcscheme`.
3. On the Video scheme, enable the flag for Run/Test/Profile/Analyze. Preferred approaches (pick one that works in this Xcode version; STOP if none work cleanly):
   - Scheme **Build** → build settings override / `xcconfig` referenced only by that scheme, **or**
   - Pass `SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) NOTINHAS_VIDEO_MODULE'` via scheme environment / shared xcconfig `Configs/VideoModule.xcconfig` included only by a dedicated configuration — **simplest reliable path for this repo**: teach `build_and_run.sh` and document that Xcode users select **Snapzy Video** and add to the target’s Debug settings **only when using that scheme** is awkward; instead use:

**Recommended concrete approach**:
- Add `Configs/NotinhasVideoModule.xcconfig` containing:
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) NOTINHAS_VIDEO_MODULE`
- Do **not** `#include` it from the main project configs.
- `Snapzy Video.xcscheme`: use the same targets as Snapzy; document that local builds pass the flag via xcodebuild (`SWIFT_ACTIVE_COMPILATION_CONDITIONS=...`) — **and** set the scheme’s BuildableReference the same as Snapzy.
- Additionally store in the scheme’s `LaunchAction` / use `BuildableReference` + custom build setting if Xcode UI allows “arguments passed on launch” — **compilation** conditions must be build settings, not launch args.

Practical pattern that works with this project’s script-centric workflow:
- Default scheme `Snapzy`: no video flag.
- Scheme `Snapzy Video`: identical XML but add under `LaunchAction` is insufficient for compile flags — so set in scheme file using `BuildActionEntries` + rely on **script and xcodebuild `-scheme "Snapzy Video"`** after adding a **user-defined build setting** on the Snapzy target that schemes can override is hard.

**Executor MUST implement one of these working patterns**:

**Pattern A (preferred)**: In `project.pbxproj`, add two new configurations `Debug+Video` and `Release+Video` that duplicate Debug/Release and append `NOTINHAS_VIDEO_MODULE` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. Point `Snapzy Video.xcscheme` Run/Test at `Debug+Video`. Default `Snapzy.xcscheme` stays `Debug` / `Release`.

**Pattern B**: Always pass the flag from `build_and_run.sh` / documented xcodebuild extra args; scheme is a convenience that the script selects when video is enabled. Xcode ⌘R on `Snapzy Video` must still work — if Pattern B cannot make ⌘R work, use Pattern A.

**Verify**:
```bash
# Module off (default scheme) — VideoModuleAvailability.isCompiledIn must be false
xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug -derivedDataPath /tmp/snapzy-novideo -showBuildSettings 2>/dev/null | rg "SWIFT_ACTIVE_COMPILATION_CONDITIONS"
```
→ must **not** list `NOTINHAS_VIDEO_MODULE`.

```bash
# Module on — must list NOTINHAS_VIDEO_MODULE
xcodebuild -project Snapzy.xcodeproj -scheme "Snapzy Video" -configuration Debug -derivedDataPath /tmp/snapzy-video -showBuildSettings 2>/dev/null | rg "SWIFT_ACTIVE_COMPILATION_CONDITIONS"
```
→ must include `NOTINHAS_VIDEO_MODULE` (configuration name may be `Debug+Video` if Pattern A).

### Step 4: Interactive + scriptable flag in `build_and_run.sh`

Extend `configure_interactive_build` (after Debug/Release choice, before or after clean):

```text
Include optional Video module (recording + video editor)? [y/N]:
```

- `y` → set `ENABLE_VIDEO_MODULE=1`, `SCHEME="Snapzy Video"` (or pass compilation conditions).
- `N`/empty → `ENABLE_VIDEO_MODULE=0`, `SCHEME="Snapzy"`.

Also support non-interactive overrides (document in `usage`):
- Env: `ENABLE_VIDEO_MODULE=0|1`
- Flag: `--video-module` / `--no-video-module`

When `ENABLE_VIDEO_MODULE=1`, `run_xcodebuild` must ensure the Video scheme **or** append:
`SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) NOTINHAS_VIDEO_MODULE` (and `DEBUG` when Debug) consistently with Step 3.

Update `usage()` help text with the new options and the interactive prompt.

**Verify**: `bash -n scripts/build_and_run.sh` → exit 0.  
`rg -n "ENABLE_VIDEO_MODULE|video-module|Snapzy Video" scripts/build_and_run.sh` → hits present.

### Step 5: XCTest for availability defaults

Add `SnapzyTests/Services/Configuration/VideoModuleAvailabilityTests.swift`:

- `testRuntimeDefaultIsOffWhenKeyUnset` — remove key; if `isCompiledIn`, assert `isEnabled == false`.
- `testSetEnabledRoundTrip` — only when `isCompiledIn`; set true/false; assert; clean up key in `tearDown`.
- `testDisabledWhenNotCompiledIn` — if `!isCompiledIn`, `isEnabled` is false even if UserDefaults key is `true` (set key true, still false).

Model after small existing tests e.g. `SnapzyTests/Services/Capture/RecordingMetadataCleanupSchedulerTests.swift` structure.

**Note**: Until plan 024 isolates code, the test host may be built with or without the flag depending on which scheme `run-tests.sh` uses. Prefer leaving `run-tests.sh` on default `Snapzy` (module off) for these tests’ `!isCompiledIn` path, **and** document that Video-scheme test run covers `isCompiledIn` — OR parameterize. Minimum bar: tests pass on **default** `./scripts/run-tests.sh`.

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/VideoModuleAvailabilityTests` → all pass.

### Step 6: Format and status

- `swiftformat` on touched Swift paths.
- Update `plans/README.md` row 020 → DONE (or IN PROGRESS if leaving follow-ups — should be DONE when Steps 1–5 pass).

**Verify**: `git status --short` only shows in-scope paths (+ README).

## Test plan

- New: `VideoModuleAvailabilityTests` as above.
- Manual (operator): run `./scripts/build_and_run.sh`, choose Debug, answer `y` to video → app Advanced shows toggle default off; answer `N` → Advanced has no Optional modules section.
- Do not yet require full menu gating (022).

## Done criteria

- [ ] `VideoModuleAvailability.isCompiledIn` / `isEnabled` exist and match locked defaults
- [ ] `PreferencesKeys.videoModuleEnabled == "videoModule.enabled"`
- [ ] Advanced toggle exists only under `#if NOTINHAS_VIDEO_MODULE` and defaults off; refuses disable-while-recording when a session is active (or toggle to disable is disabled)
- [ ] Default `Snapzy` scheme / Debug+Release build settings do **not** define `NOTINHAS_VIDEO_MODULE`
- [ ] `Snapzy Video` scheme (or Debug+Video config) **does** define it (`-showBuildSettings` proof)
- [ ] `build_and_run.sh` interactive prompt + `ENABLE_VIDEO_MODULE` / `--video-module` documented in usage
- [ ] `./scripts/run-tests.sh -only-testing:SnapzyTests/VideoModuleAvailabilityTests` passes
- [ ] No out-of-scope feature gating merged into this plan
- [ ] `plans/README.md` status updated

## STOP conditions

- Cannot add a working Video-enabled build configuration/scheme without breaking the default Snapzy scheme.
- `ScreenRecordingManager` has no safe way to detect “recording active” for the Advanced toggle — stop and report the API gap (do not invent a second recorder singleton).
- Synchronized root group / pbxproj edit corrupts the Xcode project (project won’t open) — revert pbxproj and report.
- Drift in Advanced settings / build script contradicts excerpts and cannot be reconciled.

## Maintenance notes

- Later plans must call `VideoModuleAvailability.isEnabled` (runtime) and/or `#if NOTINHAS_VIDEO_MODULE` (compile) — never invent a second flag name.
- Config import/export of `videoModule.enabled` can be added in a follow-up; not required here. If importer already round-trips unknown keys, leave it; do not strip recording keys when disabled (user may re-enable).
- Reviewers: confirm Release distribution path stays module-off; confirm script default is N.
