//
//  AppCoordinator.swift
//  Notinhas
//
//  App lifecycle orchestration for startup, notifications, and shutdown.
//

import AppKit
import Foundation

@MainActor
final class AppCoordinator {
    private let screenCaptureViewModel: ScreenCaptureViewModel
    private var observers: [NSObjectProtocol] = []

    init(screenCaptureViewModel: ScreenCaptureViewModel) {
        self.screenCaptureViewModel = screenCaptureViewModel
    }

    func applicationDidFinishLaunching() {
        AppIdentityManager.shared.refresh()
        let didCrash = CrashSentinel.shared.checkAndReset()
        DiagnosticLogger.shared.startSession()
        DiagnosticLogger.shared.log(
            .info,
            .lifecycle,
            "App launch sequence started",
            context: ["previousCrash": didCrash ? "true" : "false"],
        )
        LegacyLicenseCleanupService.shared.runIfNeeded()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferencesKeys.diagnosticsRetentionDays) == nil {
            defaults.set(LogCleanupScheduler.defaultRetentionDays, forKey: PreferencesKeys.diagnosticsRetentionDays)
        }

        if defaults.object(forKey: PreferencesKeys.urlSchemeEnabled) == nil {
            defaults.set(true, forKey: PreferencesKeys.urlSchemeEnabled)
        }

        // History defaults
        if defaults.object(forKey: PreferencesKeys.historyEnabled) == nil {
            defaults.set(true, forKey: PreferencesKeys.historyEnabled)
        }
        if defaults.object(forKey: PreferencesKeys.historyRetentionDays) == nil {
            defaults.set(30, forKey: PreferencesKeys.historyRetentionDays)
        }
        if defaults.object(forKey: PreferencesKeys.historyMaxCount) == nil {
            defaults.set(500, forKey: PreferencesKeys.historyMaxCount)
        }
        if defaults.object(forKey: PreferencesKeys.historyOpenOnLaunch) == nil {
            defaults.set(false, forKey: PreferencesKeys.historyOpenOnLaunch)
        }

        // Floating history panel defaults
        if defaults.object(forKey: "history.floating.enabled") == nil {
            defaults.set(true, forKey: "history.floating.enabled")
        }
        if defaults.object(forKey: "history.floating.position") == nil {
            defaults.set("topCenter", forKey: "history.floating.position")
        }

        let configurationAutoImportResult = applyUserConfigurationIfNeeded()
        startConfigurationSync(after: configurationAutoImportResult)

        LogCleanupScheduler.shared.start()
        #if CUE_VIDEO_MODULE
            syncRecordingMetadataCleanupScheduler()
        #endif
        CaptureHistoryRetentionService.shared.start()
        DiagnosticLogger.shared.log(.debug, .lifecycle, "Background schedulers started")

