//
//  AreaSelectionBackdropCapturer.swift
//  Notinhas
//
//  Seam for area-selection backdrop grabs (magnifier / luma). Production uses
//  ScreenCaptureKit; XCTest hosts default to a synthetic image so the
//  suite does not trigger Screen Recording TCC for com.mourato.notinhas.debug.
//

import CoreGraphics
import CoreVideo
import Foundation
@preconcurrency import ScreenCaptureKit

/// Captures an on-screen backdrop for area-selection magnifier / luma paths.
protocol AreaSelectionBackdropCapturing: Sendable {
    func captureBackdrop(
        displayID: CGDirectDisplayID,
        captureRect: CGRect,
        scaleFactor: CGFloat,
        isVisible: Bool,
    ) async -> AreaSelectionBackdrop?
}

/// Production capturer — requires Screen Recording permission when run.
struct LiveAreaSelectionBackdropCapturer: AreaSelectionBackdropCapturing {
    func captureBackdrop(
        displayID: CGDirectDisplayID,
        captureRect _: CGRect,
        scaleFactor: CGFloat,
        isVisible: Bool,
    ) async -> AreaSelectionBackdrop? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == Int(displayID) }) else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let pointPixelScale = CGFloat(filter.pointPixelScale)
            let pixelScale = scaleFactor > 0
                ? scaleFactor
                : (pointPixelScale > 0 ? pointPixelScale : 2.0)

            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int((display.frame.width * pixelScale).rounded()))
            configuration.height = max(1, Int((display.frame.height * pixelScale).rounded()))
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false
            configuration.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration,
            )
            return AreaSelectionBackdrop(
                displayID: displayID,
                image: image,
                scaleFactor: pixelScale,
                isVisible: isVisible,
            )
        } catch {
            return nil
        }
    }
}

/// Test/host capturer — never touches screen-capture APIs.
struct SyntheticAreaSelectionBackdropCapturer: AreaSelectionBackdropCapturing {
    /// Fixed pixel size keeps synthetic images cheap regardless of display bounds.
    var pixelSize: Int = 64

    func captureBackdrop(
        displayID: CGDirectDisplayID,
        captureRect _: CGRect,
        scaleFactor: CGFloat,
        isVisible: Bool,
    ) async -> AreaSelectionBackdrop? {
        let dimension = max(1, pixelSize)
        guard let image = Self.makeSolidImage(width: dimension, height: dimension) else {
            return nil
        }
        return AreaSelectionBackdrop(
            displayID: displayID,
            image: image,
            scaleFactor: scaleFactor,
            isVisible: isVisible,
        )
    }

    private static func makeSolidImage(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            pixels[offset] = 40
            pixels[offset + 1] = 40
            pixels[offset + 2] = 40
            pixels[offset + 3] = 255
        }

        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )
    }
}

enum AreaSelectionBackdropCapturerPolicy {
    static let allowScreenCaptureInTestsEnvironmentKey = "CUE_ALLOW_SCREEN_CAPTURE_IN_TESTS"

    /// Live capturer outside XCTest; synthetic under XCTest unless explicitly opted in.
    static func makeDefault(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        xctestRuntimePresent: () -> Bool = { NSClassFromString("XCTestCase") != nil },
    ) -> any AreaSelectionBackdropCapturing {
        if shouldUseLiveCapturer(environment: environment, xctestRuntimePresent: xctestRuntimePresent) {
            return LiveAreaSelectionBackdropCapturer()
        }
        return SyntheticAreaSelectionBackdropCapturer()
    }

    static func shouldUseLiveCapturer(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        xctestRuntimePresent: () -> Bool = { NSClassFromString("XCTestCase") != nil },
    ) -> Bool {
        let underXCTest = environment["XCTestConfigurationFilePath"] != nil || xctestRuntimePresent()
        guard underXCTest else { return true }
        return environment[allowScreenCaptureInTestsEnvironmentKey] == "1"
    }
}
