//
//  AnnotationShapeFillStyleMigrationTests.swift
//  NotinhasTests
//
//  Persistence migration for filledRectangle → rectangle+solid and oval → circle.
//

@testable import Cue
import XCTest

final class AnnotationShapeFillStyleMigrationTests: XCTestCase {
    func testPersistedFilledRectangleMigratesToRectangleWithSolidFill() throws {
        var persisted = PersistedAnnotationItem(
            item: AnnotationItem(
                type: .rectangle,
                bounds: CGRect(x: 0, y: 0, width: 40, height: 20),
                properties: AnnotationProperties(shapeFillStyle: .outline),
            ),
        )
        persisted.type.kind = .filledRectangle

        let item = try XCTUnwrap(persisted.annotationItem)
        XCTAssertEqual(item.type, .rectangle)
        XCTAssertEqual(item.properties.shapeFillStyle, .solid)
    }

    func testPersistedOvalMigratesToCircle() throws {
        var persisted = PersistedAnnotationItem(
            item: AnnotationItem(
                type: .circle,
                bounds: CGRect(x: 0, y: 0, width: 40, height: 20),
                properties: AnnotationProperties(),
            ),
        )
        persisted.type.kind = .oval

        let item = try XCTUnwrap(persisted.annotationItem)
        XCTAssertEqual(item.type, .circle)
        XCTAssertEqual(item.properties.shapeFillStyle, .outline)
    }

    func testPersistedCircleEncodesAsCircleKind() {
        let item = AnnotationItem(
            type: .circle,
            bounds: CGRect(x: 1, y: 2, width: 3, height: 4),
            properties: AnnotationProperties(shapeFillStyle: .hatched),
        )
        let persisted = PersistedAnnotationItem(item: item)
        XCTAssertEqual(persisted.type.kind, .circle)
        XCTAssertEqual(persisted.properties.shapeFillStyle, AnnotationShapeFillStyle.hatched.rawValue)
    }

    func testNotinhasCasesOmitSolid() {
        XCTAssertFalse(AnnotationShapeFillStyle.notinhasCases.contains(.solid))
        XCTAssertEqual(
            AnnotationShapeFillStyle.notinhasCases,
            [.outline, .tinted, .hatched],
        )
    }
}