        AppStatusBarController.shared.setup(viewModel: screenCaptureViewModel)
        DiagnosticLogger.shared.log(.debug, .ui, "Status bar controller configured")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            DiagnosticLogger.shared.log(.debug, .ui, "Splash presentation scheduled")
            self.presentStartupExperience(configurationAutoImportResult: configurationAutoImportResult)
        }

        observeNotifications()
    }

    func applicationWillTerminate() {
        flushConfigurationSyncBeforeTermination()
        DiagnosticLogger.shared.log(.info, .lifecycle, "App terminated normally")
        CrashSentinel.shared.markTerminated()
        LogCleanupScheduler.shared.stop()
        #if CUE_VIDEO_MODULE
            RecordingMetadataCleanupScheduler.shared.stop()
        #endif
        CueConfigurationSyncCoordinator.shared.stop()

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    func handleDeepLink(_ url: URL) {
        CueDeepLinkHandler(screenCaptureViewModel: screenCaptureViewModel)
            .handle(url)
    }

    private func observeNotifications() {
        let onboardingObserver = NotificationCenter.default.addObserver(
            forName: .showOnboarding,
            object: nil,
            queue: .main,
        ) { _ in
            Task { @MainActor in
                DiagnosticLogger.shared.log(.info, .ui, "Onboarding requested from notification")
                SplashWindowController.shared.show(forceOnboarding: true)
            }
        }

        observers.append(onboardingObserver)

        let videoModuleObserver = NotificationCenter.default.addObserver(
            forName: .videoModuleAvailabilityDidChange,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncRecordingMetadataCleanupScheduler()
            }
        }
        observers.append(videoModuleObserver)

        DiagnosticLogger.shared.log(
            .debug,
            .lifecycle,
            "App notifications observed",
            context: ["observerCount": "\(observers.count)"],
        )
    }

    private func syncRecordingMetadataCleanupScheduler() {
        #if CUE_VIDEO_MODULE
            if VideoModuleAvailability.isEnabled {
                RecordingMetadataCleanupScheduler.shared.start()
            } else {
                RecordingMetadataCleanupScheduler.shared.stop()
            }
        #endif
    }

    private func applyUserConfigurationIfNeeded() -> CueConfigurationAutoImportResult {
        let result = CueConfigurationAutoImporter.applyIfNeededOnLaunch()
        let context = [
            "file": result.fileURL.path,
            "changes": "\(result.appliedChangeCount)",
            "warnings": "\(result.warningCount)",
            "errors": "\(result.errorCount)",
        ]

        switch result.status {
        case .applied:
            DiagnosticLogger.shared.log(
                .info,
                .preferences,
                "TOML configuration auto-applied",
                context: context,
            )
        case .failed:
            var failedContext = context
            if let errorMessage = result.errorMessage {
                failedContext["error"] = errorMessage
            }
            DiagnosticLogger.shared.log(
                .warning,
                .preferences,
                "TOML configuration auto-apply failed",
                context: failedContext,
            )
        case .skippedMissingFile:
            DiagnosticLogger.shared.log(
                .debug,
                .preferences,
                "TOML configuration auto-apply skipped; file missing",
                context: ["file": result.fileURL.path],
            )
        case .skippedPermissionRequired:
            DiagnosticLogger.shared.log(
                .debug,
                .preferences,
                "TOML configuration auto-apply skipped; folder access required",
                context: ["file": result.fileURL.path],
            )
        case .skippedUnchanged:
            DiagnosticLogger.shared.log(
                .debug,
                .preferences,
                "TOML configuration auto-apply skipped; file unchanged",
                context: ["file": result.fileURL.path],
            )
        }

        return result
    }

    private func startConfigurationSync(after autoImportResult: CueConfigurationAutoImportResult) {
        let coordinator = CueConfigurationSyncCoordinator.shared
        coordinator.start()

        guard autoImportResult.status != .applied else { return }
        coordinator.scheduleSync(reason: .appLaunch)
    }

    private func flushConfigurationSyncBeforeTermination() {
        do {
            try CueConfigurationSyncCoordinator.shared.flushPendingSync(reason: .appTerminate)
        } catch {
            DiagnosticLogger.shared.logError(
                .preferences,
                error,
                "TOML configuration sync before termination failed",
            )
        }
    }

    private func presentStartupExperience(
        configurationAutoImportResult: CueConfigurationAutoImportResult,
    ) {
        if shouldPresentConfigurationAccessOnboarding(for: configurationAutoImportResult) {
            UserDefaults.standard.set(true, forKey: PreferencesKeys.configurationAccessOnboardingPrompted)
            DiagnosticLogger.shared.log(.info, .ui, "Configuration access onboarding scheduled")
            SplashWindowController.shared.showConfigurationAccess()
            return
        }

        SplashWindowController.shared.show()
    }

    private func shouldPresentConfigurationAccessOnboarding(
        for result: CueConfigurationAutoImportResult,
    ) -> Bool {
        guard result.status == .skippedPermissionRequired else {
            return false
        }

        guard OnboardingFlowView.hasCompletedOnboarding else {
            return false
        }

        return !UserDefaults.standard.bool(forKey: PreferencesKeys.configurationAccessOnboardingPrompted)
    }
}
