import CoreGraphics
@testable import Cue
import SwiftUI
import XCTest

final class NotinhasPinSizeTests: XCTestCase {
    private let red = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)

    func testMissingPinControlValueDecodesToLegacyDiameter() throws {
        let original = NotinhasVisualNote(
            text: "Legacy",
            target: .point(CGPoint(x: 10, y: 20)),
            color: red,
            creationOrder: 1,
        )
        var keyed = try XCTUnwrap(try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        keyed.removeValue(forKey: "pinControlValue")
        let data = try JSONSerialization.data(withJSONObject: keyed)
        let decoded = try JSONDecoder().decode(NotinhasVisualNote.self, from: data)
        XCTAssertEqual(decoded.pinDiameter, NotinhasNoteGeometry.pinDiameter, accuracy: 0.001)
    }

    func testMissingAreaStrokeWidthDecodesToDefault() throws {
        let original = NotinhasVisualNote(
            text: "Legacy",
            target: .rect(CGRect(x: 0, y: 0, width: 40, height: 20)),
            color: red,
            areaStrokeWidth: 4,
            creationOrder: 1,
        )
        var keyed = try XCTUnwrap(try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        keyed.removeValue(forKey: "areaStrokeWidth")
        let data = try JSONSerialization.data(withJSONObject: keyed)
        let decoded = try JSONDecoder().decode(NotinhasVisualNote.self, from: data)
        XCTAssertEqual(decoded.areaStrokeWidth, NotinhasVisualNote.defaultAreaStrokeWidth, accuracy: 0.001)
    }

    func testLegacyAreaStrokeWidthSnapsToNearestPreset() throws {
        let original = NotinhasVisualNote(
            text: "Legacy",
            target: .rect(CGRect(x: 0, y: 0, width: 40, height: 20)),
            color: red,
            creationOrder: 1,
        )
        var keyed = try XCTUnwrap(try JSONSerialization
            .jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        keyed["areaStrokeWidth"] = 5
        let data = try JSONSerialization.data(withJSONObject: keyed)
        let decoded = try JSONDecoder().decode(NotinhasVisualNote.self, from: data)

        XCTAssertEqual(decoded.areaStrokeWidth, AnnotationStrokeWidth.regular.points, accuracy: 0.001)
    }

    func testPinDiameterUsesCounterFormula() {
        let note = NotinhasVisualNote(
            text: "Sized",
            target: .point(.zero),
            color: red,
            pinControlValue: 8,
            creationOrder: 1,
        )
        XCTAssertEqual(
            note.pinDiameter,
            AnnotationProperties.counterDiameter(for: 8),
            accuracy: 0.001,
        )
    }

    func testHitTestRespectsPerNoteDiameter() {
        let small = NotinhasVisualNote(
            text: "Small",
            target: .point(CGPoint(x: 50, y: 50)),
            color: red,
            pinControlValue: 2,
            creationOrder: 1,
        )
        let large = NotinhasVisualNote(
            text: "Large",
            target: .point(CGPoint(x: 50, y: 50)),
            color: red,
            pinControlValue: 10,
            creationOrder: 2,
        )
        let probe = CGPoint(x: 70, y: 50)

        XCTAssertFalse(NotinhasNoteGeometry.hitTest(note: small, at: probe))
        XCTAssertTrue(NotinhasNoteGeometry.hitTest(note: large, at: probe))
    }

    func testRectHitTestIncludesOversizedPin() {
        let note = NotinhasVisualNote(
            text: "Area",
            target: .rect(CGRect(x: 100, y: 40, width: 80, height: 40)),
            color: red,
            pinControlValue: 10,
            creationOrder: 1,
        )
        // Default pin corner is topLeft; a large diameter extends left of minX at maxY.
        let probe = CGPoint(x: 100 - note.pinDiameter / 2 + 1, y: 80)

        XCTAssertTrue(NotinhasNoteGeometry.hitTest(note: note, at: probe))
    }
}

@MainActor
final class NotinhasPinSizeAnnotateStateTests: XCTestCase {
    func testBeginDrawingUsesToolDefaultPinControlValue() {
        let state = AnnotateState(defaults: UserDefaultsFactory.make())
        state.activateTool(.notinhasNote)
        state.quickStrokeWidthBinding.wrappedValue = 6

        state.notinhasBeginDrawing(at: CGPoint(x: 10, y: 10), color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1))

        XCTAssertEqual(state.notinhasDraftNote?.pinControlValue, 6)
    }

    func testNoteToolShowsQuickPropertiesBarWithSize() {
        let state = AnnotateState(defaults: UserDefaultsFactory.make())
        state.activateTool(.notinhasNote)

        XCTAssertTrue(state.showsQuickPropertiesBar)
        XCTAssertTrue(state.quickPropertiesSupportsStrokeWidth)
        XCTAssertEqual(state.quickPropertiesTool, .notinhasNote)
    }

    func testQuickStrokeColorUpdatesSelectedNoteColor() throws {
        let state = AnnotateState(defaults: UserDefaultsFactory.make())
        let note = NotinhasVisualNote(
            text: "Pin",
            target: .point(CGPoint(x: 20, y: 20)),
            color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1),
            creationOrder: 1,
        )
        state.notinhasAddNote(note)
        state.notinhasSelectNote(id: note.id)
        state.activateTool(.notinhasNote)

        state.quickStrokeColorBinding.wrappedValue = .blue

        let updated = state.notinhasNotes.first(where: { $0.id == note.id })
        let expected = RGBAColor(color: .blue)
        XCTAssertNotNil(updated)
        XCTAssertNotNil(expected)
        XCTAssertEqual(try XCTUnwrap(updated?.color.red), try XCTUnwrap(expected?.red), accuracy: 0.02)
        XCTAssertEqual(try XCTUnwrap(updated?.color.green), try XCTUnwrap(expected?.green), accuracy: 0.02)
        XCTAssertEqual(try XCTUnwrap(updated?.color.blue), try XCTUnwrap(expected?.blue), accuracy: 0.02)
    }

    func testBeginDrawingUsesToolDefaultQuickStrokeColor() {
        let state = AnnotateState(defaults: UserDefaultsFactory.make())
        state.activateTool(.notinhasNote)
        state.quickStrokeColorBinding.wrappedValue = .green

        let color = RGBAColor(color: state.quickStrokeColorBinding.wrappedValue)
            ?? RGBAColor(red: 0, green: 1, blue: 0, alpha: 1)
        state.notinhasBeginDrawing(at: CGPoint(x: 12, y: 12), color: color)

        XCTAssertEqual(state.notinhasDraftNote?.color, color)
    }
}
