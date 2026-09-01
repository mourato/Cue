//
//  AnnotationStrokeWidthTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

final class AnnotationStrokeWidthTests: XCTestCase {
    func testPresetsMatchScreendropInspectorWidths() {
        XCTAssertEqual(
            AnnotationStrokeWidth.allCases.map(\.points),
            [2, 4, 6, 8, 12],
        )
        XCTAssertEqual(AnnotationStrokeWidth.default, .regular)
    }

    func testNearestSnapsLegacyValuesOntoPresets() {
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 1), .thin)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 3), .thin)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 5), .regular)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 7), .medium)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 9), .thick)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 11), .heavy)
        XCTAssertEqual(AnnotationStrokeWidth.nearest(to: 20), .heavy)
    }

    func testClampedControlValueUsesStrokeWidthPresets() {
        XCTAssertEqual(AnnotationProperties.clampedControlValue(3), AnnotationStrokeWidth.thin.points)
        XCTAssertEqual(AnnotationProperties.clampedControlValue(9), AnnotationStrokeWidth.thick.points)
        XCTAssertEqual(AnnotationProperties.clampedControlValue(11), AnnotationStrokeWidth.heavy.points)
    }
}
