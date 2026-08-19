//
//  AnnotateModifierGestureTests.swift
//  NotinhasTests
//
//  Shift square/circle constrain, Option-drag duplicate, and annotation clipboard.
//

import CoreGraphics
@testable import Notinhas
import XCTest

final class AnnotateModifierGestureTests: XCTestCase {
    @MainActor private static var retainedAnnotateStates: [AnnotateState] = []

    @MainActor
    private func makeAnnotateState() -> AnnotateState {
        let state = AnnotateState(defaults: UserDefaultsFactory.make())
        Self.retainedAnnotateStates.append(state)
        return state
    }

    func testShiftSquareCornerConstrainsEqualDelta() {
        let start = CGPoint(x: 10, y: 20)
        let end = CGPoint(x: 97, y: 52)

        let constrained = AnnotationAngleSnapping.snapSquareCorner(end, from: start)

        XCTAssertEqual(abs(constrained.x - start.x), abs(constrained.y - start.y), accuracy: 0.001)
        XCTAssertEqual(abs(constrained.x - start.x), 87, accuracy: 0.001)
        XCTAssertEqual(constrained.x, 97, accuracy: 0.001)
        XCTAssertEqual(constrained.y, 107, accuracy: 0.001)
    }

    func testShiftSquareCornerPreservesNegativeQuadrant() {
        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 40, y: 160)

        let constrained = AnnotationAngleSnapping.snapSquareCorner(end, from: start)

        XCTAssertEqual(abs(constrained.x - start.x), abs(constrained.y - start.y), accuracy: 0.001)
        XCTAssertEqual(constrained.x, 40, accuracy: 0.001)
        XCTAssertEqual(constrained.y, 160, accuracy: 0.001)
    }

    @MainActor
    func testDuplicateAnnotationsCreatesNewIDsAndLeavesOriginals() throws {
        let state = makeAnnotateState()
        let original = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 10, y: 20, width: 40, height: 30),
            properties: AnnotationProperties(),
        )
        state.annotations = [original]
        state.setSelectedAnnotationIds([original.id])

        let cloneIds = state.duplicateAnnotations(withIds: [original.id])

        XCTAssertEqual(cloneIds.count, 1)
        let cloneId = try XCTUnwrap(cloneIds.first)
        XCTAssertNotEqual(cloneId, original.id)
        XCTAssertEqual(state.annotations.count, 2)
        XCTAssertEqual(state.selectedAnnotationIds, cloneIds)

        let untouchedOriginal = try XCTUnwrap(state.annotations.first { $0.id == original.id })
        XCTAssertEqual(untouchedOriginal.bounds, original.bounds)

        let clone = try XCTUnwrap(state.annotations.first { $0.id == cloneId })
        XCTAssertEqual(clone.bounds, original.bounds)
    }

    @MainActor
    func testDuplicateCounterAnnotationsAssignFreshCounterValues() throws {
        let state = makeAnnotateState()
        let counter = AnnotationItem(
            type: .counter(3),
            bounds: CGRect(x: 0, y: 0, width: 32, height: 32),
            properties: AnnotationProperties(strokeWidth: 3),
        )
        state.annotations = [counter]
        state.setSelectedAnnotationIds([counter.id])

        let cloneIds = state.duplicateAnnotations(withIds: [counter.id])
        let clone = try XCTUnwrap(state.annotations.first { $0.id == cloneIds.first })

        guard case .counter(let cloneValue) = clone.type else {
            return XCTFail("Expected duplicated counter annotation")
        }
        XCTAssertEqual(cloneValue, 4)
    }

    @MainActor
    func testPasteAnnotationsOffsetsAndAssignsNewIDs() throws {
        let state = makeAnnotateState()
        let original = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 10, y: 20, width: 40, height: 30),
            properties: AnnotationProperties(),
        )
        state.annotations = [original]
        state.setSelectedAnnotationIds([original.id])

        state.copySelectedAnnotationsToClipboard()
        XCTAssertTrue(state.hasAnnotationClipboard)

        state.pasteAnnotationsFromClipboard()

        XCTAssertEqual(state.annotations.count, 2)
        let pasted = try XCTUnwrap(state.annotations.last)
        XCTAssertNotEqual(pasted.id, original.id)
        XCTAssertEqual(pasted.bounds.origin.x, original.bounds.origin.x + 12, accuracy: 0.001)
        XCTAssertEqual(pasted.bounds.origin.y, original.bounds.origin.y + 12, accuracy: 0.001)
        XCTAssertEqual(state.selectedAnnotationIds, [pasted.id])
    }
}
