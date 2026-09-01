//
//  CrashSentinel.swift
//  Notinhas
//
//  Flag-based crash detection using UserDefaults
//

import Foundation

private final class CrashSentinelState: @unchecked Sendable {
    private let lock = NSLock()
    private let sessionActiveKey = PreferencesKeys.diagnosticsSessionActive
    private var didCrashLastSession = false

    /// The lock serializes the in-memory flag and its UserDefaults marker so
    /// startup, termination, and diagnostic-header reads see one state.
    var lastSessionCrashed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didCrashLastSession
    }

    @discardableResult
    func checkAndReset() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        didCrashLastSession = UserDefaults.standard.bool(forKey: sessionActiveKey)
        UserDefaults.standard.set(true, forKey: sessionActiveKey)
        return didCrashLastSession
    }

    func markTerminated() {
        lock.lock()
        defer { lock.unlock() }

        didCrashLastSession = false
        UserDefaults.standard.set(false, forKey: sessionActiveKey)
    }
}

final class CrashSentinel: Sendable {
    static let shared = CrashSentinel()

    private let state: CrashSentinelState

    /// Whether the previous session ended abnormally (crash / force-quit)
    var didCrashLastSession: Bool {
        state.lastSessionCrashed
    }

    private init(state: CrashSentinelState = CrashSentinelState()) {
        self.state = state
    }

    // MARK: - Lifecycle

    /// Call at launch — reads crash flag, then sets it for the new session.
    /// Returns `true` if the previous session crashed.
    @discardableResult
    func checkAndReset() -> Bool {
        state.checkAndReset()
    }

    /// Call on clean termination (`applicationWillTerminate`).
    func markTerminated() {
        state.markTerminated()
    }
}
