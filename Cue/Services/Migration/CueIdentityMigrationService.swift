//
//  CueIdentityMigrationService.swift
//  Notinhas
//
//  One-time migration from Notinhas storage paths to Cue identity paths.
//

import Foundation
import os.log
import Security

private let identityMigrationLogger = Logger(
    subsystem: "Cue",
    category: "CueIdentityMigration",
)

enum CueStoragePaths {
    static let legacyAppSupportFolderName = "Notinhas"
    static let destinationAppSupportFolderName = "Cue"
    static let legacyDatabaseBaseName = "notinhas"
    static let destinationDatabaseBaseName = "cue"
    static let legacyLogsFolderName = "Notinhas"
    static let destinationLogsFolderName = "Cue"
    static let legacyLogFilePrefix = "notinhas_"
    static let destinationLogFilePrefix = "cue_"
    static let legacyConfigFolderName = "notinhas"
    static let destinationConfigFolderName = "cue"
    static let legacyReleaseBundleIdentifier = "com.mourato.notinhas"
    static let legacyDebugBundleIdentifier = "com.mourato.notinhas.debug"
    static let legacyCurrentKeychainService = "com.mourato.notinhas.cloud"
    static let destinationKeychainService = "com.mourato.cue.cloud"
    static let markerFileName = ".cue-identity-migration-completed"

    static let legacyPreferenceBundleIdentifiers = [
        legacyReleaseBundleIdentifier,
        legacyDebugBundleIdentifier,
    ]

    static let databaseCompanionSuffixes = ["", "-wal", "-shm"]

    static func databaseFileName(baseName: String, suffix: String) -> String {
        "\(baseName).db\(suffix)"
    }
}

struct CueIdentityMigrationResult: Equatable {
    let didRun: Bool
    let copiedApplicationSupportItems: Int
    let skippedApplicationSupportItems: Int
    let errorSkippedApplicationSupportItems: Int
    let migratedDatabaseFiles: Int
    let importedPreferenceKeys: Int
    let skippedPreferenceKeys: Int
    let copiedLogItems: Int
    let copiedConfigItems: Int
    let migratedKeychainItems: Int

    static let skipped = CueIdentityMigrationResult(
        didRun: false,
        copiedApplicationSupportItems: 0,
        skippedApplicationSupportItems: 0,
        errorSkippedApplicationSupportItems: 0,
        migratedDatabaseFiles: 0,
        importedPreferenceKeys: 0,
        skippedPreferenceKeys: 0,
        copiedLogItems: 0,
        copiedConfigItems: 0,
        migratedKeychainItems: 0,
    )
}

protocol CueIdentityKeychainAdapting {
    func read(service: String, account: String) -> Data?
    func write(service: String, account: String, value: Data) throws
    func delete(service: String, account: String)
}

struct LiveCueIdentityKeychainAdapter: CueIdentityKeychainAdapting {
    func read(service: String, account: String) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        query[kSecUseDataProtectionKeychain as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func write(service: String, account: String, value: Data) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CueIdentityMigrationService.MigrationError.keychainWriteFailed(status: updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CueIdentityMigrationService.MigrationError.keychainWriteFailed(status: addStatus)
        }
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class CueIdentityMigrationService {
    struct Configuration {
        var homeDirectory: URL
        var applicationSupportDirectory: URL
        var libraryDirectory: URL
        var userDefaults: UserDefaults
        var fileManager: FileManager
        var keychainAdapter: CueIdentityKeychainAdapting

        static func live() -> Configuration? {
            guard
                let applicationSupportDirectory = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                ).first,
                let libraryDirectory = FileManager.default.urls(
                    for: .libraryDirectory,
                    in: .userDomainMask,
                ).first
            else {
                return nil
            }

            return Configuration(
                homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
                applicationSupportDirectory: applicationSupportDirectory,
                libraryDirectory: libraryDirectory,
                userDefaults: .standard,
                fileManager: .default,
                keychainAdapter: LiveCueIdentityKeychainAdapter(),
            )
        }
    }

    enum MigrationError: LocalizedError, Equatable {
        case configurationUnavailable
        case incompleteSQLiteCompanionSet(missing: [String])
        case unsafeSQLiteDestinationCollision(existing: [String])
        case applicationSupportMigrationFailed(underlyingDescription: String)
        case keychainWriteFailed(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .configurationUnavailable:
                "Could not resolve user Library paths for Cue identity migration."
            case let .incompleteSQLiteCompanionSet(missing):
                "Incomplete SQLite database companion set; missing: \(missing.joined(separator: ", "))."
            case let .unsafeSQLiteDestinationCollision(existing):
                "Unsafe SQLite destination collision; existing files: \(existing.joined(separator: ", "))."
            case let .applicationSupportMigrationFailed(underlyingDescription):
                "Application Support migration failed: \(underlyingDescription)"
            case let .keychainWriteFailed(status):
                "Keychain write failed with status \(status)."
            }
        }
    }

