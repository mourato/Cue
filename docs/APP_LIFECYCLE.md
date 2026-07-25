# App Lifecycle

How Notinhas launches, runs onboarding, lives in the menu bar, and shuts down. Covers `Notinhas/App/`, splash/onboarding, app identity, theme, data migrations, and the entitlements/Info.plist contract.

Current as of HEAD (`v1.30.0-beta.4`, build 140, macOS 13.0+ deployment target).

## Platform shape

- Menu-bar-only app: `INFOPLIST_KEY_LSUIElement = YES` (build setting in `Notinhas.xcodeproj/project.pbxproj`), no Dock icon by default.
- `@main` entry: `NotinhasApp` in `Notinhas/App/NotinhasApp.swift` — declares only a `Settings` scene hosting `PreferencesView`, tinted by `ThemeManager.shared.systemAppearance`. All other windows are AppKit-driven.
- `NotinhasApp.init()` calls `AppIdentityManager.shared.refresh()` before anything else.
- Bundle IDs: `com.mourato.notinhas` (release), `com.mourato.notinhas.debug` (debug) — see `AppBundleIdentity` in `Notinhas/Services/AppIdentity/AppIdentityManager.swift`.
- Not sandboxed: `ENABLE_APP_SANDBOX = NO` and `Notinhas/Notinhas.entitlements` contains no `com.apple.security.app-sandbox` key. Hardened runtime is enabled. The declared entitlements still matter for specific subsystems (see below).

## Launch sequence

```mermaid
flowchart TD
    A["NotinhasApp @main<br/>(LSUIElement, Settings scene only)"] --> B["AppDelegate.applicationWillFinishLaunching<br/>register AppleEvent kAEGetURL handler"]
    B --> C["applicationDidFinishLaunching"]
    C --> D{"AppLaunchPolicy<br/>shouldStartInteractiveApplication?"}
    D -- "XCTest && !NOTINHAS_ALLOW_INTERACTIVE_XCTEST_HOST=1" --> X[return, no UI]
    D -- "headless (0 screens)" --> X
    D -- pass --> E["AppIdentityManager.refresh()"]
    E --> F{"SandboxOffDataMigrationService.runIfNeeded()"}
    F -- "error" --> F1["modal: Try Again / Start Fresh… / Quit"]
    F1 --> F
    F -- ok --> G{"DatabaseManager.prepare()"}
    G -- "failure" --> G1["modal: Try Repair / Reset Database… / Quit<br/>reset archives to DatabaseRecovery-&lt;timestamp&gt;"]
    G1 --> G
    G -- ok --> H["TempCaptureManager.cleanupOrphanedFiles()"]
    H --> I["AppCoordinator(environment: .live())<br/>applicationDidFinishLaunching"]
    I --> J["flushPendingDeepLinks() + flushPendingOpenFileURLs()"]
```

- `AppLaunchPolicy` (`Notinhas/App/NotinhasApp.swift`): skips interactive startup under XCTest unless `NOTINHAS_ALLOW_INTERACTIVE_XCTEST_HOST=1`, and in headless sessions (`NSScreen.screens.count == 0`). XCTest detection uses `XCTestConfigurationFilePath`, `XCInjectBundle`, `DYLD_INSERT_LIBRARIES` (XCTest inject dylibs), and linked `XCTestCase` — so splash/onboarding/menu-bar setup do not start during host-app tests even when the configuration path env var is absent early in launch.
- Sandbox-off migration failure loops a critical modal: **Try Again** (retry), **Start Fresh…** (confirm, then `skipMigration()`; old sandbox data is left untouched), **Quit Notinhas**.
- Database failure loops: **Try Repair** (`DatabaseManager.attemptRepair()`), **Reset Database…** (moves files into `DatabaseRecovery-<timestamp>` then `retryInitialization()`), **Quit Notinhas**.
- AppleEvents arriving before the coordinator exists are queued in `pendingDeepLinkURLs` and flushed after launch; same for cold-launch "Open With" file URLs (`pendingOpenFileURLs`).
- `applicationShouldHandleReopen`: when the menu bar icon is hidden (`showMenuBarIcon == false`) and no windows are visible, opens Preferences (General tab) and suppresses default reopen.
- `application(_:open:)`: file URLs routed to `AnnotateManager.shared.openAnnotation(url:)` (Finder "Open With" / Dock drop); non-file URLs ignored here (deep links flow through the AppleEvent handler).
- `applicationWillTerminate`: removes the AppleEvent handler, forwards to `AppCoordinator.applicationWillTerminate()`.

