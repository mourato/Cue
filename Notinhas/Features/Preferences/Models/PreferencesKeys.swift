//
//  PreferencesKeys.swift
//  Notinhas
//
//  Shared UserDefaults keys for preferences
//

import Foundation

/// Centralized keys for UserDefaults storage
enum PreferencesKeys {
    // Onboarding
    static let onboardingCompleted = "onboardingCompleted"
    static let splashSkipped = "splashSkipped"
    static let splashSkipOnceAfterOnboardingRelaunch = "splash.skipOnceAfterOnboardingRelaunch"
    static let legacyLicenseCleanupCompleted = "legacyLicenseCleanupCompleted"
    static let sandboxOffMigrationCompleted = "migration.sandboxOff.completed"
    static let notinhasIdentityMigrationCompleted = "migration.notinhasIdentity.completed"

    // General
    static let playSounds = "playSounds"
    static let urlSchemeEnabled = "urlSchemeEnabled"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let exportLocation = "exportLocation"
    static let exportLocationBookmark = "exportLocation.bookmark"
    static let configurationFileBookmark = "configuration.fileBookmark"
    static let configurationDirectoryBookmark = "configuration.directoryBookmark"
    static let configurationLastAppliedSignature = "configuration.lastAppliedSignature"
    static let configurationAccessOnboardingPrompted = "configuration.accessOnboardingPrompted"
    static let hideDesktopIcons = "hideDesktopIcons"
    static let hideDesktopWidgets = "hideDesktopWidgets"
    static let wallpaperDirectoryBookmark = "wallpaper.directoryBookmark"
    static let customWallpaperBookmarks = "wallpaper.customBookmarks"

    /// Appearance
    static let appearanceMode = "appearanceMode"

    /// Updates
    static let updateChannel = "updates.channel"

    // Shortcuts
    static let shortcutsEnabled = "shortcutsEnabled"
    static let fullscreenShortcut = "fullscreenShortcut"
    static let areaShortcut = "areaShortcut"
    /// Legacy key retained only for one-time migration into AIO `.window` mode shortcuts.
    static let areaApplicationCaptureShortcut = "shortcuts.area.applicationCapture"
    static let recordingApplicationCaptureShortcut = "shortcuts.recording.applicationCapture"
    static let smartElementShortcut = "smartElementShortcut"
    static let shortcutListShortcut = "shortcutListShortcut"
    static let disabledGlobalShortcuts = "shortcuts.disabledGlobalActions"
    static let clearedGlobalShortcuts = "shortcuts.clearedGlobalActions"
    static let disabledAnnotateActionShortcuts = "shortcuts.disabledAnnotateActionShortcuts"
    static let disabledAnnotateToolShortcuts = "shortcuts.disabledAnnotateToolShortcuts"

    // Screenshot
    static let screenshotFormat = "screenshot.format"
    static let screenshotFileNameTemplate = "screenshot.fileNameTemplate"
    static let screenshotIncludeOwnApp = "screenshot.includeOwnApp"
    static let screenshotShowCursor = "screenshot.showCursor"
    static let screenshotFreezeArea = "screenshot.freezeArea"
    static let screenshotShowSelectionAreaOverlay = "screenshot.showSelectionAreaOverlay"
    static let screenshotReverseMagnifierZoomDirection = "screenshot.reverseMagnifierZoomDirection"
    static let scrollingCaptureShowHints = "scrollingCapture.showHints"
    static let captureAllInOneLastAreaRect = "capture.allInOne.lastAreaRect"
    static let captureAllInOneAspectRatioLocked = "capture.allInOne.aspectRatioLocked"
    static let captureAllInOneModeOrder = "capture.allInOne.modeOrder.v1"
    static let captureAllInOneEnabledModes = "capture.allInOne.enabledModes.v1"
    static let captureSelectionSnapDistance = "capture.selection.snapDistance"
    static let captureSelectionColorSensitivity = "capture.selection.colorSensitivity"
    static let backgroundCutoutAutoCropEnabled = "backgroundCutout.autoCropEnabled"
    static let annotateCanvasPresets = "annotate.canvasPresets.v1"
    static let annotateDefaultCanvasPresetId = "annotate.defaultCanvasPresetId.v1"
    static let annotateClipboardImageOpenBehavior = "annotate.clipboardImageOpenBehavior"
    static let annotateCloseAfterDrag = "annotate.closeAfterDrag"
    static let annotateBringForwardAfterDrag = "annotate.bringForwardAfterDrag"
    static let annotatePrimaryColor = "annotate.primaryColor.v1"
    static let annotateParameterDefaults = "annotate.parameterDefaults.v1"
    static let annotateToolParameterDefaults = "annotate.toolParameterDefaults.v1"
    static let annotateQuickPropertiesSyncEnabled = "annotate.quickPropertiesSyncEnabled"
    static let annotateCombineSaveAsEdit = "annotate.combineSaveAsEdit"
    static let annotateCombineLastMode = "annotate.combineLastMode"
    static let annotateChromeToolbarOrder = "annotate.chrome.toolbarOrder.v1"
    static let annotateChromeBottomOrder = "annotate.chrome.bottomOrder.v1"
    static let annotateChromeEnabledItems = "annotate.chrome.enabled.v1"
    static let notinhasNotesPanelSide = "annotate.notinhasNotes.panelSide.v1"
    static let legacyNotinhasNotesPanelSide = "notinhas.notes.panelSide"
    /// Legacy ImgBB API key in UserDefaults. Retained for one-time migration only; new writes use Keychain.
    static let notinhasImgBBAPIKey = "notinhas.imgbb.apiKey"
    /// Non-secret presence cache so Annotate / Quick Access can enable upload without unlocking Keychain.
    static let imgbbCredentialConfigured = "notinhas.imgbb.credentialConfigured"
    static let imageKitCredentialConfigured = "notinhas.imagekit.credentialConfigured"
    static let annotateCustomColors = "annotate.customColors.v1"
    static let annotateFavoriteColors = "annotate.favoriteColors.v1"
    static let ocrSuccessNotificationEnabled = "ocr.successNotificationEnabled"
    static let ocrLinkDetectionEnabled = "ocr.linkDetectionEnabled"

