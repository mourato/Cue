#if CUE_VIDEO_MODULE
//
    //  GIFProcessingTests.swift
    //  NotinhasTests
//
    //  Unit tests for GIF frame planning (duplicate collapse) and palette quantization.
//

    import CoreGraphics
    @testable import Cue
    import XCTest

    final class GIFProcessingTests: XCTestCase {
        func testPaletteColorCount_mapsQualityRange() {
            XCTAssertEqual(GIFPaletteQuantizer.colorCount(for: 1.0), 256)
            XCTAssertEqual(GIFPaletteQuantizer.colorCount(for: 2.0), 256)
            XCTAssertEqual(GIFPaletteQuantizer.colorCount(for: 0.75), 178)
            XCTAssertEqual(GIFPaletteQuantizer.colorCount(for: 0.1), 16)
            XCTAssertEqual(GIFPaletteQuantizer.colorCount(for: 0.0), 16)
        }

        func testCollapse_extendsDelayForConsecutiveDuplicates() {
            let (indices, delays) = GIFFramePlan.collapse(
                hashes: [1, 1, 2, 2, 2, 3],
                frameDelay: 0.1,
            )

            XCTAssertEqual(indices, [0, 2, 5])
            XCTAssertEqual(delays.count, 3)
            XCTAssertEqual(delays[0], 0.2, accuracy: 0.0001)
            XCTAssertEqual(delays[1], 0.3, accuracy: 0.0001)
            XCTAssertEqual(delays[2], 0.1, accuracy: 0.0001)
        }

        func testCollapse_handlesEmptyAndUniformInput() {
            let empty = GIFFramePlan.collapse(hashes: [], frameDelay: 0.1)
            XCTAssertTrue(empty.indices.isEmpty)
            XCTAssertTrue(empty.delays.isEmpty)

            let uniform = GIFFramePlan.collapse(hashes: [7, 7, 7], frameDelay: 0.1)
            XCTAssertEqual(uniform.indices, [0])
            XCTAssertEqual(uniform.delays.count, 1)
            XCTAssertEqual(uniform.delays[0], 0.3, accuracy: 0.0001)
        }

        func testThumbnailHash_matchesIdenticalImagesOnly() throws {
            let red = try solidImage(red: 255, green: 0, blue: 0)
            let redAgain = try solidImage(red: 255, green: 0, blue: 0)
            let blue = try solidImage(red: 0, green: 0, blue: 255)

            XCTAssertEqual(
                GIFFramePlan.thumbnailHash(red),
                GIFFramePlan.thumbnailHash(redAgain),
            )
            XCTAssertNotEqual(
                GIFFramePlan.thumbnailHash(red),
                GIFFramePlan.thumbnailHash(blue),
            )
        }

        func testQuantize_preservesTwoColorImageWithinBudget() throws {
            let image = try halfSplitImage(
                left: (255, 0, 0),
                right: (0, 0, 255),
                width: 64,
                height: 64,
            )
            let quantized = try XCTUnwrap(GIFPaletteQuantizer.quantize(image, maxColors: 2))

            XCTAssertEqual(quantized.width, 64)
            XCTAssertEqual(quantized.height, 64)
            XCTAssertLessThanOrEqual(try distinctColorCount(of: quantized), 2)
        }

        func testQuantize_reducesGradientToBudget() throws {
            let image = try horizontalGradientImage(width: 256, height: 16)
            let quantized = try XCTUnwrap(GIFPaletteQuantizer.quantize(image, maxColors: 16))

            XCTAssertEqual(quantized.width, 256)
            XCTAssertEqual(quantized.height, 16)
            XCTAssertLessThanOrEqual(try distinctColorCount(of: quantized), 16)
        }

        func testProcess_withoutOptimizeKeepsAllFrames() throws {
            let red = try solidImage(red: 255, green: 0, blue: 0)
            var options = GIFConverter.Options()
            options.fps = 10
            options.optimize = false
            options.quality = 1.0

            let planned = GIFFramePlan.process(frames: [red, red, red], options: options)

            XCTAssertEqual(planned.images.count, 3)
            XCTAssertEqual(planned.delays, [0.1, 0.1, 0.1])
        }

        func testProcess_withOptimizeCollapsesDuplicates() throws {
            let red = try solidImage(red: 255, green: 0, blue: 0)
            let blue = try solidImage(red: 0, green: 0, blue: 255)
            var options = GIFConverter.Options()
            options.fps = 10
            options.optimize = true
            options.quality = 1.0

            let planned = GIFFramePlan.process(frames: [red, red, blue], options: options)

            XCTAssertEqual(planned.images.count, 2)
            XCTAssertEqual(planned.delays.count, 2)
            XCTAssertEqual(planned.delays[0], 0.2, accuracy: 0.0001)
            XCTAssertEqual(planned.delays[1], 0.1, accuracy: 0.0001)
        }

        // MARK: - Synthetic images

        private func solidImage(red: UInt8, green: UInt8, blue: UInt8, size: Int = 32) throws -> CGImage {
            let pixels = [UInt8](repeating: 0, count: size * size * 4)
            var mutable = pixels
            for i in stride(from: 0, to: mutable.count, by: 4) {
                mutable[i] = red
                mutable[i + 1] = green
                mutable[i + 2] = blue
                mutable[i + 3] = 255
            }
            return try imageFromRGBA(width: size, height: size, pixels: mutable)
        }

        private func halfSplitImage(
            left: (UInt8, UInt8, UInt8),
            right: (UInt8, UInt8, UInt8),
            width: Int,
            height: Int,
        ) throws -> CGImage {
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let base = (y * width + x) * 4
                    let color = x < width / 2 ? left : right
                    pixels[base] = color.0
                    pixels[base + 1] = color.1
                    pixels[base + 2] = color.2
                }
            }
            return try imageFromRGBA(width: width, height: height, pixels: pixels)
        }

        private func horizontalGradientImage(width: Int, height: Int) throws -> CGImage {
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let base = (y * width + x) * 4
                    let value = UInt8(x * 255 / max(width - 1, 1))
                    pixels[base] = value
                    pixels[base + 1] = value
                    pixels[base + 2] = value
                }
            }
            return try imageFromRGBA(width: width, height: height, pixels: pixels)
        }

        private func imageFromRGBA(width: Int, height: Int, pixels: [UInt8]) throws -> CGImage {
            let data = Data(pixels)
            let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
            return try XCTUnwrap(CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent,
            ))
        }

        private func distinctColorCount(of image: CGImage) throws -> Int {
            let width = image.width
            let height = image.height
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            ), let data = context.data else {
                throw XCTSkip("Cannot read test image pixels")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var colors = Set<Int>()
            let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
            for i in stride(from: 0, to: width * height * 4, by: 4) {
                colors.insert(Int(bytes[i]) << 16 | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]))
            }
            return colors.count
        }
    }
#endif