## AppCoordinator duties

`Notinhas/App/AppCoordinator.swift` — `applicationDidFinishLaunching()` performs, in order:

1. `AppIdentityManager.shared.refresh()`.
2. `CrashSentinel.shared.checkAndReset()` → `didCrash` flag.
3. `DiagnosticLogger.shared.startSession()` + launch log with `previousCrash` context.
4. `LegacyLicenseCleanupService.shared.runIfNeeded()`.
5. UserDefaults defaults seeding (only when key absent):

   | Key | Seeded value |
   | --- | --- |
   | `diagnostics.retentionDays` | 3 (`LogCleanupScheduler.defaultRetentionDays`) |
   | `urlSchemeEnabled` | `true` |
   | `history.enabled` | `true` |
   | `history.retentionDays` | 30 |
   | `history.maxCount` | 500 |
   | `history.openOnLaunch` | `false` |
   | `history.floating.enabled` | `true` |
   | `history.floating.position` | `"topCenter"` |
   | `history.floating.maxDisplayedItems` | 10 |

6. TOML configuration: `NotinhasConfigurationAutoImporter.applyIfNeededOnLaunch()` → `NotinhasConfigurationSyncCoordinator.start()`; when the auto-import did not apply, `scheduleSync(reason: .appLaunch)`.
7. Schedulers: `LogCleanupScheduler`, `RecordingMetadataCleanupScheduler`, `CaptureHistoryRetentionService` — all `.start()`.
8. `AppStatusBarController.shared.setup(viewModel:updater:didCrash:)` — `didCrash` prompt only when crash detected **and** `DiagnosticLogger.isEnabled`; also pre-allocates the area-selection window pool via `AreaSelectionController.shared.prepareWindowPool()` (targets <150 ms activation).
9. After 0.3 s: `presentStartupExperience(...)` (see Onboarding).
10. `.showOnboarding` notification observer → `SplashWindowController.shared.show(forceOnboarding: true)` ("Restart Onboarding" path).

Termination (`applicationWillTerminate`): `NotinhasConfigurationSyncCoordinator.flushPendingSync(reason: .appTerminate)`, `CrashSentinel.markTerminated()`, stop `LogCleanupScheduler` / `RecordingMetadataCleanupScheduler` / sync coordinator, remove observers.

Deep links: `handleDeepLink(_:)` constructs `NotinhasDeepLinkHandler` and dispatches — see [SHORTCUTS.md](SHORTCUTS.md) for the route table.

## Onboarding & splash

Unified flow: `SplashWindowController` (`Notinhas/Features/Splash/SplashWindow.swift`) hosts `SplashOnboardingRootView` (`Notinhas/Features/Splash/SplashOnboardingRootView.swift`) in a `SplashWindow` (~85% of visible screen, max 1200×800, min 700×500, transparent titlebar, fades in/out).

State machine (`SplashScreen`): `splash` → `language` → `sponsor` (only when `sponsorPromptSeen` is false) → `permissions` → `configAccess` → `shortcuts` → `diagnostics` → `completion`. Default onboarding steps: `[language, permissions, configAccess, shortcuts, diagnostics, completion]`.

- `hasCompletedOnboarding` = UserDefaults `onboardingCompleted` (`OnboardingFlowView` in `Notinhas/Features/Onboarding/OnboardingFlowView.swift`).
- Permissions step (`Notinhas/Features/Onboarding/Components/OnboardingPermissionsView.swift`): screen recording / microphone / accessibility rows.
- `configAccess` step: grant folder access for `~/.config/notinhas` (holds `config.toml`; see `NotinhasConfigurationPaths` in `Notinhas/Services/Configuration/`).
- Shortcuts step: Accept calls `KeyboardShortcutManager.shared.enable()`; Decline just advances.
- Diagnostics step: toggle for `diagnostics.enabled` (default on).
- Completion sets `onboardingCompleted` + `sponsorPromptSeen`.
- Skip logic in `SplashWindowController.showWindow`:
  - `splashSkipped` → skip splash entirely when onboarding done and sponsor seen.
  - `splash.skipOnceAfterOnboardingRelaunch` → one-time skip after a language-change relaunch, then the key is removed.
