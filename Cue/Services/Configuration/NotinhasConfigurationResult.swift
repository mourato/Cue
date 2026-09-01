//
//  NotinhasConfigurationResult.swift
//  Notinhas
//
//  Import/export result models for TOML configuration.
//

import Foundation

enum NotinhasConfigurationIssueSeverity: Sendable {
    case warning
    case error
}

struct NotinhasConfigurationIssue: Identifiable, Sendable {
    let id = UUID()
    let severity: NotinhasConfigurationIssueSeverity
    let message: String
}

struct NotinhasConfigurationImportResult: Sendable {
    let appliedChangeCount: Int
    let issues: [NotinhasConfigurationIssue]

    var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
}

enum NotinhasConfigurationSyncDecision: Equatable, Sendable {
    case alreadyCurrent
    case syncAutomatically
    case askBeforeReplacing
}

enum NotinhasConfigurationSyncStatus: Equatable, Sendable {
    case alreadyCurrent
    case synced
    case needsConfirmation
    case permissionRequired
}

struct NotinhasConfigurationSyncResult: Sendable {
    let status: NotinhasConfigurationSyncStatus
    let fileURL: URL
    let observedFileSignature: String?
    let exportedSettingsSignature: String?

    nonisolated init(
        status: NotinhasConfigurationSyncStatus,
        fileURL: URL,
        observedFileSignature: String? = nil,
        exportedSettingsSignature: String? = nil,
    ) {
        self.status = status
        self.fileURL = fileURL
        self.observedFileSignature = observedFileSignature
        self.exportedSettingsSignature = exportedSettingsSignature
    }
}

enum NotinhasConfigurationSyncError: LocalizedError, Sendable {
    case fileChangedSinceConfirmation

    var errorDescription: String? {
        switch self {
        case .fileChangedSinceConfirmation:
            "config.toml changed. Review it and try again."
        }
    }
}
