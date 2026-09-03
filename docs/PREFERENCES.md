# Preferences

Reference for the Settings window: tab structure, every section, and how preferences are stored. Verified against `Cue/Features/Preferences/` at HEAD (`v1.30.0-beta.4`).

## Root

- `PreferencesView` (`Cue/Features/Preferences/PreferencesView.swift`) — SwiftUI `TabView`, fixed 760×550, nine tabs (no About/update/report tab).
- Selection driven by `PreferencesNavigationState.shared.selectedTab` (`Models/PreferencesNavigationState.swift`, `PreferencesTab` enum) — set programmatically from menu bar, deep links (`cue://settings?tab=`, see [SHORTCUTS.md](SHORTCUTS.md)), and the shortcut overlay.
- Presented through the `Settings` scene in `CueApp`; activation-policy dance handled by `AppStatusBarController` (see [APP_LIFECYCLE.md](APP_LIFECYCLE.md)).

## Storage pattern

- Simple prefs: `@AppStorage(PreferencesKeys.*)` directly in views; keys centralized in `Cue/Features/Preferences/Models/PreferencesKeys.swift`.
- Complex structured prefs: `PreferencesManager.shared` (`PreferencesManager.swift`) behind the `PreferencesProviding` protocol (`PreferencesProviding.swift`) for DI.
- TOML export/import covers most prefs — see [CONFIGURATION.md](CONFIGURATION.md).
- Upload provider credentials stay in Keychain. Cloudflare additionally stores its HTTPS Worker URL in UserDefaults; its UPLOAD_TOKEN is never exported.

### Uploads

Select ImgBB (default), ImageKit, or Cloudflare Worker. Cloudflare setup offers
token generation, explicit reveal/copy actions, a link to the official
Worker documentation, and Verify Connection. Uploads remain manual; no provider
fallback is automatic.

## Tabs

### General (`PreferencesGeneralSettingsView.swift`)

- **Startup**: Start at Login (`LoginItemManager` / SMAppService), Play Sounds (`playSounds`), Show Menu Bar Icon (`showMenuBarIcon`).
- **Appearance**: Language row (`PreferencesLanguageSettingRow`), theme picker (`AppearanceModePicker` → `appearanceMode`).
- **Storage**: Save Location (`exportLocation` + `exportLocation.bookmark`, via `SandboxFileAccessManager`).
- **Help**: Restart Onboarding (`OnboardingFlowView.resetOnboarding()` + `.showOnboarding`).

### Capture (`PreferencesCaptureSettingsView.swift`)

One unified **Capture** pane with eight sections in user-flow order. When the
optional Video module is compiled in and enabled at runtime, a segmented control
shows **Capture** and **Recording**; with Video off, the unified Capture form
renders directly without an inner picker.

- **Capture Environment**:
  - Include Cue windows in screenshots (`screenshot.includeOwnApp`) / in
    recordings (`recording.includeOwnApp`, Video module on).
  - Hide Desktop Icons (`hideDesktopIcons`), Hide Desktop Widgets
    (`hideDesktopWidgets`).
- **Selection**:
  - Show Selection Area Overlay (`screenshot.showSelectionAreaOverlay`).
  - Reverse Magnifier Zoom Direction (`screenshot.reverseMagnifierZoomDirection`).
  - All-In-One Selection Snapping: snap distance (`capture.selection.snapDistance`)
    and color edge sensitivity (`capture.selection.colorSensitivity`) — applies to
    All-In-One resize refinement only.
- **All-In-One Modes**: reorder and enable toolbar modes using
  `capture.allInOne.modeOrder.v1` and `capture.allInOne.enabledModes.v1`.
  Reset restores the default order and enables every mode. Recording appears
  only when Video is available, while its saved position and enabled state are
  retained. At least one non-Video mode must remain enabled.
- **Screenshot Behavior**:
  - Freeze Area (`screenshot.freezeArea`), Show Cursor (`screenshot.showCursor`).
- **Specialized Capture**:
  - Scrolling Capture: Show Session Hints (`scrollingCapture.showHints`) + info note.
  - OCR: Success Notification (`ocr.successNotificationEnabled`), Link Detection
    (`ocr.linkDetectionEnabled`).
- **Output**:
  - Image Format (`screenshot.format`, `ImageFormatOption`; WebP warning, JPEG
    cutout note).
  - Screenshot and conditional recording file-name templates
    (`screenshot.fileNameTemplate`, `recording.fileNameTemplate`) with token list,
    live preview, and reset.
- **Post-Processing**:
  - Default annotate canvas preset (`PreferencesScreenshotDefaultPresetPicker`).
  - Auto-Crop Subject (`backgroundCutout.autoCropEnabled`) — background removal
    in capture and Annotate.