- Language preview: `OnboardingLocalizationController` (`Notinhas/Features/Onboarding/Managers/`) re-renders onboarding strings in the selected language without relaunch; on completion `commitLanguageSelection()` persists via `AppLanguageManager` and, when `requiresRelaunchOnCompletion`, calls `relaunchApplication()` after setting the skip-once key.
- Startup gating (`AppCoordinator.presentStartupExperience`): for existing users (`hasCompletedOnboarding`), when TOML auto-import returns `.skippedPermissionRequired` and `configuration.accessOnboardingPrompted` is false, show a one-time configAccess-only step (`showConfigurationAccess()`, steps `[.configAccess]`) instead of the splash. Otherwise `SplashWindowController.show()`, then after 1.5 s remove the legacy `hasSeenSmartElementIntro` key and present any pending `FeatureIntroManager` campaign.
- "Restart Onboarding" (Preferences → General → Help): `OnboardingFlowView.resetOnboarding()` clears `onboardingCompleted` / `splashSkipped` / skip-once key, posts `.showOnboarding`.

## Menu bar

`AppStatusBarController` (`Notinhas/App/AppStatusBarController.swift`) — singleton owning the `NSStatusItem` (variable length, template `MenubarIcon` rescaled to 21 pt).

- Click behavior: button `sendAction(on: [.leftMouseUp, .rightMouseUp])` — both left and right click rebuild and open the same menu (`buildMenu()` runs on every open to refresh state).
- Menu structure (verified in `buildMenu()`):
  - When recording/paused: **Stop Recording (mm:ss)** and **Pause/Resume Recording**, then separator.
  - Captures: Capture Area, Capture Area & Annotate, Application Capture (menu action), Capture Fullscreen, Capture Active Window, Scrolling Capture (disabled while a session is active), Capture Text (OCR), Capture Smart Element, Object Cutout (macOS 14+ only).
  - Recording: Record Screen, Application Recording (both disabled while recorder active).
  - Tools: Open Annotate, Edit Video, Cloud Uploads (enabled only when `CloudManager.shared.isConfigured`), History, Keyboard Shortcuts.
  - Conditional: **Grant Permission** (when screen permission missing), **What's New** (pending `FeatureIntroManager` campaign).
  - Preferences `⌘,`, Quit `⌘Q` (menu title shows **Notinhas**).
  - Configured shortcut key equivalents are attached to menu items via `applyConfiguredShortcut(_:for:using:)`; the Recording → Application Recording overlay shortcut can render as a child-key suffix (see [SHORTCUTS.md](SHORTCUTS.md)).
- Recording state rendering: while recording, the title shows a monospaced-digit timer (`recorder.formattedDuration`); when paused it is prefixed with `|| `; tooltip mirrors state. `setProcessing(_:)` swaps the icon for an `NSProgressIndicator` spinner (used e.g. during OCR) on Core Animation so it keeps animating.
- Visibility: `showMenuBarIcon` pref toggles the status item (`syncStatusItemVisibility`).
- Preferences activation-policy dance (`presentPreferencesWindow`): elevates `.accessory` → `.regular` so Notinhas appears in the app menu/Cmd+Tab, triggers the Settings scene (synthesized `⌘,` key equivalent on macOS 14+, `showSettingsWindow:` before), tracks the window (12 retry passes), and reverts to `.accessory` in `windowDidClose` when no other normal windows remain. While recording, the tracked Preferences window is added to the recorder's runtime exclusion list so Notinhas's own window isn't captured.

Notinhas does not ship Check for Updates, About, or Report a Problem UI. Diagnostics are local only — see [UPDATES.md](UPDATES.md).

## App identity

`AppIdentityManager` (`Notinhas/Services/AppIdentity/AppIdentityManager.swift`) evaluates `AppIdentityHealth` at launch and on refresh:

