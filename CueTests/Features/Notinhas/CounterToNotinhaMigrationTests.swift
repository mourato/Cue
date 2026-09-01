//
//  CounterToNotinhaMigrationTests.swift
//  NotinhasTests
//

@testable import Cue
import SwiftUI
import XCTest

final class CounterToNotinhaMigrationTests: XCTestCase {
    func testMigrate_noCounters_isIdempotent() {
        let annotations = [
            AnnotationItem(type: .rectangle, bounds: CGRect(x: 0, y: 0, width: 10, height: 10), properties: .init()),
        ]
        let existing = makeNote(order: 1, center: CGPoint(x: 20, y: 20))

        let result = CounterToNotinhaMigration.migrate(annotations: annotations, notinhasNotes: [existing])

        XCTAssertFalse(result.didMigrate)
        XCTAssertEqual(result.annotations, annotations)
        XCTAssertEqual(result.notinhasNotes, [existing])
    }

    func testMigrate_convertsCountersAndAppendsAfterExistingNotes() {
        let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        let existing = makeNote(order: 3, center: CGPoint(x: 5, y: 5), color: red)
        let firstCounter = AnnotationItem(
            type: .counter(9),
            bounds: CGRect(x: 38, y: 48, width: 24, height: 24),
            properties: AnnotationProperties(strokeColor: .blue, strokeWidth: 6),
        )
        let secondCounter = AnnotationItem(
            type: .counter(2),
            bounds: CGRect(x: 100, y: 120, width: 16, height: 16),
            properties: AnnotationProperties(strokeColor: .green, strokeWidth: 4),
        )
        let rectangle = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 0, y: 0, width: 40, height: 40),
            properties: .init(),
        )

        let result = CounterToNotinhaMigration.migrate(
            annotations: [rectangle, firstCounter, secondCounter],
            notinhasNotes: [existing],
        )

        XCTAssertTrue(result.didMigrate)
        XCTAssertEqual(result.annotations, [rectangle])
        XCTAssertEqual(result.notinhasNotes.count, 3)
        XCTAssertEqual(result.notinhasNotes[0].creationOrder, 3)

        let migratedFirst = result.notinhasNotes[1]
        XCTAssertEqual(migratedFirst.text, "")
        XCTAssertEqual(migratedFirst.creationOrder, 4)
        XCTAssertEqual(migratedFirst.pinControlValue, 6)
        XCTAssertEqual(migratedFirst.color, RGBAColor(color: .blue))
        guard case .point(let center) = migratedFirst.target else {
            return XCTFail("Expected point target")
        }
        XCTAssertEqual(center.x, 50, accuracy: 0.001)
        XCTAssertEqual(center.y, 60, accuracy: 0.001)

        let migratedSecond = result.notinhasNotes[2]
        XCTAssertEqual(migratedSecond.creationOrder, 5)
        XCTAssertEqual(migratedSecond.pinControlValue, 4)
        XCTAssertEqual(migratedSecond.color, RGBAColor(color: .green))
        guard case .point(let secondCenter) = migratedSecond.target else {
            return XCTFail("Expected point target")
        }
        XCTAssertEqual(secondCenter.x, 108, accuracy: 0.001)
        XCTAssertEqual(secondCenter.y, 128, accuracy: 0.001)
    }

    func testMigrate_secondRun_isIdempotent() {
        let counter = AnnotationItem(
            type: .counter(1),
            bounds: CGRect(x: 10, y: 10, width: 20, height: 20),
            properties: AnnotationProperties(strokeColor: .red, strokeWidth: 3),
        )
        let first = CounterToNotinhaMigration.migrate(annotations: [counter], notinhasNotes: [])
        let second = CounterToNotinhaMigration.migrate(
            annotations: first.annotations,
            notinhasNotes: first.notinhasNotes,
        )

        XCTAssertTrue(first.didMigrate)
        XCTAssertFalse(second.didMigrate)
        XCTAssertEqual(second.annotations, first.annotations)
        XCTAssertEqual(second.notinhasNotes, first.notinhasNotes)
    }

    @MainActor
    func testAnnotateState_migrateLegacyCountersToNotinhasIfNeeded() {
        let state = AnnotateState()
        state.annotations = [
            AnnotationItem(
                type: .counter(7),
                bounds: CGRect(x: 0, y: 0, width: 24, height: 24),
                properties: AnnotationProperties(strokeColor: .orange, strokeWidth: 5),
            ),
        ]

        state.migrateLegacyCountersToNotinhasIfNeeded()

        XCTAssertTrue(state.annotations.isEmpty)
        XCTAssertEqual(state.notinhasNotes.count, 1)
        XCTAssertEqual(state.notinhasNotes[0].creationOrder, 1)
        XCTAssertTrue(state.hasUnsavedChanges)
    }

    private func makeNote(order: Int, center: CGPoint, color: RGBAColor? = nil) -> NotinhasVisualNote {
        NotinhasVisualNote(
            target: .point(center),
            color: color ?? RGBAColor(red: 0, green: 0, blue: 1, alpha: 1),
            creationOrder: order,
        )
    }
}
