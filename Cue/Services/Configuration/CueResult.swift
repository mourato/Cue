//
//  CueConfigurationResult.swift
//  Notinhas
//
//  Import/export result models for TOML configuration.
//

import Foundation

enum CueConfigurationIssueSeverity: Sendable {
    case warning
    case error
}

struct CueConfigurationIssue: Identifiable, Sendable {
    let id = UUID()
    let severity: CueConfigurationIssueSeverity
    let message: String
}

struct CueConfigurationImportResult: Sendable {
    let appliedChangeCount: Int
    let issues: [CueConfigurationIssue]

    var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }
}

enum CueConfigurationSyncDecision: Equatable, Sendable {
    case alreadyCurrent
    case syncAutomatically
    case askBeforeReplacing
}

enum CueConfigurationSyncStatus: Equatable, Sendable {
    case alreadyCurrent
    case synced
    case needsConfirmation
    case permissionRequired
}

struct CueConfigurationSyncResult: Sendable {
    let status: CueConfigurationSyncStatus
    let fileURL: URL
    let observedFileSignature: String?
    let exportedSettingsSignature: String?

    nonisolated init(
        status: CueConfigurationSyncStatus,
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

enum CueConfigurationSyncError: LocalizedError, Sendable {
    case fileChangedSinceConfirmation

    var errorDescription: String? {
        switch self {
        case .fileChangedSinceConfirmation:
            "config.toml changed. Review it and try again."
        }
    }
}