    private let configurationProvider: () -> Configuration?
    private let completedKey = PreferencesKeys.cueIdentityMigrationCompleted

    init(configurationProvider: @escaping () -> Configuration? = Configuration.live) {
        self.configurationProvider = configurationProvider
    }

    @discardableResult
    func runIfNeeded() throws -> CueIdentityMigrationResult {
        guard let configuration = configurationProvider() else {
            throw MigrationError.configurationUnavailable
        }

        guard !hasCompletedMigration(configuration) else {
            return .skipped
        }

        let destinationAppSupport = destinationAppSupportDirectory(configuration)
        let legacyAppSupportDirectories = legacyApplicationSupportDirectories(configuration)
        let legacyLogDirectories = legacyLogsDirectories(configuration)
        let hasLegacyAppSupport = legacyAppSupportDirectories.contains {
            configuration.fileManager.fileExists(atPath: $0.path)
        }
        let hasLegacyLogs = legacyLogDirectories.contains {
            configuration.fileManager.fileExists(atPath: $0.path)
        }
        let hasLegacyConfig = configuration.fileManager.fileExists(
            atPath: legacyConfigDirectory(configuration).path,
        )
        let hasLegacyPreferences = legacyPreferenceURLs(configuration).contains {
            configuration.fileManager.fileExists(atPath: $0.path)
        }
        let hasLegacyKeychain = hasLegacyKeychainItems(configuration: configuration)

        guard
            hasLegacyAppSupport || hasLegacyLogs || hasLegacyConfig || hasLegacyPreferences || hasLegacyKeychain
        else {
            try markCompleted(configuration)
            return CueIdentityMigrationResult(
                didRun: true,
                copiedApplicationSupportItems: 0,
                skippedApplicationSupportItems: 0,
                errorSkippedApplicationSupportItems: 0,
                migratedDatabaseFiles: 0,
                importedPreferenceKeys: 0,
                skippedPreferenceKeys: 0,
                copiedLogItems: 0,
                copiedConfigItems: 0,
                migratedKeychainItems: 0,
            )
        }

        var applicationSupportSummary = DirectoryMergeSummary()
        for legacyAppSupport in legacyAppSupportDirectories
            where configuration.fileManager.fileExists(atPath: legacyAppSupport.path) {
            try mergeApplicationSupport(
                from: legacyAppSupport,
                to: destinationAppSupport,
                configuration: configuration,
                summary: &applicationSupportSummary,
            )
        }

        var migratedDatabaseFiles = 0
        for legacyAppSupport in legacyAppSupportDirectories
            where configuration.fileManager.fileExists(atPath: legacyAppSupport.path) {
            migratedDatabaseFiles += try migrateDatabaseFiles(
                from: legacyAppSupport,
                to: destinationAppSupport,
                configuration: configuration,
            )
        }

        var logSummary = DirectoryMergeSummary()
        for legacyLogs in legacyLogDirectories where configuration.fileManager.fileExists(atPath: legacyLogs.path) {
            try mergeDirectoryIfPresent(
                from: legacyLogs,
                to: destinationLogsDirectory(configuration),
                configuration: configuration,
                summary: &logSummary,
            )
        }

        let preferencesSummary = migratePreferences(configuration: configuration)

        var configSummary = DirectoryMergeSummary()
        if hasLegacyConfig {
            try mergeDirectoryIfPresent(
                from: legacyConfigDirectory(configuration),
                to: destinationConfigDirectory(configuration),
                configuration: configuration,
                summary: &configSummary,
            )
        }

        let migratedKeychainItems = try migrateKeychainItems(configuration: configuration)

        try markCompleted(configuration)

        let result = CueIdentityMigrationResult(
            didRun: true,
            copiedApplicationSupportItems: applicationSupportSummary.copiedItems,
            skippedApplicationSupportItems: applicationSupportSummary.skippedItems,
            errorSkippedApplicationSupportItems: applicationSupportSummary.errorSkippedItems,
            migratedDatabaseFiles: migratedDatabaseFiles,
            importedPreferenceKeys: preferencesSummary.importedKeys,
            skippedPreferenceKeys: preferencesSummary.skippedKeys,
            copiedLogItems: logSummary.copiedItems,
            copiedConfigItems: configSummary.copiedItems,
            migratedKeychainItems: migratedKeychainItems,
        )
        identityMigrationLogger.info(
            "Cue identity migration completed: appSupportCopied=\(result.copiedApplicationSupportItems), databaseFiles=\(result.migratedDatabaseFiles), prefsImported=\(result.importedPreferenceKeys), logsCopied=\(result.copiedLogItems), configCopied=\(result.copiedConfigItems), keychainMigrated=\(result.migratedKeychainItems)",
        )
        return result
    }