    // Floating Screenshot (Quick Access)
    static let floatingEnabled = "floatingScreenshot.enabled"
    static let floatingPosition = "floatingScreenshot.position"
    static let floatingAutoDismissEnabled = "floatingScreenshot.autoDismissEnabled"
    static let floatingAutoDismissDelay = "floatingScreenshot.autoDismissDelay"
    static let floatingOverlayScale = "floatingScreenshot.overlayScale"
    static let quickAccessCornerButtonScale = "quickAccess.cornerButtonScale"
    static let floatingDragDropEnabled = "floatingScreenshot.dragDropEnabled"
    static let floatingTwoFingerSwipeToDismissEnabled = "floatingScreenshot.twoFingerSwipeToDismissEnabled"
    static let floatingSwipeSensitivity = "floatingScreenshot.swipeSensitivity"
    static let quickAccessTrackpadSwipeMode = "quickAccess.trackpad.swipe.mode"
    static let quickAccessActionOrder = "quickAccess.actions.order.v1"
    static let quickAccessEnabledActions = "quickAccess.actions.enabled.v1"
    static let quickAccessActionSlotAssignments = "quickAccess.actions.slots.v1"
    static let quickAccessSwipeLeftAction = "quickAccess.swipe.action.left"
    static let quickAccessSwipeRightAction = "quickAccess.swipe.action.right"
    static let quickAccessHideCardWhenWindowOpen = "quickAccess.hideCardWhenWindowOpen"
    static let quickAccessAnimationStyle = "quickAccess.animationStyle"

    // Recording
    static let recordingFormat = "recording.format"
    static let recordingFileNameTemplate = "recording.fileNameTemplate"
    static let recordingFPS = "recording.fps"
    static let recordingQuality = "recording.quality"
    static let recordingCaptureAudio = "recording.captureAudio"
    static let recordingCaptureMicrophone = "recording.captureMicrophone"
    static let recordingMicrophoneDeviceID = "recording.microphoneDeviceID"
    static let recordingCaptureCamera = "recording.captureCamera"
    static let recordingCameraDeviceID = "recording.cameraDeviceID"
    static let recordingShortcut = "recordingShortcut"
    static let recordingLastAreaRect = "recording.lastAreaRect"
    static let recordingRememberLastArea = "recording.rememberLastArea"
    static let recordingOutputMode = "recording.outputMode"
    static let recordingIncludeOwnApp = "recording.includeOwnApp"
    static let recordingShowCursor = "recording.showCursor"
    static let recordingHighlightClicks = "recording.highlightClicks"
    static let recordingShowKeystrokes = "recording.showKeystrokes"
    static let recordingHoverBarVisible = "recording.hoverBarVisible"
    static let recordingShowTimeOnMenuBar = "recording.showTimeOnMenuBar"
    static let recordingHoverBarFrameOrigin = "recording.hoverBarFrameOrigin"
    static let videoEditorZoomTransitionDuration = "videoEditor.zoom.transitionDuration"
    static let videoModuleEnabled = "videoModule.enabled"

    // Mouse Highlight Customization
    static let mouseHighlightSize = "recording.mouseHighlight.size"
    static let mouseHighlightAnimationDuration = "recording.mouseHighlight.animationDuration"
    static let mouseHighlightColor = "recording.mouseHighlight.color"
    static let mouseHighlightOpacity = "recording.mouseHighlight.opacity"
    static let mouseHighlightRippleCount = "recording.mouseHighlight.rippleCount"

    // Keystroke Overlay Customization
    static let keystrokeFontSize = "recording.keystroke.fontSize"
    static let keystrokePosition = "recording.keystroke.position"
    static let keystrokeDisplayDuration = "recording.keystroke.displayDuration"

    // Recording Annotation Shortcuts
    static let annotationShortcutModifier = "recording.annotation.shortcutModifier"
    static let annotationShortcutHoldDuration = "recording.annotation.shortcutHoldDuration"

    // Diagnostics
    nonisolated static let diagnosticsEnabled = "diagnostics.enabled"
    static let diagnosticsRetentionDays = "diagnostics.retentionDays"
    static let diagnosticsSessionActive = "diagnostics.sessionActive"

    // History
    static let historyEnabled = "history.enabled"
    static let historyRetentionDays = "history.retentionDays"
    static let historyMaxCount = "history.maxCount"
    static let historyBackgroundStyle = "history.backgroundStyle"
    static let historyFloatingScale = "history.floating.scale"
    static let historyOpenOnLaunch = "history.openOnLaunch"

    // Uploads
    static let uploadOptimizeImages = "uploads.optimizeImages"
    static let uploadImageFormat = "uploads.imageFormat"
    static let uploadMaximumDimension = "uploads.maximumDimension"
    static let uploadJPEGQuality = "uploads.jpegQuality"
    static let uploadProvider = "uploads.provider"
}
