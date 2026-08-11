//
//  PreferencesAdvancedSettingsView.swift
//  Notinhas
//
//  Advanced preferences for portable app configuration and diagnostics.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AdvancedSettingsView: View {
    @AppStorage(PreferencesKeys.diagnosticsEnabled) private var diagnosticsEnabled = true
    @AppStorage(PreferencesKeys.diagnosticsRetentionDays) private var diagnosticsRetentionDays = LogCleanupScheduler
        .defaultRetentionDays
    @AppStorage(PreferencesKeys.urlSchemeEnabled) private var urlSchemeEnabled = true

    @State private var needsConfigAccess = NotinhasConfigurationService.shared.needsUserSelectedConfigAccess
    @State private var isRestoreConfirmationPresented = false
    @State private var isConfigSyncConfirmationPresented = false
    @State private var pendingConfigSyncURL: URL?
    @State private var pendingConfigSyncSignature: String?
    @State private var logSizeText = L10n.PreferencesAdvanced.calculating
    @ObservedObject private var configSyncCoordinator = NotinhasConfigurationSyncCoordinator.shared

    private let service = NotinhasConfigurationService.shared
    private let tomlContentType = UTType(filenameExtension: "toml") ?? .plainText

    private var canUseBackupActions: Bool {
        !needsConfigAccess
    }

    var body: some View {
        Form {
            Section(L10n.PreferencesAdvanced.backupSection) {
                if needsConfigAccess {
                    AdvancedConfigAccessWarningRow {
                        grantConfigAccess(openAfterGrant: false)
                    }
                }

                SettingRow(
                    icon: "square.and.arrow.down",
                    title: L10n.PreferencesAdvanced.importTitle,
                    description: L10n.PreferencesAdvanced.importDescription,
                ) {
                    Button(L10n.PreferencesAdvanced.importButton) {
                        importConfig()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canUseBackupActions)
                    .help(disabledBackupActionHelp)
                }

                SettingRow(
                    icon: "square.and.arrow.up",
                    title: L10n.PreferencesAdvanced.exportTitle,
                    description: L10n.PreferencesAdvanced.exportDescription,
                ) {
                    Button(L10n.PreferencesAdvanced.exportButton) {
                        exportConfig()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canUseBackupActions)
                    .help(disabledBackupActionHelp)
                }

                SettingRow(
                    icon: "arrow.counterclockwise.circle",
                    title: L10n.PreferencesAdvanced.restoreDefaultsTitle,
                    description: L10n.PreferencesAdvanced.restoreDefaultsDescription,
                ) {
                    Button(L10n.PreferencesAdvanced.restoreDefaultsButton, role: .destructive) {
                        requestRestoreDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canUseBackupActions)
                    .help(disabledBackupActionHelp)
                }

                SettingRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: L10n.PreferencesAdvanced.configSyncStatusTitle,
                    description: configSyncStatusDescription,
                ) {
                    HStack(spacing: 10) {
                        StatusBadge(configuration: configSyncBadgeConfiguration)

                        Button(L10n.PreferencesAdvanced.syncNowButton) {
                            syncConfigNow()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canUseBackupActions || isConfigSyncing)
                        .help(disabledBackupActionHelp)
                    }
                }

                HStack {
                    Spacer()

                    Button(L10n.PreferencesAdvanced.openConfigButton) {
                        openConfigFile()
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .disabled(!canUseBackupActions)
                    .help(disabledBackupActionHelp)
                }
            }

            Section(L10n.PreferencesAdvanced.integrationSection) {
                SettingRow(
                    icon: "link",
                    title: L10n.PreferencesAdvanced.urlSchemeTitle,
                    description: L10n.PreferencesAdvanced.urlSchemeDescription,
                ) {
                    Toggle("", isOn: $urlSchemeEnabled)
                        .labelsHidden()
                }
            }

            #if NOTINHAS_VIDEO_MODULE
                Section(L10n.PreferencesAdvanced.optionalModulesSection) {
                    VideoModuleToggleRow()
                }
            #endif

            Section(L10n.PreferencesAdvanced.diagnosticsSection) {
                SettingRow(
                    icon: "doc.text.magnifyingglass",
                    title: L10n.PreferencesAdvanced.diagnosticLoggingTitle,
                    description: L10n.PreferencesAdvanced.diagnosticLoggingDescription,
                ) {
                    Toggle("", isOn: $diagnosticsEnabled)
                        .labelsHidden()
                }

                SettingRow(
                    icon: "calendar.badge.clock",
                    title: L10n.PreferencesAdvanced.logRetentionTitle,
                    description: L10n.PreferencesAdvanced.logRetentionDescription(diagnosticsRetentionDays),
                ) {
                    PreferencesNumericPicker(
                        value: Binding(
                            get: { Double(diagnosticsRetentionDays) },
                            set: { diagnosticsRetentionDays = Int($0.rounded()) },
                        ),
                        range: Double(LogCleanupScheduler.retentionDaysRange.lowerBound)
                            ... Double(LogCleanupScheduler.retentionDaysRange.upperBound),
                        presets: [1, 3, 7, 14, 30],
                        step: 1,
                        accessibilityTitle: L10n.PreferencesAdvanced.logRetentionTitle,
                        unit: "days",
                        valueLabel: { "\(Int($0)) days" },
                    )
                }

                SettingRow(icon: "folder", title: L10n.PreferencesAdvanced.logFilesTitle, description: logSizeText) {
                    Button(L10n.PreferencesAdvanced.openFolderButton) {
                        revealLogFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshConfigAccessState()
            updateLogSize()
        }
        .onChange(of: diagnosticsRetentionDays) { _ in
            LogCleanupScheduler.shared.performCleanupNow()
            updateLogSize()
        }
        .alert(
            L10n.PreferencesAdvanced.restoreDefaultsConfirmationTitle,
            isPresented: $isRestoreConfirmationPresented,
        ) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.PreferencesAdvanced.restoreDefaultsConfirmButton, role: .destructive) {
                performRestoreDefaults()
            }
        } message: {
            Text(L10n.PreferencesAdvanced.restoreDefaultsConfirmationMessage)
        }
        .alert(
            L10n.PreferencesAdvanced.configSyncConfirmationTitle,
            isPresented: $isConfigSyncConfirmationPresented,
        ) {
            Button(L10n.Common.cancel, role: .cancel) {
                pendingConfigSyncURL = nil
                pendingConfigSyncSignature = nil
            }
            Button(L10n.PreferencesAdvanced.openExistingConfigButton) {
                openPendingConfigWithoutSync()
            }
            Button(L10n.PreferencesAdvanced.syncConfigConfirmButton, role: .destructive) {
                syncPendingConfigAndOpen()
            }
        } message: {
            Text(L10n.PreferencesAdvanced.configSyncConfirmationMessage)
        }
    }

    private var disabledBackupActionHelp: String {
        needsConfigAccess ? L10n.PreferencesAdvanced.configAccessRequiredToast : ""
    }

    private var isConfigSyncing: Bool {
        if case .syncing = effectiveConfigSyncStatus {
            return true
        }
        return false
    }

    private var effectiveConfigSyncStatus: NotinhasConfigurationSyncCoordinator.Status {
        needsConfigAccess ? .needsPermission : configSyncCoordinator.status
    }

    private var configSyncStatusDescription: String {
        switch effectiveConfigSyncStatus {
        case .idle:
            L10n.PreferencesAdvanced.configSyncIdleDescription
        case .scheduled:
            L10n.PreferencesAdvanced.configSyncQueuedDescription
        case .syncing:
            L10n.PreferencesAdvanced.configSyncWritingDescription
        case .upToDate(let date):
            L10n.PreferencesAdvanced.configSyncUpToDateDescription(configSyncTimeText(date))
        case .synced(let date):
            L10n.PreferencesAdvanced.configSyncSyncedDescription(configSyncTimeText(date))
        case .needsPermission:
            L10n.PreferencesAdvanced.configAccessRequiredToast
        case .conflict:
            L10n.PreferencesAdvanced.configSyncNeedsConfirmation
        case .failed(let message):
            message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L10n.PreferencesAdvanced.openConfigUnavailable
                : message
        }
    }

    private var configSyncBadgeConfiguration: StatusBadge.Configuration {
        switch effectiveConfigSyncStatus {
        case .idle, .upToDate, .synced:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeSynced,
                systemImage: "checkmark.circle.fill",
                tint: .green,
            )
        case .scheduled:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeQueued,
                systemImage: "clock.fill",
                tint: .blue,
            )
        case .syncing:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeSyncing,
                tint: .blue,
                showsProgress: true,
            )
        case .needsPermission:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeAccessNeeded,
                systemImage: "lock.fill",
                tint: .orange,
            )
        case .conflict:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeReviewNeeded,
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
            )
        case .failed:
            StatusBadge.Configuration(
                label: L10n.PreferencesAdvanced.configSyncBadgeFailed,
                systemImage: "xmark.octagon.fill",
                tint: .red,
            )
        }
    }

    private func configSyncTimeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }

    private func requestRestoreDefaults() {
        guard backupActionsAreAvailable() else { return }
        isRestoreConfirmationPresented = true
    }

    private func exportConfig() {
        guard backupActionsAreAvailable() else { return }

        let panel = NSSavePanel()
        panel.title = L10n.PreferencesAdvanced.exportPanelTitle
        panel.nameFieldStringValue = "config.toml"
        panel.directoryURL = service.suggestedConfigDirectoryURL
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [tomlContentType]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try service.export(to: url)
            if service.isSuggestedConfigFile(url) {
                try? service.rememberConfigFileAccess(url)
            }
            refreshConfigAccessState()
            showNotice(L10n.PreferencesAdvanced.exportSucceeded, style: .success)
        } catch {
            showNotice(error.localizedDescription, fallback: L10n.PreferencesAdvanced.exportFailed, style: .error)
        }
    }

    private func importConfig() {
        guard backupActionsAreAvailable() else { return }

        let panel = NSOpenPanel()
        panel.title = L10n.PreferencesAdvanced.importPanelTitle
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [tomlContentType]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let result = try service.importBackupReplacingManagedConfig(from: url)
            showImportNotice(for: result)
        } catch {
            showNotice(error.localizedDescription, fallback: L10n.PreferencesAdvanced.importFailed, style: .error)
        }
    }

    private func performRestoreDefaults() {
        guard backupActionsAreAvailable() else { return }

        do {
            let result = try service.restoreDefaultsReplacingManagedConfig()
            showRestoreNotice(for: result)
        } catch {
            showNotice(
                error.localizedDescription,
                fallback: L10n.PreferencesAdvanced.restoreDefaultsFailed,
                style: .error,
            )
        }
    }

    private func openConfigFile() {
        guard backupActionsAreAvailable(showNotice: false) else { return }

        do {
            let result = try configSyncCoordinator.syncNow(reason: .openConfig)
            switch result.status {
            case .alreadyCurrent, .synced:
                openConfigFile(at: result.fileURL)
            case .needsConfirmation:
                pendingConfigSyncURL = result.fileURL
                pendingConfigSyncSignature = result.observedFileSignature
                isConfigSyncConfirmationPresented = true
            case .permissionRequired:
                break
            }
        } catch {
            DiagnosticLogger.shared.logError(.preferences, error, "Open config.toml sync failed")
        }
    }

    private func syncConfigNow() {
        guard backupActionsAreAvailable(showNotice: false) else { return }

        do {
            let result = try configSyncCoordinator.syncNow(reason: .manual)
            switch result.status {
            case .alreadyCurrent, .synced:
                break
            case .needsConfirmation:
                pendingConfigSyncURL = result.fileURL
                pendingConfigSyncSignature = result.observedFileSignature
                isConfigSyncConfirmationPresented = true
            case .permissionRequired:
                break
            }
        } catch {
            DiagnosticLogger.shared.logError(.preferences, error, "Manual config.toml sync failed")
        }
    }

    private func openConfigFile(at url: URL) {
        let access = service.beginAccessingConfigFile(url)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = false

        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            access.stop()
            DispatchQueue.main.async {
                if let error {
                    showNotice(
                        error.localizedDescription,
                        fallback: L10n.PreferencesAdvanced.openConfigUnavailable,
                        style: .error,
                    )
                    return
                }

                showNotice(L10n.PreferencesAdvanced.openConfigSucceeded, style: .success)
            }
        }
    }

    private func openPendingConfigWithoutSync() {
        guard let url = pendingConfigSyncURL else { return }
        pendingConfigSyncURL = nil
        pendingConfigSyncSignature = nil
        openConfigFile(at: url)
    }

    private func syncPendingConfigAndOpen() {
        guard let url = pendingConfigSyncURL else { return }
        let expectedSignature = pendingConfigSyncSignature
        pendingConfigSyncURL = nil
        pendingConfigSyncSignature = nil

        do {
            let syncedURL = try configSyncCoordinator.syncCurrentSettingsAfterConfirmation(
                at: url,
                expectedFileSignature: expectedSignature,
            )
            openConfigFile(at: syncedURL)
        } catch {
            DiagnosticLogger.shared.logError(.preferences, error, "Confirmed config.toml sync failed")
        }
    }

    private func grantConfigAccess(openAfterGrant: Bool) {
        do {
            guard let grantResult = try NotinhasConfigurationAccessGranting.grantSuggestedConfigAccess(service: service)
            else {
                return
            }

            refreshConfigAccessState()
            showGrantNotice(for: grantResult)

            if openAfterGrant {
                openConfigFile(at: grantResult.configURL)
            }
        } catch {
            showNotice(
                error.localizedDescription,
                fallback: L10n.PreferencesAdvanced.openConfigUnavailable,
                style: .error,
            )
        }
    }

    private func issues(for autoImportResult: NotinhasConfigurationAutoImportResult) -> [NotinhasConfigurationIssue] {
        if let issues = autoImportResult.importResult?.issues {
            return issues
        }

        if autoImportResult.status == .failed, let errorMessage = autoImportResult.errorMessage {
            return [NotinhasConfigurationIssue(severity: .error, message: errorMessage)]
        }

        return []
    }

    @discardableResult
    private func ensureSuggestedConfigExists(reportFailure: Bool) -> URL? {
        ensureConfigExists(at: service.resolvedConfigFileURL, reportFailure: reportFailure)
    }

    @discardableResult
    private func ensureConfigExists(at url: URL, reportFailure: Bool) -> URL? {
        do {
            return try service.ensureConfigExists(at: url)
        } catch {
            if reportFailure {
                showNotice(
                    error.localizedDescription,
                    fallback: L10n.PreferencesAdvanced.openConfigUnavailable,
                    style: .error,
                )
            }
            return nil
        }
    }

    private func refreshConfigAccessState() {
        needsConfigAccess = service.needsUserSelectedConfigAccess
    }

    private func backupActionsAreAvailable(showNotice shouldShowNotice: Bool = true) -> Bool {
        refreshConfigAccessState()

        if needsConfigAccess {
            if shouldShowNotice {
                showNotice(L10n.PreferencesAdvanced.configAccessRequiredToast, style: .warning)
            }
            return false
        }

        return true
    }

    private func revealLogFolder() {
        let logDir = DiagnosticLogger.shared.logDirectoryURL
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir.path) {
            try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logDir.path)
    }

    private func updateLogSize() {
        let logDir = DiagnosticLogger.shared.logDirectoryURL
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: logDir.path) else {
            logSizeText = L10n.PreferencesAdvanced.noLogs
            return
        }
        let totalBytes = files.compactMap { file -> Int? in
            let path = logDir.appendingPathComponent(file).path
            return (try? fm.attributesOfItem(atPath: path))?[.size] as? Int
        }.reduce(0, +)

        if totalBytes == 0 {
            logSizeText = L10n.PreferencesAdvanced.noLogs
        } else {
            logSizeText = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
        }
    }

    private func showGrantNotice(for grantResult: NotinhasConfigurationAccessGrantResult) {
        let issues = issues(for: grantResult.autoImportResult)
        let style = noticeStyle(for: issues)
        let message: String = if let importResult = grantResult.autoImportResult.importResult {
            noticeSummary(for: importResult, successMessage: L10n.PreferencesAdvanced.configAccessReady)
        } else if grantResult.autoImportResult.status == .failed {
            issues.first?.message ?? L10n.PreferencesAdvanced.openConfigUnavailable
        } else {
            L10n.PreferencesAdvanced.configAccessReady
        }

        showNotice(message, style: style)
    }

    private func showImportNotice(for result: NotinhasConfigurationImportResult) {
        showNotice(
            noticeSummary(for: result, successMessage: L10n.PreferencesAdvanced.importSucceeded),
            style: noticeStyle(for: result.issues),
        )
    }

    private func showRestoreNotice(for result: NotinhasConfigurationImportResult) {
        guard !result.hasErrors else {
            showImportNotice(for: result)
            return
        }

        let style = noticeStyle(for: result.issues)
        let message = result.issues.contains(where: { $0.severity == .warning })
            ? noticeSummary(for: result, successMessage: L10n.PreferencesAdvanced.restoreDefaultsSucceeded)
            : L10n.PreferencesAdvanced.restoreDefaultsSucceeded
        showNotice(message, style: style)
    }

    private func noticeSummary(
        for result: NotinhasConfigurationImportResult,
        successMessage: String,
    ) -> String {
        if result.hasErrors {
            return L10n.PreferencesAdvanced.importFailedWithErrors(
                result.issues.filter { $0.severity == .error }.count,
            )
        }

        let warningCount = result.issues.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return L10n.PreferencesAdvanced.importedWithWarnings(
                result.appliedChangeCount,
                warningCount,
            )
        }

        return successMessage
    }

    private func noticeStyle(for issues: [NotinhasConfigurationIssue]) -> AppToastStyle {
        if issues.contains(where: { $0.severity == .error }) {
            return .error
        }

        if issues.contains(where: { $0.severity == .warning }) {
            return .warning
        }

        return .success
    }

    private func showNotice(
        _ message: String,
        fallback: String? = nil,
        style: AppToastStyle,
    ) {
        let resolvedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallback ?? L10n.PreferencesAdvanced.operationFinished
            : message

        AppToastManager.shared.show(
            message: resolvedMessage,
            style: style,
            duration: style == .success ? 2.4 : 4.0,
        )
    }
}

