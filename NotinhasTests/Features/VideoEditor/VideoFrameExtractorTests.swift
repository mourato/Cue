#if NOTINHAS_VIDEO_MODULE
    import AVFoundation
    import CoreVideo
    import ImageIO
    @testable import Notinhas
    import XCTest

    final class VideoFrameExtractorTests: XCTestCase {
        func testClampTime_enforcesPositiveFiniteAssetDuration() {
            XCTAssertEqual(VideoFrameExtractor.clampTime(0, duration: 4), 0)
            XCTAssertEqual(VideoFrameExtractor.clampTime(-2, duration: 4), 0)
            XCTAssertEqual(VideoFrameExtractor.clampTime(4, duration: 4), 4)
            XCTAssertEqual(VideoFrameExtractor.clampTime(9, duration: 4), 4)
            XCTAssertNil(VideoFrameExtractor.clampTime(.nan, duration: 4))
            XCTAssertNil(VideoFrameExtractor.clampTime(.infinity, duration: 4))
            XCTAssertNil(VideoFrameExtractor.clampTime(1, duration: .infinity))
            XCTAssertNil(VideoFrameExtractor.clampTime(1, duration: 0))
        }

        @MainActor
        func testGIFState_hidesFrameExtractionAndStartsIdle() {
            let state = VideoEditorState(url: URL(fileURLWithPath: "/tmp/capture.gif"))

            XCTAssertTrue(state.isGIF)
            XCTAssertFalse(state.isExtractingFrame)
            XCTAssertFalse(state.isExtractingFrames)
        }

        func testExtraction_writesNonEmptyPNGAndUsesFrameName() async throws {
            let root = try makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let sourceURL = root.appendingPathComponent("fixture.mov")
            try await makeVideo(at: sourceURL)

            let result = try await VideoFrameExtractor.extract(
                request: VideoFrameExtractionRequest(
                    sourceURL: sourceURL,
                    requestedTime: 0,
                    assetDuration: 1,
                    baseName: "fixture",
                ),
                outputRoot: root.appendingPathComponent("frames"),
            )

            XCTAssertEqual(result.url.deletingPathExtension().lastPathComponent, "fixture-frame")
            XCTAssertGreaterThan(try Data(contentsOf: result.url).count, 0)
            XCTAssertNotNil(CGImageSourceCreateWithURL(result.url as CFURL, nil))
        }

        func testExtraction_failureRemovesPartialOutput() async throws {
            let root = try makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let outputRoot = root.appendingPathComponent("frames")
            let request = VideoFrameExtractionRequest(
                sourceURL: root.appendingPathComponent("missing.mov"),
                requestedTime: 0,
                assetDuration: 1,
                baseName: "missing",
            )

            await XCTAssertThrowsErrorAsync {
                _ = try await VideoFrameExtractor.extract(request: request, outputRoot: outputRoot)
            }

            XCTAssertFalse(FileManager.default
                .fileExists(atPath: outputRoot.appendingPathComponent("missing-frame.png").path))
        }

        private func makeTemporaryDirectory() throws -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("NotinhasTests_FrameExtractor_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        private func makeVideo(at url: URL) async throws {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 16,
                AVVideoHeightKey: 16,
            ])
            writer.add(input)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: 16,
                    kCVPixelBufferHeightKey as String: 16,
                ],
            )
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
            while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                await Task.yield()
            }
            XCTAssertTrue(try adaptor.append(XCTUnwrap(pixelBuffer), withPresentationTime: .zero))
            input.markAsFinished()
            await writer.finishWriting()
            XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
        }
    }

    private extension XCTestCase {
        func XCTAssertThrowsErrorAsync(_ expression: @escaping () async throws -> Void) async {
            do {
                try await expression()
                XCTFail("Expected an error")
            } catch {}
        }
    }
#endif
