# Plan 027: Remove Sparkle, Report a Problem, and About

> **Executor instructions**: A Composer 2.5 subagent implements this plan in an
> isolated worktree, runs all gates, commits, merges, cleans the worktree/branch,
> and pushes. If isolation prevents integration, GPT 5.6 performs those
> operations from the returned commit. GPT 5.6 then runs
> `/thermo-nuclear-code-quality-review`, fixes every finding, commits the fixes,
> and only then starts Plan 028.
>
> **Drift check**:
> `git diff --stat d2c1b57..HEAD -- Snapzy.xcodeproj/project.pbxproj Snapzy/Resources/Info.plist Snapzy/Snapzy.entitlements Snapzy/App/AppCoordinator.swift Snapzy/App/AppStatusBarController.swift Snapzy/Features/Preferences Snapzy/Features/CrashReport Snapzy/Services/Updates .github/workflows/release-publish.yml scripts/dry-run-release.sh scripts/update-appcast.sh scripts/test-update-local.sh appcast.xml`
> must be empty.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/026-identity-data-migration.md`
- **Category**: tech-debt
- **Planned at**: `d2c1b57`, 2026-07-21 (reconciled after Plan 026 review fixes)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — project, preferences, release, and Info.plist surfaces overlap.
- **Reviewer required**: yes — remove upstream integrations without removing local diagnostics.
- **Rationale**: The deletion is broad but mechanically verifiable through project and residue scans.
- **Escalate when**: a replacement updater, cloud behavior change, or diagnostics deletion is proposed.

## Why this matters and current state

`UpdaterManager.swift:8-37` starts Sparkle; `AppCoordinator.swift:76-85` and
`AppStatusBarController.swift:719-730,879-895` wire update/report actions;
`PreferencesGeneralSettingsView.swift:68-123` exposes update/report controls;
`PreferencesAboutSettingsView.swift` and `PreferencesNavigationState.swift`
own About. `Info.plist:46-51`, entitlements, `project.pbxproj`, and
`.github/workflows/release-publish.yml:169-210,452-633` carry Sparkle feed,
signing, and appcast behavior. `CrashReport/` owns the upstream report flow.
`SnapzyConfigurationExporter/Importer.swift` write/read `[updates]`.

Keep `DiagnosticLogger`, `CrashSentinel`, `LogCleanupScheduler`, Advanced
diagnostics, and onboarding diagnostics. Keep GitHub Release/DMG publishing,
minus Sparkle-only steps.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Sparkle scan | `rg -n 'import Sparkle|SPUUpdater|SUFeedURL|SUPublicEDKey|appcast|SPARKLE_PRIVATE_KEY|Sparkle\\.framework' Snapzy SnapzyTests Snapzy.xcodeproj .github scripts appcast.xml` | No active matches |
| Removed surface scan | `rg -n 'CrashReportService|ProblemReport|Report a Problem|Report Issue|PreferencesAbout|PreferencesTab\\.about|Check for Updates' Snapzy SnapzyTests` | No active matches |
| Tests | `./scripts/run-tests.sh && ./scripts/run-tests.sh --video-module` | Both exit 0 |
| Package inspection | `xcodebuild -project Snapzy.xcodeproj -scheme Snapzy -showBuildSettings` | Succeeds; no Sparkle product |
| Format | `swiftformat --lint Snapzy/App Snapzy/Features/Preferences Snapzy/Services/Configuration` | No violations |

## Scope

**In scope**:

- `Snapzy.xcodeproj/project.pbxproj`
- `Snapzy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `Snapzy/Resources/Info.plist`, `Snapzy/Snapzy.entitlements`
- `Snapzy/App/AppCoordinator.swift`, `Snapzy/App/AppStatusBarController.swift`
- General/About preferences and navigation/key models
- About-only component files (delete)
- all `Snapzy/Features/CrashReport/` files (delete)
- `Snapzy/Services/Updates/UpdaterManager.swift` and
  `Snapzy/Features/Updates/UpdatesCheckForUpdatesView.swift` (delete)
- configuration importer/exporter and relevant tests
- `.github/workflows/release-publish.yml`
- Sparkle/appcast scripts and `appcast.xml` (delete)
- affected status-bar/preferences/deep-link tests

**Out of scope**: URL scheme/parser (Plan 028), physical project/module rename
(Plan 029), README/docs/agent guidance (Plan 030), diagnostics removal,
cloud/recording/video removal, and a replacement updater.

## Git workflow

Branch: `advisor/027-remove-upstream-surfaces`; commit:
`refactor: remove Sparkle and upstream support surfaces`.

## Steps

### 1. Delete Sparkle runtime/build/configuration

Remove Sparkle package/product/resolved pin, all imports/updater wiring,
Info.plist feed/signing keys, entitlements, updater UI, and appcast/update-test
scripts. Preserve non-Sparkle network entitlements. Keep the diagnostic
`.update` log category only for historical parsing.

**Verify**: Sparkle scan returns no active matches.

### 2. Remove Report a Problem and About

Delete `Features/CrashReport`, report actions/URLs/buttons, and problem-report
localization. Remove About tab registration, enum case, view/components, and
About tests. Preserve local diagnostics and the remaining preference tabs.

**Verify**: removed-surface scan returns no active matches.

### 3. Make legacy TOML safe and release manual

Stop exporting `[updates]`; import it as ignored legacy data while applying
valid non-update fields. Add a test proving old config imports and new export
contains no update keys. Strip only Sparkle signing/appcast/private-key steps
from release workflow; retain archive, signing/notarization, DMG, and GitHub
Release publication.

**Verify**: configuration tests and both test configurations pass.

## Test plan

Extend configuration tests for legacy `[updates]`, update-free export, and
remaining preference-tab selection. Run diagnostics tests explicitly. Do not
replace deleted report tests with a support endpoint.

## Done criteria

- [ ] No Sparkle runtime/build/feed/entitlement/appcast/update UI remains.
- [ ] No Report a Problem or About surface remains.
- [ ] Local diagnostics still compile and render.
- [ ] Legacy `[updates]` imports safely; new export omits it.
- [ ] Manual GitHub Release/DMG workflow remains intact.
- [ ] Default/video tests and format checks pass.
- [ ] Only Scope files changed.
- [ ] Composer 2.5 commit merged, cleaned, and pushed; GPT 5.6 review fixes
      committed before Plan 028.

## STOP conditions

Stop if removal would break cloud/OAuth, release publication, diagnostics, or
legacy config import; if a remaining Sparkle reference is an unclear external
format; after two failed gates; or if an out-of-scope file is required.

## Maintenance notes

Plan 028 edits the same Info.plist and deep-link tests. Plan 030 rewrites public
update/release documentation after this plan is integrated.
