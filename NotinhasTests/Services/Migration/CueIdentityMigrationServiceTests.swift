//
//  CueIdentityMigrationServiceTests.swift
//  NotinhasTests
//
//  Tests for one-time Notinhas-to-Cue identity data migration.
//

import Foundation
@testable import Notinhas
import XCTest

@MainActor
final class CueIdentityMigrationServiceTests: XCTestCase {
    private var rootDirectory: URL!
    private var homeDirectory: URL!
    private var libraryDirectory: URL!
    private var applicationSupportDirectory: URL!
    private var defaults: UserDefaults!
    private var keychain: FakeCueIdentityKeychainAdapter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotinhasTests_CueIdentityMigration_\(UUID().uuidString)", isDirectory: true)
        homeDirectory = rootDirectory.appendingPathComponent("Home", isDirectory: true)
        libraryDirectory = rootDirectory
            .appendingPathComponent("DestinationLibrary", isDirectory: true)
        applicationSupportDirectory = libraryDirectory
            .appendingPathComponent("Application Support", isDirectory: true)
        defaults = UserDefaultsFactory.make()
        keychain = FakeCueIdentityKeychainAdapter()

        try FileManager.default.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removeObject(forKey: PreferencesKeys.cueIdentityMigrationCompleted)
        defaults = nil
        keychain = nil
        try? FileManager.default.removeItem(at: rootDirectory)
        try super.tearDownWithError()
    }

    func testRunIfNeeded_migratesApplicationSupportDatabaseLogsConfigPreferencesAndKeychainOnce() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        let legacyLogs = legacyLogsDirectory()
        let legacyConfig = legacyConfigDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: legacyAppSupport.appendingPathComponent("Captures", isDirectory: true),
            withIntermediateDirectories: true,
        )
        try FileManager.default.createDirectory(at: legacyLogs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyConfig, withIntermediateDirectories: true)

        try Data("db".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db"))
        try Data("wal".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db-wal"))
        try Data("capture".utf8).write(to: legacyAppSupport.appendingPathComponent("Captures/capture.png"))
        try Data("log".utf8).write(to: legacyLogs.appendingPathComponent("notinhas_2026-06-21.txt"))
        try Data("config".utf8).write(to: legacyConfig.appendingPathComponent("config.toml"))

        let releasePreferences = legacyPreferencesURL(bundleIdentifier: CueStoragePaths
            .legacyReleaseBundleIdentifier)
        try FileManager.default.createDirectory(
            at: releasePreferences.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        XCTAssertTrue(
            ([
                PreferencesKeys.screenshotFormat: "webp",
                PreferencesKeys.historyEnabled: false,
            ] as NSDictionary).write(to: releasePreferences, atomically: true),
        )

        keychain.store(
            service: CueStoragePaths.legacyCurrentKeychainService,
            account: "com.mourato.notinhas.cloud.accessKey",
            value: Data("secret-access".utf8),
        )

        let firstResult = try makeService().runIfNeeded()

        XCTAssertTrue(firstResult.didRun)
        XCTAssertEqual(firstResult.copiedApplicationSupportItems, 1)
        XCTAssertEqual(firstResult.migratedDatabaseFiles, 2)
        XCTAssertEqual(firstResult.copiedLogItems, 1)
        XCTAssertEqual(firstResult.copiedConfigItems, 1)
        XCTAssertEqual(firstResult.importedPreferenceKeys, 2)
        XCTAssertEqual(firstResult.migratedKeychainItems, 1)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp")
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.historyEnabled))
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationAppSupport().appendingPathComponent("cue.db").path,
            ),
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationAppSupport().appendingPathComponent("cue.db-wal").path,
            ),
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationAppSupport().appendingPathComponent("Captures/capture.png").path,
            ),
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationLogsDirectory().appendingPathComponent("notinhas_2026-06-21.txt").path,
            ),
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationConfigDirectory().appendingPathComponent("config.toml").path,
            ),
        )
        XCTAssertEqual(
            keychain.read(
                service: CueStoragePaths.destinationKeychainService,
                account: "com.mourato.cue.cloud.accessKey",
            ),
            Data("secret-access".utf8),
        )
        XCTAssertNil(
            keychain.read(
                service: CueStoragePaths.legacyCurrentKeychainService,
                account: "com.mourato.notinhas.cloud.accessKey",
            ),
        )

        let secondResult = try makeService().runIfNeeded()
        XCTAssertFalse(secondResult.didRun)
        XCTAssertEqual(secondResult.copiedApplicationSupportItems, 0)
    }

    func testRunIfNeeded_marksCompletedWhenNoLegacySourcesExist() throws {
        let firstResult = try makeService().runIfNeeded()
        let secondResult = try makeService().runIfNeeded()

        XCTAssertTrue(firstResult.didRun)
        XCTAssertFalse(secondResult.didRun)
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: destinationAppSupport().appendingPathComponent(CueStoragePaths.markerFileName).path,
            ),
        )
    }

    func testRunIfNeeded_migratesLegacySandboxContainerStorage() throws {
        let sandboxAppSupport = homeDirectory
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.legacyReleaseBundleIdentifier, isDirectory: true)
            .appendingPathComponent("Data/Library/Application Support/Notinhas", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sandboxAppSupport.appendingPathComponent("Captures", isDirectory: true),
            withIntermediateDirectories: true,
        )
        try Data("sandbox-db".utf8).write(to: sandboxAppSupport.appendingPathComponent("notinhas.db"))
        try Data("sandbox-capture".utf8).write(
            to: sandboxAppSupport.appendingPathComponent("Captures/capture.png"),
        )

        let result = try makeService().runIfNeeded()

        XCTAssertEqual(result.migratedDatabaseFiles, 1)
        XCTAssertEqual(result.copiedApplicationSupportItems, 1)
        XCTAssertEqual(
            try String(contentsOf: destinationAppSupport().appendingPathComponent("cue.db")),
            "sandbox-db",
        )
        XCTAssertEqual(
            try String(contentsOf: destinationAppSupport().appendingPathComponent("Captures/capture.png")),
            "sandbox-capture",
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: sandboxAppSupport.path))
    }

    func testRunIfNeeded_preservesExistingDestinationFilesAndPreferences() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(
            at: legacyAppSupport.appendingPathComponent("Captures", isDirectory: true),
            withIntermediateDirectories: true,
        )
        try Data("legacy capture".utf8).write(to: legacyAppSupport.appendingPathComponent("Captures/capture.png"))

        try FileManager.default.createDirectory(
            at: destinationAppSupport().appendingPathComponent("Captures", isDirectory: true),
            withIntermediateDirectories: true,
        )
        try Data("current database".utf8).write(to: destinationAppSupport().appendingPathComponent("cue.db"))

        let releasePreferences = legacyPreferencesURL(bundleIdentifier: CueStoragePaths
            .legacyReleaseBundleIdentifier)
        try FileManager.default.createDirectory(
            at: releasePreferences.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        XCTAssertTrue(
            ([
                PreferencesKeys.historyEnabled: false,
                PreferencesKeys.screenshotFormat: "webp",
            ] as NSDictionary).write(to: releasePreferences, atomically: true),
        )
        defaults.set(true, forKey: PreferencesKeys.historyEnabled)

        let result = try makeService().runIfNeeded()

        XCTAssertEqual(result.copiedApplicationSupportItems, 1)
        XCTAssertEqual(result.skippedApplicationSupportItems, 0)
        XCTAssertEqual(result.migratedDatabaseFiles, 0)
        XCTAssertEqual(
            try String(contentsOf: destinationAppSupport().appendingPathComponent("cue.db")),
            "current database",
        )
        XCTAssertEqual(
            try String(contentsOf: destinationAppSupport().appendingPathComponent("Captures/capture.png")),
            "legacy capture",
        )
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.historyEnabled))
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp")
    }

    func testRunIfNeeded_importsDebugPreferencesWithoutOverridingExistingValues() throws {
        let debugPreferences = legacyPreferencesURL(bundleIdentifier: CueStoragePaths.legacyDebugBundleIdentifier)
        try FileManager.default.createDirectory(
            at: debugPreferences.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        XCTAssertTrue(
            ([
                PreferencesKeys.screenshotFormat: "png",
                PreferencesKeys.historyEnabled: false,
            ] as NSDictionary).write(to: debugPreferences, atomically: true),
        )
        defaults.set("webp", forKey: PreferencesKeys.screenshotFormat)

        let result = try makeService().runIfNeeded()

        XCTAssertEqual(result.importedPreferenceKeys, 1)
        XCTAssertEqual(result.skippedPreferenceKeys, 1)
        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "webp")
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.historyEnabled))
    }

    func testRunIfNeeded_throwsForIncompleteSQLiteCompanionSet() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try Data("wal-only".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db-wal"))

        XCTAssertThrowsError(try makeService().runIfNeeded()) { error in
            guard case CueIdentityMigrationService.MigrationError.incompleteSQLiteCompanionSet = error else {
                return XCTFail("Expected incompleteSQLiteCompanionSet, got \(error)")
            }
        }
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
    }

    func testRunIfNeeded_throwsForUnsafeSQLiteDestinationCollision() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db"))
        try FileManager.default.createDirectory(at: destinationAppSupport(), withIntermediateDirectories: true)
        try Data("wal".utf8).write(to: destinationAppSupport().appendingPathComponent("cue.db-wal"))

        XCTAssertThrowsError(try makeService().runIfNeeded()) { error in
            guard case CueIdentityMigrationService.MigrationError.unsafeSQLiteDestinationCollision = error else {
                return XCTFail("Expected unsafeSQLiteDestinationCollision, got \(error)")
            }
        }
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
    }

    func testRunIfNeeded_doesNotMarkCompletedWhenApplicationSupportCopyFails() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try Data("database".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db"))

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: applicationSupportDirectory.path,
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: applicationSupportDirectory.path,
            )
        }

        XCTAssertThrowsError(try makeService().runIfNeeded())
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
    }

    func testSkipMigration_marksCompletedWithoutCopyingData() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try Data("database".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db"))

        let service = makeService()
        try service.skipMigration()

        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationAppSupport().appendingPathComponent("cue.db").path,
            ),
        )

        let result = try service.runIfNeeded()
        XCTAssertFalse(result.didRun)
    }

    func testRunIfNeeded_doesNotImportNotinhasIdentityMigrationFlag() throws {
        let releasePreferences = legacyPreferencesURL(bundleIdentifier: CueStoragePaths
            .legacyReleaseBundleIdentifier)
        try FileManager.default.createDirectory(
            at: releasePreferences.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        XCTAssertTrue(
            ([
                PreferencesKeys.notinhasIdentityMigrationCompleted: true,
                PreferencesKeys.screenshotFormat: "png",
            ] as NSDictionary).write(to: releasePreferences, atomically: true),
        )

        _ = try makeService().runIfNeeded()

        XCTAssertEqual(defaults.string(forKey: PreferencesKeys.screenshotFormat), "png")
        XCTAssertFalse(defaults.bool(forKey: PreferencesKeys.notinhasIdentityMigrationCompleted))
        XCTAssertTrue(defaults.bool(forKey: PreferencesKeys.cueIdentityMigrationCompleted))
    }

    func testRunIfNeeded_migratesImgBBKeychainItem() throws {
        keychain.store(
            service: CueStoragePaths.legacyCurrentKeychainService,
            account: "com.mourato.notinhas.cloud.imgbbAPIKey",
            value: Data("imgbb-secret".utf8),
        )

        let result = try makeService().runIfNeeded()

        XCTAssertEqual(result.migratedKeychainItems, 1)
        XCTAssertEqual(
            keychain.read(
                service: CueStoragePaths.destinationKeychainService,
                account: "com.mourato.cue.cloud.imgbbAPIKey",
            ),
            Data("imgbb-secret".utf8),
        )
        XCTAssertNil(
            keychain.read(
                service: CueStoragePaths.legacyCurrentKeychainService,
                account: "com.mourato.notinhas.cloud.imgbbAPIKey",
            ),
        )
    }

    func testRunIfNeeded_preservesLegacySourceFiles() throws {
        let legacyAppSupport = legacyAppSupportDirectory()
        try FileManager.default.createDirectory(at: legacyAppSupport, withIntermediateDirectories: true)
        try Data("precious".utf8).write(to: legacyAppSupport.appendingPathComponent("notinhas.db"))

        _ = try makeService().runIfNeeded()

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: legacyAppSupport.appendingPathComponent("notinhas.db").path,
            ),
        )
    }

    private func makeService() -> CueIdentityMigrationService {
        CueIdentityMigrationService {
            CueIdentityMigrationService.Configuration(
                homeDirectory: self.homeDirectory,
                applicationSupportDirectory: self.applicationSupportDirectory,
                libraryDirectory: self.libraryDirectory,
                userDefaults: self.defaults,
                fileManager: .default,
                keychainAdapter: self.keychain,
            )
        }
    }

    private func legacyAppSupportDirectory() -> URL {
        applicationSupportDirectory.appendingPathComponent(
            CueStoragePaths.legacyAppSupportFolderName,
            isDirectory: true,
        )
    }

    private func destinationAppSupport() -> URL {
        applicationSupportDirectory.appendingPathComponent(
            CueStoragePaths.destinationAppSupportFolderName,
            isDirectory: true,
        )
    }

    private func legacyLogsDirectory() -> URL {
        libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.legacyLogsFolderName, isDirectory: true)
    }

    private func destinationLogsDirectory() -> URL {
        libraryDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.destinationLogsFolderName, isDirectory: true)
    }

    private func legacyConfigDirectory() -> URL {
        homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.legacyConfigFolderName, isDirectory: true)
    }

    private func destinationConfigDirectory() -> URL {
        homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(CueStoragePaths.destinationConfigFolderName, isDirectory: true)
    }

    private func legacyPreferencesURL(bundleIdentifier: String) -> URL {
        libraryDirectory
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).plist")
    }
}

private final class FakeCueIdentityKeychainAdapter: CueIdentityKeychainAdapting {
    private var storage: [String: Data] = [:]

    func read(service: String, account: String) -> Data? {
        storage[key(service: service, account: account)]
    }

    func write(service: String, account: String, value: Data) throws {
        storage[key(service: service, account: account)] = value
    }

    func delete(service: String, account: String) {
        storage.removeValue(forKey: key(service: service, account: account))
    }

    func store(service: String, account: String, value: Data) {
        storage[key(service: service, account: account)] = value
    }

    private func key(service: String, account: String) -> String {
        "\(service)|\(account)"
    }
}
