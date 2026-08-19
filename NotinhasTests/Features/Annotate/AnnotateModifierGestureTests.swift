//
//  AnnotateModifierGestureTests.swift
//  NotinhasTests
//
//  Shift square/circle constrain, Option-drag duplicate, and annotation clipboard.
//

import AppKit
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

    @MainActor
    func testCopyWithEmptySelectionClearsAnnotationClipboard() {
        let state = makeAnnotateState()
        let original = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 0, y: 0, width: 20, height: 20),
            properties: AnnotationProperties(),
        )
        state.annotations = [original]
        state.setSelectedAnnotationIds([original.id])
        state.copySelectedAnnotationsToClipboard()
        XCTAssertTrue(state.hasAnnotationClipboard)

        state.deselectAnnotation()
        state.copySelectedAnnotationsToClipboard()

        XCTAssertFalse(state.hasAnnotationClipboard)
    }

    @MainActor
    func testRepeatedPasteAccumulatesOffset() throws {
        let state = makeAnnotateState()
        let original = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 10, y: 20, width: 40, height: 30),
            properties: AnnotationProperties(),
        )
        state.annotations = [original]
        state.setSelectedAnnotationIds([original.id])
        state.copySelectedAnnotationsToClipboard()

        state.pasteAnnotationsFromClipboard()
        state.pasteAnnotationsFromClipboard()

        XCTAssertEqual(state.annotations.count, 3)
        let pasted = state.annotations
            .filter { $0.id != original.id }
            .sorted { $0.bounds.origin.x < $1.bounds.origin.x }
        XCTAssertEqual(pasted.count, 2)
        XCTAssertEqual(pasted[0].bounds.origin.x, 22, accuracy: 0.001)
        XCTAssertEqual(pasted[0].bounds.origin.y, 32, accuracy: 0.001)
        XCTAssertEqual(pasted[1].bounds.origin.x, 34, accuracy: 0.001)
        XCTAssertEqual(pasted[1].bounds.origin.y, 44, accuracy: 0.001)
    }

    @MainActor
    func testDuplicateWithoutMoveUsesSingleUndoCheckpoint() throws {
        let state = makeAnnotateState()
        let original = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 0, y: 0, width: 30, height: 20),
            properties: AnnotationProperties(),
        )
        state.annotations = [original]
        state.setSelectedAnnotationIds([original.id])

        let cloneIds = state.duplicateAnnotations(withIds: [original.id])
        XCTAssertEqual(state.annotations.count, 2)
        XCTAssertTrue(state.canUndo)

        state.undo()

        XCTAssertEqual(state.annotations.count, 1)
        XCTAssertEqual(state.annotations.first?.id, original.id)
        XCTAssertFalse(cloneIds.contains(original.id))
    }

    @MainActor
    func testDuplicateDetailMapsAnchorCloneID() throws {
        let state = makeAnnotateState()
        let lower = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 0, y: 0, width: 20, height: 20),
            properties: AnnotationProperties(),
        )
        let upper = AnnotationItem(
            type: .rectangle,
            bounds: CGRect(x: 40, y: 40, width: 20, height: 20),
            properties: AnnotationProperties(),
        )
        state.annotations = [lower, upper]
        state.setSelectedAnnotationIds([lower.id, upper.id])

        let detail = state.duplicateAnnotationsDetail(withIds: [lower.id, upper.id], anchorOriginalId: upper.id)

        XCTAssertEqual(detail.cloneIds.count, 2)
        let anchorClone = try XCTUnwrap(detail.anchorCloneId)
        XCTAssertNotEqual(anchorClone, upper.id)
        XCTAssertTrue(detail.cloneIds.contains(anchorClone))
    }

    @MainActor
    func testDuplicateEmbeddedImageUsesDistinctAssetID() throws {
        let state = makeAnnotateState()
        state.loadImage(NSImage(size: NSSize(width: 200, height: 200)), url: nil)
        state.importImage(NSImage(size: NSSize(width: 50, height: 50)))

        let embedded = try XCTUnwrap(state.annotations.last)
        guard case .embeddedImage(let originalAssetId) = embedded.type else {
            return XCTFail("Expected embedded image annotation")
        }

        let cloneIds = state.duplicateAnnotations(withIds: [embedded.id], anchorOriginalId: embedded.id)
        let clone = try XCTUnwrap(state.annotations.first { cloneIds.contains($0.id) })
        guard case .embeddedImage(let cloneAssetId) = clone.type else {
            return XCTFail("Expected duplicated embedded image annotation")
        }

        XCTAssertNotEqual(cloneAssetId, originalAssetId)
        XCTAssertNotNil(state.embeddedImage(for: cloneAssetId))
    }
}