    func skipMigration() throws {
        guard let configuration = configurationProvider() else {
            throw MigrationError.configurationUnavailable
        }

        identityMigrationLogger.info("Cue identity migration skipped by user (Start Fresh).")
        try markCompleted(configuration)
    }

    private struct DirectoryMergeSummary {
        var copiedItems = 0
        var skippedItems = 0
        var errorSkippedItems = 0
    }

    private struct PreferencesMigrationSummary {
        var importedKeys = 0
        var skippedKeys = 0
    }

    private func legacyAppSupportDirectory(_ configuration: Configuration) -> URL {
        configuration.applicationSupportDirectory
            .appendingPathComponent(CueStoragePaths.legacyAppSupportFolderName, isDirectory: true)
    }

    private func legacySandboxDataDirectories(_ configuration: Configuration) -> [URL] {
        CueStoragePaths.legacyPreferenceBundleIdentifiers.map {
            configuration.homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Containers", isDirectory: true)
                .appendingPathComponent($0, isDirectory: true)
                .appendingPathComponent("Data", isDirectory: true)
        }
    }

    private func legacyApplicationSupportDirectories(_ configuration: Configuration) -> [URL] {
        [legacyAppSupportDirectory(configuration)] + legacySandboxDataDirectories(configuration)
            .map { dataDirectory in
                dataDirectory
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Application Support", isDirectory: true)
                    .appendingPathComponent(CueStoragePaths.legacyAppSupportFolderName, isDirectory: true)
            }
    }

    private func destinationAppSupportDirectory(_ configuration: Configuration) -> URL {
        configuration.applicationSupportDirectory
            .appendingPathComponent(CueStoragePaths.destinationAppSupportFolderName, isDirectory: true)
    }