- **After Capture**:
  - Action matrix only (`PreferencesAfterCaptureMatrixView`); see below.
- **Recording pane** (optional, Video module on):
  - Format: MOV / MP4 (`recording.format`).
  - Quality: Frame Rate 30/60 (`recording.fps`), Quality (`recording.quality`, `VideoQuality`).
  - Behavior: Show Cursor (`recording.showCursor`), Show Camera Preview While Recording (`recording.showCameraPreviewDuringRecording`), Remember Last Area (`recording.rememberLastArea`).
  - Controls: Hover Bar Visible (`recording.hoverBarVisible`), Show Time on Menu Bar (`recording.showTimeOnMenuBar`).
  - Mouse Highlight: size 30–100, animation 0.3–2.0 s, ripple count 1–5, color (archived `NSColor` in `recording.mouseHighlight.color`), opacity 0.2–1.0; reset-to-default.
  - Keystroke Overlay: font size 12–32, position (`KeystrokeOverlayPosition`), display duration 0.5–5.0 s; reset-to-default.
  - Audio: System Audio (`recording.captureAudio`), Microphone (`recording.captureMicrophone`, runs `AVCaptureDevice` authorization flow with System Settings fallback), Mic Input device picker (`recording.microphoneDeviceID`).

### Annotate (`PreferencesAnnotateSettingsView.swift`)

- **Editor chrome** (`AnnotateChromeCustomizationView`): reorder and enable/disable toolbar items (crop, background, rotate, drawing tools, cutout, Save as) and bottom-bar actions (New window, Share, selected-provider upload, Pin, Copy, Delete). The persisted `uploadToImgBB` raw action remains a compatibility identifier. Selection, Undo, Redo, and Done always stay visible; zoom, pan, mode tabs, and Drag to app are fixed. Keys `annotate.chrome.toolbarOrder.v1`, `annotate.chrome.bottomOrder.v1`, `annotate.chrome.enabled.v1`; Reset chrome restores defaults. Inline Capture Markup uses the same drawing-tool order/enable subset.
- Behavior section:
  - Sync Tool Defaults / quick-properties sync (`annotate.quickPropertiesSyncEnabled`, default on).
  - Combine Save-as-Edit (`annotate.combineSaveAsEdit`, default on).
  - Clipboard image open behavior (`annotate.clipboardImageOpenBehavior`): `ask` (default) / `loadAutomatically` / `doNothing` (`AnnotateClipboardImageBehavior`).
  - Close After Drag (`annotate.closeAfterDrag`, default on).
  - Bring Forward After Drag (`annotate.bringForwardAfterDrag`, default off; disabled when Close After Drag is on).

### Quick Access (`PreferencesQuickAccessSettingsView.swift`)

- **Actions**: `QuickAccessActionCustomizationView` — action enable/order/slot assignment with live preview card (`PreferencesQuickAccessPreviewCard`); keys `quickAccess.actions.*`, `quickAccess.swipe.action.*`.
- **Position**: screen edge left/right (`floatingScreenshot.position`).
- **Appearance**: overlay size slider 0.75–1.5 (`floatingScreenshot.overlayScale`).
- **Behaviors**: floating overlay enable (`floatingScreenshot.enabled`), Auto-Close toggle + 3–30 s slider (default 10, `floatingScreenshot.autoDismiss*`) + Pause on Hover, Hide Card When Window Open (`quickAccess.hideCardWhenWindowOpen`), Animation Style (`quickAccess.animationStyle`), Drag & Drop (`floatingScreenshot.dragDropEnabled`), Two-Finger Swipe to Dismiss + sensitivity 0.5–3.0 (`floatingScreenshot.twoFingerSwipe*`).
- **Trackpad Swipe Mode**: mode picker (`quickAccess.trackpad.swipe.mode`) + swipe-action hints; visible when swipe-to-dismiss is on.

### History (`PreferencesHistorySettingsView.swift`)

- **Floating Panel**: enable (`history.floating.enabled`), Panel Position (`history.floating.position`).
- **Display**: Default Filter (all/screenshots/videos/gifs), Background Style (`history.backgroundStyle`, thumbnail picker), Panel Size scale slider (`history.floating.scale`), Max Items 3–20 (`history.floating.maxDisplayedItems`).
- **Retention**: Retention Days 0–90, 0 = keep forever (`history.retentionDays`), Max Count 0–1000, 0 = unlimited (`history.maxCount`).
- **Storage**: capture storage size + Open Capture Storage (`CaptureStorageManager`), Clear History with confirmation (`HistoryWindowController.deleteRecords`).
- Master history enable (`history.enabled`) seeded on; see [APP_LIFECYCLE.md](APP_LIFECYCLE.md) for seeded defaults.

