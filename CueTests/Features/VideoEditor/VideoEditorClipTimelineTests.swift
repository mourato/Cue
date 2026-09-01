#if CUE_VIDEO_MODULE
//
    //  VideoEditorClipTimelineTests.swift
    //  NotinhasTests
//

    import Foundation
    @testable import Cue
    import XCTest

    final class VideoEditorClipTimelineTests: XCTestCase {
        func testFull_singleSegmentCoversSource() {
            let timeline = VideoEditorClipTimeline.full(sourceDuration: 10)
            XCTAssertEqual(timeline.segments.count, 1)
            XCTAssertEqual(timeline.duration, 10, accuracy: 0.001)
            XCTAssertTrue(timeline.isUnedited(sourceDuration: 10))
        }

        func testSplit_createsTwoSegments() {
            var timeline = VideoEditorClipTimeline.full(sourceDuration: 4)
            guard let result = timeline.split(at: 2) else {
                XCTFail("Expected split to succeed")
                return
            }
            timeline = result.timeline
            XCTAssertEqual(timeline.segments.count, 2)
            XCTAssertEqual(result.selectedID, timeline.segments[1].id)
        }

        func testSplit_rejectsTooCloseToEdge() {
            let timeline = VideoEditorClipTimeline.full(sourceDuration: 0.2)
            XCTAssertNil(timeline.split(at: 0.05))
        }

        func testDelete_requiresAtLeastTwoClips() {
            let timeline = VideoEditorClipTimeline.full(sourceDuration: 5)
            XCTAssertNil(timeline.deleting(segmentID: timeline.segments[0].id))
        }

        func testDelete_removesSelectedClip() {
            var timeline = VideoEditorClipTimeline(segments: [
                VideoEditorClipSegment(sourceStart: 0, sourceEnd: 2),
                VideoEditorClipSegment(sourceStart: 2, sourceEnd: 5),
            ])
            let deleteID = timeline.segments[0].id
            guard let next = timeline.deleting(segmentID: deleteID) else {
                XCTFail("Expected delete to succeed")
                return
            }
            timeline = next
            XCTAssertEqual(timeline.segments.count, 1)
            XCTAssertEqual(timeline.segments[0].sourceStart, 2, accuracy: 0.001)
        }

        func testPerClipSpeed_affectsEditorDuration() {
            let timeline = VideoEditorClipTimeline(segments: [
                VideoEditorClipSegment(sourceStart: 0, sourceEnd: 4, speed: 2),
            ])
            XCTAssertEqual(timeline.duration, 2, accuracy: 0.001)
        }

        func testSourceTimeRoundTrip() throws {
            let timeline = VideoEditorClipTimeline(segments: [
                VideoEditorClipSegment(sourceStart: 0, sourceEnd: 2, speed: 1),
                VideoEditorClipSegment(sourceStart: 4, sourceEnd: 6, speed: 2),
            ])
            let editor = timeline.editorTime(forSourceTime: 5)
            XCTAssertNotNil(editor)
            XCTAssertEqual(try timeline.sourceTime(at: XCTUnwrap(editor)), 5, accuracy: 0.001)
        }
    }
#endif