    private func legacyLogsDirectory(_ configuration: Configuration) -> URL {
        configuration.libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.legacyLogsFolderName, isDirectory: true)
    }

    private func legacyLogsDirectories(_ configuration: Configuration) -> [URL] {
        [legacyLogsDirectory(configuration)] + legacySandboxDataDirectories(configuration).map { dataDirectory in
            dataDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Logs", isDirectory: true)
                .appendingPathComponent(CueStoragePaths.legacyLogsFolderName, isDirectory: true)
        }
    }

    private func destinationLogsDirectory(_ configuration: Configuration) -> URL {
        configuration.libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.destinationLogsFolderName, isDirectory: true)
    }

    private func legacyConfigDirectory(_ configuration: Configuration) -> URL {
        configuration.homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.legacyConfigFolderName, isDirectory: true)
    }

    private func destinationConfigDirectory(_ configuration: Configuration) -> URL {
        configuration.homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.destinationConfigFolderName, isDirectory: true)
    }

    private func legacyPreferencesURL(_ configuration: Configuration, bundleIdentifier: String) -> URL {
        configuration.libraryDirectory
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
    }

    private func legacyPreferenceURLs(_ configuration: Configuration) -> [URL] {
        let directURLs = CueStoragePaths.legacyPreferenceBundleIdentifiers.map {
            legacyPreferencesURL(configuration, bundleIdentifier: $0)
        }
        let sandboxURLs = legacySandboxDataDirectories(configuration).flatMap { dataDirectory in
            CueStoragePaths.legacyPreferenceBundleIdentifiers.map {
                dataDirectory
                    .appendingPathComponent("Library", isDirectory: true)
                    .appendingPathComponent("Preferences", isDirectory: true)
                    .appendingPathComponent("\($0).plist")
            }
        }
        return directURLs + sandboxURLs
    }

    private func markerFileURL(_ configuration: Configuration) -> URL {
        destinationAppSupportDirectory(configuration)
            .appendingPathComponent(CueStoragePaths.markerFileName)
    }

    private func hasCompletedMigration(_ configuration: Configuration) -> Bool {
        configuration.userDefaults.bool(forKey: completedKey)
            || configuration.fileManager.fileExists(atPath: markerFileURL(configuration).path)
    }

    private func markCompleted(_ configuration: Configuration) throws {
        let destinationDirectory = destinationAppSupportDirectory(configuration)
        let markerURL = markerFileURL(configuration)
        let marker = "completedAt=\(ISO8601DateFormatter().string(from: Date()))"

        try configuration.fileManager.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true,
        )
        try marker.write(to: markerURL, atomically: true, encoding: .utf8)

        configuration.userDefaults.set(true, forKey: completedKey)
        configuration.userDefaults.synchronize()
    }

    private func mergeApplicationSupport(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        configuration: Configuration,
        summary: inout DirectoryMergeSummary,
    ) throws {
        let databaseFileNames = Set(
            CueStoragePaths.databaseCompanionSuffixes.map {
                CueStoragePaths.databaseFileName(
                    baseName: CueStoragePaths.legacyDatabaseBaseName,
                    suffix: $0,
                )
            },
        )

        let fileManager = configuration.fileManager
        guard fileManager.fileExists(atPath: sourceDirectory.path) else { return }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let sourceItems: [URL]
        do {
            sourceItems = try fileManager.contentsOfDirectory(
                at: sourceDirectory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [],
            )
        } catch {
            throw MigrationError.applicationSupportMigrationFailed(underlyingDescription: error.localizedDescription)
        }

        for sourceItem in sourceItems {
            if databaseFileNames.contains(sourceItem.lastPathComponent) {
                continue
            }

            try mergeItem(
                from: sourceItem,
                to: destinationDirectory.appendingPathComponent(sourceItem.lastPathComponent),
                configuration: configuration,
                summary: &summary,
            )
        }
    }

    private func migrateDatabaseFiles(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        configuration: Configuration,
    ) throws -> Int {
        let fileManager = configuration.fileManager
        let legacyNames = CueStoragePaths.databaseCompanionSuffixes.map {
            CueStoragePaths.databaseFileName(
                baseName: CueStoragePaths.legacyDatabaseBaseName,
                suffix: $0,
            )
        }
        let destinationNames = CueStoragePaths.databaseCompanionSuffixes.map {
            CueStoragePaths.databaseFileName(
                baseName: CueStoragePaths.destinationDatabaseBaseName,
                suffix: $0,
            )
        }

        let existingSourceFiles = legacyNames.enumerated().compactMap { index, name -> (Int, URL)? in
            let url = sourceDirectory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return (index, url)
        }

        guard !existingSourceFiles.isEmpty else { return 0 }

        let hasMainDatabase = existingSourceFiles.contains { $0.0 == 0 }
        let hasCompanionWithoutMain = existingSourceFiles.contains { $0.0 != 0 } && !hasMainDatabase
        if hasCompanionWithoutMain {
            let missing = [legacyNames[0]]
            throw MigrationError.incompleteSQLiteCompanionSet(missing: missing)
        }

        let existingDestinationFiles = destinationNames.enumerated().compactMap { index, name -> (Int, URL)? in
            let url = destinationDirectory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return (index, url)
        }

        if existingDestinationFiles.contains(where: { $0.0 == 0 }) {
            throw MigrationError.unsafeSQLiteDestinationCollision(
                existing: existingDestinationFiles.map(\.1.lastPathComponent),
            )
        }

        if !existingDestinationFiles.isEmpty {
            let existingNames = existingDestinationFiles.map(\.1.lastPathComponent)
            throw MigrationError.unsafeSQLiteDestinationCollision(existing: existingNames)
        }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var copiedCount = 0
        for (index, sourceURL) in existingSourceFiles {
            let destinationURL = destinationDirectory.appendingPathComponent(destinationNames[index])
            try copyItemAtomically(from: sourceURL, to: destinationURL, fileManager: fileManager)
            copiedCount += 1
        }

        return copiedCount
    }

    private func mergeDirectoryIfPresent(
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        configuration: Configuration,
        summary: inout DirectoryMergeSummary,
    ) throws {
        let fileManager = configuration.fileManager
        guard fileManager.fileExists(atPath: sourceDirectory.path) else { return }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let sourceItems = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [],
        )

        for sourceItem in sourceItems {
            try mergeItem(
                from: sourceItem,
                to: destinationDirectory.appendingPathComponent(sourceItem.lastPathComponent),
                configuration: configuration,
                summary: &summary,
            )
        }
    }

    private func mergeItem(
        from sourceItem: URL,
        to destinationItem: URL,
        configuration: Configuration,
        summary: inout DirectoryMergeSummary,
    ) throws {
        let fileManager = configuration.fileManager
        let values = try sourceItem.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let isDirectory = values.isDirectory == true && values.isSymbolicLink != true

        if isDirectory {
            if fileManager.fileExists(atPath: destinationItem.path) {
                var isDestinationDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: destinationItem.path, isDirectory: &isDestinationDirectory),
                   isDestinationDirectory.boolValue {
                    try mergeDirectoryIfPresent(
                        from: sourceItem,
                        to: destinationItem,
                        configuration: configuration,
                        summary: &summary,
                    )
                } else {
                    summary.skippedItems += 1
                }
            } else {
                try mergeDirectoryIfPresent(
                    from: sourceItem,
                    to: destinationItem,
                    configuration: configuration,
                    summary: &summary,
                )
            }
            return
        }

        guard !fileManager.fileExists(atPath: destinationItem.path) else {
            summary.skippedItems += 1
            return
        }

        try copyItemAtomically(from: sourceItem, to: destinationItem, fileManager: fileManager)
        summary.copiedItems += 1
    }

    private func copyItemAtomically(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager,
    ) throws {
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )

        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".identity-migration-\(UUID().uuidString)-\(destinationURL.lastPathComponent)")
        try? fileManager.removeItem(at: temporaryURL)
        do {
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func migratePreferences(configuration: Configuration) -> PreferencesMigrationSummary {
        var summary = PreferencesMigrationSummary()
        var existingPreferences = configuration.userDefaults.dictionaryRepresentation()

        for sourcePreferencesURL in legacyPreferenceURLs(configuration) {
            guard
                configuration.fileManager.fileExists(atPath: sourcePreferencesURL.path),
                let sourcePreferences = NSDictionary(contentsOf: sourcePreferencesURL) as? [String: Any]
            else {
                continue
            }

            for (key, value) in sourcePreferences
                where key != completedKey
                && key != PreferencesKeys.sandboxOffMigrationCompleted
                && key != PreferencesKeys.notinhasIdentityMigrationCompleted {
                guard existingPreferences[key] == nil else {
                    summary.skippedKeys += 1
                    continue
                }

                configuration.userDefaults.set(value, forKey: key)
                existingPreferences[key] = value
                summary.importedKeys += 1
            }
        }

        if summary.importedKeys > 0 {
            configuration.userDefaults.synchronize()
        }

        return summary
    }

    private func migrateKeychainItems(configuration: Configuration) throws -> Int {
        var migratedCount = 0

        for item in CloudKeychainItem.cueMigrationCases {
            let destinationAccount = item.cueMigrationDestinationAccount
            if configuration.keychainAdapter.read(
                service: CueStoragePaths.destinationKeychainService,
                account: destinationAccount,
            ) != nil {
                continue
            }

            guard let legacyMatch = findLegacyKeychainValue(for: item, configuration: configuration) else {
                continue
            }

            do {
                try configuration.keychainAdapter.write(
                    service: CueStoragePaths.destinationKeychainService,
                    account: destinationAccount,
                    value: legacyMatch.value,
                )
                configuration.keychainAdapter.delete(
                    service: legacyMatch.service,
                    account: legacyMatch.account,
                )
                migratedCount += 1
                identityMigrationLogger.info(
                    "Migrated keychain item: \(item.cueMigrationDiagnosticName, privacy: .public)",
                )
            } catch {
                throw error
            }
        }

        return migratedCount
    }

    private struct LegacyKeychainMatch {
        let service: String
        let account: String
        let value: Data
    }

    private func findLegacyKeychainValue(
        for item: CloudKeychainItem,
        configuration: Configuration,
    ) -> LegacyKeychainMatch? {
        for location in item.cueMigrationLegacyKeychainLocations {
            if let value = configuration.keychainAdapter.read(service: location.service, account: location.account) {
                return LegacyKeychainMatch(service: location.service, account: location.account, value: value)
            }
        }
        return nil
    }

    private func hasLegacyKeychainItems(configuration: Configuration) -> Bool {
        CloudKeychainItem.cueMigrationCases.contains {
            findLegacyKeychainValue(for: $0, configuration: configuration) != nil
        }
    }
}