#if NOTINHAS_VIDEO_MODULE
    private struct VideoModuleToggleRow: View {
        @ObservedObject private var recorder = ScreenRecordingManager.shared
        @State private var isEnabled = VideoModuleAvailability.isEnabled

        private var isRecordingActive: Bool {
            recorder.isActive
        }

        private var toggleBinding: Binding<Bool> {
            Binding(
                get: { isEnabled },
                set: { newValue in
                    if !newValue, isRecordingActive {
                        return
                    }
                    isEnabled = newValue
                    VideoModuleAvailability.setEnabled(newValue)
                },
            )
        }

        var body: some View {
            SettingRow(
                icon: "video.fill",
                title: L10n.PreferencesAdvanced.videoModuleTitle,
                description: isRecordingActive && isEnabled
                    ? L10n.PreferencesAdvanced.videoModuleDisabledWhileRecording
                    : L10n.PreferencesAdvanced.videoModuleDescription,
            ) {
                Toggle("", isOn: toggleBinding)
                    .labelsHidden()
                    .disabled(isRecordingActive && isEnabled)
            }
            .onReceive(NotificationCenter.default.publisher(for: .videoModuleAvailabilityDidChange)) { _ in
                isEnabled = VideoModuleAvailability.isEnabled
            }
        }
    }
#endif

private struct AdvancedConfigAccessWarningRow: View {
    let onGrant: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.PreferencesAdvanced.configAccessWarningTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(L10n.PreferencesAdvanced.configAccessWarningDescription(
                    NotinhasConfigurationService.shared.suggestedConfigDirectoryURL.path,
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(L10n.PreferencesAdvanced.grantConfigAccessButton) {
                onGrant()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onGrant()
        }
    }
}

#Preview {
    AdvancedSettingsView()
        .frame(width: 600, height: 450)
}
