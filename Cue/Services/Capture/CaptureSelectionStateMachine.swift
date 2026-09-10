//
//  CaptureSelectionStateMachine.swift
//  Cue
//
//  Pure state machine managing the interactive lifecycle of area selection:
//  idle -> selecting -> selected <-> moving / resizing.
//

import CoreGraphics
import Foundation

// MARK: - CaptureSelectionPhase

enum CaptureSelectionPhase: Equatable, Sendable {
    case idle
    case selecting(startPoint: CGPoint, currentPoint: CGPoint, rect: CGRect)
    case selected(rect: CGRect)
    case moving(initialRect: CGRect, currentRect: CGRect, startPoint: CGPoint, currentPoint: CGPoint)
    case resizing(
        initialRect: CGRect,
        currentRect: CGRect,
        handle: CaptureSelectionResizeHandle,
        aspectLocked: Bool,
        aspectRatio: CGFloat?,
    )
}

// MARK: - CaptureSelectionStateMachine

struct CaptureSelectionStateMachine: Equatable, Sendable {
    private(set) var phase: CaptureSelectionPhase = .idle

    var currentRect: CGRect? {
        switch phase {
        case .idle:
            nil
        case .selecting(_, _, let rect):
            rect
        case .selected(let rect):
            rect
        case .moving(_, let currentRect, _, _):
            currentRect
        case .resizing(_, let currentRect, _, _, _):
            currentRect
        }
    }

    var isSelecting: Bool {
        if case .selecting = phase {
            return true
        }
        return false
    }

    var isMoving: Bool {
        if case .moving = phase {
            return true
        }
        return false
    }

    var isResizing: Bool {
        if case .resizing = phase {
            return true
        }
        return false
    }

    var isInteracting: Bool {
        switch phase {
        case .idle, .selected:
            false
        case .selecting, .moving, .resizing:
            true
        }
    }

    // MARK: - Transitions

    /// Starts a fresh drag-selection at the given point.
    mutating func startSelection(at point: CGPoint) {
        phase = .selecting(startPoint: point, currentPoint: point, rect: CGRect(origin: point, size: .zero))
    }

    /// Updates an in-progress drag selection.
    /// - Parameters:
    ///   - point: The current mouse/pointer location.
    ///   - squareConstrained: True when Shift is held to enforce a 1:1 aspect ratio.
    ///   - snappedRect: An optional pre-computed snapped rectangle (e.g. from edge/window snapping).
    mutating func updateSelection(
        to point: CGPoint,
        squareConstrained: Bool = false,
        snappedRect: CGRect? = nil,
    ) {
        guard case .selecting(let startPoint, _, _) = phase else { return }

        let rect: CGRect
        if let snappedRect {
            rect = snappedRect
        } else {
            var width = point.x - startPoint.x
            var height = point.y - startPoint.y

            if squareConstrained {
                let side = max(abs(width), abs(height))
                width = width < 0 ? -side : side
                height = height < 0 ? -side : side
            }

            rect = CGRect(
                x: min(startPoint.x, startPoint.x + width),
                y: min(startPoint.y, startPoint.y + height),
                width: abs(width),
                height: abs(height),
            )
        }

        phase = .selecting(startPoint: startPoint, currentPoint: point, rect: rect)
    }

    /// Commits the active drag-selection if it meets the minimum size requirements.
    /// - Parameter minSize: Minimum width and height required to commit (default:
    /// `CaptureSelectionChromeMetrics.creationMinimumSize`).
    /// - Returns: The committed rectangle if valid, or nil if discarded.
    @discardableResult
    mutating func commitSelection(minSize: CGFloat = CaptureSelectionChromeMetrics.creationMinimumSize) -> CGRect? {
        guard case .selecting(_, _, let rect) = phase else {
            return currentRect
        }

        if rect.width >= minSize, rect.height >= minSize {
            let confirmed = rect.standardized
            phase = .selected(rect: confirmed)
            return confirmed
        } else {
            phase = .idle
            return nil
        }
    }

    /// Explicitly adopts a known selected rectangle (e.g. from restored last selection or window selection).
    mutating func select(rect: CGRect) {
        phase = .selected(rect: rect.standardized)
    }