private extension CloudKeychainItem {
    struct KeychainLocation: Equatable {
        let service: String
        let account: String
    }

    static var cueMigrationCases: [CloudKeychainItem] {
        [
            .accessKey,
            .secretKey,
            .passwordHash,
            .googleRefreshToken,
            .googleClientId,
            .googleClientSecret,
            .imgbbAPIKey,
            .imageKitPrivateKey,
        ]
    }

    var cueMigrationDestinationAccount: String {
        "com.mourato.cue.cloud.\(cueMigrationDiagnosticName)"
    }

    var cueMigrationDiagnosticName: String {
        switch self {
        case .accessKey: "accessKey"
        case .secretKey: "secretKey"
        case .passwordHash: "passwordHash"
        case .googleRefreshToken: "googleRefreshToken"
        case .googleClientId: "googleClientId"
        case .googleClientSecret: "googleClientSecret"
        case .imgbbAPIKey: "imgbbAPIKey"
        case .imageKitPrivateKey: "imageKitPrivateKey"
        }
    }

    var cueMigrationLegacyKeychainLocations: [KeychainLocation] {
        [
            KeychainLocation(
                service: CueStoragePaths.legacyCurrentKeychainService,
                account: cueMigrationLegacyAccount,
            ),
        ]
    }

    var cueMigrationLegacyAccount: String {
        switch self {
        case .accessKey: "com.mourato.notinhas.cloud.accessKey"
        case .secretKey: "com.mourato.notinhas.cloud.secretKey"
        case .passwordHash: "com.mourato.notinhas.cloud.passwordHash"
        case .googleRefreshToken: "com.mourato.notinhas.cloud.google.refreshToken"
        case .googleClientId: "com.mourato.notinhas.cloud.google.clientId"
        case .googleClientSecret: "com.mourato.notinhas.cloud.google.clientSecret"
        case .imgbbAPIKey: "com.mourato.notinhas.cloud.imgbbAPIKey"
        case .imageKitPrivateKey: "com.mourato.notinhas.cloud.imagekitPrivateKey"
        }
    }
}