### Shortcuts (`PreferencesShortcutsSettingsView.swift`)

- Master toggle (`shortcutsEnabled`).
- Grouped recorders with per-shortcut enable toggles and per-section Reset: Capture, Recording, Tools, History, Quick Access, Annotate Actions, Annotate Tool Keys; Reset to Defaults (all).
- System-conflict guidance via `SystemScreenshotShortcutManager`.
- Full mechanics and default bindings: [SHORTCUTS.md](SHORTCUTS.md).

### Permissions (`PreferencesPermissionsSettingsView.swift`)

- Rows with status labels + System Settings deep links:
  - Screen Recording → `Privacy_ScreenCapture`
  - Save Folder → `Privacy_FilesAndFolders`
  - Microphone → `Privacy_Microphone`
  - Accessibility → `Privacy_Accessibility`
- Shows `grantedButUnavailableDueToAppIdentity` when `AppIdentityManager` reports issues (see [APP_LIFECYCLE.md](APP_LIFECYCLE.md)).

### Uploads (`PreferencesCloudSettingsView.swift`)

The **Uploads** section owns provider selection (ImgBB, ImageKit, or Cloudflare Worker), image optimization/derivative settings, and the selected provider credential. Secrets are stored only in provider-scoped Keychain items and are not exported. Existing users retain ImgBB unless they explicitly select another provider; invalid or missing selection safely uses ImgBB. GIFs can be uploaded through either provider; MOV/MP4/M4V uploads are supported by ImageKit or Cloudflare. When ImageKit is selected, the plan picker controls the local video upload target (Free 100 MB, Lite 300 MB, Pro 2 GB, or custom) because ImageKit does not expose plan limits through its API. Cloudflare uses a fixed 95 MiB client target. The Cloudflare documentation link covers the BYO Worker setup; Cue does not deploy a companion Worker. UploadThing is unavailable. BYO provider settings, usage, password, transfer, and upload-history controls remain retired. See [CLOUD.md](CLOUD.md).

### Advanced (`PreferencesAdvancedSettingsView.swift`)

- **Backup**: TOML Import / Export / Restore Defaults (`CueConfiguration*` services).
- **Configuration File**: grant access to `~/.config/cue`, Sync Now, Open Config, status/issues — see [CONFIGURATION.md](CONFIGURATION.md).
- **Integration**: URL Scheme toggle (`urlSchemeEnabled`).
- **Diagnostics**: enable toggle (`diagnostics.enabled`), retention days (`diagnostics.retentionDays`, default 3, range 1–30 via `LogCleanupScheduler`), Open Folder (`~/Library/Logs/Cue`) — see [UPDATES.md](UPDATES.md).

## After-capture matrix

```mermaid
flowchart LR
    A["Capture completes"] --> B{"PreferencesManager.isActionEnabled<br/>(action, type)"}
    B --> C["showQuickAccess → Quick Access card"]
    B --> D["copyFile → clipboard"]
    B --> E["save → export location"]
    B --> F["openAnnotate → editor (screenshot only)"]
```

- `AfterCaptureAction` (4 cases) × `CaptureType` (2: screenshot, recording) — defined in `PreferencesManager.swift`.
- Defaults: `showQuickAccess`, `copyFile`, `save` = on for both types; `openAnnotate` = off (opt-in, screenshot-only).
- Stored as JSON `[String: [String: Bool]]` under UserDefaults key `afterCaptureActions`; load failures fall back to seeded defaults.
- Edited via `PreferencesAfterCaptureMatrixView.swift` (Capture → After Capture section).
- **Plan 089**: Generic BYO cloud uploads and their after-capture UI were retired. Local sharing and the selected ImgBB, ImageKit, or Cloudflare upload remain — see [CLOUD.md](CLOUD.md).

## Related docs

- [SHORTCUTS.md](SHORTCUTS.md) — shortcut mechanics, defaults, conflicts
- [CLOUD.md](CLOUD.md) — Uploads tab and image-host sharing boundary
- [UPDATES.md](UPDATES.md) — local diagnostics and manual upgrade notes
- [APP_LIFECYCLE.md](APP_LIFECYCLE.md) — seeded defaults, activation policy, onboarding
- [CONFIGURATION.md](CONFIGURATION.md) — TOML backup/sync of these prefs
- [QUICK_ACCESS.md](QUICK_ACCESS.md) — overlay behavior details
- [HISTORY.md](HISTORY.md) — retention and storage internals