- `unexpectedBundleIdentifier` — bundle ID ≠ expected (`com.mourato.notinhas` / `.debug`).
- `invalidBundleSignature` — strict `SecStaticCode` validation (release builds only; debug skips since Xcode ad-hoc signing fails `kSecCSStrictValidate`).
- `outsideApplications` + `quarantined` — only flagged together when the app has the quarantine xattr **and** runs outside `/Applications` and `~/Applications`. Quarantine inside Applications folders is intentionally ignored (some install paths preserve the xattr; Gatekeeper clears it on first launch — issue #337).

The Permissions tab reflects unhealthy identity as `grantedButUnavailableDueToAppIdentity`.

## Theme

- `ThemeManager` (`Notinhas/Services/Appearance/ThemeManager.swift`): `@AppStorage(PreferencesKeys.appearanceMode)` → `AppearanceMode` `.system` / `.light` / `.dark`.
- `nsAppearance`: `nil` (system) / `.aqua` / `.darkAqua` for AppKit windows; `systemAppearance: ColorScheme` published for SwiftUI `.preferredColorScheme`, tracking `AppleInterfaceThemeChangedNotification`.
- `WindowSurfacePalette`: shared opaque window backgrounds (`lightBase` white 0.95, `darkBase` white 0.12).

## Migrations & recovery

- Sandbox-off data migration: `SandboxOffDataMigrationService` (`Notinhas/Services/Migration/`) — one-time move of App Support items, preferences, and logs out of the old sandbox container for upgrades to unsandboxed builds. Skips when running sandboxed (`APP_SANDBOX_CONTAINER_ID` present) or already done. Completion tracked by marker file `.sandbox-off-migration-completed` and UserDefaults `migration.sandboxOff.completed`. Launch-blocking modal on failure (see flowchart).
- Legacy license cleanup: `LegacyLicenseCleanupService` (`Notinhas/Services/LegacyLicenseCleanupService.swift`), completion key `legacyLicenseCleanupCompleted`.
- Database recovery: `DatabaseManager` (`Notinhas/Services/Cloud/DatabaseManager.swift`) prepares `notinhas.db`; reset archives old files to `DatabaseRecovery-<timestamp>` (capture files on disk and cloud objects are never deleted).
- Legacy key cleanup: `hasSeenSmartElementIntro` removed at launch (replaced by `FeatureIntroManager` campaigns).

## Entitlements & Info.plist

`Notinhas/Notinhas.entitlements` (no app-sandbox key — builds are **not** sandboxed):

- `com.apple.security.network.client` — outbound network (cloud uploads, updates, OAuth). No `network.server` entitlement is declared.
- `com.apple.security.files.user-selected.read-write` — user-picked files/folders.
- `com.apple.security.device.audio-input` — microphone for recordings.
- `com.apple.security.temporary-exception.shared-preference.read-only` → `com.apple.symbolichotkeys` — system screenshot shortcut conflict detection (see [SHORTCUTS.md](SHORTCUTS.md)).
- `com.apple.security.temporary-exception.mach-lookup.global-name` → `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki` —  installer launcher service (paired with `SUEnableInstallerLauncherService`).

`Notinhas/Resources/Info.plist`:

- `CFBundleURLTypes`: `notinhas://` scheme (deep links — see [SHORTCUTS.md](SHORTCUTS.md)).
- `CFBundleDocumentTypes`: Editor role (rank `Alternate`) for `public.png`, `public.jpeg`, `public.heic`, `public.heif`, `public.tiff`, `com.compuserve.gif`, `org.webmproject.webp`, `public.bmp` — routes "Open With" into the Annotate editor.
- `NSMicrophoneUsageDescription`, `NSScreenCaptureUsageDescription`.
-  keys: `SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService` — see [UPDATES.md](UPDATES.md).

Security-scoped bookmarks persisted in UserDefaults: `exportLocation.bookmark` (save folder), `configuration.fileBookmark` / `configuration.directoryBookmark` (TOML config), `wallpaper.directoryBookmark` / `wallpaper.customBookmarks`.

## Deep link dispatch

AppleEvent `kAEGetURL` → `AppDelegate.handleGetURLEvent` → queued until coordinator ready → `AppCoordinator.handleDeepLink` → `NotinhasDeepLinkHandler.handle(url)`. Gated by `urlSchemeEnabled` (default `true`); unknown routes are logged and ignored. Full route table: [SHORTCUTS.md](SHORTCUTS.md#url-scheme-automation).

## Unresolved questions

- `reportProblemAction` / `didDetectCrash` in `AppStatusBarController` are stored but never wired into the menu — dead code or pending feature? Currently problem reporting is only reachable via Preferences (see [UPDATES.md](UPDATES.md)).

## Related docs

- [SHORTCUTS.md](SHORTCUTS.md) — hotkeys + `notinhas://` route table
- [PREFERENCES.md](PREFERENCES.md) — Settings window reference
- [UPDATES.md](UPDATES.md) —  diagnostics, crash/problem reporting
- [CONFIGURATION.md](CONFIGURATION.md) — TOML config file, `~/.config/notinhas` grant
- [STRUCTURE.md](STRUCTURE.md) — project layout
- [DEVELOPMENT.md](DEVELOPMENT.md) — local development setup
