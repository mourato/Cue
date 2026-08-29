#if NOTINHAS_VIDEO_MODULE
//
    //  RecordingMouseTrackerTests.swift
    //  NotinhasTests
//
    //  Unit tests for RecordingMouseTracker sample-rate resolution and lifecycle.
//

    import CoreGraphics
    @testable import Notinhas
    import XCTest

    @MainActor
    final class RecordingMouseTrackerTests: XCTestCase {
        func testResolvedSamplesPerSecond_fps15_clampedToMin() {
            XCTAssertEqual(RecordingMouseTracker.resolvedSamplesPerSecond(for: 15), 60)
        }

        func testResolvedSamplesPerSecond_fps30_doubled() {
            XCTAssertEqual(RecordingMouseTracker.resolvedSamplesPerSecond(for: 30), 60)
        }

        func testResolvedSamplesPerSecond_fps60_doubled() {
            XCTAssertEqual(RecordingMouseTracker.resolvedSamplesPerSecond(for: 60), 120)
        }

        func testResolvedSamplesPerSecond_fps120_clampedToMax() {
            XCTAssertEqual(RecordingMouseTracker.resolvedSamplesPerSecond(for: 120), 120)
        }

        func testInit_samplesPerSecond_matchesResolved() {
            let tracker = makeTracker()
            XCTAssertEqual(tracker.samplesPerSecond, 60)
        }

        func testStartStop_returnsSamples() {
            let clock = TestClock()
            let tracker = makeTracker(clock: clock)

            tracker.start()
            clock.uptime += 0.02
            let result = tracker.stop()
            XCTAssertGreaterThanOrEqual(result.samples.count, 2)
            XCTAssertEqual(result.samples.first?.normalizedX, 0.5)
            XCTAssertEqual(result.samples.first?.normalizedY, 0.5)
            tracker.reset()
        }

        func testPressCapture_recordsMouseDownInsideRect() {
            let clock = TestClock()
            var capturedEvents: [NSEvent] = []
            let tracker = RecordingMouseTracker(
                recordingRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                fps: 30,
                uptimeProvider: { clock.uptime },
                mouseLocationProvider: { CGPoint(x: 50, y: 50) },
                mouseMonitorInstaller: { _ in TestMouseMonitor() },
                mouseMonitorRemover: { _ in },
                pressMonitorInstaller: { handler in
                    let event = NSEvent.mouseEvent(
                        with: .leftMouseDown,
                        location: CGPoint(x: 50, y: 50),
                        modifierFlags: [],
                        timestamp: 0,
                        windowNumber: 0,
                        context: nil,
                        eventNumber: 0,
                        clickCount: 1,
                        pressure: 0,
                    )!
                    capturedEvents.append(event)
                    handler(event)
                    return TestMouseMonitor()
                },
                pressMonitorRemover: { _ in },
            )

            tracker.start()
            clock.uptime += 0.02
            let result = tracker.stop()
            XCTAssertEqual(result.presses.count, 1)
            XCTAssertEqual(result.presses.first?.phase, .down)
            XCTAssertEqual(result.presses.first?.button, 0)
            tracker.reset()
        }

        func testReset_clearsSamples() {
            let clock = TestClock()
            let tracker = makeTracker(clock: clock)

            tracker.start()
            clock.uptime += 0.02
            _ = tracker.stop()
            XCTAssertNotNil(tracker.diagnostics)

            tracker.reset()
            XCTAssertNil(tracker.diagnostics)
        }

        @MainActor
        private func makeTracker() -> RecordingMouseTracker {
            makeTracker(clock: TestClock())
        }

        @MainActor
        private func makeTracker(clock: TestClock) -> RecordingMouseTracker {
            RecordingMouseTracker(
                recordingRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                fps: 30,
                uptimeProvider: { clock.uptime },
                mouseLocationProvider: { CGPoint(x: 50, y: 50) },
                mouseMonitorInstaller: { _ in TestMouseMonitor() },
                mouseMonitorRemover: { _ in },
            )
        }
    }

    private final class TestClock {
        var uptime: TimeInterval = 100
    }

    private final class TestMouseMonitor {}
#endif
