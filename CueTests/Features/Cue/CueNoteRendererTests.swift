import AppKit
@testable import Cue
import XCTest

final class CueNoteRendererTests: XCTestCase {
    func testDrawPointTargetRendersBadgeFill() {
        let width = 100
        let height = 100
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0,
        ) else {
            XCTFail("Expected bitmap representation")
            return
        }
        bitmap.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            XCTFail("Expected graphics context")
            return
        }
        NSGraphicsContext.current = graphicsContext

        let center = CGPoint(x: 50, y: 50)
        CueNoteRenderer.drawPointTarget(
            center: center,
            color: .red,
            displayNumber: 1,
            isSelected: false,
            in: graphicsContext.cgContext,
        )
        NSGraphicsContext.restoreGraphicsState()

        let sampleX = Int(center.x + CueNoteRenderer.defaultPinRadius * 0.6)
        let sampleY = Int(center.y)
        guard let color = bitmap.colorAt(x: sampleX, y: sampleY) else {
            XCTFail("Expected color at sample point")
            return
        }

        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        XCTAssertGreaterThan(rgb.redComponent, 0.8)
        XCTAssertLessThan(rgb.greenComponent, 0.3)
        XCTAssertLessThan(rgb.blueComponent, 0.3)
    }
}
