//
//  AllInOneTimerSchedulerTests.swift
//  NotinhasTests
//
//  Deterministic tests for All-In-One delayed area capture scheduling.
//

@testable import Cue
import XCTest

@MainActor
final class AllInOneTimerSchedulerTests: XCTestCase {
    func testScheduleAreaCapture_firesActionOnceAfterDelayCompletes() async {
        let gate = DelayGate()
        let scheduler = AllInOneTimerScheduler { nanoseconds in
            try await gate.wait(for: nanoseconds)
        }
        var fireCount = 0

        scheduler.scheduleAreaCapture(afterNanoseconds: 1) {
            fireCount += 1
        }

        XCTAssertTrue(scheduler.hasPendingCapture)
        await gate.waitUntilBlocked(count: 1)
        gate.resumeAll()
        await gate.waitUntilIdle()
        await Task.yield()

        XCTAssertEqual(fireCount, 1)
        XCTAssertFalse(scheduler.hasPendingCapture)
    }

    func testCancel_beforeDelayCompletes_preventsCapture() async {
        let gate = DelayGate()
        let scheduler = AllInOneTimerScheduler { nanoseconds in
            try await gate.wait(for: nanoseconds)
        }
        var fireCount = 0

        scheduler.scheduleAreaCapture(afterNanoseconds: 1) {
            fireCount += 1
        }
        await gate.waitUntilBlocked(count: 1)
        scheduler.cancel()
        gate.resumeAll()
        await gate.waitUntilIdle()
        await Task.yield()

        XCTAssertEqual(fireCount, 0)
        XCTAssertFalse(scheduler.hasPendingCapture)
    }

    func testReplacement_cancelsPreviousPendingCapture() async {
        let scheduler = AllInOneTimerScheduler()
        var firedValues: [Int] = []

        scheduler.scheduleAreaCapture(afterNanoseconds: 10_000_000) {
            firedValues.append(1)
        }
        scheduler.scheduleAreaCapture(afterNanoseconds: 1_000_000) {
            firedValues.append(2)
        }

        try? await Task.sleep(nanoseconds: 3_000_000)

        XCTAssertEqual(firedValues, [2])
    }
}

@MainActor
private final class DelayGate {
    private var waiters: [CheckedContinuation<Void, Error>] = []
    private(set) var blockedCount = 0

    func wait(for _: UInt64) async throws {
        blockedCount += 1
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
        blockedCount -= 1
    }

    func resumeAll() {
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func waitUntilBlocked(count: Int, timeoutNanoseconds: UInt64 = 1_000_000_000) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while blockedCount < count {
            if DispatchTime.now().uptimeNanoseconds > deadline {
                XCTFail("Timed out waiting for delayed capture to block")
                return
            }
            await Task.yield()
        }
    }

    func waitUntilIdle(timeoutNanoseconds: UInt64 = 1_000_000_000) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while blockedCount > 0 || !waiters.isEmpty {
            if DispatchTime.now().uptimeNanoseconds > deadline {
                XCTFail("Timed out waiting for delayed capture to finish")
                return
            }
            await Task.yield()
        }
    }
}
