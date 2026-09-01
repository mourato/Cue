import AppKit
@testable import Cue
import XCTest

final class CuePaletteColorTests: XCTestCase {
    func testFixedPaletteMatchesProductHexValues() {
        XCTAssertEqual(rgbaHex(.red), "#D93530")
        XCTAssertEqual(rgbaHex(.orange), "#ED8413")
        XCTAssertEqual(rgbaHex(.blue), "#0076DE")
        XCTAssertEqual(rgbaHex(.green), "#5EDBA7")
        XCTAssertEqual(rgbaHex(.purple), "#9747FF")
        XCTAssertEqual(rgbaHex(.magenta), "#E8178A")
        XCTAssertEqual(rgbaHex(.black), "#212121")
    }

    func testFixedPaletteUsesExplicitNumeralColors() {
        XCTAssertTrue(CuePaletteColor.red.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(CuePaletteColor.orange.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(CuePaletteColor.blue.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(CuePaletteColor.green.numeralColor.isEqual(NSColor.black))
        XCTAssertTrue(CuePaletteColor.purple.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(CuePaletteColor.magenta.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(CuePaletteColor.black.numeralColor.isEqual(NSColor.white))
    }

    private func rgbaHex(_ color: CuePaletteColor) -> String {
        let rgba = color.rgba
        return String(
            format: "#%02X%02X%02X",
            Int((rgba.red * 255).rounded()),
            Int((rgba.green * 255).rounded()),
            Int((rgba.blue * 255).rounded()),
        )
    }
}
