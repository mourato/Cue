//
//  AnnotateBuiltInColorPaletteTests.swift
//  NotinhasTests
//
//  Shared annotate + Notes built-in palette merge rules.
//

@testable import Notinhas
import XCTest

@MainActor
final class AnnotateBuiltInColorPaletteTests: XCTestCase {
    func testAnnotationPaletteIncludesEveryNotinhasPaletteColor() {
        for paletteColor in NotinhasPaletteColor.allCases {
            let match = AnnotateBuiltInColorPalette.annotationEntries.contains {
                colorsMatch($0.rgba, paletteColor.rgba)
            }
            XCTAssertTrue(match, "Missing Notes color \(paletteColor.rawValue)")
        }
    }

    func testNamedOverlapsPreferNotinhasHexValues() {
        XCTAssertEqual(hex(of: .red), "#D93530")
        XCTAssertEqual(hex(of: .orange), "#ED8413")
        XCTAssertEqual(hex(of: .blue), "#0076DE")
        XCTAssertEqual(hex(of: .green), "#5EDBA7")
        XCTAssertEqual(hex(of: .purple), "#9747FF")
        XCTAssertEqual(hex(of: .black), "#212121")
    }

    func testAnnotationPaletteKeepsAnnotateOnlyExtras() {
        XCTAssertTrue(contains(id: "yellow"))
        XCTAssertTrue(contains(id: "white"))
        XCTAssertTrue(contains(id: "pink"))
        XCTAssertTrue(contains(id: "gray"))
        XCTAssertTrue(contains(id: NotinhasPaletteColor.magenta.rawValue))
    }

    func testAnnotationPaletteHasNoDuplicateRGB() {
        let values = AnnotateBuiltInColorPalette.annotationEntries.map(\.rgba)
        for (index, value) in values.enumerated() {
            for other in values[(index + 1)...] {
                XCTAssertFalse(
                    colorsMatch(value, other),
                    "Duplicate RGB in annotation palette",
                )
            }
        }
    }

    func testFillColorsPrefixClearThenAnnotationSolids() {
        let fill = AnnotateBuiltInColorPalette.fillColors
        XCTAssertFalse(fill.isEmpty)
        XCTAssertTrue(AnnotateColorPaletteStore.isClear(fill[0]))
        XCTAssertEqual(fill.count, AnnotateBuiltInColorPalette.annotationColors.count + 1)
    }

    func testCanvasPaletteExtendsAnnotationSet() {
        for entry in AnnotateBuiltInColorPalette.annotationEntries {
            XCTAssertTrue(
                AnnotateBuiltInColorPalette.canvasEntries.contains { $0.id == entry.id },
                "Canvas missing annotation entry \(entry.id)",
            )
        }
        XCTAssertTrue(AnnotateBuiltInColorPalette.canvasEntries.contains { $0.id == "darkGray" })
        XCTAssertTrue(AnnotateBuiltInColorPalette.canvasEntries.contains { $0.id == "nearWhite" })
    }

    private func contains(id: String) -> Bool {
        AnnotateBuiltInColorPalette.annotationEntries.contains { $0.id == id }
    }

    private func hex(of paletteColor: NotinhasPaletteColor) -> String {
        let entry = AnnotateBuiltInColorPalette.annotationEntries.first {
            $0.id == paletteColor.rawValue
        }
        XCTAssertNotNil(entry)
        return rgbaHex(entry!.rgba)
    }

    private func colorsMatch(_ lhs: RGBAColor, _ rhs: RGBAColor) -> Bool {
        abs(lhs.red - rhs.red) < 0.001
            && abs(lhs.green - rhs.green) < 0.001
            && abs(lhs.blue - rhs.blue) < 0.001
            && abs(lhs.alpha - rhs.alpha) < 0.001
    }

    private func rgbaHex(_ color: RGBAColor) -> String {
        String(
            format: "#%02X%02X%02X",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded()),
        )
    }
}
