//
//  OCRExecutionTests.swift
//  NotinhasTests
//
//  Behavior coverage for the OCR execution boundary and launch prewarm.
//

@testable import Cue
import Dispatch
import XCTest

@MainActor
final class OCRExecutionTests: XCTestCase {
    func testRecognition_completesWhileMainActorIsBlocked() async throws {
        let service = OCRService()
        let image = try OCRTestImageRenderer.renderImage(text: "Cue execution boundary")
        let recognitionFinished = DispatchSemaphore(value: 0)

        // Detached so the recognition task itself never inherits the test's
        // main-actor isolation; only the OCR service boundary is under test.
        let recognitionTask = Task.detached(priority: .userInitiated) { () -> String? in
            let text = try? await service.recognizeText(from: image)
            recognitionFinished.signal()
            return text
        }

        // Occupy the main actor while recognition runs: recognition that needs
        // the main actor cannot finish until this wait times out. The 30s
        // bound only fails the test, it is not a latency guarantee for ANE.
        let recognizedInTime = waitForRecognitionSignal(recognitionFinished, timeoutSeconds: 30)

        XCTAssertTrue(
            recognizedInTime,
            "OCR finished only after the main actor was released; heavy recognition runs on the main actor"
        )

        guard let text = await recognitionTask.value else {
            return XCTFail("OCR recognition failed while checking the execution boundary")
        }
        XCTAssertTrue(text.localizedStandardContains("cue"), text)
    }

    /// `DispatchSemaphore.wait` is `noasync`, so the blocking wait lives in a
    /// synchronous helper; calling it from the test holds the main actor.
    private nonisolated func waitForRecognitionSignal(
        _ semaphore: DispatchSemaphore,
        timeoutSeconds: Int
    ) -> Bool {
        if case .success = semaphore.wait(timeout: .now() + .seconds(timeoutSeconds)) {
            return true
        }
        return false
    }

    func testPrewarm_overlappingCalls_runOnlyOneInitialAttempt() async {
        let service = OCRService()

        async let first = service.prewarm(preferredLanguageIdentifier: nil)
        async let second = service.prewarm(preferredLanguageIdentifier: nil)
        let firstOutcome = await first
        let secondOutcome = await second
        let outcomes = [firstOutcome, secondOutcome]

        // The warmup request itself is fail-soft, so its outcome may be
        // .succeeded or .failed depending on the environment; the contract is
        // that exactly one call makes an attempt and the other is rejected.
        XCTAssertEqual(
            outcomes.filter { $0 != .alreadyPrewarmed }.count,
            1,
            "overlapping prewarm calls must start exactly one initial attempt"
        )
        XCTAssertEqual(
            outcomes.filter { $0 == .alreadyPrewarmed }.count,
            1,
            "the remaining overlapping call must observe the once-only guard"
        )
    }

    func testPrewarm_doesNotDisableSubsequentRecognition() async throws {
        let service = OCRService()

        let prewarm = await service.prewarm(preferredLanguageIdentifier: "en")
        // Warmup success is environment-dependent and fail-soft; only a
        // skipped warmup would mean the attempt never happened here.
        XCTAssertNotEqual(
            prewarm,
            .alreadyPrewarmed,
            "the test-owned service must perform its initial warmup attempt"
        )

        let text = try await service.recognizeText(
            from: OCRTestImageRenderer.renderImage(text: "Cue after prewarm")
        )

        XCTAssertTrue(text.localizedStandardContains("cue"), text)
    }
}
