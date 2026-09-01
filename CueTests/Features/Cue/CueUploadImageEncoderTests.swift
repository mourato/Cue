import AppKit
import ImageIO
@testable import Cue
import XCTest

@MainActor
final class CueUploadImageEncoderTests: XCTestCase {
    func testEncodeLimitsPhysicalPixelDimension() throws {
        let imageData = try XCTUnwrap(makeTestImage(hasAlpha: true).tiffRepresentation)
        let settings = CueUploadEncodingSettings(
            optimizeImages: true,
            imageFormat: .png,
            maximumDimension: 2048,
            jpegQuality: 0.9,
        )

        let encoded = try CueUploadImageEncoder.encode(imageData: imageData, settings: settings)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded.data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(encoded.fileExtension, "png")
        XCTAssertLessThanOrEqual(max(image.width, image.height), 2048)
        XCTAssertEqual(image.width, 2048)
    }

    func testJPEGQualityUsesJPEGEncodingForOpaqueImages() throws {
        let imageData = try XCTUnwrap(makeTestImage(hasAlpha: false).tiffRepresentation)
        let settings = CueUploadEncodingSettings(
            optimizeImages: true,
            imageFormat: .jpeg,
            maximumDimension: 2048,
            jpegQuality: 0.73,
        )

        let encoded = try CueUploadImageEncoder.encode(imageData: imageData, settings: settings)

        XCTAssertEqual(encoded.fileExtension, "jpg")
        XCTAssertEqual(encoded.contentType, "image/jpeg")
        XCTAssertFalse(encoded.data.isEmpty)
    }

    func testDisabledOptimizationKeepsPhysicalDimensionsAndUsesLosslessPNG() throws {
        let imageData = try XCTUnwrap(makeTestImage(hasAlpha: true).tiffRepresentation)
        let settings = CueUploadEncodingSettings(
            optimizeImages: false,
            imageFormat: .jpeg,
            maximumDimension: 512,
            jpegQuality: 0.5,
        )

        let encoded = try CueUploadImageEncoder.encode(imageData: imageData, settings: settings)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(encoded.data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(encoded.fileExtension, "png")
        XCTAssertEqual(image.width, 4000)
        XCTAssertEqual(image.height, 2000)
    }

    func testPrepareWritesDerivativeWithoutChangingOriginal() async throws {
        let originalData = try XCTUnwrap(makeTestImage(hasAlpha: true).tiffRepresentation)
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotinhasUploadTest-\(UUID().uuidString).tiff")
        try originalData.write(to: sourceURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let settings = CueUploadEncodingSettings(
            optimizeImages: true,
            imageFormat: .webp,
            maximumDimension: 2048,
            jpegQuality: 0.9,
        )
        let prepared = try await CueUploadImageEncoder.prepare(fileURL: sourceURL, settings: settings)
        defer { prepared.cleanup() }

        XCTAssertTrue(prepared.isTemporary)
        XCTAssertNotEqual(prepared.url, sourceURL)
        XCTAssertEqual(
            prepared.url.deletingPathExtension().lastPathComponent,
            sourceURL.deletingPathExtension().lastPathComponent,
        )
        XCTAssertEqual(prepared.url.pathExtension, "webp")
        XCTAssertEqual(try Data(contentsOf: sourceURL), originalData)

        prepared.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: prepared.url.path))
    }

    private func makeTestImage(hasAlpha: Bool) throws -> NSImage {
        let image = NSImage(size: NSSize(width: 2000, height: 1000))
        let representation = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 4000,
                pixelsHigh: 2000,
                bitsPerSample: 8,
                samplesPerPixel: hasAlpha ? 4 : 3,
                hasAlpha: hasAlpha,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bitmapFormat: [],
                bytesPerRow: 0,
                bitsPerPixel: 0,
            ),
        )
        image.addRepresentation(representation)
        return image
    }
}
