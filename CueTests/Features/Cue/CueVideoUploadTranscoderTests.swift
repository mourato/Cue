import AVFoundation
import CoreVideo
@testable import Cue
import XCTest

@MainActor
final class CueVideoUploadTranscoderTests: XCTestCase {
    func testPrepareCreatesVerifiedMP4AndPreservesSource() async throws {
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueVideoTranscoder-\(UUID().uuidString).mov")
        try await makeTestVideo(at: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let originalData = try Data(contentsOf: sourceURL)

        let prepared = try await CueVideoUploadTranscoder.prepare(
            sourceURL: sourceURL,
            maximumBytes: 5 * 1_048_576,
            settings: CueVideoUploadSettings(
                maximumDimension: 320,
                quality: .compact,
                frameRate: 24,
                includesAudio: false,
            ),
        )
        defer { prepared.cleanup() }

        XCTAssertTrue(prepared.isTemporary)
        XCTAssertEqual(prepared.url.pathExtension, "mp4")
        XCTAssertLessThanOrEqual(
            try XCTUnwrap(prepared.url.resourceValues(forKeys: [.fileSizeKey]).fileSize),
            5 * 1_048_576,
        )
        XCTAssertGreaterThan(try Data(contentsOf: prepared.url).count, 0)
        let outputAsset = AVURLAsset(url: prepared.url)
        let outputTracks = try await outputAsset.loadTracks(withMediaType: .video)
        let outputTrack = try XCTUnwrap(outputTracks.first)
        let outputSize = try await outputTrack.load(.naturalSize)
        XCTAssertLessThanOrEqual(max(outputSize.width, outputSize.height), 320)
        let outputAudioTracks = try await outputAsset.loadTracks(withMediaType: .audio)
        XCTAssertTrue(outputAudioTracks.isEmpty)
        XCTAssertEqual(try Data(contentsOf: sourceURL), originalData)
    }

    private func makeTestVideo(at url: URL) async throws {
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
        while !input.isReadyForMoreMediaData {
            await Task.yield()
        }
        XCTAssertTrue(try adaptor.append(XCTUnwrap(pixelBuffer), withPresentationTime: .zero))
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
    }
}
