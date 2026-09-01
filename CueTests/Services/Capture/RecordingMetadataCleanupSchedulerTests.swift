#if CUE_VIDEO_MODULE
//
    //  RecordingMetadataCleanupSchedulerTests.swift
    //  NotinhasTests
//
    //  Unit tests for RecordingMetadataCleanupScheduler lifecycle.
//

    @testable import Cue
    import XCTest

    @MainActor
    final class RecordingMetadataCleanupSchedulerTests: XCTestCase {
        private var scheduler: RecordingMetadataCleanupScheduler!

        override func setUp() {
            super.setUp()
            scheduler = RecordingMetadataCleanupScheduler.shared
            scheduler.stop()
        }

        override func tearDown() {
            scheduler.stop()
            super.tearDown()
        }

        func testStart_createsTimer() {
            scheduler.start()
            // Timer is private, but start() should not crash
        }

        func testStop_invalidatesTimer() {
            scheduler.start()
            scheduler.stop()
            // stop() should not crash; timer invalidated
        }

        func testStartStopLifecycle() {
            scheduler.start()
            scheduler.stop()
            scheduler.start()
            scheduler.stop()
        }
    }
#endif