    /// Starts moving an existing selection.
    mutating func startMove(from point: CGPoint) {
        guard let rect = currentRect else { return }
        phase = .moving(initialRect: rect, currentRect: rect, startPoint: point, currentPoint: point)
    }

    /// Updates an in-progress move gesture.
    /// - Parameters:
    ///   - point: The current mouse/pointer location.
    ///   - bounds: Optional bounding rectangle (e.g. desktop union frame) to clamp movement.
    mutating func updateMove(to point: CGPoint, clampedToBounds bounds: CGRect? = nil) {
        guard case .moving(let initialRect, _, let startPoint, _) = phase else { return }

        let translation = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)
        var newRect = initialRect.offsetBy(dx: translation.x, dy: translation.y)

        if let bounds {
            if newRect.width <= bounds.width {
                if newRect.minX < bounds.minX {
                    newRect.origin.x = bounds.minX
                }
                if newRect.maxX > bounds.maxX {
                    newRect.origin.x = bounds.maxX - newRect.width
                }
            }
            if newRect.height <= bounds.height {
                if newRect.minY < bounds.minY {
                    newRect.origin.y = bounds.minY
                }
                if newRect.maxY > bounds.maxY {
                    newRect.origin.y = bounds.maxY - newRect.height
                }
            }
        }

        phase = .moving(initialRect: initialRect, currentRect: newRect, startPoint: startPoint, currentPoint: point)
    }

    /// Completes the move gesture, settling into `.selected`.
    @discardableResult
    mutating func finishMove() -> CGRect? {
        guard case .moving(_, let currentRect, _, _) = phase else { return currentRect }
        let settled = currentRect.standardized
        phase = .selected(rect: settled)
        return settled
    }

    /// Starts resizing an existing selection using a specific handle.
    mutating func startResize(
        handle: CaptureSelectionResizeHandle,
        aspectLocked: Bool = false,
        aspectRatio: CGFloat? = nil,
    ) {
        guard let rect = currentRect else { return }
        let effectiveRatio = aspectLocked ? (aspectRatio ?? CaptureSelectionGeometry.aspectRatio(of: rect)) : nil
        phase = .resizing(
            initialRect: rect,
            currentRect: rect,
            handle: handle,
            aspectLocked: aspectLocked,
            aspectRatio: effectiveRatio,
        )
    }

    /// Updates an in-progress resize gesture.
    /// - Parameters:
    ///   - proposedRect: The proposed new rectangle (e.g. from mouse drag or snapped bounds).
    ///   - minSize: Minimum size constraint.
    mutating func updateResize(
        to proposedRect: CGRect,
        minSize: CGFloat = CaptureSelectionGeometry.defaultMinSize,
    ) {
        guard case .resizing(let initialRect, _, let handle, let aspectLocked, let aspectRatio) = phase else { return }

        let normalized: CGRect
        if aspectLocked, let ratio = aspectRatio, ratio > 0 {
            let translation = CGPoint(
                x: proposedRect.origin.x - initialRect.origin.x,
                y: proposedRect.origin.y - initialRect.origin.y,
            )
            normalized = CaptureSelectionGeometry.resizedRect(
                original: initialRect,
                handle: handle,
                translation: translation,
                aspectLocked: true,
                aspectRatio: ratio,
                minSize: minSize,
            )
        } else {
            normalized = CaptureSelectionGeometry.normalized(proposedRect, minSize: minSize)
        }

        phase = .resizing(
            initialRect: initialRect,
            currentRect: normalized,
            handle: handle,
            aspectLocked: aspectLocked,
            aspectRatio: aspectRatio,
        )
    }

    /// Completes the resize gesture, settling into `.selected`.
    @discardableResult
    mutating func finishResize() -> CGRect? {
        guard case .resizing(_, let currentRect, _, _, _) = phase else { return currentRect }
        let settled = currentRect.standardized
        phase = .selected(rect: settled)
        return settled
    }

    /// Cancels any active gesture or selection and resets to `.idle`.
    mutating func reset() {
        phase = .idle
    }
}
