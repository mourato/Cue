import AppKit
@testable import Notinhas
import XCTest

final class NotinhasPaletteColorTests: XCTestCase {
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
        XCTAssertTrue(NotinhasPaletteColor.red.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(NotinhasPaletteColor.orange.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(NotinhasPaletteColor.blue.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(NotinhasPaletteColor.green.numeralColor.isEqual(NSColor.black))
        XCTAssertTrue(NotinhasPaletteColor.purple.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(NotinhasPaletteColor.magenta.numeralColor.isEqual(NSColor.white))
        XCTAssertTrue(NotinhasPaletteColor.black.numeralColor.isEqual(NSColor.white))
    }

    private func rgbaHex(_ color: NotinhasPaletteColor) -> String {
        let rgba = color.rgba
        return String(
            format: "#%02X%02X%02X",
            Int((rgba.red * 255).rounded()),
            Int((rgba.green * 255).rounded()),
            Int((rgba.blue * 255).rounded()),
        )
    }
}
