//
//  CaptureSelectionStateMachineTests.swift
//  CueTests
//
//  Unit tests for CaptureSelectionStateMachine pure lifecycle transitions.
//

import CoreGraphics
@testable import Cue
import XCTest

final class CaptureSelectionStateMachineTests: XCTestCase {
    func testInitialState_isIdle() {
        let machine = CaptureSelectionStateMachine()
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertNil(machine.currentRect)
        XCTAssertFalse(machine.isSelecting)
        XCTAssertFalse(machine.isMoving)
        XCTAssertFalse(machine.isResizing)
        XCTAssertFalse(machine.isInteracting)
    }

    func testSelection_dragAndCommit() {
        var machine = CaptureSelectionStateMachine()
        machine.startSelection(at: CGPoint(x: 100, y: 100))

        XCTAssertTrue(machine.isSelecting)
        XCTAssertTrue(machine.isInteracting)

        // Drag to bottom-right
        machine.updateSelection(to: CGPoint(x: 250, y: 300))
        XCTAssertEqual(machine.currentRect, CGRect(x: 100, y: 100, width: 150, height: 200))

        // Drag in reverse (top-left of start)
        machine.updateSelection(to: CGPoint(x: 50, y: 40))
        XCTAssertEqual(machine.currentRect, CGRect(x: 50, y: 40, width: 50, height: 60))

        let committed = machine.commitSelection(minSize: 10)
        XCTAssertEqual(committed, CGRect(x: 50, y: 40, width: 50, height: 60))
        XCTAssertEqual(machine.phase, .selected(rect: CGRect(x: 50, y: 40, width: 50, height: 60)))
        XCTAssertFalse(machine.isSelecting)
        XCTAssertFalse(machine.isInteracting)
    }

    func testSelection_underMinimumSize_isDiscarded() {
        var machine = CaptureSelectionStateMachine()
        machine.startSelection(at: CGPoint(x: 100, y: 100))
        machine.updateSelection(to: CGPoint(x: 103, y: 104))

        let committed = machine.commitSelection(minSize: 10)
        XCTAssertNil(committed)
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertNil(machine.currentRect)
    }

    func testSelection_squareConstraintWithShift() {
        var machine = CaptureSelectionStateMachine()
        machine.startSelection(at: CGPoint(x: 100, y: 100))
        machine.updateSelection(to: CGPoint(x: 200, y: 150), squareConstrained: true)

        XCTAssertEqual(machine.currentRect, CGRect(x: 100, y: 100, width: 100, height: 100))
    }

    func testMove_updatesAndClampsToBounds() throws {
        var machine = CaptureSelectionStateMachine()
        let initialRect = CGRect(x: 100, y: 100, width: 200, height: 100)
        machine.select(rect: initialRect)

        machine.startMove(from: CGPoint(x: 150, y: 150))
        XCTAssertTrue(machine.isMoving)
        XCTAssertTrue(machine.isInteracting)

        // Normal translation
        machine.updateMove(to: CGPoint(x: 170, y: 180))
        XCTAssertEqual(machine.currentRect, CGRect(x: 120, y: 130, width: 200, height: 100))

        // Clamping to desktop bounds
        let desktop = CGRect(x: 50, y: 50, width: 400, height: 300)
        machine.updateMove(to: CGPoint(x: 0, y: 0), clampedToBounds: desktop)
        XCTAssertEqual(machine.currentRect?.minX, desktop.minX)
        XCTAssertEqual(machine.currentRect?.minY, desktop.minY)

        let settled = machine.finishMove()
        XCTAssertEqual(settled, machine.currentRect)
        XCTAssertEqual(machine.phase, try .selected(rect: XCTUnwrap(settled)))
        XCTAssertFalse(machine.isMoving)
    }

    func testResize_freeAndAspectLocked() throws {
        var machine = CaptureSelectionStateMachine()
        let initialRect = CGRect(x: 100, y: 100, width: 200, height: 100) // Aspect ratio 2:1
        machine.select(rect: initialRect)

        // Aspect-locked resize
        machine.startResize(handle: .topRight, aspectLocked: true)
        XCTAssertTrue(machine.isResizing)
        XCTAssertTrue(machine.isInteracting)

        machine.updateResize(to: CGRect(x: 100, y: 100, width: 300, height: 250))
        let resized = try XCTUnwrap(machine.currentRect)
        XCTAssertEqual(resized.width / resized.height, 2.0, accuracy: 0.001)

        let settled = machine.finishResize()
        XCTAssertEqual(machine.phase, try .selected(rect: XCTUnwrap(settled)))
        XCTAssertFalse(machine.isResizing)
    }

    func testReset_cancelsAnyPhase() {
        var machine = CaptureSelectionStateMachine()
        machine.startSelection(at: CGPoint(x: 50, y: 50))
        machine.updateSelection(to: CGPoint(x: 100, y: 100))
        XCTAssertTrue(machine.isSelecting)

        machine.reset()
        XCTAssertEqual(machine.phase, .idle)
        XCTAssertNil(machine.currentRect)
    }
}
