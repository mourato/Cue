//
//  AllInOneTimerScheduler.swift
//  Notinhas
//
//  Cancellable delayed area capture scheduling for All-In-One Timer mode.
//

import Foundation

@MainActor
final class AllInOneTimerScheduler {
    static let defaultDelayNanoseconds: UInt64 = 3_000_000_000

    private let sleep: @Sendable (UInt64) async throws -> Void
    private var pendingTask: Task<Void, Never>?

    init(sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.sleep = sleep
    }

    var hasPendingCapture: Bool {
        pendingTask != nil
    }

    func scheduleAreaCapture(
        afterNanoseconds delay: UInt64 = AllInOneTimerScheduler.defaultDelayNanoseconds,
        action: @escaping @MainActor () -> Void,
    ) {
        cancel()
        pendingTask = Task { @MainActor [sleep] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            action()
            pendingTask = nil
        }
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
